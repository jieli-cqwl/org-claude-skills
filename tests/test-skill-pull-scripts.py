#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL_SCRIPTS = ROOT / "shared" / "skills" / "skill-pull" / "scripts"
SOURCE_LOCK_FIXTURE = ROOT / "tests" / "fixtures" / "skill-pull" / "SOURCES.yaml"


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, SKILL_SCRIPTS / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load module: {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def write_source_lock(path: Path) -> None:
    path.write_text(SOURCE_LOCK_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")


def make_anthropic_status(lib, *, status: str = "update", summary: str = ""):
    return lib.SourceStatus(
        name="anthropic_skills",
        status=status,
        current_ref="aaa111",
        candidate_ref="aaa111" if status == "current" else "new999",
        candidate_source="fixture" if status == "current" else "release",
        summary=summary,
    )


class CandidateLookupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lib = load_module("skill_pull_lib", "skill_pull_lib.py")
        self.temp_dir = tempfile.TemporaryDirectory()
        self.lock_path = Path(self.temp_dir.name) / "SOURCES.yaml"
        write_source_lock(self.lock_path)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_managed_sources_match_source_lock(self) -> None:
        locks = self.lib.load_source_locks(self.lock_path)
        managed = self.lib.managed_locks(locks)

        self.assertEqual(
            set(managed),
            {
                "anthropic_skills",
                "superpowers",
                "vercel_skills",
                "vercel_agent_browser",
                "alchaincyf_darwin_skill",
                "nextlevelbuilder_ui_ux_pro_max",
                "persona_colleague_skill",
                "persona_nuwa_skill",
                "persona_yourself_skill",
                "persona_midas_skill",
            },
        )

    def test_no_update_when_candidate_equals_locked_ref(self) -> None:
        locks = self.lib.load_source_locks(self.lock_path)
        candidates = {
            name: self.lib.CandidateRef(name=name, ref=lock.ref, source="fixture")
            for name, lock in self.lib.managed_locks(locks).items()
        }

        statuses = self.lib.classify_candidates(locks, candidates)

        self.assertTrue(statuses)
        self.assertTrue(all(status.status == "current" for status in statuses))

    def test_update_when_candidate_differs_from_locked_ref(self) -> None:
        locks = self.lib.load_source_locks(self.lock_path)
        candidates = {
            "anthropic_skills": self.lib.CandidateRef(
                name="anthropic_skills",
                ref="new999",
                source="release",
                summary="v2.0.0",
            )
        }

        statuses = self.lib.classify_candidates(locks, candidates)
        by_name = {status.name: status for status in statuses}

        self.assertEqual(by_name["anthropic_skills"].status, "update")
        self.assertEqual(by_name["anthropic_skills"].current_ref, "aaa111")
        self.assertEqual(by_name["anthropic_skills"].candidate_ref, "new999")

    def test_blocked_when_candidate_lookup_failed(self) -> None:
        locks = self.lib.load_source_locks(self.lock_path)
        candidates = {
            "superpowers": self.lib.CandidateRef(
                name="superpowers",
                ref="",
                source="error",
                blocker="release lookup failed",
            )
        }

        statuses = self.lib.classify_candidates(locks, candidates)
        by_name = {status.name: status for status in statuses}

        self.assertEqual(by_name["superpowers"].status, "blocked")
        self.assertEqual(by_name["superpowers"].blocker, "release lookup failed")


class FakeRunner:
    def __init__(self, fail_contains: str = "") -> None:
        self.commands: list[list[str]] = []
        self.fail_contains = fail_contains

    def run(self, cmd: list[str], cwd: Path | None = None):
        self.commands.append(cmd)
        text = " ".join(cmd)
        returncode = 1 if self.fail_contains and self.fail_contains in text else 0
        stdout = "abc123\n" if cmd == ["git", "rev-parse", "--short", "HEAD"] else ""
        return type(
            "Result",
            (),
            {
                "returncode": returncode,
                "stdout": stdout,
                "stderr": f"failed: {text}" if returncode else "",
            },
        )()


class RunUpdateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lib = load_module("skill_pull_lib", "skill_pull_lib.py")
        self.run_update = load_module("run_update", "run_update.py")
        self.summarize = load_module("summarize_changes", "summarize_changes.py")
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo_root = Path(self.temp_dir.name)
        (self.repo_root / "community").mkdir()
        (self.repo_root / ".worktrees").mkdir()
        write_source_lock(self.repo_root / "community" / "SOURCES.yaml")

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_branch_name_uses_date_and_suffix_on_conflict(self) -> None:
        branch = self.run_update.make_update_branch_name(
            "2026-04-22",
            {
                "codex/skill-pull-20260422",
                "codex/skill-pull-20260422-2",
            },
        )

        self.assertEqual(branch, "codex/skill-pull-20260422-3")

    def test_no_update_does_not_leave_worktree_or_branch(self) -> None:
        statuses = [make_anthropic_status(self.lib, status="current")]
        runner = FakeRunner()

        result = self.run_update.run_update_flow(
            repo_root=self.repo_root,
            statuses=statuses,
            today="2026-04-22",
            runner=runner,
            existing_branches=set(),
        )

        self.assertEqual(result.status, "current")
        self.assertEqual(runner.commands, [])
        self.assertFalse(any((self.repo_root / ".worktrees").iterdir()))
        result_path = self.repo_root / "current-result.json"
        result_path.write_text(
            json.dumps(self.run_update.build_report_payload(result, statuses)),
            encoding="utf-8",
        )
        summary = self.summarize.render_summary(result_path)
        self.assertIn("anthropic_skills", summary)
        self.assertIn("aaa111", summary)

    def test_superpowers_sync_command_has_no_body_rewrite_mode(self) -> None:
        command = self.run_update.SYNC_COMMANDS["superpowers"]

        self.assertEqual(
            command, ["python3", "tools/community/sync_canonical_from_upstream.py"]
        )
        command_text = " ".join(command)
        for marker in (
            "--skip-" + "translate",
            "deep_" + "translator",
            "Google" + "Translator",
            "zh-" + "CN",
        ):
            self.assertNotIn(marker, command_text)

    def test_persona_sources_share_one_sync_command(self) -> None:
        statuses = [
            self.lib.SourceStatus(
                name="persona_colleague_skill",
                status="update",
                current_ref="ggg777",
                candidate_ref="new777",
                candidate_source="default_branch",
            ),
            self.lib.SourceStatus(
                name="persona_nuwa_skill",
                status="update",
                current_ref="hhh888",
                candidate_ref="new888",
                candidate_source="default_branch",
            ),
        ]

        commands = self.run_update._sync_commands_for(statuses)

        self.assertEqual(
            commands,
            [["python3", "tools/community/sync_persona_skills_from_upstream.py"]],
        )

    def test_update_runs_sync_validations_install_commit_and_cleanup_in_order(
        self,
    ) -> None:
        statuses = [make_anthropic_status(self.lib, summary="v2.0.0")]
        runner = FakeRunner()

        result = self.run_update.run_update_flow(
            repo_root=self.repo_root,
            statuses=statuses,
            today="2026-04-22",
            runner=runner,
            existing_branches=set(),
        )

        command_text = [" ".join(command) for command in runner.commands]
        self.assertEqual(result.status, "updated")
        self.assertIn("git worktree add", command_text[0])
        self.assertLess(
            command_text.index("bash tests/test-install-runtime-smoke.sh"),
            command_text.index("bash install.sh --target all --check full"),
        )
        self.assertLess(
            command_text.index("bash tests/test-community-tools.sh"),
            command_text.index(
                "python3 tools/community/check_superpowers_upstream_fidelity.py"
            ),
        )
        self.assertLess(
            command_text.index(
                "python3 tools/community/check_superpowers_upstream_fidelity.py"
            ),
            command_text.index("bash tests/test-single-source-layout.sh"),
        )
        self.assertLess(
            command_text.index("bash install.sh --target all --check full"),
            command_text.index("bash install.sh --target all"),
        )
        self.assertIn(
            "python3 tools/community/sync_anthropic_skills_from_upstream.py",
            command_text,
        )
        self.assertIn("git commit -m chore: pull external skill sources", command_text)
        self.assertTrue(command_text[-1].startswith("git worktree remove"))
        self.assertFalse(Path(result.worktree_path).exists())

    def test_failure_preserves_worktree_and_stops_before_install(self) -> None:
        statuses = [make_anthropic_status(self.lib)]
        runner = FakeRunner(fail_contains="test-community-tools")

        result = self.run_update.run_update_flow(
            repo_root=self.repo_root,
            statuses=statuses,
            today="2026-04-22",
            runner=runner,
            existing_branches=set(),
        )

        command_text = [" ".join(command) for command in runner.commands]
        self.assertEqual(result.status, "blocked")
        self.assertIn("bash tests/test-community-tools.sh", command_text)
        self.assertNotIn("bash install.sh --target all", command_text)
        self.assertTrue(Path(result.worktree_path).exists())
        updated_lock = (
            Path(result.worktree_path) / "community" / "SOURCES.yaml"
        ).read_text(encoding="utf-8")
        self.assertIn("ref: new999", updated_lock)

    def test_update_report_payload_feeds_conversation_summary(self) -> None:
        statuses = [make_anthropic_status(self.lib, summary="v2.0.0")]

        result = self.run_update.run_update_flow(
            repo_root=self.repo_root,
            statuses=statuses,
            today="2026-04-22",
            runner=FakeRunner(),
            existing_branches=set(),
        )
        result_path = self.repo_root / "result.json"
        result_path.write_text(
            json.dumps(self.run_update.build_report_payload(result, statuses)),
            encoding="utf-8",
        )

        summary = self.summarize.render_summary(result_path)

        self.assertIn("aaa111 -> new999", summary)
        self.assertIn("bash install.sh --target all --check full", summary)
        self.assertIn("bash install.sh --target all", summary)
        self.assertIn("abc123", summary)


class SummaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.summarize = load_module("summarize_changes", "summarize_changes.py")
        self.temp_dir = tempfile.TemporaryDirectory()
        self.result_path = Path(self.temp_dir.name) / "result.json"

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_success_summary_contains_required_sections(self) -> None:
        self.result_path.write_text(
            json.dumps(
                {
                    "result": {
                        "status": "updated",
                        "branch": "codex/skill-pull-20260422",
                        "commit": "abc123",
                    },
                    "sources": [
                        {
                            "name": "anthropic_skills",
                            "current_ref": "aaa111",
                            "candidate_ref": "new999",
                            "summary": "v2.0.0",
                        }
                    ],
                    "validations": [
                        {
                            "command": "bash tests/test-community-tools.sh",
                            "status": "passed",
                        }
                    ],
                    "install": {
                        "command": "bash install.sh --target all",
                        "status": "passed",
                    },
                }
            ),
            encoding="utf-8",
        )

        summary = self.summarize.render_summary(self.result_path)

        for section in (
            "Source updates",
            "Upstream changes",
            "Local adapter changes",
            "Validation results",
            "Install result",
            "Branch and commit",
        ):
            self.assertIn(section, summary)
        self.assertIn("anthropic_skills", summary)
        self.assertIn("aaa111 -> new999", summary)

    def test_blocked_summary_contains_failure_evidence_and_preserved_path(self) -> None:
        worktree_path = str(Path(tempfile.gettempdir()) / "skill-pull")
        self.result_path.write_text(
            json.dumps(
                {
                    "result": {
                        "status": "blocked",
                        "failed_phase": "validation",
                        "failed_command": "bash tests/test-community-tools.sh",
                        "worktree_path": worktree_path,
                        "stderr": "failed validation",
                    }
                }
            ),
            encoding="utf-8",
        )

        summary = self.summarize.render_summary(self.result_path)

        self.assertIn("Blocked", summary)
        self.assertIn("validation", summary)
        self.assertIn("bash tests/test-community-tools.sh", summary)
        self.assertIn(worktree_path, summary)
        self.assertIn("failed validation", summary)


if __name__ == "__main__":
    unittest.main(verbosity=2)
