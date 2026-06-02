#!/usr/bin/env python3
"""Validate Stage 2 test-design materials without entering qft-pai."""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/community"))
sys.path.insert(0, str(ROOT / "tools/eval/scripts"))

from render_stage2_product_director_handoff import render  # noqa: E402
from review_digest_common import canonical_payload_digest  # noqa: E402
from validate_stage2_confirmed_brief_materials import (
    build_package as build_confirmed_package,
)  # noqa: E402
from validate_stage2_design_materials import build_design_package  # noqa: E402
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json  # noqa: E402
from validate_stage2_product_director_handoff_materials import make_real_candidate  # noqa: E402
from validate_stage2_product_manager_materials import build_pm_package  # noqa: E402
from validate_stage2_test_design_package import (  # noqa: E402
    TEST_DESIGN_ALLOWED_ACTIONS,
    TEST_DESIGN_BLOCKED_ACTIONS,
    validate,
)


POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger"}


def reviewed_test_cases_digest(payload: dict[str, Any]) -> str:
    return canonical_payload_digest(payload, POST_REVIEW_FIELDS)


def case(
    case_id: str, title: str, case_type: str, owner_stage: str, expected: str
) -> dict[str, Any]:
    return {
        "case_id": case_id,
        "title": title,
        "product_refs": ["UNIT-1.json#acceptance_criteria[0].ac_id"],
        "design_refs": [
            "design.json#interfaces[0].interface_id",
            "design.json#verification_mapping[0].evidence_ref",
        ],
        "case_type": case_type,
        "priority": "P0",
        "preconditions": [
            "Stage 2 qft-pai design package has been accepted by design gate"
        ],
        "test_data": [
            "single-channel text callback with tenant_id, conversation_id and message_id"
        ],
        "steps": [
            "submit callback",
            "observe suggestion package",
            "inspect trace and manual confirmation status",
        ],
        "expected_result": expected,
        "assertion_target": "VP-001",
        "execution_mode": "non_browser_ok",
        "automation_level": "automatable",
        "evidence_expectation": "trace_id, context source summary, dispatch result, manual confirmation state",
        "owner_stage": owner_stage,
    }


def special_triggers() -> list[dict[str, Any]]:
    rows = [
        (
            "ST-001",
            "quality_attribute",
            "design.json#quality_attributes[0]",
            "TEST_CASE",
            ["TC-003"],
            [],
        ),
        (
            "ST-002",
            "data_architecture",
            "design.json#data_architecture",
            "QA_HANDOFF",
            [],
            ["QA-OB-001"],
        ),
        (
            "ST-003",
            "cross_cutting_concern",
            "design.json#cross_cutting_concerns[0]",
            "TEST_CASE",
            ["TC-001"],
            [],
        ),
        (
            "ST-004",
            "cross_cutting_concern",
            "design.json#cross_cutting_concerns[1]",
            "TEST_CASE",
            ["TC-002"],
            [],
        ),
        (
            "ST-005",
            "cross_cutting_concern",
            "design.json#cross_cutting_concerns[2]",
            "TEST_CASE",
            ["TC-003"],
            [],
        ),
        (
            "ST-006",
            "cross_cutting_concern",
            "design.json#cross_cutting_concerns[3]",
            "TEST_CASE",
            ["TC-002"],
            [],
        ),
    ]
    triggers = []
    for (
        trigger_id,
        trigger_type,
        source_ref,
        handling,
        test_refs,
        obligation_refs,
    ) in rows:
        row: dict[str, Any] = {
            "trigger_id": trigger_id,
            "trigger_type": trigger_type,
            "source_ref": source_ref,
            "trigger_rule": {
                "quality_attribute": "QUALITY_ATTRIBUTE_REQUIRED",
                "data_architecture": "DATA_FLOW_REQUIRED",
                "cross_cutting_concern": "CROSS_CUTTING_REQUIRED",
            }[trigger_type],
            "threshold_ref": source_ref,
            "qa_stage": "QA_A" if handling == "TEST_CASE" else "QA_B",
            "handling": handling,
        }
        if test_refs:
            row["test_case_refs"] = test_refs
        if obligation_refs:
            row["qa_handoff_obligation_refs"] = obligation_refs
        triggers.append(row)
    return triggers


