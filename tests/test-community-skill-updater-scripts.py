#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL_SCRIPTS = ROOT / "shared" / "skills" / "community-skill-updater" / "scripts"


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, SKILL_SCRIPTS / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load module: {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def write_source_lock(path: Path) -> None:
    path.write_text(
        """sources:
  anthropic_skills:
    repo: https://github.com/anthropics/skills
    ref: aaa111
    captured_at: 2026-04-18
    scope:
      - community/anthropic/skills
    notes:
      - good
  openspec:
    repo: https://github.com/Fission-AI/OpenSpec
    ref: v1.2.0
    captured_at: 2026-03-27
    scope:
      - docs/commands.md
    notes:
      - historical
  superpowers:
    repo: https://github.com/obra/superpowers
    ref: bbb222
    captured_at: 2026-04-12
    scope:
      - community/superpowers
    notes:
      - good
  vercel_skills:
    repo: https://github.com/vercel-labs/skills
    ref: ccc333
    captured_at: 2026-04-12
    scope:
      - community/vercel/skills/find-skills
    notes:
      - good
  vercel_agent_browser:
    repo: https://github.com/vercel-labs/agent-browser
    ref: ddd444
    captured_at: 2026-04-12
    scope:
      - community/vercel/skills/agent-browser
    notes:
      - good
  alchaincyf_darwin_skill:
    repo: https://github.com/alchaincyf/darwin-skill
    ref: eee555
    captured_at: 2026-04-18
    scope:
      - community/alchaincyf/skills/darwin-skill
    notes:
      - good
  nextlevelbuilder_ui_ux_pro_max:
    repo: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
    ref: fff666
    captured_at: 2026-04-20
    scope:
      - community/nextlevelbuilder/skills/ui-ux-pro-max
    notes:
      - good
""",
        encoding="utf-8",
    )


class CandidateLookupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lib = load_module("community_skill_updater_lib", "community_skill_updater_lib.py")
        self.temp_dir = tempfile.TemporaryDirectory()
        self.lock_path = Path(self.temp_dir.name) / "SOURCES.yaml"
        write_source_lock(self.lock_path)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_managed_sources_exclude_openspec(self) -> None:
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
            },
        )
        self.assertNotIn("openspec", managed)

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
        self.lib = load_module("community_skill_updater_lib", "community_skill_updater_lib.py")
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
                "codex/community-skill-update-20260422",
                "codex/community-skill-update-20260422-2",
            },
        )

        self.assertEqual(branch, "codex/community-skill-update-20260422-3")

    def test_no_update_does_not_leave_worktree_or_branch(self) -> None:
        statuses = [
            self.lib.SourceStatus(
                name="anthropic_skills", status="current",
                current_ref="aaa111", candidate_ref="aaa111",
                candidate_source="fixture",
            )
        ]
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
        result_path.write_text(json.dumps(self.run_update.build_report_payload(result, statuses)), encoding="utf-8")
        summary = self.summarize.render_summary(result_path)
        self.assertIn("anthropic_skills", summary)
        self.assertIn("aaa111", summary)

    def test_superpowers_sync_command_has_no_body_rewrite_mode(self) -> None:
        command = self.run_update.SYNC_COMMANDS["superpowers"]

        self.assertEqual(command, ["python3", "tools/community/sync_canonical_from_upstream.py"])
        command_text = " ".join(command)
        for marker in (
            "--skip-" + "translate",
            "deep_" + "translator",
            "Google" + "Translator",
            "zh-" + "CN",
        ):
            self.assertNotIn(marker, command_text)

    def test_update_runs_sync_validations_install_commit_and_cleanup_in_order(self) -> None:
        statuses = [
            self.lib.SourceStatus(
                name="anthropic_skills", status="update",
                current_ref="aaa111", candidate_ref="new999",
                candidate_source="release", summary="v2.0.0",
            )
        ]
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
            command_text.index("python3 tools/community/check_superpowers_upstream_fidelity.py"),
        )
        self.assertLess(
            command_text.index("python3 tools/community/check_superpowers_upstream_fidelity.py"),
            command_text.index("bash tests/test-single-source-layout.sh"),
        )
        self.assertLess(
            command_text.index("bash install.sh --target all --check full"),
            command_text.index("bash install.sh --target all"),
        )
        self.assertIn("python3 tools/community/sync_anthropic_skills_from_upstream.py", command_text)
        self.assertIn("git commit -m chore: update community skill sources", command_text)
        self.assertTrue(command_text[-1].startswith("git worktree remove"))
        self.assertFalse(Path(result.worktree_path).exists())

    def test_failure_preserves_worktree_and_stops_before_install(self) -> None:
        statuses = [
            self.lib.SourceStatus(
                name="anthropic_skills",
                status="update",
                current_ref="aaa111",
                candidate_ref="new999",
                candidate_source="release",
            )
        ]
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
        updated_lock = (Path(result.worktree_path) / "community" / "SOURCES.yaml").read_text(encoding="utf-8")
        self.assertIn("ref: new999", updated_lock)

    def test_update_report_payload_feeds_conversation_summary(self) -> None:
        statuses = [
            self.lib.SourceStatus(
                name="anthropic_skills", status="update",
                current_ref="aaa111", candidate_ref="new999",
                candidate_source="release", summary="v2.0.0",
            )
        ]

        result = self.run_update.run_update_flow(
            repo_root=self.repo_root,
            statuses=statuses,
            today="2026-04-22",
            runner=FakeRunner(),
            existing_branches=set(),
        )
        result_path = self.repo_root / "result.json"
        result_path.write_text(json.dumps(self.run_update.build_report_payload(result, statuses)), encoding="utf-8")

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
                        "branch": "codex/community-skill-update-20260422",
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
                    "validations": [{"command": "bash tests/test-community-tools.sh", "status": "passed"}],
                    "install": {"command": "bash install.sh --target all", "status": "passed"},
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
        self.result_path.write_text(
            json.dumps(
                {
                    "result": {
                        "status": "blocked",
                        "failed_phase": "validation",
                        "failed_command": "bash tests/test-community-tools.sh",
                        "worktree_path": "/tmp/community-skill-update",
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
        self.assertIn("/tmp/community-skill-update", summary)
        self.assertIn("failed validation", summary)


if __name__ == "__main__":
    unittest.main(verbosity=2)
