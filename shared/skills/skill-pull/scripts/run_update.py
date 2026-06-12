#!/usr/bin/env python3
"""Run the managed skill pull workflow in an isolated worktree."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Protocol, Sequence

from skill_pull_lib import SourceStatus, load_statuses, run_command, write_json


SYNC_COMMANDS = {
    "anthropic_skills": [
        "python3",
        "tools/community/sync_anthropic_skills_from_upstream.py",
    ],
    "superpowers": ["python3", "tools/community/sync_canonical_from_upstream.py"],
    "vercel_skills": ["python3", "tools/community/sync_vercel_skills_from_upstream.py"],
    "vercel_agent_browser": [
        "python3",
        "tools/community/sync_vercel_skills_from_upstream.py",
    ],
    "alchaincyf_darwin_skill": [
        "python3",
        "tools/community/sync_alchaincyf_skills_from_upstream.py",
    ],
    "nextlevelbuilder_ui_ux_pro_max": [
        "python3",
        "tools/community/sync_nextlevelbuilder_skills_from_upstream.py",
    ],
    "panniantong_agent_reach": [
        "python3",
        "tools/community/sync_panniantong_skills_from_upstream.py",
    ],
    "skills_sh_alirezarezvani_code_to_prd": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_baoyu_markdown_to_html": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_bb_browser": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_github_prd": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_github_prompt_optimizer": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_graphify": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_markdown_viewer_architecture": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_humanizer_zh": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_mattpocock_to_prd": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_notebooklm": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_othmanadi_planning_with_files": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_self_improving_agent": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
    "skills_sh_softaworks_mermaid_diagrams": [
        "python3",
        "tools/community/sync_skills_sh_skills_from_upstream.py",
    ],
}
VALIDATION_COMMANDS = (
    ["python3", "tools/community/source_lock_check.py"],
    ["bash", "tests/test-community-tools.sh"],
    ["python3", "tools/community/check_superpowers_upstream_fidelity.py"],
    ["bash", "tests/test-single-source-layout.sh"],
    ["bash", "tests/test-codex-skill-adapter.sh"],
)
FULL_CHECK_COMMAND = ["bash", "install.sh", "--target", "all", "--check", "full"]
INSTALL_COMMAND = ["bash", "install.sh", "--target", "all"]
WORKFLOW_TIMEOUT_SECONDS = 3600


class Runner(Protocol):
    def run(
        self, cmd: list[str], cwd: Path | None = None
    ) -> subprocess.CompletedProcess[str]: ...


class SubprocessRunner:
    def run(
        self, cmd: list[str], cwd: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return run_command(cmd, cwd=cwd, timeout=WORKFLOW_TIMEOUT_SECONDS)


@dataclass(frozen=True)
class CommandOutcome:
    command: str
    status: str


@dataclass(frozen=True)
class UpdateResult:
    status: str
    branch: str = ""
    worktree_path: str = ""
    failed_phase: str = ""
    failed_command: str = ""
    failed_returncode: int | None = None
    duration_seconds: float = 0.0
    stdout: str = ""
    stderr: str = ""
    commit: str = ""
    validations: tuple[CommandOutcome, ...] = ()
    install: CommandOutcome | None = None


def make_update_branch_name(today: str, existing_branches: set[str]) -> str:
    compact = today.replace("-", "")
    base = f"codex/skill-pull-{compact}"
    if base not in existing_branches:
        return base
    suffix = 2
    while f"{base}-{suffix}" in existing_branches:
        suffix += 1
    return f"{base}-{suffix}"


def make_worktree_path(worktree_root: Path, branch_name: str) -> Path:
    return worktree_root / branch_name.replace("/", "-")


def update_lock_text(
    text: str, statuses: Sequence[SourceStatus], captured_at: str
) -> str:
    updated = text
    for status in statuses:
        if status.status != "update":
            continue
        pattern = re.compile(
            rf"(^  {re.escape(status.name)}:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*))",
            flags=re.MULTILINE,
        )
        match = pattern.search(updated)
        if not match:
            raise RuntimeError(f"source block not found: {status.name}")
        block = match.group(0)
        block = re.sub(
            r"^    ref: .*$",
            f"    ref: {status.candidate_ref}",
            block,
            flags=re.MULTILINE,
        )
        block = re.sub(
            r"^    captured_at: .*$",
            f"    captured_at: {captured_at}",
            block,
            flags=re.MULTILINE,
        )
        updated = updated[: match.start()] + block + updated[match.end() :]
    return updated


def _copy_for_fake_runner(repo_root: Path, worktree_path: Path) -> None:
    if worktree_path.exists():
        return
    shutil.copytree(
        repo_root, worktree_path, ignore=shutil.ignore_patterns(".git", ".worktrees")
    )


def _run_or_block(
    runner: Runner,
    cmd: list[str],
    *,
    cwd: Path,
    phase: str,
    branch: str,
    worktree_path: Path,
) -> UpdateResult | None:
    started = time.monotonic()
    result = runner.run(cmd, cwd=cwd)
    duration_seconds = round(time.monotonic() - started, 3)
    if result.returncode == 0:
        return None
    stdout = (result.stdout or "").strip()
    stderr = (result.stderr or "").strip()
    return UpdateResult(
        status="blocked",
        branch=branch,
        worktree_path=str(worktree_path),
        failed_phase=phase,
        failed_command=" ".join(cmd),
        failed_returncode=result.returncode,
        duration_seconds=duration_seconds,
        stdout=stdout,
        stderr=stderr or stdout,
    )


def _passed(command: list[str]) -> CommandOutcome:
    return CommandOutcome(command=" ".join(command), status="passed")


def _sync_commands_for(statuses: Sequence[SourceStatus]) -> list[list[str]]:
    commands: list[list[str]] = []
    seen: set[tuple[str, ...]] = set()
    for status in statuses:
        if status.status != "update":
            continue
        command = SYNC_COMMANDS[status.name]
        key = tuple(command)
        if key not in seen:
            seen.add(key)
            commands.append(command)
    return commands


def _existing_branches(repo_root: Path) -> set[str]:
    result = run_command(["git", "branch", "--format=%(refname:short)"], cwd=repo_root)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git branch lookup failed")
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def build_report_payload(
    result: UpdateResult, statuses: Sequence[SourceStatus]
) -> dict[str, Any]:
    result_payload = asdict(result)
    validations = result_payload.pop("validations")
    install = result_payload.pop("install") or {}
    checked_sources = [asdict(status) for status in statuses]
    return {
        "result": result_payload,
        "checked_sources": checked_sources,
        "sources": [
            source for source in checked_sources if source.get("status") == "update"
        ],
        "validations": validations,
        "install": install,
    }


def _write_updated_source_lock(
    worktree_path: Path, statuses: Sequence[SourceStatus], today: str
) -> None:
    source_lock = worktree_path / "community" / "SOURCES.yaml"
    source_lock.write_text(
        update_lock_text(source_lock.read_text(encoding="utf-8"), statuses, today),
        encoding="utf-8",
    )


def _run_workflow_commands(
    runner: Runner,
    commands: Sequence[list[str]],
    *,
    phase: str,
    branch: str,
    worktree_path: Path,
) -> list[CommandOutcome] | UpdateResult:
    outcomes: list[CommandOutcome] = []
    for command in commands:
        blocked_result = _run_or_block(
            runner,
            command,
            cwd=worktree_path,
            phase=phase,
            branch=branch,
            worktree_path=worktree_path,
        )
        if blocked_result:
            return blocked_result
        outcomes.append(_passed(command))
    return outcomes


def _commit_updates(
    runner: Runner,
    *,
    branch: str,
    worktree_path: Path,
    validations: list[CommandOutcome],
    install: CommandOutcome,
) -> str | UpdateResult:
    for command in (
        ["git", "add", "community", "shared", "tests", "install.sh", "README.md"],
        ["git", "commit", "-m", "chore: pull external skill sources"],
    ):
        blocked_result = _run_or_block(
            runner,
            command,
            cwd=worktree_path,
            phase="commit",
            branch=branch,
            worktree_path=worktree_path,
        )
        if blocked_result:
            return blocked_result

    commit_command = ["git", "rev-parse", "--short", "HEAD"]
    started = time.monotonic()
    commit_result = runner.run(commit_command, cwd=worktree_path)
    duration_seconds = round(time.monotonic() - started, 3)
    if commit_result.returncode == 0:
        return commit_result.stdout.strip()
    stdout = (commit_result.stdout or "").strip()
    stderr = (commit_result.stderr or "").strip()
    return UpdateResult(
        status="blocked",
        branch=branch,
        worktree_path=str(worktree_path),
        failed_phase="commit",
        failed_command=" ".join(commit_command),
        failed_returncode=commit_result.returncode,
        duration_seconds=duration_seconds,
        stdout=stdout,
        stderr=stderr or stdout,
        validations=tuple(validations),
        install=install,
    )


def _cleanup_worktree(
    runner: Runner,
    *,
    repo_root: Path,
    branch: str,
    worktree_path: Path,
) -> UpdateResult | None:
    blocked_result = _run_or_block(
        runner,
        ["git", "worktree", "remove", str(worktree_path)],
        cwd=repo_root,
        phase="cleanup",
        branch=branch,
        worktree_path=worktree_path,
    )
    if blocked_result:
        return blocked_result
    if worktree_path.exists():
        shutil.rmtree(worktree_path)
    return None


def _apply_updates_in_worktree(
    *,
    repo_root: Path,
    statuses: Sequence[SourceStatus],
    today: str,
    runner: Runner,
    branch: str,
    worktree_path: Path,
) -> UpdateResult:
    _copy_for_fake_runner(repo_root, worktree_path)
    _write_updated_source_lock(worktree_path, statuses, today)

    sync = _run_workflow_commands(
        runner,
        _sync_commands_for(statuses),
        phase="sync",
        branch=branch,
        worktree_path=worktree_path,
    )
    if isinstance(sync, UpdateResult):
        return sync

    validations = _run_workflow_commands(
        runner,
        VALIDATION_COMMANDS,
        phase="validation",
        branch=branch,
        worktree_path=worktree_path,
    )
    if isinstance(validations, UpdateResult):
        return validations

    full_check = _run_workflow_commands(
        runner,
        [FULL_CHECK_COMMAND],
        phase="full-check install gate",
        branch=branch,
        worktree_path=worktree_path,
    )
    if isinstance(full_check, UpdateResult):
        return full_check
    validations += full_check

    install_outcomes = _run_workflow_commands(
        runner,
        [INSTALL_COMMAND],
        phase="install",
        branch=branch,
        worktree_path=worktree_path,
    )
    if isinstance(install_outcomes, UpdateResult):
        return install_outcomes
    install = install_outcomes[0]

    commit = _commit_updates(
        runner,
        branch=branch,
        worktree_path=worktree_path,
        validations=validations,
        install=install,
    )
    if isinstance(commit, UpdateResult):
        return commit

    cleanup = _cleanup_worktree(
        runner,
        repo_root=repo_root,
        branch=branch,
        worktree_path=worktree_path,
    )
    if cleanup:
        return cleanup

    return UpdateResult(
        status="updated",
        branch=branch,
        worktree_path=str(worktree_path),
        commit=commit,
        validations=tuple(validations),
        install=install,
    )


def run_update_flow(
    *,
    repo_root: Path,
    statuses: Sequence[SourceStatus],
    today: str,
    runner: Runner | None = None,
    existing_branches: set[str] | None = None,
) -> UpdateResult:
    blocked = [status for status in statuses if status.status == "blocked"]
    if blocked:
        return UpdateResult(
            status="blocked", failed_phase="candidate", stderr=blocked[0].blocker
        )

    updates = [status for status in statuses if status.status == "update"]
    if not updates:
        return UpdateResult(status="current")

    repo_root = repo_root.resolve()
    worktree_root = repo_root / ".worktrees"
    if existing_branches is None:
        existing_branches = _existing_branches(repo_root)
    branch = make_update_branch_name(today, existing_branches)
    worktree_path = make_worktree_path(worktree_root, branch)
    active_runner: Runner = runner or SubprocessRunner()

    blocked_result = _run_or_block(
        active_runner,
        ["git", "worktree", "add", str(worktree_path), "-b", branch],
        cwd=repo_root,
        phase="worktree",
        branch=branch,
        worktree_path=worktree_path,
    )
    if blocked_result:
        return blocked_result

    return _apply_updates_in_worktree(
        repo_root=repo_root,
        statuses=statuses,
        today=today,
        runner=active_runner,
        branch=branch,
        worktree_path=worktree_path,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Run managed skill pulls.")
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root. Defaults to current directory.",
    )
    parser.add_argument(
        "--candidate-json", required=True, help="JSON produced by check_candidates.py."
    )
    parser.add_argument(
        "--today", required=True, help="Capture date in YYYY-MM-DD format."
    )
    parser.add_argument(
        "--output-json", required=True, help="Path for update result JSON."
    )
    args = parser.parse_args()

    statuses = load_statuses(Path(args.candidate_json))
    result = run_update_flow(
        repo_root=Path(args.repo_root), statuses=statuses, today=args.today
    )
    write_json(Path(args.output_json), build_report_payload(result, statuses))
    if result.status == "blocked":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
