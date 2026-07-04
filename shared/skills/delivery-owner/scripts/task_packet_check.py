#!/usr/bin/env python3
"""Validate a delivery-owner task packet before dispatch."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from json import JSONDecodeError
from pathlib import Path
from typing import Any

from task_packet_rules import (
    ALLOWED_ROLES,
    AMBIGUOUS_VALUES,
    CONSISTENCY_AUDIT_FINAL_INPUT_CATEGORIES,
    FORBIDDEN_ACTION_CATEGORIES,
    LEGACY_FIELD_REPLACEMENTS,
    REQUIRED_FIELDS,
    ROLE_EVIDENCE_CATEGORIES,
    ROLE_INPUT_CATEGORIES,
)


DISPATCH_AUTH_ROLES = {
    "consistency-auditor",
    "developer",
    "verifier",
    "qa",
    "fixer",
}
SESSION_ID_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]+$")
DEFAULT_AUTH_TTL_SECONDS = 600


class PacketFailure(Exception):
    def __init__(self, code: str, reason: str, fields: list[str] | None = None) -> None:
        super().__init__(reason)
        self.code = code
        self.reason = reason
        self.fields = fields or []


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packet", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--authorize-dispatch", action="store_true")
    parser.add_argument("--session-id")
    parser.add_argument("--dispatch-state-dir", type=Path)
    parser.add_argument("--ttl-seconds", type=int, default=DEFAULT_AUTH_TTL_SECONDS)
    args = parser.parse_args(argv)
    if args.ttl_seconds <= 0:
        parser.error("--ttl-seconds must be positive")
    return args


def load_packet(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise PacketFailure(
            "MISSING_PACKET", f"packet file not found: {path}", ["packet"]
        )
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise PacketFailure(
            "INVALID_JSON", f"malformed JSON: {path}: {exc}", ["packet"]
        ) from exc
    if not isinstance(payload, dict):
        raise PacketFailure(
            "INVALID_JSON", "packet top-level JSON must be an object", ["packet"]
        )
    return payload


def packet_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def has_value(value: Any) -> bool:
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return any(has_value(item) for item in value)
    if isinstance(value, dict):
        return any(has_value(item) for item in value.values())
    return value is not None


def flattened_strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value.strip()]
    if isinstance(value, list):
        result: list[str] = []
        for item in value:
            result.extend(flattened_strings(item))
        return result
    if isinstance(value, dict):
        result: list[str] = []
        for item in value.values():
            result.extend(flattened_strings(item))
        return result
    return []


def is_ambiguous_text(value: str) -> bool:
    normalized = value.casefold().strip()
    separator = r"[\s。．.!！?？,，;；:：]+"
    for term in AMBIGUOUS_VALUES:
        if any(ord(char) > 127 for char in term):
            if term in normalized:
                return True
            continue
        if re.search(rf"(^|{separator}){re.escape(term)}({separator}|$)", normalized):
            return True
    return False


def assert_required(packet: dict[str, Any]) -> None:
    missing = [field for field in REQUIRED_FIELDS if not has_value(packet.get(field))]
    if missing:
        raise PacketFailure(
            "PACKET_INCOMPLETE",
            f"missing required fields: {', '.join(missing)}",
            missing,
        )


def assert_no_legacy_fields(packet: dict[str, Any]) -> None:
    legacy_fields = [field for field in LEGACY_FIELD_REPLACEMENTS if field in packet]
    if legacy_fields:
        replacements = ", ".join(
            f"{field}->{LEGACY_FIELD_REPLACEMENTS[field]}" for field in legacy_fields
        )
        raise PacketFailure(
            "PACKET_UNSAFE",
            f"legacy packet fields are not allowed: {replacements}",
            legacy_fields,
        )


def assert_role(packet: dict[str, Any]) -> None:
    role = packet.get("role")
    if not isinstance(role, str) or role not in ALLOWED_ROLES:
        raise PacketFailure("ROLE_UNSUPPORTED", f"unsupported role: {role!r}", ["role"])


def assert_not_ambiguous(packet: dict[str, Any], field: str) -> None:
    if any(is_ambiguous_text(value) for value in flattened_strings(packet.get(field))):
        raise PacketFailure("PACKET_AMBIGUOUS", f"{field} is too ambiguous", [field])


def assert_forbidden_actions(packet: dict[str, Any]) -> None:
    text = " ".join(flattened_strings(packet.get("forbidden_actions"))).lower()
    missing = [
        category
        for category, terms in FORBIDDEN_ACTION_CATEGORIES.items()
        if not any(re.search(term, text, flags=re.IGNORECASE) for term in terms)
    ]
    if missing:
        raise PacketFailure(
            "PACKET_UNSAFE",
            "forbidden_actions must cover scope, baseline, commit/release, and role boundaries",
            ["forbidden_actions", *missing],
        )


def assert_role_evidence(packet: dict[str, Any]) -> None:
    role = str(packet.get("role"))
    categories = ROLE_EVIDENCE_CATEGORIES.get(role, {})
    text = " ".join(flattened_strings(packet.get("expected_evidence"))).lower()
    missing = [
        category
        for category, terms in categories.items()
        if not any(re.search(term, text, flags=re.IGNORECASE) for term in terms)
    ]
    if missing:
        raise PacketFailure(
            "PACKET_EVIDENCE_INCOMPLETE",
            f"expected_evidence for {role} is missing role-specific evidence: {', '.join(missing)}",
            ["expected_evidence", *missing],
        )


def assert_role_inputs(packet: dict[str, Any]) -> None:
    role = str(packet.get("role"))
    if role == "consistency-auditor":
        assert_consistency_auditor_inputs(packet)
        return
    categories = ROLE_INPUT_CATEGORIES.get(role, {})
    text = " ".join(flattened_strings(packet.get("input_refs"))).lower()
    missing = [
        category
        for category, terms in categories.items()
        if not any(re.search(term, text, flags=re.IGNORECASE) for term in terms)
    ]
    if missing:
        raise PacketFailure(
            "PACKET_INPUT_INCOMPLETE",
            f"input_refs for {role} is missing role-specific refs: {', '.join(missing)}",
            ["input_refs", *missing],
        )


def assert_consistency_auditor_inputs(packet: dict[str, Any]) -> None:
    goal_text = " ".join(
        flattened_strings(
            [packet.get("task_ref"), packet.get("goal"), packet.get("forbidden_scope")]
        )
    ).lower()
    categories = ROLE_INPUT_CATEGORIES["consistency-auditor"]
    if any(term in goal_text for term in ("full", "commit", "提交", "final", "do-s8")):
        categories = CONSISTENCY_AUDIT_FINAL_INPUT_CATEGORIES
    text = " ".join(flattened_strings(packet.get("input_refs"))).lower()
    missing = [
        category
        for category, terms in categories.items()
        if not any(re.search(term, text, flags=re.IGNORECASE) for term in terms)
    ]
    if missing:
        raise PacketFailure(
            "PACKET_INPUT_INCOMPLETE",
            f"input_refs for consistency-auditor is missing mode-specific refs: {', '.join(missing)}",
            ["input_refs", *missing],
        )


def validate(packet: dict[str, Any]) -> dict[str, Any]:
    assert_required(packet)
    assert_no_legacy_fields(packet)
    assert_role(packet)
    for field in (
        "task_ref",
        "goal",
        "forbidden_scope",
        "input_refs",
        "expected_evidence",
        "stop_condition",
        "forbidden_actions",
    ):
        assert_not_ambiguous(packet, field)
    assert_forbidden_actions(packet)
    assert_role_inputs(packet)
    assert_role_evidence(packet)
    return {
        "status": "PASS",
        "decision": "DISPATCH_READY",
        "task_ref": packet.get("task_ref"),
        "role": packet.get("role"),
        "safe_to_dispatch": True,
    }


def default_dispatch_state_dir() -> Path:
    configured = os.environ.get("ORG_CODEX_DISPATCH_AUTH_STATE_DIR")
    if configured:
        return Path(configured)
    return Path.home() / ".codex" / "hooks" / "state" / "standard-chain-dispatch"


def dispatch_auth_state_dir(args: argparse.Namespace) -> Path:
    return args.dispatch_state_dir or default_dispatch_state_dir()


def active_skills_state_dir() -> Path:
    configured = os.environ.get("ORG_CODEX_ACTIVE_SKILLS_STATE_DIR")
    if configured:
        return Path(configured)
    return Path.home() / ".codex" / "hooks" / "state" / "active-skills"


def parse_timestamp(value: Any, fallback: float) -> float:
    if isinstance(value, str) and value.strip():
        try:
            parsed = datetime.fromisoformat(value.strip())
        except ValueError:
            return fallback
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.timestamp()
    return fallback


def infer_delivery_owner_session_id() -> str:
    state_dir = active_skills_state_dir()
    if not state_dir.is_dir():
        raise PacketFailure(
            "MISSING_DELIVERY_OWNER_SESSION",
            "active skill state is unavailable; pass --session-id explicitly",
            ["session_id"],
        )

    candidates: list[tuple[float, str]] = []
    for path in state_dir.glob("*.json"):
        try:
            state = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, JSONDecodeError):
            continue
        if not isinstance(state, dict) or state.get("skill") != "delivery-owner":
            continue
        session_id = state.get("session_id")
        if not isinstance(session_id, str) or not session_id.strip():
            session_id = path.stem
        try:
            mtime = path.stat().st_mtime
        except OSError:
            mtime = 0.0
        candidates.append((parse_timestamp(state.get("updated_at"), mtime), session_id.strip()))

    if not candidates:
        raise PacketFailure(
            "MISSING_DELIVERY_OWNER_SESSION",
            "no active delivery-owner session found; pass --session-id explicitly",
            ["session_id"],
        )

    candidates.sort(reverse=True)
    return candidates[0][1]


def resolve_dispatch_session_id(args: argparse.Namespace) -> str:
    if args.session_id:
        return args.session_id
    return infer_delivery_owner_session_id()


def dispatch_auth_file(state_dir: Path, session_id: str) -> Path:
    if not SESSION_ID_PATTERN.fullmatch(session_id):
        raise PacketFailure(
            "INVALID_SESSION_ID",
            "session_id contains unsupported characters",
            ["session_id"],
        )
    return state_dir / f"{session_id}.json"


def write_dispatch_authorization(
    args: argparse.Namespace, packet: dict[str, Any], result: dict[str, Any]
) -> Path:
    role = result.get("role")
    if role not in DISPATCH_AUTH_ROLES:
        raise PacketFailure(
            "ROLE_NOT_AGENT_BACKED",
            f"role cannot be authorized for Codex agent dispatch: {role}",
            ["role"],
        )

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(seconds=args.ttl_seconds)
    state_dir = dispatch_auth_state_dir(args)
    state_dir.mkdir(parents=True, exist_ok=True)
    session_id = resolve_dispatch_session_id(args)
    auth_file = dispatch_auth_file(state_dir, session_id)
    token = {
        "schema_version": 1,
        "session_id": session_id,
        "role": role,
        "task_ref": result.get("task_ref"),
        "authorized_by": "delivery-owner",
        "created_at": now.isoformat(),
        "expires_at": expires_at.isoformat(),
        "packet_sha256": packet_sha256(args.packet),
    }
    tmp_file = auth_file.with_name(f".{auth_file.name}.{os.getpid()}.tmp")
    tmp_file.write_text(
        json.dumps(token, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    tmp_file.replace(auth_file)
    result["dispatch_session_id"] = session_id
    return auth_file


def failure_payload(exc: PacketFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "decision": "PACKET_BLOCKED",
        "failure_code": exc.code,
        "reason": exc.reason,
        "fields": exc.fields,
        "safe_to_dispatch": False,
    }


def emit(payload: dict[str, Any], output: Path | None) -> None:
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    if output:
        output.write_text(text + "\n", encoding="utf-8")
    print(text)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        packet = load_packet(args.packet)
        payload = validate(packet)
        if args.authorize_dispatch:
            auth_file = write_dispatch_authorization(args, packet, payload)
            payload["dispatch_authorization_ref"] = str(auth_file)
    except PacketFailure as exc:
        emit(failure_payload(exc), args.output)
        return 1
    emit(payload, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
