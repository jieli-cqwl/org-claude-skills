"""Path, JSON, and subprocess helpers for the Anthropic adapter."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ALLOWED_REASONING_EFFORTS = {"low", "medium", "high", "xhigh"}


def repo_root() -> Path:
    """Return the repository root from this script location."""

    return Path(__file__).resolve().parents[4]


def write_json(path: Path, payload: object) -> None:
    """Write stable UTF-8 JSON for downstream official scripts."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_json(path: Path) -> object:
    """Load a JSON document."""

    return json.loads(path.read_text(encoding="utf-8"))


def resolve_repo_path(root: Path, value: str) -> Path:
    """Resolve a config path under the repo root."""

    path = Path(value)
    if path.is_absolute():
        return path
    return root / path


def load_config(config_path: Path) -> dict:
    """Load adapter config and resolve path fields."""

    root = repo_root()
    payload = load_json(config_path)
    if not isinstance(payload, dict):
        raise ValueError(f"{config_path}: config must be an object")
    for key in ("skill_path", "evals_path", "official_skill_creator_path", "default_output_dir"):
        payload[key] = str(resolve_repo_path(root, str(payload[key])))
    return payload


def apply_codex_runtime_options(command: list[str], model: str | None, reasoning_effort: str | None) -> None:
    """Add explicit Codex runtime options immediately after `codex exec`."""

    runtime_args = []
    if model:
        runtime_args.extend(["--model", model])
    if reasoning_effort:
        if reasoning_effort not in ALLOWED_REASONING_EFFORTS:
            allowed = ", ".join(sorted(ALLOWED_REASONING_EFFORTS))
            raise ValueError(f"unsupported reasoning effort: {reasoning_effort}; allowed: {allowed}")
        runtime_args.extend(["-c", f'model_reasoning_effort="{reasoning_effort}"'])
    command[2:2] = runtime_args


def run_command(cmd: list[str], cwd: Path, timeout_sec: int | None) -> subprocess.CompletedProcess[str]:
    """Run a subprocess with nested agent session guards removed."""

    nested_vars = {
        "CLAUDECODE",
        "CODEX_COMPANION_SESSION_ID",
        "CODEX_INTERNAL_ORIGINATOR_OVERRIDE",
        "CODEX_SHELL",
        "CODEX_THREAD_ID",
    }
    env = {key: value for key, value in os.environ.items() if key not in nested_vars}
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
            start_new_session=True,
        )
        started_at = time.time()
        timed_out = False
        while True:
            elapsed = time.time() - started_at
            if timeout_sec is not None and elapsed >= timeout_sec:
                timed_out = True
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                except OSError:
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
                    f"[anthropic-adapter] running {cmd[0]} for {int(time.time() - started_at)}s",
                    file=sys.stderr,
                    flush=True,
                )

        stdout_file.seek(0)
        stderr_file.seek(0)
        stdout = stdout_file.read()
        stderr = stderr_file.read()
        return_code = 124 if timed_out else process.returncode
        return subprocess.CompletedProcess(cmd, return_code if return_code is not None else 124, stdout, stderr)


def write_process_log(path: Path, cmd: list[str], cwd: Path, completed: subprocess.CompletedProcess[str]) -> None:
    """Persist subprocess diagnostics for failed or reviewed adapter stages."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "\n".join(
            [
                f"command={json.dumps(cmd, ensure_ascii=False)}",
                f"cwd={cwd}",
                f"returncode={completed.returncode}",
                "",
                "[stdout]",
                completed.stdout or "",
                "",
                "[stderr]",
                completed.stderr or "",
            ]
        ),
        encoding="utf-8",
    )


def validate_official_skill_creator(path: Path) -> None:
    """Validate that the upstream skill-creator directory is usable."""

    script = path / "scripts" / "quick_validate.py"
    if not script.is_file():
        raise FileNotFoundError(f"missing official quick_validate.py: {script}")
    completed = run_command(["python3", str(script), str(path)], repo_root(), 60)
    if completed.returncode != 0:
        raise RuntimeError(completed.stdout + completed.stderr)
