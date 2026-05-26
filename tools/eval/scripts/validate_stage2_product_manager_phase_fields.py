"""Phase PRD field checks for the Stage 2 product-manager package gate."""

from __future__ import annotations

from typing import Any


def _add_failure(failures: list[str], field: str, reason: str) -> None:
    failures.append(f"{field}: {reason}")


def _is_substantive_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def check_phase_prd_fields(
    phase_prd: dict[str, Any], unit_ids: set[str], failures: list[str]
) -> None:
    if phase_prd.get("artifact_type") != "phase-prd":
        _add_failure(failures, "phase_prd.artifact_type", "must be phase-prd")
    for field in [
        "coverage_matrix",
        "technical_evidence_requirements",
        "business_flows",
        "user_paths",
        "rule_mappings",
    ]:
        values = phase_prd.get(field)
        if not isinstance(values, list) or not values:
            _add_failure(failures, f"phase_prd.{field}", "must be non-empty array")
        elif field in {"business_flows", "user_paths", "rule_mappings"} and not all(
            _is_substantive_string(item) for item in values
        ):
            _add_failure(
                failures, f"phase_prd.{field}", "must contain substantive strings"
            )
    release = phase_prd.get("release_readiness")
    if not isinstance(release, dict):
        _add_failure(failures, "phase_prd.release_readiness", "must be object")
    else:
        for field in [
            "supported_platforms",
            "conditional_platforms",
            "unsupported_platforms",
            "residual_risks",
        ]:
            if not isinstance(release.get(field), list):
                _add_failure(
                    failures, f"phase_prd.release_readiness.{field}", "must be array"
                )
    if not isinstance(phase_prd.get("design_decision_candidates"), list):
        _add_failure(failures, "phase_prd.design_decision_candidates", "must be array")
    unit_index = phase_prd.get("unit_index")
    if not isinstance(unit_index, list) or not unit_index:
        _add_failure(failures, "phase_prd.unit_index", "must be non-empty")
    elif set(unit_index) != unit_ids:
        _add_failure(
            failures, "phase_prd.unit_index", f"must match units: {sorted(unit_ids)}"
        )
    priority_order = phase_prd.get("unit_priority_order")
    if not isinstance(priority_order, list) or not priority_order:
        _add_failure(failures, "phase_prd.unit_priority_order", "must be non-empty")
    else:
        priority_ids = {
            item.get("unit_id") for item in priority_order if isinstance(item, dict)
        }
        if priority_ids != unit_ids:
            _add_failure(
                failures, "phase_prd.unit_priority_order", "must cover every UNIT"
            )
    if "review_conclusion" not in phase_prd:
        _add_failure(failures, "phase_prd.review_conclusion", "missing")
    if "issue_ledger" not in phase_prd:
        _add_failure(failures, "phase_prd.issue_ledger", "missing")
