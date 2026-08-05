"""Bounded isolated Codex execution for one evaluator case."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import os
from pathlib import Path
import subprocess
import tempfile
import time

from rule_runtime_eval.common import CommandResult, redact_stderr
from rule_runtime_eval.contracts import EvalCase
from rule_runtime_eval.workspace import RuntimeWorkspace


@dataclass(frozen=True)
class ExecutionSettings:
    codex_bin: str
    model: str
    reasoning_effort: str
    timeout_seconds: int


def run_executor(
    case: EvalCase,
    workspace: RuntimeWorkspace,
    run_dir: Path,
    settings: ExecutionSettings,
) -> CommandResult:
    """Run one case in a fresh non-repository cwd and retain raw process evidence."""

    run_dir.mkdir(parents=True, exist_ok=False)
    outputs = run_dir / "outputs"
    outputs.mkdir()
    response_path = outputs / "response.md"
    case_workspace = Path(tempfile.mkdtemp(prefix="case-", dir=workspace.home))
    args = [
        settings.codex_bin,
        "exec",
        "--json",
        "--ephemeral",
        "--skip-git-repo-check",
        "--sandbox",
        "workspace-write",
        "--model",
        settings.model,
        "-c",
        f'model_reasoning_effort="{settings.reasoning_effort}"',
        "-C",
        str(case_workspace),
        "--output-last-message",
        str(response_path),
        case.prompt,
    ]
    env = dict(os.environ)
    env.update({"HOME": str(workspace.home), "CODEX_HOME": str(workspace.codex_home)})
    started_at = datetime.now(UTC)
    started = time.monotonic()
    try:
        completed = subprocess.run(
            args,
            cwd=case_workspace,
            env=env,
            capture_output=True,
            check=False,
            timeout=settings.timeout_seconds,
        )
        returncode = completed.returncode
        stdout = completed.stdout
        stderr = completed.stderr
        timed_out = False
    except subprocess.TimeoutExpired as exc:
        returncode = None
        stdout = exc.stdout or b""
        stderr = exc.stderr or b""
        timed_out = True
    except OSError as exc:
        returncode = 127
        stdout = b""
        stderr = f"executor launch failed: {exc.__class__.__name__}"
        timed_out = False
    ended_at = datetime.now(UTC)
    (run_dir / "executor.jsonl").write_bytes(_as_bytes(stdout))
    (run_dir / "executor.log").write_text(
        redact_stderr(_as_bytes(stderr).decode("utf-8", errors="replace"), "executor"),
        encoding="utf-8",
    )
    return CommandResult(
        args=args,
        returncode=returncode,
        stdout=_as_bytes(stdout).decode("utf-8", errors="replace"),
        stderr=_as_bytes(stderr).decode("utf-8", errors="replace"),
        timed_out=timed_out,
        started_at=started_at.isoformat(),
        ended_at=ended_at.isoformat(),
        duration_seconds=time.monotonic() - started,
    )


def extract_final_agent_message(events: list[dict]) -> str:
    """Return the final completed agent message without guessing alternate event shapes."""

    response = ""
    for event in events:
        item = event.get("item")
        if (
            event.get("type") == "item.completed"
            and isinstance(item, dict)
            and item.get("type") == "agent_message"
            and isinstance(item.get("text"), str)
            and item["text"].strip()
        ):
            response = item["text"]
    return response


def classify_execution_state(
    result: CommandResult, events: list[dict] | None, response_path: Path
) -> str:
    """Classify execution boundaries in timeout, process, output, then event order."""

    if result.timed_out:
        return "INFRA_BLOCKED_TIMEOUT"
    if result.returncode != 0:
        return "INFRA_BLOCKED_PROCESS"
    try:
        if not response_path.is_file() or not response_path.read_text(encoding="utf-8").strip():
            return "INFRA_BLOCKED_MISSING_OUTPUT"
    except OSError:
        return "INFRA_BLOCKED_MISSING_OUTPUT"
    if events is not None and not extract_final_agent_message(events):
        return "INFRA_BLOCKED_MISSING_OUTPUT"
    return "EXECUTOR_OK"


def _as_bytes(value: bytes | str) -> bytes:
    return value if isinstance(value, bytes) else value.encode("utf-8")
