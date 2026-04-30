#!/usr/bin/env python3
"""Validate a delivery-owner control decision before the next loop."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from control_decision_support import (
    ControlFailure,
    assert_gap_delta,
    assert_packet_delta,
    assert_return_loop_state,
    has_value,
    load_json_object,
    require_canonical_ref_array,
    require_fields,
    require_matching_value,
    require_object_fields,
)

REQUIRED_FIELDS = (
    "task_ref",
    "previous_owner",
    "owner",
    "gap",
    "decision",
    "increment",
    "evidence_refs",
    "next_action",
)
ALLOWED_DECISIONS = {
    "ADVANCE",
    "RETURN",
    "REROUTE",
    "ESCALATE",
    "REBASELINE",
    "SIGNOFF_READY",
    "BLOCKED",
}
INCREMENT_KINDS = {
    "evidence",
    "fix",
    "judgment",
    "blocker",
    "risk",
    "authority_decision",
    "owner_changed",
    "packet_changed",
    "rebaseline_request",
    "readiness_bundle",
    "no_increment",
}
INCREMENT_EFFECTS = {
    "gap_closed",
    "gap_narrowed",
    "new_blocker",
    "new_risk",
    "owner_changed",
    "packet_changed",
    "rebaseline_needed",
    "readiness_bundle_complete",
    "no_progress",
}
NO_INCREMENT_DECISIONS = {"REROUTE", "ESCALATE", "REBASELINE", "BLOCKED"}
FOLLOW_UP_FIELDS = ("missing_gap", "expected_new_evidence", "stop_condition")
EXECUTOR_OWNERS = {"developer", "verify", "review", "qa", "fix", "consistency-audit"}
READINESS_BUNDLE_FIELDS = (
    "developer_reports",
    "verify_results",
    "code_review_result",
    "qa_result",
    "consistency_audit_result",
    "signoff_package",
)
ESCALATION_PACKET_FIELDS = (
    "problem",
    "attempted_actions",
    "blocking_decision",
    "options",
    "recommended_path",
    "risk",
    "required_authority",
    "evidence_refs",
)
REBASELINE_REQUEST_FIELDS = (
    "problem",
    "affected_refs",
    "requested_update",
    "rebaseline_owner",
    "evidence_refs",
    "stop_condition",
)
BLOCKER_PACKET_FIELDS = (
    "blocked_by",
    "attempted_actions",
    "unblock_condition",
    "next_owner",
    "evidence_refs",
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--decision", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def load_decision(path: Path) -> dict[str, Any]:
    return load_json_object(path, "decision")


def increment_state(payload: dict[str, Any]) -> tuple[str, str]:
    increment = payload.get("increment")
    if not isinstance(increment, dict):
        raise ControlFailure("CONTROL_INCOMPLETE", "increment must be an object", ["increment"])
    kind = increment.get("kind")
    if kind not in INCREMENT_KINDS:
        raise ControlFailure("INVALID_INCREMENT", f"unsupported increment kind: {kind!r}", ["increment.kind"])
    effect = increment.get("effect")
    if effect not in INCREMENT_EFFECTS:
        raise ControlFailure("INVALID_INCREMENT", f"unsupported increment effect: {effect!r}", ["increment.effect"])
    if kind == "no_increment":
        if not has_value(increment.get("reason")):
            raise ControlFailure("NO_INCREMENT_UNEXPLAINED", "no_increment requires a reason", ["increment.reason"])
        if effect != "no_progress":
            raise ControlFailure("INVALID_INCREMENT", "no_increment requires effect=no_progress", ["increment.effect"])
    elif not has_value(increment.get("summary")):
        raise ControlFailure("CONTROL_INCOMPLETE", "increment.summary is required", ["increment.summary"])
    elif effect == "no_progress":
        raise ControlFailure(
            "INCREMENT_NO_PROGRESS",
            "non-no_increment decisions must close, narrow, or reroute the gap",
            ["increment.kind", "increment.effect"],
        )
    return str(kind), str(effect)


def assert_decision(payload: dict[str, Any]) -> str:
    decision = payload.get("decision")
    if decision not in ALLOWED_DECISIONS:
        raise ControlFailure("INVALID_DECISION", f"unsupported control decision: {decision!r}", ["decision"])
    return str(decision)


def assert_no_increment_policy(payload: dict[str, Any], decision: str, kind: str) -> None:
    if kind != "no_increment":
        return
    if decision not in NO_INCREMENT_DECISIONS:
        raise ControlFailure(
            "NO_INCREMENT_REPEATED",
            "no_increment cannot ADVANCE, RETURN, or SIGNOFF_READY; change strategy or stop",
            ["increment.kind", "decision"],
        )
    if decision == "REROUTE" and payload.get("previous_owner") == payload.get("owner"):
        raise ControlFailure(
            "NO_INCREMENT_SAME_OWNER",
            "no_increment REROUTE must change owner",
            ["previous_owner", "owner"],
        )


def assert_kind_matches_effect(kind: str, effect: str) -> None:
    allowed_kinds_by_effect = {
        "gap_closed": {"evidence", "fix", "judgment", "authority_decision"},
        "gap_narrowed": {"evidence", "fix", "judgment"},
        "new_blocker": {"blocker"},
        "new_risk": {"risk"},
        "owner_changed": {"owner_changed"},
        "packet_changed": {"packet_changed"},
        "rebaseline_needed": {"rebaseline_request"},
        "readiness_bundle_complete": {"readiness_bundle"},
        "no_progress": {"no_increment"},
    }
    allowed = allowed_kinds_by_effect.get(effect, set())
    if kind not in allowed:
        raise ControlFailure(
            "KIND_EFFECT_MISMATCH",
            f"increment.kind={kind} is not valid for increment.effect={effect}",
            ["increment.kind", "increment.effect"],
        )


def assert_effect_matches_decision(decision: str, effect: str) -> None:
    allowed_by_decision = {
        "ADVANCE": {"gap_closed"},
        "RETURN": {"gap_narrowed", "packet_changed"},
        "REROUTE": {"owner_changed", "new_blocker", "new_risk", "no_progress"},
        "ESCALATE": {"new_blocker", "new_risk", "no_progress"},
        "REBASELINE": {"rebaseline_needed", "new_blocker", "no_progress"},
        "SIGNOFF_READY": {"readiness_bundle_complete"},
        "BLOCKED": {"new_blocker", "new_risk", "no_progress"},
    }
    allowed = allowed_by_decision.get(decision, set())
    if effect not in allowed:
        raise ControlFailure(
            "EFFECT_DECISION_MISMATCH",
            f"increment.effect={effect} is not valid for decision={decision}",
            ["increment.effect", "decision"],
        )


def assert_decision_specific_fields(payload: dict[str, Any], decision: str, effect: str) -> None:
    if decision == "RETURN":
        if payload.get("previous_owner") != payload.get("owner"):
            raise ControlFailure(
                "RETURN_OWNER_CHANGED",
                "RETURN must keep the same owner; use REROUTE when owner changes",
                ["previous_owner", "owner", "decision"],
            )
        follow_up = payload.get("follow_up")
        if not isinstance(follow_up, dict):
            raise ControlFailure("FOLLOW_UP_INCOMPLETE", "RETURN requires follow_up object", ["follow_up"])
        require_fields(follow_up, FOLLOW_UP_FIELDS, "follow_up")
        assert_return_loop_state(payload, follow_up, effect)
    elif decision == "REROUTE":
        if payload.get("previous_owner") == payload.get("owner"):
            raise ControlFailure("REROUTE_SAME_OWNER", "REROUTE must change owner", ["previous_owner", "owner"])
        if payload.get("owner") not in EXECUTOR_OWNERS:
            raise ControlFailure(
                "REROUTE_OWNER_UNSUPPORTED",
                "REROUTE owner must be an executable role owner",
                ["owner"],
            )
        if not has_value(payload.get("reroute_reason")):
            raise ControlFailure("REROUTE_INCOMPLETE", "REROUTE requires reroute_reason", ["reroute_reason"])
    elif decision == "ESCALATE":
        if not has_value(payload.get("required_authority")):
            raise ControlFailure("ESCALATION_INCOMPLETE", "ESCALATE requires required_authority", ["required_authority"])
        packet = require_object_fields(payload, "escalation_packet", ESCALATION_PACKET_FIELDS)
        require_matching_value(
            payload.get("owner"),
            payload.get("required_authority"),
            ["owner", "required_authority"],
            "OWNER_AUTHORITY_MISMATCH",
            "ESCALATE owner must be the required_authority",
        )
        require_matching_value(
            packet.get("required_authority"),
            payload.get("required_authority"),
            ["escalation_packet.required_authority", "required_authority"],
            "ESCALATION_PACKET_MISMATCH",
            "escalation_packet.required_authority must match required_authority",
        )
        require_canonical_ref_array(packet, "evidence_refs", "escalation_packet")
    elif decision == "REBASELINE":
        if not has_value(payload.get("rebaseline_reason")):
            raise ControlFailure("REBASELINE_INCOMPLETE", "REBASELINE requires rebaseline_reason", ["rebaseline_reason"])
        request = require_object_fields(payload, "rebaseline_request", REBASELINE_REQUEST_FIELDS)
        require_matching_value(
            payload.get("owner"),
            request.get("rebaseline_owner"),
            ["owner", "rebaseline_request.rebaseline_owner"],
            "OWNER_REBASELINE_MISMATCH",
            "REBASELINE owner must match rebaseline_request.rebaseline_owner",
        )
        require_canonical_ref_array(request, "evidence_refs", "rebaseline_request")
    elif decision == "BLOCKED":
        if not has_value(payload.get("blocked_by")):
            raise ControlFailure("BLOCKED_INCOMPLETE", "BLOCKED requires blocked_by", ["blocked_by"])
        packet = require_object_fields(payload, "blocker_packet", BLOCKER_PACKET_FIELDS)
        require_matching_value(
            payload.get("owner"),
            packet.get("next_owner"),
            ["owner", "blocker_packet.next_owner"],
            "OWNER_BLOCKER_MISMATCH",
            "BLOCKED owner must match blocker_packet.next_owner",
        )
        require_canonical_ref_array(packet, "evidence_refs", "blocker_packet")
    elif decision == "SIGNOFF_READY":
        bundle = payload.get("readiness_bundle_refs")
        if not isinstance(bundle, dict):
            raise ControlFailure("READINESS_BUNDLE_INCOMPLETE", "SIGNOFF_READY requires readiness_bundle_refs", ["readiness_bundle_refs"])
        require_fields(bundle, READINESS_BUNDLE_FIELDS, "readiness_bundle_refs")


def validate(payload: dict[str, Any]) -> dict[str, Any]:
    require_fields(payload, REQUIRED_FIELDS)
    decision = assert_decision(payload)
    kind, effect = increment_state(payload)
    require_canonical_ref_array(payload, "evidence_refs")
    assert_no_increment_policy(payload, decision, kind)
    assert_kind_matches_effect(kind, effect)
    assert_effect_matches_decision(decision, effect)
    assert_gap_delta(payload, effect)
    assert_packet_delta(payload, effect)
    assert_decision_specific_fields(payload, decision, effect)
    return {
        "status": "PASS",
        "decision": "CONTROL_READY",
        "control_decision": decision,
        "increment_kind": kind,
        "increment_effect": effect,
        "safe_to_continue": True,
    }


def failure_payload(exc: ControlFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "decision": "CONTROL_BLOCKED",
        "failure_code": exc.code,
        "reason": exc.reason,
        "fields": exc.fields,
        "safe_to_continue": False,
    }


def emit(payload: dict[str, Any], output: Path | None) -> None:
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    if output:
        output.write_text(text + "\n", encoding="utf-8")
    print(text)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        payload = validate(load_decision(args.decision))
    except ControlFailure as exc:
        emit(failure_payload(exc), args.output)
        return 1
    emit(payload, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
