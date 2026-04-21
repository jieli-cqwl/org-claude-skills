"""Shared constants and process helpers for standard-chain local evals."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]

INFRA_FAILURE_FINDING = {
    "issue": "Eval infrastructure failed before grading completed",
    "suggested_change": "Fix the runner, timeout, CLI invocation, or workspace setup before using this case to judge skill quality.",
}


@dataclass(frozen=True)
class EvalSelection:
    """Selected skill and case ids for one local eval run."""

    skills: list[str]
    eval_ids: set[str] | None


def write_json(path: Path, payload: object) -> None:
    """Write stable UTF-8 JSON for human review and downstream scripts."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_json(path: Path) -> object:
    """Load one JSON document from disk."""

    return json.loads(path.read_text(encoding="utf-8"))


def run_command(cmd: list[str], cwd: Path, timeout_sec: int | None) -> subprocess.CompletedProcess[str]:
    """Run a subprocess while preserving logs and removing nested session guards."""

    env = {key: value for key, value in os.environ.items() if key != "CLAUDECODE"}
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as stdout_file, tempfile.TemporaryFile(
        mode="w+",
        encoding="utf-8",
    ) as stderr_file:
        process = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            text=True,
            stdout=stdout_file,
            stderr=stderr_file,
            env=env,
        )
        started_at = time.time()
        timed_out = False
        while True:
            elapsed = time.time() - started_at
            if timeout_sec is not None and elapsed >= timeout_sec:
                timed_out = True
                process.kill()
                process.wait()
                stderr_file.write(f"\nTimeoutExpired: command timed out after {timeout_sec} seconds\n")
                break
            wait_for = min(15, timeout_sec - elapsed if timeout_sec is not None else 15)
            try:
                process.wait(timeout=wait_for)
                break
            except subprocess.TimeoutExpired:
                print(
                    f"[eval-runner] running {cmd[0]} for {int(time.time() - started_at)}s",
                    file=sys.stderr,
                    flush=True,
                )

        stdout_file.seek(0)
        stderr_file.seek(0)
        stdout = stdout_file.read()
        stderr = stderr_file.read()
        return_code = 124 if timed_out else process.returncode
        return subprocess.CompletedProcess(cmd, return_code if return_code is not None else 124, stdout=stdout, stderr=stderr)


def parse_csv(value: str | None) -> list[str]:
    """Parse a comma-separated CLI value into a list."""

    if not value:
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


def parse_selection(args: argparse.Namespace) -> EvalSelection:
    """Convert CLI arguments into a normalized eval selection."""

    skills = parse_csv(args.skills)
    eval_ids = set(parse_csv(args.eval_ids)) or None
    return EvalSelection(skills=skills, eval_ids=eval_ids)