def design_source_refs(design: dict[str, Any]) -> list[str]:
    refs = [
        f"design.json#verification_mapping[{index}].manager_vp_ref"
        for index, _row in enumerate(design.get("verification_mapping", []))
    ]
    refs.extend(
        f"design.json#key_decisions[{index}]"
        for index, _row in enumerate(design.get("key_decisions", []))
    )
    refs.extend(
        f"design.json#interfaces[{index}]"
        for index, _row in enumerate(design.get("interfaces", []))
    )
    if design.get("quality_attributes"):
        refs.append("design.json#quality_attributes[0]")
    return refs


def build_test_cases_artifact(design_package: dict[str, Any]) -> dict[str, Any]:
    design = design_package["design"]
    unit = design_package["product_manager_package"]["units"][0]
    test_cases: dict[str, Any] = {
        "artifact_type": "test-cases",
        "artifact_id": "qft-pai-stage2-phase1.unit-1.test-cases",
        "schema_version": "1.0.0",
        "producer": "test-design",
        "produced_at": "2026-05-14T03:00:00Z",
        "chain_version": "standard-chain/v1",
        "chain_registry_digest": design["chain_registry_digest"],
        "authority_scope": "artifact",
        "authoritative_fields": [
            "$.test_analysis",
            "$.traceability_matrix",
            "$.ac_coverage_matrix",
            "$.test_cases",
            "$.qa_handoff_contract",
            "$.design_gap_report",
            "$.cross_unit_obligations",
            "$.special_test_triggers",
            "$.review_conclusion",
            "$.issue_ledger",
        ],
        "test_analysis": {
            "risk_model": [
                {
                    "risk_ref": "design.json#risks[0].risk_id",
                    "risk_type": "context-risk",
                    "test_depth": "positive, negative and boundary coverage",
                }
            ],
            "strategy_by_quality_area": [
                {
                    "quality_area": "operability",
                    "strategy": "围绕 trace_id、上下文来源和人工确认状态设计可复验证据",
                }
            ],
            "test_flow": [
                {
                    "checkpoint_id": "FLOW-1",
                    "source_refs": [
                        "phase-prd.json#exit_conditions[0]",
                        "UNIT-1.json#acceptance_criteria[0].ac_id",
                        "design.json#verification_mapping[0].manager_vp_ref",
                    ],
                    "expected_checkpoint": "每条回调都能映射到明确测试用例和 evidence expectation",
                }
            ],
        },
        "traceability_matrix": [
            {
                "product_ref": "phase-prd.json#exit_conditions[0]",
                "unit_ref": "UNIT-1.json#unit_id",
                "ac_ref": "UNIT-1.json#acceptance_criteria[0].ac_id",
                "design_ref": "design.json#verification_mapping[0].evidence_ref",
                "test_case_refs": ["TC-001", "TC-002", "TC-003"],
                "gap_refs": [],
            }
        ],
        "ac_coverage_matrix": [
            {
                "ac_id": unit["acceptance_criteria"][0]["ac_id"],
                "positive_case_refs": ["TC-001"],
                "negative_case_refs": ["TC-002"],
                "boundary_case_refs": ["TC-003"],
            }
        ],
        "test_cases": [
            case(
                "TC-001",
                "valid text callback creates suggestion package",
                "positive",
                "developer",
                "suggestion package contains trace_id, context source and manual confirmation state",
            ),
            case(
                "TC-002",
                "missing context enters manual takeover",
                "negative",
                "verify",
                "system returns takeover reason and never auto-sends a reply",
            ),
            case(
                "TC-003",
                "duplicate callback keeps idempotent trace state",
                "boundary",
                "developer",
                "duplicate message_id returns the same trace state without duplicate outbound side effects",
            ),
        ],
        "qa_handoff_contract": [
            {
                "obligation_id": "QA-OB-001",
                "obligation_type": "RUNTIME_REPLAY",
                "trigger_refs": [
                    "design.json#verification_mapping[0].manager_vp_ref",
                    "design.json#quality_attributes[0]",
                ],
                "qa_stage": "QA_B",
                "requiredness": "REQUIRED",
                "execution_mode": "non_browser_ok",
                "skip_policy": "NOT_SKIPPABLE",
                "evidence_contract_ref": "artifact://qa-result/qft-pai-stage2-phase1.qa@active#obligation-results",
                "design_source_refs": design_source_refs(design),
            }
        ],
        "design_gap_report": {"status": "NO_GAPS", "gaps": []},
        "cross_unit_obligations": [],
        "special_test_triggers": special_triggers(),
    }
    reviewed_digest = reviewed_test_cases_digest(test_cases)
    test_cases["review_conclusion"] = {
        "verdict": "PASS",
        "closure_status": "CLOSED",
        "review_round": "R2",
        "reviewed_test_cases_digest": reviewed_digest,
        "reviewer_verdicts": [
            {
                "perspective": "test_quality",
                "verdict": "PASS",
                "issue_count": 0,
                "review_round": "R2",
                "reviewed_test_cases_digest": reviewed_digest,
                "evidence_refs": [
                    "test-cases.json#traceability_matrix",
                    "test-cases.json#ac_coverage_matrix",
                    "test-cases.json#special_test_triggers",
                ],
            },
            {
                "perspective": "product",
                "verdict": "PASS",
                "issue_count": 0,
                "review_round": "R2",
                "reviewed_test_cases_digest": reviewed_digest,
                "evidence_refs": [
                    "test-cases.json#traceability_matrix",
                    "UNIT-1.json#acceptance_criteria[0].ac_id",
                ],
            },
            {
                "perspective": "architecture",
                "verdict": "PASS",
                "issue_count": 0,
                "review_round": "R2",
                "reviewed_test_cases_digest": reviewed_digest,
                "evidence_refs": [
                    "test-cases.json#qa_handoff_contract",
                    "design.json#verification_mapping[0].manager_vp_ref",
                ],
            },
        ],
        "convergence_evidence": [
            {
                "round": "R2",
                "result": "PASS",
                "fail_count": 0,
                "control_action": "CONFIRMATION",
                "evidence_refs": [
                    "test-cases.json#review_conclusion.reviewer_verdicts"
                ],
            }
        ],
    }
    test_cases["issue_ledger"] = []
    return test_cases


