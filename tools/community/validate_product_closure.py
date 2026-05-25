#!/usr/bin/env python3
"""Validate final product planning closure fields for canonical readiness gates."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime
from pathlib import Path

from normalize_canonical_artifact import load_json
from review_digest_common import canonical_bundle_digest, is_sha256_digest

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

REQUIRED_REVIEW_PERSPECTIVES = {"product", "architecture", "test"}

POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger", "delivery_confirmation"}

DIRECTOR_LOCK_FIELDS = {
    "brief": (
        "root_problem",
        "user_profile",
        "business_goals",
        "appetite",
        "scope_boundaries",
        "non_goals",
        "feasibility_constraints",
        "risks_and_unknowns",
        "decision_rationale",
        "delivery_plan",
    ),
    "phase-prd": ("phase_goal", "entry_conditions", "exit_conditions"),
}


def is_substantive_text(value: object) -> bool:
    if not isinstance(value, str):
        return False
    normalized = value.strip().lower()
    return normalized not in PLACEHOLDER_VALUES


def is_string_list(value: object, *, allow_empty: bool = False) -> bool:
    if not isinstance(value, list):
        return False
    if not allow_empty and not value:
        return False
    return all(is_substantive_text(item) for item in value)


def parse_iso_datetime(value: object, label: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be a non-empty date-time string")
    datetime.fromisoformat(value.replace("Z", "+00:00"))


def assert_confirmation(
    payload: dict, field_name: str, expected_status: str, label: str
) -> None:
    confirmation = payload.get(field_name)
    if not isinstance(confirmation, dict):
        raise ValueError(f"{label} missing {field_name}")
    if confirmation.get("status") != expected_status:
        raise ValueError(f"{label} {field_name}.status must be {expected_status}")
    parse_iso_datetime(
        confirmation.get("confirmed_at"), f"{label} {field_name}.confirmed_at"
    )


def locked_field_digest(payload: dict, fields: tuple[str, ...]) -> str:
    locked = {field: payload.get(field) for field in fields}
    raw = json.dumps(locked, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def snapshot_digest(snapshot: dict) -> str:
    raw = json.dumps(
        snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )
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
        raise ValueError(
            f"{label} director_confirmation.locked_fields must be an object"
        )
    expected_keys = set(fields)
    actual_keys = set(locked_fields)
    if actual_keys != expected_keys:
        raise ValueError(
            f"{label} director_confirmation.locked_fields must exactly snapshot Director fields: "
            f"expected={sorted(expected_keys)} "
            f"missing={sorted(expected_keys - actual_keys)} extra={sorted(actual_keys - expected_keys)}"
        )
    for field in fields:
        if payload.get(field) != locked_fields.get(field):
            raise ValueError(
                f"{label} Director-owned field drift from locked_fields snapshot: {field}"
            )
    expected_digest = snapshot_digest(locked_fields)
    actual_digest = confirmation.get("locked_field_digest")
    if actual_digest != expected_digest:
        raise ValueError(
            f"{label} director_confirmation.locked_field_digest drift: "
            f"expected={expected_digest} actual={actual_digest!r}. "
            f"Run shared/skills/product-manager/scripts/compute_digest.py to regenerate."
        )


def assert_reviewed_artifact_refs(team_review: dict, label: str) -> list[str]:
    reviewed_refs = team_review.get("reviewed_artifact_refs")
    if not is_string_list(reviewed_refs):
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.reviewed_artifact_refs must be a non-empty string array"
        )
    if len(reviewed_refs) < 3:
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.reviewed_artifact_refs must include brief, phase-prd, and UNIT refs"
        )
    if len(set(reviewed_refs)) != len(reviewed_refs):
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.reviewed_artifact_refs must be unique"
        )
    return reviewed_refs


def feature_root_for_artifact(path: Path) -> Path:
    if path.name == "brief.json":
        return path.parent
    if path.name == "phase-prd.json":
        return path.parent.parent
    return path.parent


def assert_reviewed_bundle_digest(
    team_review: dict, label: str, artifact_path: Path, reviewed_refs: list[str]
) -> str:
    digest = team_review.get("reviewed_bundle_digest")
    if not is_sha256_digest(digest):
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.reviewed_bundle_digest must be sha256:<64 hex>"
        )
    expected = canonical_bundle_digest(
        feature_root_for_artifact(artifact_path), reviewed_refs, POST_REVIEW_FIELDS
    )
    if digest != expected:
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.reviewed_bundle_digest mismatch: "
            f"expected={expected} actual={digest!r}"
        )
    return str(digest)


def assert_reviewer_verdicts(
    team_review: dict,
    label: str,
    final_verdict: str,
    round_id: str,
    reviewed_refs: list[str],
    reviewed_digest: str,
) -> None:
    reviewer_verdicts = team_review.get("reviewer_verdicts")
    if not isinstance(reviewer_verdicts, list):
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.reviewer_verdicts must be an array"
        )
    if len(reviewer_verdicts) != len(REQUIRED_REVIEW_PERSPECTIVES):
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.reviewer_verdicts must contain exactly product, architecture, and test reviewers"
        )

    seen_perspectives: set[str] = set()
    reviewer_final_verdicts: list[str] = []
    for index, item in enumerate(reviewer_verdicts, start=1):
        perspective, verdict = assert_single_reviewer_verdict(
            item, label, index, round_id, reviewed_refs, reviewed_digest
        )
        if perspective in seen_perspectives:
            raise ValueError(
                f"{label} review_conclusion.agent_team_review.reviewer_verdicts[{index}].perspective is duplicated: {perspective}"
            )
        seen_perspectives.add(perspective)
        reviewer_final_verdicts.append(verdict)

    missing = REQUIRED_REVIEW_PERSPECTIVES - seen_perspectives
    if missing:
        raise ValueError(
            f"{label} review_conclusion.agent_team_review missing reviewer perspectives: {', '.join(sorted(missing))}"
        )
    if final_verdict == "PASS" and any(
        verdict != "PASS" for verdict in reviewer_final_verdicts
    ):
        raise ValueError(
            f"{label} PASS review_conclusion requires all reviewer verdicts PASS"
        )


def assert_single_reviewer_verdict(
    item: object,
    label: str,
    index: int,
    round_id: str,
    reviewed_refs: list[str],
    reviewed_digest: str,
) -> tuple[str, str]:
    path = f"{label} review_conclusion.agent_team_review.reviewer_verdicts[{index}]"
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    perspective = item.get("perspective")
    if perspective not in REQUIRED_REVIEW_PERSPECTIVES:
        raise ValueError(f"{path}.perspective must be product, architecture, or test")
    if item.get("round") != round_id:
        raise ValueError(f"{path}.round must match agent_team_review.round")
    if item.get("read_only") is not True:
        raise ValueError(f"{path}.read_only must be true")
    verdict = item.get("verdict")
    if verdict not in {"PASS", "WARN"}:
        raise ValueError(f"{path}.verdict must be PASS or WARN at final closure")
    if not is_substantive_text(item.get("reviewer_output_ref")):
        raise ValueError(f"{path}.reviewer_output_ref must reference the reviewer output")
    if item.get("artifact_refs") != reviewed_refs:
        raise ValueError(
            f"{path}.artifact_refs must match agent_team_review.reviewed_artifact_refs"
        )
    if item.get("reviewed_bundle_digest") != reviewed_digest:
        raise ValueError(
            f"{path}.reviewed_bundle_digest must match agent_team_review.reviewed_bundle_digest"
        )
    if not is_string_list(item.get("finding_refs"), allow_empty=True):
        raise ValueError(f"{path}.finding_refs must be a string array")
    if not is_string_list(item.get("evidence_refs")):
        raise ValueError(f"{path}.evidence_refs must be a non-empty string array")
    return str(perspective), str(verdict)


def assert_convergence_evidence(team_review: dict, label: str) -> None:
    convergence = team_review.get("convergence_evidence")
    if not isinstance(convergence, list) or not convergence:
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.convergence_evidence must be a non-empty array"
        )
    has_confirmation = False
    for index, item in enumerate(convergence, start=1):
        path = f"{label} review_conclusion.agent_team_review.convergence_evidence[{index}]"
        if not isinstance(item, dict):
            raise ValueError(f"{path} must be an object")
        if not is_substantive_text(item.get("round")):
            raise ValueError(f"{path}.round is required")
        status = item.get("status")
        if not is_substantive_text(status):
            raise ValueError(f"{path}.status is required")
        if status == "CONFIRMATION":
            has_confirmation = True
        if not is_string_list(item.get("evidence_refs")):
            raise ValueError(f"{path}.evidence_refs must be a non-empty string array")
    if not has_confirmation:
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.convergence_evidence must include CONFIRMATION"
        )


def assert_agent_team_review(
    review: dict, label: str, final_verdict: str, artifact_path: Path
) -> None:
    team_review = review.get("agent_team_review")
    if not isinstance(team_review, dict):
        raise ValueError(f"{label} review_conclusion.agent_team_review must be an object")
    if team_review.get("mode") != "agent_teams":
        raise ValueError(
            f"{label} review_conclusion.agent_team_review.mode must be agent_teams"
        )
    round_id = team_review.get("round")
    if not is_substantive_text(round_id):
        raise ValueError(f"{label} review_conclusion.agent_team_review.round is required")
    reviewed_refs = assert_reviewed_artifact_refs(team_review, label)
    reviewed_digest = assert_reviewed_bundle_digest(
        team_review, label, artifact_path, reviewed_refs
    )
    assert_reviewer_verdicts(
        team_review,
        label,
        final_verdict,
        str(round_id),
        reviewed_refs,
        reviewed_digest,
    )
    assert_convergence_evidence(team_review, label)


def assert_review_closure(payload: dict, label: str, artifact_path: Path) -> None:
    review = payload.get("review_conclusion")
    if not isinstance(review, dict):
        raise ValueError(f"{label} missing review_conclusion")
    verdict = review.get("verdict")
    if verdict not in {"PASS", "WARN"}:
        raise ValueError(f"{label} review_conclusion.verdict must be PASS or WARN")
    if not is_substantive_text(review.get("summary")):
        raise ValueError(f"{label} review_conclusion.summary must be substantive")
    assert_agent_team_review(review, label, verdict, artifact_path)

    ledger = payload.get("issue_ledger")
    if not isinstance(ledger, list):
        raise ValueError(f"{label} issue_ledger must be an array")
    if verdict == "PASS" and ledger:
        raise ValueError(f"{label} issue_ledger must be empty when verdict is PASS")
    if verdict == "WARN" and not ledger:
        raise ValueError(
            f"{label} issue_ledger must include at least one closed issue when verdict is WARN"
        )
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
            raise ValueError(
                f"{label} issue_ledger[{index}] missing closure fields: {', '.join(missing)}"
            )


def assert_manager_brief_fields(payload: dict, label: str) -> None:
    """Require Manager-owned brief fields once review closure is requested."""

    if payload.get("artifact_type") != "brief":
        return
    for field in (
        "acceptance_criteria",
        "design_decisions",
        "non_functional_requirements",
    ):
        values = payload.get(field)
        if not isinstance(values, list) or not values:
            raise ValueError(
                f"{label} {field} must be non-empty after Manager refinement"
            )
        if any(not is_substantive_text(item) for item in values):
            raise ValueError(f"{label} {field} contains placeholder values")


def assert_final_phase_units(payload: dict, label: str, artifact_path: Path) -> None:
    """Require Manager-finalized phase PRDs to carry executable UNIT coverage."""

    if payload.get("artifact_type") != "phase-prd":
        return
    for field in (
        "coverage_matrix",
        "technical_evidence_requirements",
        "business_flows",
        "user_paths",
        "rule_mappings",
    ):
        values = payload.get(field)
        if not isinstance(values, list) or not values:
            raise ValueError(
                f"{label} {field} must be non-empty for Manager-finalized phase-prd"
            )
        if field in {"business_flows", "user_paths", "rule_mappings"} and any(
            not is_substantive_text(item) for item in values
        ):
            raise ValueError(f"{label} {field} contains placeholder values")
    readiness = payload.get("release_readiness")
    if not isinstance(readiness, dict):
        raise ValueError(
            f"{label} release_readiness must be an object for Manager-finalized phase-prd"
        )
    for field in (
        "supported_platforms",
        "conditional_platforms",
        "unsupported_platforms",
        "residual_risks",
    ):
        if not isinstance(readiness.get(field), list):
            raise ValueError(f"{label} release_readiness.{field} must be an array")
    decisions = payload.get("design_decision_candidates")
    if not isinstance(decisions, list):
        raise ValueError(f"{label} design_decision_candidates must be an array")
    unit_index = payload.get("unit_index")
    if not isinstance(unit_index, list) or not unit_index:
        raise ValueError(
            f"{label} unit_index must be non-empty for Manager-finalized phase-prd"
        )
    for unit_id in unit_index:
        if not is_substantive_text(unit_id):
            raise ValueError(f"{label} unit_index contains placeholder unit id")
        unit_path = artifact_path.parent / "units" / f"{unit_id}.json"
        if not unit_path.is_file():
            raise FileNotFoundError(
                f"{label} unit_index points to missing UNIT artifact: {unit_path}"
            )


def assert_unit_definition_fields(payload: dict, label: str) -> None:
    """Require PM-owned UNIT artifacts to carry executable WHAT-layer context."""

    if payload.get("artifact_type") != "unit-definition":
        return
    for field in ("trigger", "core_behavior", "observable_result"):
        if not is_substantive_text(payload.get(field)):
            raise ValueError(f"{label} {field} must be non-empty")
    for field in ("feature_refs", "flow_refs"):
        if not is_string_list(payload.get(field)):
            raise ValueError(f"{label} {field} must be a non-empty string array")
    for field in ("risk_refs", "rule_refs"):
        if not is_string_list(payload.get(field), allow_empty=True):
            raise ValueError(f"{label} {field} must be a string array")

    integration = payload.get("integration_context")
    if not isinstance(integration, dict):
        raise ValueError(f"{label} integration_context must be an object")
    for field in ("business_modules", "protected_behaviors", "business_constraints"):
        values = integration.get(field)
        if not isinstance(values, list) or not values:
            raise ValueError(f"{label} integration_context.{field} must be non-empty")
        if any(not is_substantive_text(item) for item in values):
            raise ValueError(
                f"{label} integration_context.{field} contains placeholder values"
            )
    dependencies = integration.get("cross_unit_dependencies")
    if not isinstance(dependencies, list):
        raise ValueError(
            f"{label} integration_context.cross_unit_dependencies must be an array"
        )

    criteria = payload.get("acceptance_criteria")
    if not isinstance(criteria, list) or not criteria:
        raise ValueError(f"{label} acceptance_criteria must be non-empty")
    for index, criterion in enumerate(criteria, start=1):
        if not isinstance(criterion, dict):
            raise ValueError(f"{label} acceptance_criteria[{index}] must be an object")
        missing = [
            field
            for field in (
                "ac_id",
                "description",
                "example_input",
                "expected_result",
                "boundary_case",
                "failure_mode",
            )
            if not is_substantive_text(criterion.get(field))
        ]
        if missing:
            raise ValueError(
                f"{label} acceptance_criteria[{index}] missing fields: {', '.join(missing)}"
            )

    plan = payload.get("verification_plan")
    if not isinstance(plan, list) or not plan:
        raise ValueError(f"{label} verification_plan must be non-empty")
    for index, item in enumerate(plan, start=1):
        if not isinstance(item, dict):
            raise ValueError(f"{label} verification_plan[{index}] must be an object")
        missing = [
            field
            for field in (
                "verification_type",
                "business_operation",
                "expected_observation",
                "evidence_target",
            )
            if not is_substantive_text(item.get(field))
        ]
        if not is_string_list(item.get("covers_refs")):
            missing.append("covers_refs")
        if not is_string_list(item.get("evidence_types")):
            missing.append("evidence_types")
        if missing:
            raise ValueError(
                f"{label} verification_plan[{index}] missing fields: {', '.join(missing)}"
            )

    decisions = payload.get("design_decision_candidates")
    if not isinstance(decisions, list):
        raise ValueError(f"{label} design_decision_candidates must be an array")


def validate_product_artifact(
    path: Path, require_delivery: bool, require_review: bool
) -> None:
    payload = load_json(path)
    label = path.name
    if payload.get("artifact_type") != "unit-definition":
        assert_confirmation(payload, "director_confirmation", "passed", label)
        assert_director_lock(payload, label)
    assert_unit_definition_fields(payload, label)
    if require_delivery:
        assert_confirmation(payload, "delivery_confirmation", "confirmed", label)
    if require_review:
        assert_manager_brief_fields(payload, label)
        assert_final_phase_units(payload, label, path)
        assert_review_closure(payload, label, path)


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
