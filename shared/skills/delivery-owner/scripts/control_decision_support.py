#!/usr/bin/env python3
"""Shared helpers for delivery-owner control decision validators."""

from __future__ import annotations

import json
import re
from json import JSONDecodeError
from pathlib import Path
from typing import Any

CANONICAL_REF_RE = re.compile(r"^artifact://[a-z][a-z0-9-]*/[A-Za-z0-9._-]+@[A-Za-z0-9._-]+#[A-Za-z0-9._:-]+$")
GAP_DELTA_FIELDS = ("before_open_items", "after_open_items", "closed_items", "narrowing_basis_refs")
PACKET_DELTA_FIELDS = ("before", "after", "changed_fields", "reason", "change_basis_refs")
RETURN_LOOP_FIELDS = (
    "gap_id",
    "previous_control_decision_ref",
    "remaining_gap_ids",
    "return_count",
    "stop_condition",
    "next_no_progress_action",
)
NO_PROGRESS_ACTIONS = {"REROUTE", "ESCALATE", "REBASELINE", "BLOCKED"}


class ControlFailure(Exception):
    def __init__(self, code: str, reason: str, fields: list[str] | None = None) -> None:
        super().__init__(reason)
        self.code = code
        self.reason = reason
        self.fields = fields or []


def load_json_object(path: Path, label: str) -> dict[str, Any]:
    if not path.is_file():
        raise ControlFailure(f"MISSING_{label.upper()}", f"{label} file not found: {path}", [label])
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise ControlFailure("INVALID_JSON", f"malformed JSON: {path}: {exc}", [label]) from exc
    if not isinstance(payload, dict):
        raise ControlFailure("INVALID_JSON", f"{label} top-level JSON must be an object", [label])
    return payload


def has_value(value: Any) -> bool:
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return any(has_value(item) for item in value)
    if isinstance(value, dict):
        return any(has_value(item) for item in value.values())
    return value is not None


def require_fields(payload: dict[str, Any], fields: tuple[str, ...], path: str = "") -> None:
    missing = [field for field in fields if not has_value(payload.get(field))]
    if not missing:
        return
    prefix = f"{path}." if path else ""
    raise ControlFailure(
        "CONTROL_INCOMPLETE",
        f"missing required fields: {', '.join(prefix + field for field in missing)}",
        [prefix + field for field in missing],
    )


def require_object_fields(payload: dict[str, Any], field: str, fields: tuple[str, ...]) -> dict[str, Any]:
    value = payload.get(field)
    if not isinstance(value, dict):
        raise ControlFailure("CONTROL_INCOMPLETE", f"{field} must be an object", [field])
    require_fields(value, fields, field)
    return value


def require_matching_value(left: Any, right: Any, fields: list[str], code: str, reason: str) -> None:
    if left != right:
        raise ControlFailure(code, reason, fields)


def require_string_array(payload: dict[str, Any], field: str, path: str = "", allow_empty: bool = False) -> list[str]:
    value = payload.get(field)
    full_path = f"{path}.{field}" if path else field
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        raise ControlFailure("CONTROL_INCOMPLETE", f"{full_path} must be an array of non-empty strings", [full_path])
    if not allow_empty and not value:
        raise ControlFailure("CONTROL_INCOMPLETE", f"{full_path} must not be empty", [full_path])
    return [item.strip() for item in value]


def require_canonical_ref_array(payload: dict[str, Any], field: str, path: str = "") -> list[str]:
    refs = require_string_array(payload, field, path)
    full_path = f"{path}.{field}" if path else field
    invalid = [ref for ref in refs if not CANONICAL_REF_RE.match(ref)]
    if invalid:
        raise ControlFailure("INVALID_REF", f"{full_path} contains invalid canonical refs", [full_path])
    return refs


def require_canonical_ref(payload: dict[str, Any], field: str, path: str = "") -> str:
    value = payload.get(field)
    full_path = f"{path}.{field}" if path else field
    if not isinstance(value, str) or not CANONICAL_REF_RE.match(value):
        raise ControlFailure("INVALID_REF", f"{full_path} must be a canonical ref", [full_path])
    return value


