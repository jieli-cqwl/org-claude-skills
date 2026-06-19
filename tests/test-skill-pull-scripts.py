#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import json
import time
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL_SCRIPTS = ROOT / "shared" / "skills" / "skill-pull" / "scripts"
SOURCE_LOCK_FIXTURE = ROOT / "tests/fixtures/skill-pull/SOURCES.yaml"


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


class TempDirTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()

    def tearDown(self) -> None:
        self.temp_dir.cleanup()


class CandidateLookupTests(TempDirTest):
    def setUp(self) -> None:
        super().setUp()
        self.lib = load_module("skill_pull_lib", "skill_pull_lib.py")
        self.lock_path = Path(self.temp_dir.name) / "SOURCES.yaml"
        write_source_lock(self.lock_path)

    def test_managed_sources_match_source_lock(self) -> None:
        locks = self.lib.load_source_locks(self.lock_path)
        managed = self.lib.managed_locks(locks)

        self.assertEqual(set(managed), set(self.lib.MANAGED_SOURCE_NAMES))
        self.assertIn("panniantong_agent_reach", self.lib.MANAGED_SOURCE_NAMES)
        self.assertIn(
            "skills_sh_alirezarezvani_code_to_prd", self.lib.MANAGED_SOURCE_NAMES
        )
        self.assertIn("skills_sh_bb_browser", self.lib.MANAGED_SOURCE_NAMES)
        self.assertIn("skills_sh_graphify", self.lib.MANAGED_SOURCE_NAMES)
        self.assertIn(
            "skills_sh_markdown_viewer_architecture", self.lib.MANAGED_SOURCE_NAMES
        )
        self.assertIn(
            "skills_sh_othmanadi_planning_with_files", self.lib.MANAGED_SOURCE_NAMES
        )
        self.assertIn("skills_sh_self_improving_agent", self.lib.MANAGED_SOURCE_NAMES)
        self.assertIn(
            "skills_sh_softaworks_mermaid_diagrams", self.lib.MANAGED_SOURCE_NAMES
        )
        self.assertIn(
            "skills_sh_github_prompt_optimizer", self.lib.MANAGED_SOURCE_NAMES
        )
        for retired in (
            "persona_colleague_skill",
            "persona_nuwa_skill",
            "persona_yourself_skill",
            "persona_midas_skill",
        ):
            self.assertNotIn(retired, self.lib.MANAGED_SOURCE_NAMES)

    def test_real_source_lock_has_all_managed_sources(self) -> None:
        locks = self.lib.load_source_locks(ROOT / "community/SOURCES.yaml")

        self.assertEqual(
            set(self.lib.managed_locks(locks)), set(self.lib.MANAGED_SOURCE_NAMES)
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

    def test_lookup_candidate_reports_git_timeout_as_blocker(self) -> None:
        lock = self.lib.SourceLock(
            name="vercel_agent_browser",
            repo="https://github.com/vercel-labs/agent-browser",
            ref="old-ref",
            captured_at="2026-06-18",
        )
        original_latest_release = self.lib._latest_release
        original_release_tag_ref = self.lib._release_tag_ref
        try:
            self.lib._latest_release = lambda repo: {"tag_name": "v0.28.0"}

            def timeout(_repo: str, _tag: str) -> str:
                raise subprocess.TimeoutExpired(["git", "ls-remote"], 30)

            self.lib._release_tag_ref = timeout

            candidate = self.lib.lookup_candidate(lock)
        finally:
            self.lib._latest_release = original_latest_release
            self.lib._release_tag_ref = original_release_tag_ref

        self.assertEqual(candidate.name, "vercel_agent_browser")
        self.assertEqual(candidate.source, "error")
        self.assertEqual(candidate.ref, "")
        self.assertIn("timed out", candidate.blocker)

    def test_git_ls_remote_retries_once_after_timeout(self) -> None:
        calls = []
        original_run_command = self.lib.run_command
        try:
            def fake_run_command(cmd, *, cwd=None, timeout=30):
                calls.append((cmd, timeout))
                if len(calls) == 1:
                    raise subprocess.TimeoutExpired(cmd, timeout)
                return type(
                    "Result",
                    (),
                    {
                        "returncode": 0,
                        "stdout": "abc123\trefs/tags/v1.0.0\n",
                        "stderr": "",
                    },
                )()

            self.lib.run_command = fake_run_command

            ref = self.lib._git_ls_remote(
                "https://github.com/example/project", "refs/tags/v1.0.0"
            )
        finally:
            self.lib.run_command = original_run_command

        self.assertEqual(ref, "abc123")
        self.assertEqual(len(calls), 2)
        self.assertTrue(all(timeout == 90 for _cmd, timeout in calls))

    def test_release_tag_ref_prefers_peeled_commit_from_single_lookup(self) -> None:
        calls = []
        original_run_command = self.lib.run_command
        try:
            def fake_run_command(cmd, *, cwd=None, timeout=30):
                calls.append(cmd)
                return type(
                    "Result",
                    (),
                    {
                        "returncode": 0,
                        "stdout": (
                            "tag-object\trefs/tags/v6.0.3\n"
                            "commit-ref\trefs/tags/v6.0.3^{}\n"
                        ),
                        "stderr": "",
                    },
                )()

            self.lib.run_command = fake_run_command

            ref = self.lib._release_tag_ref(
                "https://github.com/obra/superpowers", "v6.0.3"
            )
        finally:
            self.lib.run_command = original_run_command

        self.assertEqual(ref, "commit-ref")
        self.assertEqual(len(calls), 1)

    def test_default_branch_candidate_resolves_name_and_commit_from_one_lookup(self) -> None:
        calls = []
        original_run_command = self.lib.run_command
        try:
            def fake_run_command(cmd, *, cwd=None, timeout=30):
                calls.append(cmd)
                return type(
                    "Result",
                    (),
                    {
                        "returncode": 0,
                        "stdout": (
                            "ref: refs/heads/main\tHEAD\n"
                            "main-commit\tHEAD\n"
                        ),
                        "stderr": "",
                    },
                )()

            self.lib.run_command = fake_run_command

            branch, ref = self.lib._default_branch_candidate(
                "https://github.com/anthropics/skills"
            )
        finally:
            self.lib.run_command = original_run_command

        self.assertEqual(branch, "refs/heads/main")
        self.assertEqual(ref, "main-commit")
        self.assertEqual(len(calls), 1)

    def test_lookup_candidates_reuses_one_upstream_lookup_per_repo(self) -> None:
        locks = {
            "skills_sh_github_prd": self.lib.SourceLock(
                name="skills_sh_github_prd",
                repo="https://github.com/github/awesome-copilot",
                ref="old-prd",
                captured_at="2026-06-18",
            ),
            "skills_sh_github_prompt_optimizer": self.lib.SourceLock(
                name="skills_sh_github_prompt_optimizer",
                repo="https://github.com/github/awesome-copilot",
                ref="old-prompt",
                captured_at="2026-06-18",
            ),
        }
        original_latest_release = self.lib._latest_release
        original_default_branch_candidate = self.lib._default_branch_candidate
        try:
            self.lib._latest_release = lambda repo: None

            default_branch_calls = []

            def fake_default_branch_candidate(repo: str) -> tuple[str, str]:
                default_branch_calls.append(repo)
                return "refs/heads/main", "new-shared-ref"

            self.lib._default_branch_candidate = fake_default_branch_candidate

            candidates = self.lib.lookup_candidates(locks)
        finally:
            self.lib._latest_release = original_latest_release
            self.lib._default_branch_candidate = original_default_branch_candidate

        self.assertEqual(default_branch_calls, ["https://github.com/github/awesome-copilot"])
        self.assertEqual(candidates["skills_sh_github_prd"].name, "skills_sh_github_prd")
        self.assertEqual(
            candidates["skills_sh_github_prompt_optimizer"].name,
            "skills_sh_github_prompt_optimizer",
        )
        self.assertEqual(candidates["skills_sh_github_prd"].ref, "new-shared-ref")
        self.assertEqual(
            candidates["skills_sh_github_prompt_optimizer"].ref, "new-shared-ref"
        )

    def test_lookup_candidates_queries_distinct_repos_in_parallel(self) -> None:
        locks = {
            "anthropic_skills": self.lib.SourceLock(
                name="anthropic_skills",
                repo="https://github.com/anthropics/skills",
                ref="old-a",
                captured_at="2026-06-18",
            ),
            "superpowers": self.lib.SourceLock(
                name="superpowers",
                repo="https://github.com/obra/superpowers",
                ref="old-b",
                captured_at="2026-06-18",
            ),
        }
        original_lookup_candidate = self.lib.lookup_candidate
        try:
            def slow_lookup_candidate(lock):
                time.sleep(0.2)
                return self.lib.CandidateRef(
                    name=lock.name,
                    ref=f"new-{lock.name}",
                    source="fixture",
                )

            self.lib.lookup_candidate = slow_lookup_candidate
            started = time.monotonic()
            candidates = self.lib.lookup_candidates(locks)
            elapsed = time.monotonic() - started
        finally:
            self.lib.lookup_candidate = original_lookup_candidate

        self.assertLess(elapsed, 0.35)
        self.assertEqual(candidates["anthropic_skills"].ref, "new-anthropic_skills")
        self.assertEqual(candidates["superpowers"].ref, "new-superpowers")


class FakeRunner:
    def __init__(
        self, fail_contains: str = "", fail_stdout: str = "", fail_stderr: str = ""
    ) -> None:
        self.commands: list[list[str]] = []
        self.fail_contains = fail_contains
        self.fail_stdout = fail_stdout
        self.fail_stderr = fail_stderr

    def run(self, cmd: list[str], cwd: Path | None = None):
        self.last_cwd = cwd
        self.commands.append(cmd)
        text = " ".join(cmd)
        returncode = 1 if self.fail_contains and self.fail_contains in text else 0
        if cmd == ["git", "rev-parse", "--short", "HEAD"]:
            stdout = "abc123\n"
        elif returncode:
            stdout = self.fail_stdout
        else:
            stdout = ""
        stderr = self.fail_stderr if returncode and self.fail_stderr else ""
        if returncode and not stderr:
            stderr = f"failed: {text}"
        return type(
            "Result",
            (),
            {
                "returncode": returncode,
                "stdout": stdout,
                "stderr": stderr,
            },
        )()


class RunUpdateTests(TempDirTest):
    def setUp(self) -> None:
        super().setUp()
        self.lib = load_module("skill_pull_lib", "skill_pull_lib.py")
        self.run_update = load_module("run_update", "run_update.py")
        self.summarize = load_module("summarize_changes", "summarize_changes.py")
        self.repo_root = Path(self.temp_dir.name)
        (self.repo_root / "community").mkdir()
        (self.repo_root / ".worktrees").mkdir()
        write_source_lock(self.repo_root / "community" / "SOURCES.yaml")

    def test_branch_name_uses_date_and_suffix_on_conflict(self) -> None:
        branch = self.run_update.make_update_branch_name(
            "2026-04-22",
            {
                "codex/skill-pull-20260422",
                "codex/skill-pull-20260422-2",
            },
        )

        self.assertEqual(branch, "codex/skill-pull-20260422-3")

    def test_sync_commands_cover_every_managed_source(self) -> None:
        self.assertEqual(
            set(self.run_update.SYNC_COMMANDS), set(self.lib.MANAGED_SOURCE_NAMES)
        )
        self.assertEqual(
            self.run_update.SYNC_COMMANDS["panniantong_agent_reach"],
            ["python3", "tools/community/sync_panniantong_skills_from_upstream.py"],
        )
        self.assertEqual(
            self.run_update.SYNC_COMMANDS["skills_sh_bb_browser"],
            ["python3", "tools/community/sync_skills_sh_skills_from_upstream.py"],
        )
        self.assertEqual(
            self.run_update.SYNC_COMMANDS["skills_sh_github_prompt_optimizer"],
            ["python3", "tools/community/sync_skills_sh_skills_from_upstream.py"],
        )

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

    def test_skills_sh_sources_share_one_sync_command(self) -> None:
        statuses = [
            self.lib.SourceStatus(
                name="skills_sh_bb_browser",
                status="update",
                current_ref="lll222",
                candidate_ref="new222",
                candidate_source="default_branch",
            ),
            self.lib.SourceStatus(
                name="skills_sh_alirezarezvani_code_to_prd",
                status="update",
                current_ref="ttt000",
                candidate_ref="new000",
                candidate_source="default_branch",
            ),
            self.lib.SourceStatus(
                name="skills_sh_self_improving_agent",
                status="update",
                current_ref="ooo555",
                candidate_ref="new555",
                candidate_source="default_branch",
            ),
            self.lib.SourceStatus(
                name="skills_sh_github_prompt_optimizer",
                status="update",
                current_ref="yyy444",
                candidate_ref="new444",
                candidate_source="default_branch",
            ),
        ]

        commands = self.run_update._sync_commands_for(statuses)

        self.assertEqual(
            commands,
            [["python3", "tools/community/sync_skills_sh_skills_from_upstream.py"]],
        )

    def test_quick_install_gate_replaces_full_runtime_smoke_gate(self) -> None:
        validation_commands = [
            " ".join(command) for command in self.run_update.VALIDATION_COMMANDS
        ]

        self.assertNotIn("bash tests/test-install-runtime-smoke.sh", validation_commands)
        self.assertEqual(
            self.run_update.INSTALL_GATE_COMMAND,
            ["bash", "install.sh", "--target", "all", "--check", "quick"],
        )

    def test_update_flow_runs_install_commit_and_cleanup(self) -> None:
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
        self.assertNotIn("bash tests/test-install-runtime-smoke.sh", command_text)
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
            command_text.index("bash install.sh --target all --check quick"),
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

    def test_failure_result_records_command_evidence(self) -> None:
        statuses = [make_anthropic_status(self.lib)]
        runner = FakeRunner(
            fail_contains="test-community-tools",
            fail_stdout="stdout details",
            fail_stderr="stderr details",
        )

        result = self.run_update.run_update_flow(
            repo_root=self.repo_root,
            statuses=statuses,
            today="2026-04-22",
            runner=runner,
            existing_branches=set(),
        )
        payload = self.run_update.build_report_payload(result, statuses)

        self.assertEqual(result.status, "blocked")
        self.assertEqual(result.failed_returncode, 1)
        self.assertGreaterEqual(result.duration_seconds, 0)
        self.assertEqual(result.stdout, "stdout details")
        self.assertEqual(result.stderr, "stderr details")
        self.assertEqual(payload["result"]["failed_returncode"], 1)
        self.assertEqual(payload["result"]["stdout"], "stdout details")
        self.assertIn("duration_seconds", payload["result"])

    def test_install_gate_failure_uses_quick_gate_phase(self) -> None:
        statuses = [make_anthropic_status(self.lib)]
        runner = FakeRunner(fail_contains="--check quick")

        result = self.run_update.run_update_flow(
            repo_root=self.repo_root,
            statuses=statuses,
            today="2026-04-22",
            runner=runner,
            existing_branches=set(),
        )

        command_text = [" ".join(command) for command in runner.commands]
        gate_index = command_text.index(
            "bash install.sh --target all --check quick"
        )
        self.assertEqual(result.status, "blocked")
        self.assertEqual(result.failed_phase, "quick install gate")
        self.assertNotIn(
            "bash install.sh --target all", command_text[gate_index + 1 :]
        )

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
        self.assertIn("bash install.sh --target all --check quick", summary)
        self.assertIn("bash install.sh --target all", summary)
        self.assertIn("abc123", summary)


class SummaryTests(TempDirTest):
    def setUp(self) -> None:
        super().setUp()
        self.summarize = load_module("summarize_changes", "summarize_changes.py")
        self.result_path = Path(self.temp_dir.name) / "result.json"

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
            "Runtime exposure changes",
            "Validation results",
            "Install result",
            "Branch and commit",
        ):
            self.assertIn(section, summary)
        self.assertIn("anthropic_skills", summary)
        self.assertIn("aaa111 -> new999", summary)
        self.assertIn("Superpowers remains plain official SKILL.md files", summary)

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
                        "failed_returncode": 7,
                        "duration_seconds": 12.34,
                        "stdout": "stdout details",
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
        self.assertIn("7", summary)
        self.assertIn("12.34", summary)
        self.assertIn("stdout details", summary)
        self.assertIn("failed validation", summary)


if __name__ == "__main__":
    unittest.main(verbosity=2)
