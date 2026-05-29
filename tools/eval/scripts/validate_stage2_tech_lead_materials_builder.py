"""Tech-lead package fixture builder for Stage 2 material checks."""

from __future__ import annotations

from typing import Any

from validate_stage2_tech_lead_package import (
    TECH_LEAD_ALLOWED_ACTIONS,
    TECH_LEAD_BLOCKED_ACTIONS,
)


PLAN_VERSION = "plan-v1"
TASKS_VERSION = "tasks-v1"
PHASE_ID = "qft-pai-stage2-phase1"
PRODUCED_AT = "2026-05-14T04:00:00Z"


def artifact_ref(
    artifact_type: str, artifact_id: str, version: str, anchor: str
) -> str:
    return f"artifact://{artifact_type}/{artifact_id}@{version}#{anchor}"


def version_for(artifact_type: str) -> str:
    if artifact_type == "plan":
        return PLAN_VERSION
    if artifact_type == "tasks":
        return TASKS_VERSION
    return "v1"


def common_envelope(
    artifact_type: str, artifact_id: str, producer: str, digest: str
) -> dict[str, Any]:
    return {
        "artifact_type": artifact_type,
        "artifact_id": artifact_id,
        "schema_version": "1.0.0",
        "producer": producer,
        "produced_at": PRODUCED_AT,
        "chain_version": "standard-chain/v1",
        "chain_registry_digest": digest,
    }


def upstream_refs(test_design_package: dict[str, Any]) -> dict[str, Any]:
    design_package = test_design_package["design_package"]
    pm_package = design_package["product_manager_package"]
    brief = pm_package["brief"]
    phase_prd = pm_package["phase_prd"]
    unit = pm_package["units"][0]
    design = design_package["design"]
    test_cases = test_design_package["test_cases"]
    return {
        "brief": brief,
        "phase_prd": phase_prd,
        "unit": unit,
        "design": design,
        "test_cases": test_cases,
        "brief_ref": artifact_ref("brief", brief["artifact_id"], "v1", "goal-001"),
        "phase_ref": artifact_ref(
            "phase-prd", phase_prd["artifact_id"], "v1", "phase-goal"
        ),
        "unit_ref": artifact_ref("unit-definition", unit["artifact_id"], "v1", "unit"),
        "design_decision_ref": artifact_ref(
            "design", design["artifact_id"], "v1", "D-001"
        ),
        "design_interface_ref": artifact_ref(
            "design", design["artifact_id"], "v1", "IF-001"
        ),
        "test_case_ref": artifact_ref(
            "test-cases", test_cases["artifact_id"], "v1", "TC-001"
        ),
        "test_negative_ref": artifact_ref(
            "test-cases", test_cases["artifact_id"], "v1", "TC-002"
        ),
        "test_boundary_ref": artifact_ref(
            "test-cases", test_cases["artifact_id"], "v1", "TC-003"
        ),
        "qa_handoff_ref": artifact_ref(
            "test-cases", test_cases["artifact_id"], "v1", "QA-OB-001"
        ),
    }


