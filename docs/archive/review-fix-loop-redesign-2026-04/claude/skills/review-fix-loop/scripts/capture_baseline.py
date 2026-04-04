#!/usr/bin/env python3
"""Manage review-fix-loop baseline snapshots for a git repository.

Responsibilities:
- capture an immutable baseline before the review/fix loop starts
- preserve tracked, staged, and untracked changes by stashing and re-applying
- compare the current repository file set against the captured baseline

Boundary:
- only operates on the target git repository
- only returns JSON to stdout; it does not modify files outside the repo
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


class BaselineError(RuntimeError):
    """Raised when baseline capture cannot complete safely."""


def emit_json(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))


def run_git(
    repo: Path,
    args: Sequence[str],
    *,
    check: bool = True,
    timeout: int = 20,
) -> subprocess.CompletedProcess[str]:
    """Run a git command with timeout and consistent error handling."""

    try:
        completed = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        raise BaselineError(f"git 命令超时: {' '.join(args)}") from exc

    if check and completed.returncode != 0:
        stderr = completed.stderr.strip() or completed.stdout.strip() or "unknown git error"
        raise BaselineError(f"git 命令失败: {' '.join(args)}: {stderr}")

    return completed


def ensure_repo(repo: Path) -> Path:
    """Resolve and validate the git repository root."""

    completed = run_git(repo, ["rev-parse", "--show-toplevel"])
    return Path(completed.stdout.strip())


def optional_ref(repo: Path, ref: str) -> str | None:
    """Return the ref SHA when it exists, otherwise None."""

    completed = run_git(repo, ["rev-parse", "--verify", ref], check=False)
    if completed.returncode != 0:
        return None
    return completed.stdout.strip() or None


def list_repo_files(repo: Path) -> list[str]:
    """Return tracked and untracked non-ignored repo files."""

    completed = run_git(
        repo,
        ["ls-files", "-z", "--cached", "--others", "--exclude-standard"],
    )
    raw_items = [item for item in completed.stdout.split("\0") if item]
    return sorted(raw_items)


def has_tracked_dirty(repo: Path) -> bool:
    """Check whether tracked files differ from HEAD."""

    completed = run_git(repo, ["status", "--porcelain=1", "--untracked-files=no"])
    return bool(completed.stdout.strip())


def has_untracked_dirty(repo: Path) -> bool:
    """Check whether untracked non-ignored files exist."""

    completed = run_git(repo, ["ls-files", "--others", "--exclude-standard"])
    return bool(completed.stdout.strip())


def snapshot_worktree_status(repo: Path) -> list[str]:
    """Capture the exact staged/unstaged/untracked status snapshot."""

    completed = run_git(
        repo,
        ["status", "--porcelain=1", "-z", "--untracked-files=all"],
    )
    return [item for item in completed.stdout.split("\0") if item]


def capture_index_tree(repo: Path) -> str:
    """Capture the current index tree so staged state can be restored exactly."""

    completed = run_git(repo, ["write-tree"])
    return completed.stdout.strip()


def restore_after_apply_failure(
    repo: Path,
    stash_sha: str,
    original_status: list[str],
    index_tree: str,
) -> bool:
    """Best-effort restore of worktree/index after stash apply --index fails."""

    current_status = snapshot_worktree_status(repo)
    if current_status != original_status:
        run_git(repo, ["read-tree", index_tree])
        current_status = snapshot_worktree_status(repo)
    if current_status != original_status:
        try:
            run_git(repo, ["stash", "apply", stash_sha], timeout=30)
        except BaselineError:
            current_status = snapshot_worktree_status(repo)
            if current_status == original_status:
                return True
            raise
        run_git(repo, ["read-tree", index_tree])
        current_status = snapshot_worktree_status(repo)

    return current_status == original_status


def create_baseline(repo: Path) -> dict[str, Any]:
    """Capture the baseline metadata for the review/fix loop."""

    repo_root = ensure_repo(repo)
    head_sha = run_git(repo_root, ["rev-parse", "HEAD"]).stdout.strip()
    tracked_dirty = has_tracked_dirty(repo_root)
    untracked_dirty = has_untracked_dirty(repo_root)
    file_snapshot = list_repo_files(repo_root)

    baseline_kind = "head"
    stash_sha: str | None = None
    restore_command = "git checkout -- ."

    if tracked_dirty or untracked_dirty:
        original_status = snapshot_worktree_status(repo_root)
        index_tree = capture_index_tree(repo_root)
        before_stash = optional_ref(repo_root, "refs/stash")
        run_git(
            repo_root,
            ["stash", "push", "--include-untracked", "-m", "review-fix-loop baseline"],
            timeout=30,
        )
        stash_sha = optional_ref(repo_root, "refs/stash")
        if not stash_sha or stash_sha == before_stash:
            raise BaselineError("未创建新的 review-fix-loop baseline stash")

        try:
            run_git(repo_root, ["stash", "apply", "--index", stash_sha], timeout=30)
        except BaselineError as exc:
            recovered = False
            try:
                recovered = restore_after_apply_failure(repo_root, stash_sha, original_status, index_tree)
            except BaselineError as restore_exc:
                raise BaselineError(
                    f"{exc}；自动恢复失败: {restore_exc}；请手动执行: git stash apply --index {stash_sha}"
                ) from restore_exc

            if recovered:
                raise BaselineError(
                    f"{exc}；已恢复当前工作树和索引，请手动执行: git stash apply --index {stash_sha}"
                ) from exc
            raise BaselineError(
                f"{exc}；已尝试恢复但状态未完全回到基线前，请手动执行: git stash apply --index {stash_sha}"
            ) from exc

        baseline_kind = "stash"
        restore_command = f"git checkout -- . && git stash apply --index {stash_sha}"

    return {
        "baseline_kind": baseline_kind,
        "file_snapshot": file_snapshot,
        "head_sha": head_sha,
        "repo_root": str(repo_root),
        "restore_command": restore_command,
        "stash_sha": stash_sha,
        "tracked_dirty": tracked_dirty,
        "untracked_dirty": untracked_dirty,
    }


def list_new_files(repo: Path, baseline_file: Path) -> dict[str, Any]:
    """Compare the current repo file set against a captured baseline."""

    repo_root = ensure_repo(repo)
    baseline_data = json.loads(baseline_file.read_text(encoding="utf-8"))
    baseline_snapshot = baseline_data.get("file_snapshot")
    if not isinstance(baseline_snapshot, list):
        raise BaselineError("baseline 文件缺少 file_snapshot 列表")

    current_files = set(list_repo_files(repo_root))
    baseline_files = {item for item in baseline_snapshot if isinstance(item, str)}
    new_files = sorted(current_files - baseline_files)

    return {
        "baseline_kind": baseline_data.get("baseline_kind"),
        "new_files": new_files,
        "repo_root": str(repo_root),
    }


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    """Parse CLI arguments."""

    parser = argparse.ArgumentParser(description="Capture review-fix-loop git baselines")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create_parser = subparsers.add_parser("create", help="capture the starting baseline")
    create_parser.add_argument("--repo", required=True, help="git repository root")

    list_parser = subparsers.add_parser(
        "list-new-files",
        help="compare the current repo file set to a saved baseline",
    )
    list_parser.add_argument("--repo", required=True, help="git repository root")
    list_parser.add_argument("--baseline", required=True, help="baseline JSON path")

    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    """Entrypoint."""

    args = parse_args(argv)

    try:
        if args.command == "create":
            emit_json(create_baseline(Path(args.repo)))
            return 0

        emit_json(list_new_files(Path(args.repo), Path(args.baseline)))
        return 0
    except (BaselineError, json.JSONDecodeError) as exc:
        emit_json({"code": "BASELINE_ERROR", "error": str(exc)})
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
