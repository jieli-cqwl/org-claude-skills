#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


RUNTIME_HOME = Path(__file__).resolve().parents[2]
ACTIVE_STATE_DIR = Path(
    os.environ.get(
        "ORG_CODEX_ACTIVE_SKILLS_STATE_DIR",
        str(RUNTIME_HOME / "hooks" / "state" / "active-skills"),
    )
)
AUTH_STATE_DIR = Path(
    os.environ.get(
        "ORG_CODEX_DISPATCH_AUTH_STATE_DIR",
        str(RUNTIME_HOME / "hooks" / "state" / "standard-chain-dispatch"),
    )
)
PROTECTED_AGENT_ROLES = {
    "consistency-auditor": "consistency-auditor",
    "developer": "developer",
    "verifier": "verifier",
    "qa": "qa",
    "fixer": "fixer",
}
AGENT_NAME_KEYS = (
    "agent_name",
    "agentName",
    "subagent_name",
    "subagentName",
    "agent",
    "agent_type",
    "agentType",
    "subagent_type",
    "subagentType",
    "name",
    "type",
)
NESTED_PAYLOAD_KEYS = (
    "subagent",
    "agent",
    "tool_input",
    "toolInput",
    "input",
    "metadata",
)


def emit_allow() -> None:
    sys.stdout.write("{}\n")


def emit_block(code: str, reason: str) -> None:
    payload = {
        "decision": "block",
        "failure_code": code,
        "reason": reason,
        "systemMessage": reason,
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")


def state_file_for(directory: Path, session_id: str) -> Path:
    return directory / f"{session_id}.json"


def normalize_agent_name(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    text = value.strip()
    if not text:
        return None
    if text.startswith("agents."):
        text = text.removeprefix("agents.")
    return text


def extract_agent_name(payload: dict[str, Any]) -> str | None:
    for key in AGENT_NAME_KEYS:
        name = normalize_agent_name(payload.get(key))
        if name:
            return name

    for key in NESTED_PAYLOAD_KEYS:
        nested = payload.get(key)
        if not isinstance(nested, dict):
            continue
        name = extract_agent_name(nested)
        if name:
            return name

    return None


def extract_session_id(payload: dict[str, Any]) -> str | None:
    for key in ("session_id", "sessionId"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("state file must be a JSON object")
    return payload


def load_active_skill(session_id: str) -> str | None:
    path = state_file_for(ACTIVE_STATE_DIR, session_id)
    if not path.exists():
        return None
    payload = load_json(path)
    skill = payload.get("skill")
    if not isinstance(skill, str) or not skill.strip():
        raise ValueError("active skill state missing skill")
    return skill.strip()


def parse_expires_at(value: Any) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("dispatch authorization missing expires_at")
    parsed = datetime.fromisoformat(value.strip())
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def validate_dispatch_authorization(
    session_id: str, agent_name: str, expected_role: str
) -> tuple[bool, str, str | None]:
    auth_file = state_file_for(AUTH_STATE_DIR, session_id)
    if not auth_file.exists():
        return False, "MISSING_DISPATCH_AUTH", "缺少 delivery-owner dispatch authorization。"

    try:
        token = load_json(auth_file)
    except Exception:
        return False, "AUTH_UNREADABLE", "dispatch authorization 状态损坏，不能启动受管 agent。"

    if token.get("session_id") != session_id:
        return False, "SESSION_MISMATCH", "dispatch authorization session_id 不匹配。"
    if token.get("authorized_by") != "delivery-owner":
        return False, "AUTH_INVALID", "dispatch authorization 不是 delivery-owner 签发。"
    if token.get("role") != expected_role:
        return (
            False,
            "ROLE_MISMATCH",
            f"dispatch authorization role 与目标 agent 不匹配: {agent_name}。",
        )

    try:
        expires_at = parse_expires_at(token.get("expires_at"))
    except ValueError:
        return False, "AUTH_INVALID", "dispatch authorization 过期时间无效。"
    if expires_at <= datetime.now(timezone.utc):
        auth_file.unlink(missing_ok=True)
        return False, "AUTH_EXPIRED", "dispatch authorization 已过期。"

    auth_file.unlink(missing_ok=True)
    return True, "OK", None


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except json.JSONDecodeError:
        emit_allow()
        return 0
    if not isinstance(payload, dict):
        emit_allow()
        return 0

    agent_name = extract_agent_name(payload)
    expected_role = PROTECTED_AGENT_ROLES.get(agent_name or "")
    if expected_role is None:
        emit_allow()
        return 0

    session_id = extract_session_id(payload)
    if not session_id:
        emit_block("MISSING_SESSION", "受管 agent 启动缺少 session_id，无法验证 delivery-owner 调度授权。")
        return 0

    try:
        active_skill = load_active_skill(session_id)
    except Exception:
        emit_block("ACTIVE_SKILL_UNREADABLE", "active skill 状态损坏，无法验证 delivery-owner 调度授权。")
        return 0

    if active_skill != "delivery-owner":
        emit_block("MISSING_DELIVERY_OWNER", "当前 active skill 不是 delivery-owner，禁止启动受管 agent。")
        return 0

    ok, code, reason = validate_dispatch_authorization(session_id, agent_name or "", expected_role)
    if not ok:
        emit_block(code, reason or "dispatch authorization 无效。")
        return 0

    emit_allow()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