def build_tasks_artifact(test_design_package: dict[str, Any]) -> dict[str, Any]:
    refs = upstream_refs(test_design_package)
    digest = refs["brief"]["chain_registry_digest"]
    envelope = common_envelope("tasks", f"{PHASE_ID}.tasks", "tech-lead", digest)
    task_1 = {
        "task_id": "T1",
        "phase_ref": refs["phase_ref"],
        "unit_refs": [refs["unit_ref"]],
        "scope_item_refs": [refs["phase_ref"]],
        "design_refs": [refs["design_decision_ref"], refs["design_interface_ref"]],
        "decision_refs": [refs["design_decision_ref"]],
        "test_refs": [refs["test_case_ref"], refs["test_negative_ref"]],
        "depends_on": [],
        "shared_files": [],
        "batch": 1,
        "acceptance_targets": ["AC-U1-01", "TC-001", "TC-002"],
        "proving_command": "python3 tools/eval/scripts/validate_stage2_tech_lead_materials.py",
        "real_dependency_refs": [
            "artifact://evidence/qft-pai-stage2-phase1.task-T1.dependencies@v1#real-message-callback-flow"
        ],
        "evidence_target": "unit-1/tasks/T1/developer-report.json#fresh_proof",
        "mock_boundary": {
            "mock_allowed": True,
            "allowed_for": ["fixture_data", "unit_isolation"],
            "final_acceptance_requires_real_evidence": True,
        },
        "wbs_ref": "WP-1",
        "critical_path_role": "critical",
        "investment_risk_signals": ["heavy", "risky"],
    }
    task_2 = {
        "task_id": "T2",
        "phase_ref": refs["phase_ref"],
        "unit_refs": [refs["unit_ref"]],
        "scope_item_refs": [refs["phase_ref"], refs["qa_handoff_ref"]],
        "design_refs": [refs["design_decision_ref"], refs["design_interface_ref"]],
        "decision_refs": [refs["design_decision_ref"]],
        "test_refs": [refs["test_boundary_ref"], refs["qa_handoff_ref"]],
        "depends_on": ["T1"],
        "shared_files": [],
        "batch": 2,
        "acceptance_targets": ["TC-003", "QA-OB-001"],
        "proving_command": "python3 tools/eval/scripts/validate_stage2_tech_lead_materials.py",
        "real_dependency_refs": [
            "artifact://evidence/qft-pai-stage2-phase1.task-T2.dependencies@v1#fresh-trace-id-idempotency-manual-confirmation"
        ],
        "evidence_target": "unit-1/tasks/T2/developer-report.json#fresh_proof",
        "mock_boundary": {
            "mock_allowed": True,
            "allowed_for": ["unit_isolation"],
            "final_acceptance_requires_real_evidence": True,
        },
        "wbs_ref": "WP-2",
        "critical_path_role": "critical",
        "investment_risk_signals": ["risky", "rework-prone"],
    }
    return {
        **envelope,
        "authority_scope": "phase",
        "authoritative_fields": ["$.plan_version", "$.tasks"],
        "goal_source_refs": [refs["brief_ref"], refs["phase_ref"]],
        "constraint_source_refs": [refs["design_decision_ref"]],
        "obligation_source_refs": [refs["test_case_ref"], refs["qa_handoff_ref"]],
        "execution_basis_refs": [
            refs["design_decision_ref"],
            refs["test_case_ref"],
            refs["qa_handoff_ref"],
        ],
        "evidence_refs": [],
        "plan_version": PLAN_VERSION,
        "user_confirmation": {
            "status": "CONFIRMED",
            "confirmed_by": "产研负责人",
            "confirmed_at": "2026-05-14T04:00:00Z",
        },
        "tasks": [task_1, task_2],
    }


def build_plan_artifact(
    test_design_package: dict[str, Any], tasks_artifact: dict[str, Any]
) -> dict[str, Any]:
    refs = upstream_refs(test_design_package)
    digest = refs["brief"]["chain_registry_digest"]
    envelope = common_envelope("plan", f"{PHASE_ID}.plan", "tech-lead", digest)
    task_ref_1 = artifact_ref(
        "tasks", tasks_artifact["artifact_id"], TASKS_VERSION, "task-T1"
    )
    task_ref_2 = artifact_ref(
        "tasks", tasks_artifact["artifact_id"], TASKS_VERSION, "task-T2"
    )
    return {
        **envelope,
        "authority_scope": "phase",
        "authoritative_fields": [
            "$.baseline_plan_version_ref",
            "$.baseline_tasks_version_ref",
            "$.goal_source_refs",
            "$.constraint_source_refs",
            "$.obligation_source_refs",
            "$.execution_basis_refs",
            "$.planning_mode",
            "$.plan_version",
            "$.planning_readiness",
            "$.implementation_path",
            "$.goal_fidelity_review",
            "$.user_confirmation",
        ],
        "baseline_plan_version_ref": artifact_ref(
            "plan", envelope["artifact_id"], PLAN_VERSION, "plan-version"
        ),
        "baseline_tasks_version_ref": artifact_ref(
            "tasks", tasks_artifact["artifact_id"], TASKS_VERSION, "task-registry"
        ),
        "goal_source_refs": [refs["brief_ref"], refs["phase_ref"]],
        "constraint_source_refs": [
            refs["design_decision_ref"],
            refs["design_interface_ref"],
        ],
        "obligation_source_refs": [refs["test_case_ref"], refs["qa_handoff_ref"]],
        "execution_basis_refs": [
            refs["design_decision_ref"],
            refs["test_case_ref"],
            refs["qa_handoff_ref"],
        ],
        "evidence_refs": [],
        "planning_mode": "standard-chain",
        "plan_version": PLAN_VERSION,
        "planning_readiness": {
            "status": "READY",
            "blocking_gaps": [],
            "decision_package": {
                "required": False,
                "options": [],
                "recommended_option": "Proceed to delivery-owner after frozen task packet preparation.",
            },
        },
        "implementation_path": {
            "wbs": [
                {
                    "work_package_id": "WP-1",
                    "task_refs": [task_ref_1],
                },
                {
                    "work_package_id": "WP-2",
                    "task_refs": [task_ref_2],
                },
            ],
            "critical_path": ["T1", "T2"],
            "investment_risk_signals": [
                {
                    "risk_id": "IR-1",
                    "signal_type": "INTEGRATION_RISK",
                    "impact_level": "HIGH",
                    "owner": "tech-lead",
                    "source_refs": [task_ref_1],
                    "mitigation_refs": [task_ref_2],
                },
                {
                    "risk_id": "IR-2",
                    "signal_type": "USER_DECISION_NEEDED",
                    "impact_level": "BLOCKING",
                    "owner": "delivery-owner",
                    "source_refs": [task_ref_2],
                    "mitigation_refs": [task_ref_2],
                },
            ],
        },
        "goal_fidelity_review": [
            {
                "goal_ref": refs["brief_ref"],
                "task_refs": [task_ref_1, task_ref_2],
                "execution_basis_ref": refs["design_decision_ref"],
                "status": "COVERED",
            },
            {
                "goal_ref": refs["phase_ref"],
                "task_refs": [task_ref_1, task_ref_2],
                "execution_basis_ref": refs["test_case_ref"],
                "status": "COVERED",
            },
        ],
        "user_confirmation": {
            "status": "CONFIRMED",
            "confirmed_by": "产研负责人",
            "confirmed_at": "2026-05-14T04:00:00Z",
        },
    }


