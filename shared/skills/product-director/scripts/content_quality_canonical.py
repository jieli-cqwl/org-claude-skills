from __future__ import annotations

from typing import Any

from content_quality_common import dimension


BRIEF_FIELDS = {
    "root_problem": str,
    "user_profile": list,
    "business_goals": list,
    "appetite": dict,
    "scope_boundaries": list,
    "non_goals": list,
    "feasibility_constraints": list,
    "risks_and_unknowns": list,
    "decision_rationale": list,
    "delivery_plan": list,
}
PHASE_FIELDS = {
    "phase_goal": str,
    "entry_conditions": list,
    "exit_conditions": list,
}


def required_type_name(expected_type: type[Any]) -> str:
    return "string" if expected_type is str else expected_type.__name__


def is_non_empty(value: Any, expected_type: type[Any]) -> bool:
    return isinstance(value, expected_type) and (
        not isinstance(value, (str, list, dict)) or bool(value)
    )


def canonical_field_quality(
    brief: dict[str, Any], phase: dict[str, Any]
) -> dict[str, Any]:
    issues: list[str] = []
    evidence: list[str] = []
    for field, expected_type in BRIEF_FIELDS.items():
        if not is_non_empty(brief.get(field), expected_type):
            issues.append(
                f"brief.json.{field} must be a non-empty {required_type_name(expected_type)}"
            )
    for field, expected_type in PHASE_FIELDS.items():
        if not is_non_empty(phase.get(field), expected_type):
            issues.append(
                f"phase-prd.json.{field} must be a non-empty {required_type_name(expected_type)}"
            )
    if not issues:
        evidence.append("Director canonical fields are present in brief and phase-prd")
    return dimension(
        "canonical_field_quality",
        [not issues],
        evidence,
        issues,
        must_fail=bool(issues),
    )
