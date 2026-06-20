#!/usr/bin/env python3
"""Git helpers for syncing locked upstream community sources."""

from __future__ import annotations

import subprocess
import shutil
from pathlib import Path
from typing import Callable, Sequence


GIT_HTTP_LOW_SPEED_LIMIT = 1
GIT_HTTP_LOW_SPEED_TIME_SECONDS = 20

GitRunner = Callable[..., subprocess.CompletedProcess[str]]


def git_command(args: Sequence[str]) -> list[str]:
    """Build a git command with bounded HTTP low-speed behavior."""
    return [
        "git",
        "-c",
        f"http.lowSpeedLimit={GIT_HTTP_LOW_SPEED_LIMIT}",
        "-c",
        f"http.lowSpeedTime={GIT_HTTP_LOW_SPEED_TIME_SECONDS}",
        *args,
    ]


def run_git(cmd: list[str], *, runner: GitRunner = subprocess.run) -> str:
    """Run git and raise a concise error that preserves stderr."""
    result = runner(
        cmd,
        check=False,
        text=True,
        capture_output=True,
    )
    if result.returncode == 0:
        return result.stdout or ""
    command_text = _git_action(cmd)
    detail = (result.stderr or result.stdout or "").strip()
    if detail:
        raise RuntimeError(f"{command_text} failed: {detail}")
    raise RuntimeError(f"{command_text} failed with exit code {result.returncode}")


def clone_locked_ref(
    repo: str,
    ref: str,
    workdir: Path,
    checkout_name: str,
    *,
    runner: GitRunner = subprocess.run,
) -> Path:
    """Clone an upstream repo and detach at the locked commit/ref."""
    checkout = workdir / checkout_name
    last_clone_error: RuntimeError | None = None
    for _attempt in range(2):
        try:
            run_git(
                git_command(["clone", "--no-checkout", repo, str(checkout)]),
                runner=runner,
            )
            last_clone_error = None
            break
        except RuntimeError as exc:
            last_clone_error = exc
            if checkout.exists():
                shutil.rmtree(checkout)
    if last_clone_error is not None:
        raise last_clone_error
    try:
        run_git(
            git_command(["-C", str(checkout), "cat-file", "-e", f"{ref}^{{commit}}"]),
            runner=runner,
        )
    except RuntimeError:
        run_git(
            git_command(["-C", str(checkout), "fetch", "--depth", "1", "origin", ref]),
            runner=runner,
        )
    run_git(
        git_command(["-C", str(checkout), "cat-file", "-e", f"{ref}^{{commit}}"]),
        runner=runner,
    )
    run_git(
        git_command(["-C", str(checkout), "checkout", "--detach", ref]),
        runner=runner,
    )
    return checkout


def rev_parse_head(checkout: Path, *, runner: GitRunner = subprocess.run) -> str:
    """Return the current checkout commit hash."""
    return run_git(
        git_command(["-C", str(checkout), "rev-parse", "HEAD"]),
        runner=runner,
    ).strip()


def _git_action(cmd: Sequence[str]) -> str:
    if "clone" in cmd:
        return "git clone upstream"
    if "fetch" in cmd:
        if "--tags" in cmd:
            return "git fetch upstream tags"
        return "git fetch upstream ref"
    if "checkout" in cmd:
        return "git checkout upstream ref"
    if "cat-file" in cmd:
        return "git verify upstream ref"
    if "rev-parse" in cmd:
        return "git resolve upstream commit"
    return "git upstream command"
