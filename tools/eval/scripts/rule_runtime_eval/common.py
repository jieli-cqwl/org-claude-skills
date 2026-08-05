"""Common deterministic utilities for rule-runtime evaluation."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time


@dataclass(frozen=True)
class CommandResult:
    args: list[str]
    returncode: int | None
    stdout: str
    stderr: str
    timed_out: bool
    started_at: str
    ended_at: str
    duration_seconds: float


def run_command(
    args: list[str],
    *,
    cwd: Path,
    env: dict[str, str],
    timeout_seconds: int,
) -> CommandResult:
    """Run a bounded command while retaining complete process evidence."""

    started_at = datetime.now(UTC)
    started = time.monotonic()
    try:
        completed = subprocess.run(
            args,
            cwd=cwd,
            env=env,
            capture_output=True,
            check=False,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_seconds,
        )
        returncode = completed.returncode
        stdout = completed.stdout
        stderr = completed.stderr
        timed_out = False
    except subprocess.TimeoutExpired as exc:
        returncode = None
        stdout = _as_text(exc.stdout)
        stderr = _as_text(exc.stderr)
        timed_out = True
    ended_at = datetime.now(UTC)
    return CommandResult(
        args=list(args),
        returncode=returncode,
        stdout=stdout,
        stderr=stderr,
        timed_out=timed_out,
        started_at=started_at.isoformat(),
        ended_at=ended_at.isoformat(),
        duration_seconds=time.monotonic() - started,
    )


def sha256_file(path: Path) -> str:
    """Return the SHA-256 digest of a file without decoding its content."""

    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_json(payload: object) -> str:
    """Return a stable UTF-8 JSON hash for structured contract inputs."""

    return hashlib.sha256(_json_bytes(payload)).hexdigest()


def write_json(path: Path, payload: object) -> None:
    """Write stable UTF-8 JSON for deterministic machine-readable evidence."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_json_bytes(payload, indent=2) + b"\n")


def redact_stderr(value: str, source: str) -> str:
    """Withhold auth-adjacent process stderr while preserving its presence."""

    return f"[{source} stderr withheld]\n" if value else ""


def _json_bytes(payload: object, *, indent: int | None = None) -> bytes:
    return json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        indent=indent,
        separators=(",", ":") if indent is None else None,
    ).encode("utf-8")


def _as_text(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value