def require_positive_int(payload: dict[str, Any], field: str, path: str) -> int:
    value = payload.get(field)
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ControlFailure("LOOP_STATE_INVALID", f"{path}.{field} must be a positive integer", [f"{path}.{field}"])
    return value


def assert_gap_delta(payload: dict[str, Any], effect: str) -> None:
    if effect not in {"gap_closed", "gap_narrowed"}:
        return
    gap_delta = payload.get("gap_delta")
    if not isinstance(gap_delta, dict):
        raise ControlFailure("GAP_DELTA_INCOMPLETE", "gap_closed or gap_narrowed requires gap_delta", ["gap_delta"])
    missing = [field for field in GAP_DELTA_FIELDS if field not in gap_delta]
    if missing:
        raise ControlFailure("GAP_DELTA_INCOMPLETE", f"missing gap_delta fields: {', '.join(missing)}", missing)
    before = set(require_string_array(gap_delta, "before_open_items", "gap_delta"))
    after = set(require_string_array(gap_delta, "after_open_items", "gap_delta", allow_empty=True))
    closed = set(require_string_array(gap_delta, "closed_items", "gap_delta"))
    require_canonical_ref_array(gap_delta, "narrowing_basis_refs", "gap_delta")
    if not after < before:
        raise ControlFailure("GAP_NOT_NARROWED", "gap_delta.after_open_items must be a strict subset of before_open_items", ["gap_delta"])
    if closed != before - after:
        raise ControlFailure("GAP_DELTA_INCONSISTENT", "gap_delta.closed_items must equal before_open_items minus after_open_items", ["gap_delta.closed_items"])
    if effect == "gap_closed" and after:
        raise ControlFailure("GAP_NOT_CLOSED", "gap_closed requires no remaining after_open_items", ["gap_delta.after_open_items"])


def assert_packet_delta(payload: dict[str, Any], effect: str) -> None:
    if effect != "packet_changed":
        return
    packet_delta = payload.get("packet_delta")
    if not isinstance(packet_delta, dict):
        raise ControlFailure("PACKET_DELTA_INCOMPLETE", "packet_changed requires packet_delta", ["packet_delta"])
    require_fields(packet_delta, PACKET_DELTA_FIELDS, "packet_delta")
    require_string_array(packet_delta, "changed_fields", "packet_delta")
    require_canonical_ref_array(packet_delta, "change_basis_refs", "packet_delta")
    if packet_delta.get("before") == packet_delta.get("after"):
        raise ControlFailure("PACKET_NOT_CHANGED", "packet_delta.before and packet_delta.after must differ", ["packet_delta"])


def assert_return_loop_state(payload: dict[str, Any], follow_up: dict[str, Any], effect: str) -> None:
    loop_state = require_object_fields(payload, "loop_state", RETURN_LOOP_FIELDS)
    return_count = require_positive_int(loop_state, "return_count", "loop_state")
    require_canonical_ref(loop_state, "previous_control_decision_ref", "loop_state")
    remaining = require_string_array(loop_state, "remaining_gap_ids", "loop_state", allow_empty=True)
    if effect == "gap_narrowed":
        after = require_string_array(payload["gap_delta"], "after_open_items", "gap_delta", allow_empty=True)
        if set(remaining) != set(after):
            raise ControlFailure(
                "LOOP_REMAINING_MISMATCH",
                "loop_state.remaining_gap_ids must match gap_delta.after_open_items",
                ["loop_state.remaining_gap_ids", "gap_delta.after_open_items"],
            )
    require_matching_value(
        loop_state.get("stop_condition"),
        follow_up.get("stop_condition"),
        ["loop_state.stop_condition", "follow_up.stop_condition"],
        "LOOP_STOP_MISMATCH",
        "RETURN loop_state.stop_condition must match follow_up.stop_condition",
    )
    if loop_state.get("next_no_progress_action") not in NO_PROGRESS_ACTIONS:
        raise ControlFailure(
            "LOOP_NEXT_ACTION_INVALID",
            "RETURN next_no_progress_action must change strategy or stop",
            ["loop_state.next_no_progress_action"],
        )
    if effect == "packet_changed" and return_count > 1:
        raise ControlFailure(
            "PACKET_REWRITE_LOOP",
            "packet_changed RETURN is only for the first same-owner packet correction",
            ["loop_state.return_count", "increment.effect"],
        )
