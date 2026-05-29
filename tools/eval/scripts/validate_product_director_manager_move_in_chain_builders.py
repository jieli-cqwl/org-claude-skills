"""Top-level package builders for the move-in Director-to-PM eval."""

from __future__ import annotations

import copy
from typing import Any

from validate_product_director_manager_move_in_chain_common import (  # noqa: E402
    bundle_digest,
    review_conclusion,
)
from validate_product_director_manager_move_in_chain_director import (  # noqa: E402
    build_confirmed_package,
)
from validate_product_director_manager_move_in_chain_fields import (  # noqa: E402
    build_phase_manager_fields,
)
from validate_product_director_manager_move_in_chain_units import build_units  # noqa: E402


def build_pm_package(confirmed: dict[str, Any]) -> dict[str, Any]:
    brief = copy.deepcopy(confirmed["brief"])
    phase = copy.deepcopy(confirmed["phase_prd"])
    units = build_units(brief["chain_registry_digest"])
    brief["acceptance_criteria"] = [
        "AC1-AC10 覆盖已租房登记、当前在租不变、办理入住、作废、账款、小程序身份和多端范围"
    ]
    brief["design_decisions"] = [
        "下游设计只选择可见状态和失败补偿表达，不改变 PM 锁定业务边界"
    ]
    brief["non_functional_requirements"] = [
        {
            "requirement_id": "NFR-1",
            "quality_attribute": "OBSERVABILITY",
            "source_refs": ["brief.json#acceptance_criteria[0]"],
            "verification_owner": "test-design",
            "verification_stage": "NFR",
        }
    ]
    phase.update(build_phase_manager_fields())
    phase["unit_index"] = [unit["unit_id"] for unit in units]
    phase["unit_priority_order"] = [
        {
            "unit_id": "UNIT-1",
            "priority": "P0",
            "priority_basis": "先保护当前在租零污染",
        },
        {
            "unit_id": "UNIT-2",
            "priority": "P0",
            "priority_basis": "再关闭入住和作废终态",
        },
        {
            "unit_id": "UNIT-3",
            "priority": "P1",
            "priority_basis": "最后锁身份与端发布口径",
        },
    ]
    refs = [
        "brief.json",
        "phase-1/phase-prd.json",
        *[f"phase-1/units/{unit['unit_id']}.json" for unit in units],
    ]
    reviewed_digest = bundle_digest(refs, [brief, phase, *units])
    review = review_conclusion(refs, reviewed_digest)
    brief["review_conclusion"] = review
    brief["issue_ledger"] = []
    brief["delivery_confirmation"] = {
        "status": "confirmed",
        "confirmed_at": "2026-05-24T13:00:00Z",
    }
    phase["review_conclusion"] = review
    phase["issue_ledger"] = []
    return {
        "artifact_type": "stage-2-product-manager-prd-package",
        "status": "pass",
        "input_origin": "stage-2-product-director-confirmed-brief-package",
        "confirmed_brief_package": confirmed,
        "brief": brief,
        "phase_prd": phase,
        "units": units,
        "decision_boundary": {
            "allowed_actions": [
                "business_flow_refinement",
                "user_path_refinement",
                "rule_mapping",
                "unit_decomposition",
                "acceptance_criteria_definition",
                "verification_plan_definition",
                "coverage_matrix_definition",
                "technical_evidence_requirement_definition",
                "release_readiness_definition",
                "design_handoff_preparation",
                "pm_owner_self_check",
                "agent_team_review",
                "delivery_confirmation",
            ],
            "blocked_actions": [
                "language_selection",
                "architecture_finalization",
                "code_changes",
                "commit",
                "deploy",
                "auto_send",
                "business_risk_acceptance",
            ],
        },
        "handoff_to": "design",
        "resume_condition": "design_stage2_ready",
    }


def build_package(rubric: dict[str, Any]) -> dict[str, Any]:
    confirmed = build_confirmed_package(rubric)
    return {
        "artifact_type": "product-director-manager-move-in-chain-package",
        "status": "pass",
        "source_demand": {
            "source_ref": rubric["source_demand_ref"],
            "not_copied_from_golden_prd": True,
        },
        "golden_prd_ref": rubric["source_prd"],
        "rubric": rubric,
        "confirmed_brief_package": confirmed,
        "product_manager_package": build_pm_package(confirmed),
    }
