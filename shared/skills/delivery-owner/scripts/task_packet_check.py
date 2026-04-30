#!/usr/bin/env python3
"""Validate a delivery-owner task packet before dispatch."""

from __future__ import annotations

import argparse
import json
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = (
    "task_ref",
    "role",
    "goal",
    "scope",
    "input_refs",
    "expected_evidence",
    "stop_condition",
    "forbidden_actions",
)
ALLOWED_ROLES = {
    "developer",
    "verify",
    "review",
    "qa",
    "fix",
    "consistency-audit",
    "tech-lead",
    "user",
    "product",
    "authority",
    "commit",
    "release",
}
AMBIGUOUS_VALUES = {"按需处理", "as needed", "whatever is necessary", "完成即可", "done"}


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
    return parser.parse_args(argv)


def load_packet(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise PacketFailure("MISSING_PACKET", f"packet file not found: {path}", ["packet"])
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise PacketFailure("INVALID_JSON", f"malformed JSON: {path}: {exc}", ["packet"]) from exc
    if not isinstance(payload, dict):
        raise PacketFailure("INVALID_JSON", "packet top-level JSON must be an object", ["packet"])
    return payload


def has_value(value: Any) -> bool:
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return any(has_value(item) for item in value)
    if isinstance(value, dict):
        return bool(value)
    return value is not None


def flattened_strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value.strip()]
    if isinstance(value, list):
        result: list[str] = []
        for item in value:
            result.extend(flattened_strings(item))
        return result
    return []


def assert_required(packet: dict[str, Any]) -> None:
    missing = [field for field in REQUIRED_FIELDS if not has_value(packet.get(field))]
    if missing:
        raise PacketFailure("PACKET_INCOMPLETE", f"missing required fields: {', '.join(missing)}", missing)


def assert_role(packet: dict[str, Any]) -> None:
    role = packet.get("role")
    if not isinstance(role, str) or role not in ALLOWED_ROLES:
        raise PacketFailure("ROLE_UNSUPPORTED", f"unsupported role: {role!r}", ["role"])


def assert_not_ambiguous(packet: dict[str, Any], field: str) -> None:
    values = {item.lower() for item in flattened_strings(packet.get(field))}
    if any(value in AMBIGUOUS_VALUES for value in values):
        raise PacketFailure("PACKET_AMBIGUOUS", f"{field} is too ambiguous", [field])


def validate(packet: dict[str, Any]) -> dict[str, Any]:
    assert_required(packet)
    assert_role(packet)
    for field in ("task_ref", "scope", "expected_evidence", "stop_condition", "forbidden_actions"):
        assert_not_ambiguous(packet, field)
    return {
        "status": "PASS",
        "decision": "DISPATCH_READY",
        "task_ref": packet.get("task_ref"),
        "role": packet.get("role"),
        "safe_to_dispatch": True,
    }


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
        payload = validate(load_packet(args.packet))
    except PacketFailure as exc:
        emit(failure_payload(exc), args.output)
        return 1
    emit(payload, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
