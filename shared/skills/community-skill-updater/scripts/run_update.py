#!/usr/bin/env python3
"""Run the managed community skill update workflow in an isolated worktree."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Protocol, Sequence

from community_skill_updater_lib import SourceStatus, load_statuses, run_command, write_json


SYNC_COMMANDS = {
    "anthropic_skills": ["python3", "tools/community/sync_anthropic_skills_from_upstream.py"],
    "superpowers": ["python3", "tools/community/sync_canonical_from_upstream.py"],
    "vercel_skills": ["python3", "tools/community/sync_vercel_skills_from_upstream.py"],
    "vercel_agent_browser": ["python3", "tools/community/sync_vercel_skills_from_upstream.py"],
    "alchaincyf_darwin_skill": ["python3", "tools/community/sync_alchaincyf_skills_from_upstream.py"],
    "nextlevelbuilder_ui_ux_pro_max": ["python3", "tools/community/sync_nextlevelbuilder_skills_from_upstream.py"],
}
VALIDATION_COMMANDS = (
    ["python3", "tools/community/source_lock_check.py"],
    ["bash", "tests/test-community-tools.sh"],
    ["bash", "tests/test-single-source-layout.sh"],
    ["bash", "tests/test-codex-skill-adapter.sh"],
    ["bash", "tests/test-install-runtime-smoke.sh"],
    ["bash", "install.sh", "--target", "all", "--check", "full"],
    ["bash", "install.sh", "--target", "all"],
)


class Runner(Protocol):
    """Command runner boundary used by tests and real execution."""

    def run(self, cmd: list[str], cwd: Path | None = None): ...


class SubprocessRunner:
    """Run real commands with timeout and captured output."""

    def run(self, cmd: list[str], cwd: Path | None = None):
        """Execute one command from the updater workflow."""
        return run_command(cmd, cwd=cwd, timeout=600)


@dataclass(frozen=True)
class UpdateResult:
    """Structured outcome of one update orchestration run."""

    status: str
    branch: str = ""
    worktree_path: str = ""
    failed_phase: str = ""
    failed_command: str = ""
    stderr: str = ""


def make_update_branch_name(today: str, existing_branches: set[str]) -> str:
    """Create a same-day update branch name with a numeric suffix on conflict."""
    compact = today.replace("-", "")
    base = f"codex/community-skill-update-{compact}"
    if base not in existing_branches:
        return base
    suffix = 2
    while f"{base}-{suffix}" in existing_branches:
        suffix += 1
    return f"{base}-{suffix}"


def make_worktree_path(worktree_root: Path, branch_name: str) -> Path:
    """Map a branch name to a stable local worktree directory."""
    return worktree_root / branch_name.replace("/", "-")


def update_lock_text(text: str, statuses: Sequence[SourceStatus], captured_at: str) -> str:
    """Update ref and captured_at fields for sources marked for update."""
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
        block = re.sub(r"^    ref: .*$", f"    ref: {status.candidate_ref}", block, flags=re.MULTILINE)
        block = re.sub(r"^    captured_at: .*$", f"    captured_at: {captured_at}", block, flags=re.MULTILINE)
        updated = updated[: match.start()] + block + updated[match.end() :]
    return updated


def _copy_for_fake_runner(repo_root: Path, worktree_path: Path) -> None:
    """Create a test worktree when a fake runner records git commands only."""
    if worktree_path.exists():
        return
    shutil.copytree(
        repo_root,
        worktree_path,
        ignore=shutil.ignore_patterns(".git", ".worktrees"),
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
    """Run one command and convert failures into a preserved blocked result."""
    result = runner.run(cmd, cwd=cwd)
    if result.returncode == 0:
        return None
    return UpdateResult(
        status="blocked",
        branch=branch,
        worktree_path=str(worktree_path),
        failed_phase=phase,
        failed_command=" ".join(cmd),
        stderr=(result.stderr or result.stdout or "").strip(),
    )


def _sync_commands_for(statuses: Sequence[SourceStatus]) -> list[list[str]]:
    """Select source-specific sync commands without duplicating shared scripts."""
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
    """Read local branch names for branch suffix selection."""
    result = run_command(["git", "branch", "--format=%(refname:short)"], cwd=repo_root)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git branch lookup failed")
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def run_update_flow(
    *,
    repo_root: Path,
    statuses: Sequence[SourceStatus],
    today: str,
    runner: Runner | None = None,
    existing_branches: set[str] | None = None,
) -> UpdateResult:
    """Apply update statuses in an isolated worktree and return the outcome."""
    blocked = [status for status in statuses if status.status == "blocked"]
    if blocked:
        return UpdateResult(status="blocked", failed_phase="candidate", stderr=blocked[0].blocker)

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

    _copy_for_fake_runner(repo_root, worktree_path)
    source_lock = worktree_path / "community" / "SOURCES.yaml"
    source_lock.write_text(
        update_lock_text(source_lock.read_text(encoding="utf-8"), statuses, today),
        encoding="utf-8",
    )

    for command in _sync_commands_for(statuses):
        blocked_result = _run_or_block(
            active_runner,
            command,
            cwd=worktree_path,
            phase="sync",
            branch=branch,
            worktree_path=worktree_path,
        )
        if blocked_result:
            return blocked_result

    for command in VALIDATION_COMMANDS:
        blocked_result = _run_or_block(
            active_runner,
            command,
            cwd=worktree_path,
            phase="validation",
            branch=branch,
            worktree_path=worktree_path,
        )
        if blocked_result:
            return blocked_result

    for command in (
        ["git", "add", "community", "shared", "tests", "install.sh", "README.md"],
        ["git", "commit", "-m", "chore: update community skill sources"],
    ):
        blocked_result = _run_or_block(
            active_runner,
            command,
            cwd=worktree_path,
            phase="commit",
            branch=branch,
            worktree_path=worktree_path,
        )
        if blocked_result:
            return blocked_result

    blocked_result = _run_or_block(
        active_runner,
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
    return UpdateResult(status="updated", branch=branch, worktree_path=str(worktree_path))


def main() -> None:
    """CLI entrypoint for running the update orchestration."""
    parser = argparse.ArgumentParser(description="Run managed community skill updates.")
    parser.add_argument("--repo-root", default=".", help="Repository root. Defaults to current directory.")
    parser.add_argument("--candidate-json", required=True, help="JSON produced by check_candidates.py.")
    parser.add_argument("--today", required=True, help="Capture date in YYYY-MM-DD format.")
    parser.add_argument("--output-json", required=True, help="Path for update result JSON.")
    args = parser.parse_args()

    result = run_update_flow(
        repo_root=Path(args.repo_root),
        statuses=load_statuses(Path(args.candidate_json)),
        today=args.today,
    )
    write_json(Path(args.output_json), {"result": asdict(result)})
    if result.status == "blocked":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
