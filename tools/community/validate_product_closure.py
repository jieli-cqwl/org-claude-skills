#!/usr/bin/env python3
"""Validate final product planning closure fields for canonical readiness gates."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime
from pathlib import Path

from normalize_canonical_artifact import load_json

PLACEHOLDER_VALUES = {"", "tbd", "todo", "n/a", "na", "-", "待定", "未定", "占位"}

CLOSED_ISSUE_STATUSES = {
    "CLOSED",
    "WAIVED",
    "ACCEPTED",
    "ACCEPTED_RISK",
    "DEFERRED",
    "RESOLVED",
}

REQUIRED_WARN_ISSUE_FIELDS = {
    "issue_id",
    "status",
    "severity",
    "dimension",
    "finding",
    "evidence",
    "handoff_target",
}

DIRECTOR_LOCK_FIELDS = {
    "brief": ("root_problem", "business_goals", "scope_boundaries", "delivery_plan"),
    "phase-prd": ("phase_goal", "entry_conditions", "exit_conditions"),
}


def is_substantive_text(value: object) -> bool:
    if not isinstance(value, str):
        return False
    normalized = value.strip().lower()
    return normalized not in PLACEHOLDER_VALUES


def parse_iso_datetime(value: object, label: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be a non-empty date-time string")
    datetime.fromisoformat(value.replace("Z", "+00:00"))


def assert_confirmation(payload: dict, field_name: str, expected_status: str, label: str) -> None:
    confirmation = payload.get(field_name)
    if not isinstance(confirmation, dict):
        raise ValueError(f"{label} missing {field_name}")
    if confirmation.get("status") != expected_status:
        raise ValueError(f"{label} {field_name}.status must be {expected_status}")
    parse_iso_datetime(confirmation.get("confirmed_at"), f"{label} {field_name}.confirmed_at")


def locked_field_digest(payload: dict, fields: tuple[str, ...]) -> str:
    locked = {field: payload.get(field) for field in fields}
    raw = json.dumps(locked, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def snapshot_digest(snapshot: dict) -> str:
    raw = json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def assert_director_lock(payload: dict, label: str) -> None:
    artifact_type = str(payload.get("artifact_type", ""))
    fields = DIRECTOR_LOCK_FIELDS.get(artifact_type)
    if not fields:
        return
    confirmation = payload.get("director_confirmation")
    if not isinstance(confirmation, dict):
        raise ValueError(f"{label} missing director_confirmation")
    locked_fields = confirmation.get("locked_fields")
    if not isinstance(locked_fields, dict):
        raise ValueError(f"{label} director_confirmation.locked_fields must be an object")
    expected_keys = set(fields)
    actual_keys = set(locked_fields)
    if actual_keys != expected_keys:
        raise ValueError(
            f"{label} director_confirmation.locked_fields must exactly snapshot Director fields: "
            f"missing={sorted(expected_keys - actual_keys)} extra={sorted(actual_keys - expected_keys)}"
        )
    for field in fields:
        if payload.get(field) != locked_fields.get(field):
            raise ValueError(f"{label} Director-owned field drift from locked_fields snapshot: {field}")
    expected_digest = snapshot_digest(locked_fields)
    actual_digest = confirmation.get("locked_field_digest")
    if actual_digest != expected_digest:
        raise ValueError(f"{label} director_confirmation.locked_field_digest drift")


def assert_review_closure(payload: dict, label: str) -> None:
    review = payload.get("review_conclusion")
    if not isinstance(review, dict):
        raise ValueError(f"{label} missing review_conclusion")
    verdict = review.get("verdict")
    if verdict not in {"PASS", "WARN"}:
        raise ValueError(f"{label} review_conclusion.verdict must be PASS or WARN")
    if not is_substantive_text(review.get("summary")):
        raise ValueError(f"{label} review_conclusion.summary must be substantive")

    ledger = payload.get("issue_ledger")
    if not isinstance(ledger, list):
        raise ValueError(f"{label} issue_ledger must be an array")
    if verdict == "PASS" and ledger:
        raise ValueError(f"{label} issue_ledger must be empty when verdict is PASS")
    if verdict == "WARN" and not ledger:
        raise ValueError(f"{label} issue_ledger must include at least one closed issue when verdict is WARN")
    for index, issue in enumerate(ledger, start=1):
        if not isinstance(issue, dict):
            raise ValueError(f"{label} issue_ledger[{index}] must be an object")
        status = issue.get("status")
        if status not in CLOSED_ISSUE_STATUSES:
            raise ValueError(f"{label} issue_ledger[{index}].status is not closed")
        missing = [
            field
            for field in sorted(REQUIRED_WARN_ISSUE_FIELDS)
            if not is_substantive_text(issue.get(field))
        ]
        if missing:
            raise ValueError(f"{label} issue_ledger[{index}] missing closure fields: {', '.join(missing)}")


def assert_manager_brief_fields(payload: dict, label: str) -> None:
    """Require Manager-owned brief fields once review closure is requested."""

    if payload.get("artifact_type") != "brief":
        return
    for field in ("acceptance_criteria", "design_decisions", "non_functional_requirements"):
        values = payload.get(field)
        if not isinstance(values, list) or not values:
            raise ValueError(f"{label} {field} must be non-empty after Manager refinement")
        if any(not is_substantive_text(item) for item in values):
            raise ValueError(f"{label} {field} contains placeholder values")


def assert_final_phase_units(payload: dict, label: str, artifact_path: Path) -> None:
    """Require Manager-finalized phase PRDs to carry executable UNIT coverage."""

    if payload.get("artifact_type") != "phase-prd":
        return
    unit_index = payload.get("unit_index")
    if not isinstance(unit_index, list) or not unit_index:
        raise ValueError(f"{label} unit_index must be non-empty for Manager-finalized phase-prd")
    for unit_id in unit_index:
        if not is_substantive_text(unit_id):
            raise ValueError(f"{label} unit_index contains placeholder unit id")
        unit_path = artifact_path.parent / "units" / f"{unit_id}.json"
        if not unit_path.is_file():
            raise FileNotFoundError(f"{label} unit_index points to missing UNIT artifact: {unit_path}")


def validate_product_artifact(path: Path, require_delivery: bool, require_review: bool) -> None:
    payload = load_json(path)
    label = path.name
    assert_confirmation(payload, "director_confirmation", "passed", label)
    assert_director_lock(payload, label)
    if require_delivery:
        assert_confirmation(payload, "delivery_confirmation", "confirmed", label)
    if require_review:
        assert_manager_brief_fields(payload, label)
        assert_final_phase_units(payload, label, path)
        assert_review_closure(payload, label)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--require-delivery", action="store_true")
    parser.add_argument("--require-review", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    try:
        validate_product_artifact(
            args.artifact.resolve(),
            require_delivery=args.require_delivery,
            require_review=args.require_review,
        )
    except (FileNotFoundError, ValueError) as exc:
        raise SystemExit(str(exc)) from exc


if __name__ == "__main__":
    main()
