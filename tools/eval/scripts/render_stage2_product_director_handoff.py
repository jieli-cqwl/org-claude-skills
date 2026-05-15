#!/usr/bin/env python3
"""Render the Stage 2 product-director handoff from validated real intake facts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from validate_stage2_intake_gate import DEFAULT_INTAKE, ROOT, intake_kind, load_json, validate


DIRECTOR_STEPS = ["D-S1", "D-S2", "D-S3", "D-S4", "D-S5", "D-S5.5", "D-S6", "D-G1"]


def blocked_payload(validation: dict[str, Any], reason: str) -> dict[str, Any]:
    return {
        "status": "fail",
        "artifact_type": "stage-2-product-director-handoff",
        "reason": reason,
        "intake_status": validation.get("status"),
        "intake_kind": validation.get("intake_kind"),
        "stage2_readiness": validation.get("stage2_readiness"),
        "stage2_route": validation.get("stage2_route"),
        "failed_checks": validation.get("failed_checks", []),
    }


def metric_names(payload: dict[str, Any]) -> list[str]:
    metrics = payload.get("success_metrics") or []
    return [
        str(metric.get("name"))
        for metric in metrics
        if isinstance(metric, dict) and metric.get("name")
    ]


def full_metrics(payload: dict[str, Any]) -> list[dict[str, Any]]:
    metrics = payload.get("success_metrics") or []
    return [metric for metric in metrics if isinstance(metric, dict)]


def build_handoff(payload: dict[str, Any], validation: dict[str, Any]) -> dict[str, Any]:
    route = validation["stage2_route"]
    business_sample = payload["business_sample"]
    qft_pai_scope = payload["qft_pai_scope"]
    risk_acceptance = payload["risk_acceptance"]
    provenance = payload["intake_provenance"]
    acceptance_owner = payload["acceptance_owner"]
    return {
        "status": "pass",
        "artifact_type": "stage-2-product-director-handoff",
        "handoff_owner_role": "product-director",
        "input_origin": "stage-2-intake-facts",
        "intake_owner": payload["intake_owner"],
        "source_refs": provenance["fact_source_refs"],
        "stage2_readiness": validation["stage2_readiness"],
        "next_required_action": route["required_owner_action"],
        "handoff_input": route["handoff_input"],
        "discovery_boundary": {
            "allowed_actions": route["allowed_actions"],
            "blocked_actions": route["blocked_actions"],
            "qft_pai_repo_path": payload["execution_environment"]["qft_pai_repo_path"],
        },
        "director_focus": {
            "business_context": {
                "sample_name": business_sample["sample_name"],
                "business_owner": business_sample["business_owner"],
                "real_user": business_sample["real_user"],
                "scenario": business_sample["scenario"],
            },
            "root_problem_input": business_sample["current_pain"],
            "target_outcome": business_sample["target_outcome"],
            "phase1_candidate_boundary": qft_pai_scope["phase1_boundary"],
            "success_metric_names": metric_names(payload),
            "success_metrics": full_metrics(payload),
            "acceptance_owner": {
                "name": acceptance_owner["name"],
                "role": acceptance_owner["role"],
                "decision_authority": acceptance_owner["decision_authority"],
                "acceptance_method": acceptance_owner["acceptance_method"],
            },
            "risk_acceptance_boundary": risk_acceptance["risk_acceptance_policy"],
        },
        "required_product_director_steps": DIRECTOR_STEPS,
        "product_director_must_not_do": route["blocked_actions"],
        "resume_condition": "product_director_confirmed_brief_and_phase1_boundary",
    }


def render(payload: dict[str, Any], intake: Path) -> tuple[dict[str, Any], int]:
    validation = validate(payload, intake_kind(intake))
    if validation.get("status") != "pass":
        return blocked_payload(validation, "intake_gate_failed"), 1
    route = validation.get("stage2_route") or {}
    if route.get("next_standard_chain_role") != "product-director":
        return blocked_payload(validation, "product_director_handoff_not_allowed"), 1
    return build_handoff(payload, validation), 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root.")
    parser.add_argument("--intake", type=Path, default=None, help="Stage 2 intake facts JSON.")
    args = parser.parse_args()

    intake = args.intake or args.repo_root.resolve() / DEFAULT_INTAKE.relative_to(ROOT)
    payload, exit_code = render(load_json(intake), intake)
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
