#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


RUNTIME_HOME = Path(__file__).resolve().parents[2]
REGISTRY_FILE = RUNTIME_HOME / "hooks" / "registry.json"
STATE_DIR = RUNTIME_HOME / "hooks" / "state" / "active-skills"


def load_registry() -> dict:
    return json.loads(REGISTRY_FILE.read_text(encoding="utf-8"))


def load_active_skill(session_id: str) -> str | None:
    state_file = STATE_DIR / f"{session_id}.json"
    if not state_file.exists():
        return None
    try:
        payload = json.loads(state_file.read_text(encoding="utf-8"))
    except Exception:
        return None
    skill = payload.get("skill")
    return skill if isinstance(skill, str) and skill else None


def gate_for_skill(registry: dict, skill: str) -> Path | None:
    for entry in registry.get("skill_completion_gates", []):
        if entry.get("skill") != skill:
            continue
        if not entry.get("codex", {}).get("supported"):
            return None
        return RUNTIME_HOME / entry["handler_rel"]
    return None


def extract_failure_reason(stdout: str, stderr: str, skill: str) -> str:
    for raw_line in reversed(stdout.splitlines()):
        line = raw_line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except Exception:
            continue

        if isinstance(payload, dict):
            for key in ("reason", "stopReason", "message"):
                value = payload.get(key)
                if isinstance(value, str) and value.strip():
                    return value.strip()

    for stream in (stderr, stdout):
        text = stream.strip()
        if text:
            return text

    return f"{skill} completion gate failed."


def emit_stop_failure(reason: str) -> None:
    payload = {
        "continue": False,
        "stopReason": reason,
        "systemMessage": reason,
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")


def main() -> int:
    payload = json.loads(sys.stdin.read() or "{}")
    session_id = payload.get("session_id") or payload.get("sessionId")
    if not session_id:
        print("{}")
        return 0

    skill = load_active_skill(session_id)
    if not skill:
        print("{}")
        return 0

    gate_path = gate_for_skill(load_registry(), skill)
    if not gate_path or not gate_path.exists():
        print("{}")
        return 0

    proc = subprocess.run(
        ["bash", str(gate_path)],
        input=json.dumps(payload, ensure_ascii=False),
        text=True,
        capture_output=True,
    )

    if proc.returncode == 0 and proc.stdout:
        sys.stdout.write(proc.stdout)
        if not proc.stdout.endswith("\n"):
            sys.stdout.write("\n")
    elif proc.returncode == 0:
        sys.stdout.write("{}\n")
        return 0

    emit_stop_failure(extract_failure_reason(proc.stdout, proc.stderr, skill))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
