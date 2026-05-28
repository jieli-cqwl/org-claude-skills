#!/usr/bin/env python3
"""Validate a delivery-owner task packet before dispatch."""

from __future__ import annotations

import argparse
import json
import re
import sys
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