def registry_entry(
    scope_ref: str,
    artifact: dict[str, Any],
    artifact_path: str,
    version: str | None = None,
) -> dict[str, Any]:
    return {
        "scope_ref": scope_ref,
        "artifact_id": artifact["artifact_id"],
        "artifact_type": artifact["artifact_type"],
        "version": version or version_for(artifact["artifact_type"]),
        "artifact_path": artifact_path,
        "lifecycle_state": "FINALIZED",
        "active_for_consumption": True,
        "produced_by": artifact["producer"],
        "restore_basis_refs": [],
    }


def build_artifact_registry(
    test_design_package: dict[str, Any], plan: dict[str, Any], tasks: dict[str, Any]
) -> dict[str, Any]:
    refs = upstream_refs(test_design_package)
    digest = refs["brief"]["chain_registry_digest"]
    envelope = common_envelope(
        "artifact-registry", f"{PHASE_ID}.artifact-registry", "delivery-owner", digest
    )
    scope_ref = refs["phase_ref"]
    entries = [
        registry_entry(scope_ref, refs["brief"], "../brief.json", "v1"),
        registry_entry(scope_ref, refs["phase_prd"], "phase-prd.json", "v1"),
        registry_entry(scope_ref, refs["unit"], "units/UNIT-1.json", "v1"),
        registry_entry(scope_ref, refs["design"], "design.json", "v1"),
        registry_entry(scope_ref, refs["test_cases"], "unit-1/test-cases.json", "v1"),
        registry_entry(scope_ref, plan, "plan.json", PLAN_VERSION),
        registry_entry(scope_ref, tasks, "tasks.json", TASKS_VERSION),
    ]
    return {
        **envelope,
        "authority_scope": "phase",
        "authoritative_fields": [
            "$.scope_ref",
            "$.registry_revision",
            "$.active_revision_id",
            "$.runtime_artifact_policy",
            "$.revisions",
        ],
        "scope_ref": scope_ref,
        "registry_revision": "rev-1",
        "active_revision_id": "rev-1",
        "runtime_artifact_policy": {
            "active_uniqueness": "one_active_entry_per_scope_artifact_type",
            "required_runtime_artifacts": [
                "developer-report",
                "verify-result",
                "code-review-result",
                "qa-result",
                "consistency-audit-result",
            ],
        },
        "revisions": [
            {
                "revision_id": "rev-1",
                "appended_at": "2026-05-14T04:00:00Z",
                "entries": entries,
            }
        ],
    }


def build_tech_lead_package(test_design_package: dict[str, Any]) -> dict[str, Any]:
    tasks = build_tasks_artifact(test_design_package)
    plan = build_plan_artifact(test_design_package, tasks)
    artifact_registry = build_artifact_registry(test_design_package, plan, tasks)
    return {
        "artifact_type": "stage-2-tech-lead-package",
        "status": "pass",
        "input_origin": "stage-2-test-design-package",
        "test_design_package": test_design_package,
        "plan": plan,
        "tasks": tasks,
        "artifact_registry": artifact_registry,
        "decision_boundary": {
            "allowed_actions": TECH_LEAD_ALLOWED_ACTIONS,
            "blocked_actions": TECH_LEAD_BLOCKED_ACTIONS,
        },
        "handoff_to": "delivery-owner",
        "resume_condition": "delivery_owner_stage2_ready",
    }
