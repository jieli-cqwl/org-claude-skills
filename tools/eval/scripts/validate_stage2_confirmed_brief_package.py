#!/usr/bin/env python3
"""Validate a Stage 2 product-director confirmed brief package."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/community"))
from validate_product_closure import assert_director_lock  # noqa: E402


BLOCKED_ACTIONS = [
    "language_selection",
    "architecture_finalization",
    "code_changes",
    "commit",
    "deploy",
    "auto_send",
    "business_risk_acceptance",
]
ALLOWED_ACTIONS = ["real_qft_pai_discovery", "confirmed_brief_drafting", "phase1_boundary_freeze"]
PM_OWNED_BRIEF_FIELDS = {
    "acceptance_criteria",
    "design_decisions",
    "non_functional_requirements",
    "review_conclusion",
    "issue_ledger",
    "delivery_confirmation",
}
PM_OWNED_PHASE_FIELDS = {
    "review_conclusion",
    "issue_ledger",
    "business_flows",
    "user_paths",
    "rule_mappings",
    "design_decision_candidates",
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def add_failure(failures: list[str], field: str, reason: str) -> None:
    failures.append(f"{field}: {reason}")


def make_check(name: str, failures: list[str]) -> dict[str, Any]:
    return {"check": name, "status": "fail" if failures else "pass", "failures": failures}


def joined(value: Any) -> str:
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def metric_expectations(handoff: dict[str, Any]) -> list[str]:
    metrics = handoff.get("director_focus", {}).get("success_metrics") or []
    return [
        str(metric.get("name"))
        for metric in metrics
        if isinstance(metric, dict) and metric.get("name")
    ]


def check_package_envelope(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    expected = "stage-2-product-director-confirmed-brief-package"
    if package.get("artifact_type") != expected:
        add_failure(failures, "artifact_type", f"must be {expected}")
    if package.get("status") != "pass":
        add_failure(failures, "status", "must be pass")
    if package.get("input_origin") != "stage-2-product-director-handoff":
        add_failure(failures, "input_origin", "must be stage-2-product-director-handoff")
    if package.get("handoff_to") != "product-manager":
        add_failure(failures, "handoff_to", "must be product-manager")
    return make_check("package_envelope", failures)


def check_handoff_binding(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    handoff = package.get("handoff")
    if not isinstance(handoff, dict):
        add_failure(failures, "handoff", "must be object")
        return make_check("handoff_binding", failures)
    if handoff.get("status") != "pass":
        add_failure(failures, "handoff.status", "must be pass")
    if handoff.get("artifact_type") != "stage-2-product-director-handoff":
        add_failure(failures, "handoff.artifact_type", "must be stage-2-product-director-handoff")
    if handoff.get("handoff_owner_role") != "product-director":
        add_failure(failures, "handoff.handoff_owner_role", "must be product-director")
    if handoff.get("stage2_readiness") != "intake_complete_for_discovery":
        add_failure(failures, "handoff.stage2_readiness", "must be intake_complete_for_discovery")
    focus = handoff.get("director_focus") or {}
    for field in ["business_context", "root_problem_input", "target_outcome", "phase1_candidate_boundary", "success_metrics"]:
        if not focus.get(field):
            add_failure(failures, f"handoff.director_focus.{field}", "missing")
    return make_check("handoff_binding", failures)


def check_brief_alignment(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    handoff = package.get("handoff") or {}
    focus = handoff.get("director_focus") or {}
    brief = package.get("brief")
    if not isinstance(brief, dict):
        add_failure(failures, "brief", "must be object")
        return make_check("brief_alignment", failures)
    if brief.get("artifact_type") != "brief":
        add_failure(failures, "brief.artifact_type", "must be brief")
    if brief.get("root_problem") != focus.get("root_problem_input"):
        add_failure(failures, "brief.root_problem", "must match handoff root_problem_input")
    text = joined(brief)
    if str(focus.get("target_outcome")) not in text:
        add_failure(failures, "brief.business_goals", "must include target_outcome")
    if str(focus.get("phase1_candidate_boundary")) not in text:
        add_failure(failures, "brief.scope_boundaries", "must include phase1_candidate_boundary")
    for metric_name in metric_expectations(handoff):
        if metric_name not in text:
            add_failure(failures, "brief.business_goals", f"must include success metric {metric_name}")
    context = focus.get("business_context") or {}
    user_text = joined(brief.get("user_profile"))
    for field in ["real_user", "scenario"]:
        if str(context.get(field)) not in user_text:
            add_failure(failures, "brief.user_profile", f"must include business_context.{field}")
    non_goals_text = joined(brief.get("non_goals"))
    for term in ["语言选型", "代码修改", "自动外发", "风险"]:
        if term not in non_goals_text:
            add_failure(failures, "brief.non_goals", f"must mention {term}")
    pm_fields = sorted(PM_OWNED_BRIEF_FIELDS & set(brief))
    if pm_fields:
        add_failure(failures, "brief", f"contains PM-owned fields: {pm_fields}")
    return make_check("brief_alignment", failures)


def check_phase_prd_alignment(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    handoff = package.get("handoff") or {}
    focus = handoff.get("director_focus") or {}
    phase_prd = package.get("phase_prd")
    if not isinstance(phase_prd, dict):
        add_failure(failures, "phase_prd", "must be object")
        return make_check("phase_prd_alignment", failures)
    if phase_prd.get("artifact_type") != "phase-prd":
        add_failure(failures, "phase_prd.artifact_type", "must be phase-prd")
    if phase_prd.get("phase_goal") != focus.get("phase1_candidate_boundary"):
        add_failure(failures, "phase_prd.phase_goal", "must match phase1_candidate_boundary")
    phase_text = joined(phase_prd)
    for metric_name in metric_expectations(handoff):
        if metric_name not in phase_text:
            add_failure(failures, "phase_prd.exit_conditions", f"must include success metric {metric_name}")
    if phase_prd.get("unit_index") not in ([], None):
        add_failure(failures, "phase_prd.unit_index", "must remain empty for product-director")
    pm_fields = sorted(PM_OWNED_PHASE_FIELDS & set(phase_prd))
    if pm_fields:
        add_failure(failures, "phase_prd", f"contains PM-owned fields: {pm_fields}")
    return make_check("phase_prd_alignment", failures)


def check_director_lock(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    for key in ["brief", "phase_prd"]:
        artifact = package.get(key)
        if not isinstance(artifact, dict):
            add_failure(failures, key, "must be object")
            continue
        try:
            assert_director_lock(artifact, key)
        except ValueError as exc:
            add_failure(failures, f"{key}.director lock", str(exc))
    return make_check("director_lock", failures)


def check_authorization_boundary(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    boundary = package.get("decision_boundary") or {}
    allowed = boundary.get("allowed_actions") or []
    blocked = boundary.get("blocked_actions") or []
    for action in ALLOWED_ACTIONS:
        if action not in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must include {action}")
    for action in BLOCKED_ACTIONS:
        if action not in blocked:
            add_failure(failures, "decision_boundary.blocked_actions", f"must include {action}")
    return make_check("authorization_boundary", failures)


def validate(package: dict[str, Any]) -> dict[str, Any]:
    checks = [
        check_package_envelope(package),
        check_handoff_binding(package),
        check_brief_alignment(package),
        check_phase_prd_alignment(package),
        check_director_lock(package),
        check_authorization_boundary(package),
    ]
    failed_checks = [
        failure
        for check in checks
        for failure in check["failures"]
    ]
    ready = not failed_checks
    return {
        "status": "pass" if ready else "fail",
        "stage2_readiness": "confirmed_brief_ready_for_product_manager" if ready else "blocked",
        "next_standard_chain_role": "product-manager" if ready else None,
        "failed_checks": failed_checks,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path, help="Stage 2 confirmed brief package JSON.")
    args = parser.parse_args()

    payload = validate(load_json(args.package))
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
