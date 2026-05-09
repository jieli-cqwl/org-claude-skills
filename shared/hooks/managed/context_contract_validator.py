#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def runtime_home() -> Path:
    current = Path(__file__).resolve()
    candidates = [current.parents[2]]
    if len(current.parents) > 3:
        candidates.append(current.parents[3])
    for candidate in candidates:
        if (candidate / "tools" / "community" / "validate_context_contract.py").is_file():
            return candidate
    return candidates[0]


RUNTIME_HOME = runtime_home()
VALIDATOR = RUNTIME_HOME / "tools" / "community" / "validate_context_contract.py"
VALIDATOR_TIMEOUT_SEC = 25


def load_payload() -> dict:
    text = sys.stdin.read()
    if not text.strip():
        return {}
    try:
        payload = json.loads(text)
    except Exception:
        return {}
    return payload if isinstance(payload, dict) else {}


def payload_cwd(payload: dict) -> Path:
    cwd = payload.get("cwd")
    if isinstance(cwd, str) and cwd:
        return Path(cwd)
    return Path(os.getcwd())


def git_root(cwd: Path) -> Path | None:
    try:
        proc = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
            text=True,
            capture_output=True,
            timeout=2,
        )
    except Exception:
        return None
    if proc.returncode != 0:
        return None
    value = proc.stdout.strip()
    return Path(value) if value else None


def find_context_root(cwd: Path) -> Path:
    root = git_root(cwd)
    if root is not None:
        return root
    resolved = cwd.resolve()
    for candidate in (resolved, *resolved.parents):
        if (candidate / "contracts" / "active-doc-scope.yaml").is_file():
            return candidate
    return resolved


def is_participating_repo(root: Path) -> bool:
    return (root / "contracts" / "active-doc-scope.yaml").is_file()


def hook_event_name(payload: dict) -> str:
    event = payload.get("hook_event_name") or payload.get("hookEventName")
    return str(event) if isinstance(event, str) and event else ""


def is_stop_payload(payload: dict) -> bool:
    return hook_event_name(payload) == "Stop" or "stop_hook_active" in payload


def emit_allow() -> int:
    print("{}")
    return 0


def emit_failure(reason: str, stop_payload: bool) -> int:
    cleaned = reason.strip() or "context contract validation failed"
    if stop_payload:
        print(
            json.dumps(
                {
                    "decision": "block",
                    "reason": cleaned,
                    "systemMessage": cleaned,
                },
                ensure_ascii=False,
            )
        )
        return 0
    print(
        json.dumps(
            {
                "decision": "block",
                "reason": cleaned,
                "systemMessage": cleaned,
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": cleaned,
                },
            },
            ensure_ascii=False,
        )
    )
    return 0


def main() -> int:
    payload = load_payload()
    root = find_context_root(payload_cwd(payload))
    if not is_participating_repo(root):
        return emit_allow()
    if not VALIDATOR.is_file():
        return emit_failure("context contract validator runtime file missing", is_stop_payload(payload))

    try:
        proc = subprocess.run(
            [sys.executable, str(VALIDATOR), "--repo-root", str(root)],
            text=True,
            capture_output=True,
            timeout=VALIDATOR_TIMEOUT_SEC,
        )
    except subprocess.TimeoutExpired:
        return emit_failure("context contract validation timed out", is_stop_payload(payload))
    if proc.returncode == 0:
        return emit_allow()
    reason = (proc.stdout or proc.stderr).strip()
    return emit_failure(reason, is_stop_payload(payload))


if __name__ == "__main__":
    raise SystemExit(main())