def build_test_design_package(design_package: dict[str, Any]) -> dict[str, Any]:
    return {
        "artifact_type": "stage-2-test-design-package",
        "status": "pass",
        "input_origin": "stage-2-design-package",
        "design_package": design_package,
        "test_cases": build_test_cases_artifact(design_package),
        "decision_boundary": {
            "allowed_actions": TEST_DESIGN_ALLOWED_ACTIONS,
            "blocked_actions": TEST_DESIGN_BLOCKED_ACTIONS,
        },
        "handoff_to": "tech-lead",
        "resume_condition": "tech_lead_stage2_ready",
    }


def validate_materials(repo_root: Path) -> dict[str, Any]:
    example_payload = load_json(repo_root / DEFAULT_INTAKE.relative_to(ROOT))
    handoff, handoff_exit = render(
        make_real_candidate(example_payload), Path("real-stage2-intake-facts.json")
    )
    failures: list[str] = []
    if handoff_exit != 0:
        return {
            "status": "fail",
            "failed_checks": [
                "real intake candidate did not render product-director handoff"
            ],
        }

    pm_package = build_pm_package(build_confirmed_package(handoff))
    design_package = build_design_package(pm_package)
    package = build_test_design_package(design_package)
    package_result = validate(package)
    if package_result["status"] != "pass":
        failures.append("valid test-design package did not pass")

    broken = copy.deepcopy(package)
    broken["decision_boundary"]["blocked_actions"] = [
        action
        for action in broken["decision_boundary"]["blocked_actions"]
        if action != "task_decomposition"
    ]
    broken["decision_boundary"]["allowed_actions"].append("task_decomposition")
    if validate(broken)["status"] == "pass":
        failures.append("test-design package did not enforce tech-lead boundary")

    broken_gap = copy.deepcopy(package)
    broken_gap["test_cases"]["design_gap_report"] = {
        "status": "HAS_GAPS",
        "gaps": [
            {
                "gap_id": "GAP-TD-001",
                "gap_type": "DESIGN_GAP",
                "blocking_refs": ["design.json#rollback_plan[0]"],
                "owner": "design",
                "required_artifact_ref": "design.json#rollback_plan[0]",
                "decision_needed": True,
                "blocking": True,
            }
        ],
    }
    if validate(broken_gap)["status"] == "pass":
        failures.append("test-design package did not block typed gap")

    return {
        "status": "fail" if failures else "pass",
        "stage2_readiness": package_result.get("stage2_readiness"),
        "next_standard_chain_role": package_result.get("next_standard_chain_role"),
        "validated_blocked_actions": TEST_DESIGN_BLOCKED_ACTIONS,
        "failed_checks": failures,
        "package_checks": package_result.get("checks", []),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root.")
    args = parser.parse_args()

    payload = validate_materials(args.repo_root.resolve())
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
