#!/usr/bin/env python3
"""Validate a Stage 2 tech-lead package before delivery-owner handoff."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/eval/scripts"))

from validate_stage2_test_design_package import validate as validate_test_design_package  # noqa: E402


TECH_LEAD_ALLOWED_ACTIONS = [
    "planning_preflight",
    "wbs_decomposition",
    "critical_path_analysis",
    "dependency_planning",
    "parallel_batch_planning",
    "task_contract_definition",
    "plan_freeze",
    "tasks_freeze",
    "planning_owner_self_check",
    "validator_execution",
    "user_confirmation_recording",
]
TECH_LEAD_BLOCKED_ACTIONS = [
    "product_scope_rewrite",
    "architecture_decision_rewrite",
    "test_obligation_rewrite",
    "code_changes",
    "commit",
    "deploy",
    "auto_send",
    "qa_execution",
    "release_recommendation",
    "business_risk_acceptance",
    "real_qft_pai_code_modification",
]


def load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("package must be a JSON object")
    return data


def add_failure(failures: list[str], field: str, reason: str) -> None:
    failures.append(f"{field}: {reason}")


def make_check(name: str, failures: list[str]) -> dict[str, Any]:
    return {"check": name, "status": "fail" if failures else "pass", "failures": failures}


def require_object(payload: dict[str, Any], key: str, failures: list[str]) -> dict[str, Any] | None:
    value = payload.get(key)
    if not isinstance(value, dict):
        add_failure(failures, key, "must be object")
        return None
    return value


def require_confirmed_user_confirmation(payload: dict[str, Any], path: str, failures: list[str]) -> None:
    confirmation = payload.get("user_confirmation")
    status = confirmation.get("status") if isinstance(confirmation, dict) else None
    if status != "CONFIRMED":
        add_failure(failures, f"{path}.user_confirmation.status", "must be CONFIRMED")


def first_output_line(completed: subprocess.CompletedProcess[str]) -> str:
    detail = (completed.stderr or completed.stdout or f"exit={completed.returncode}").strip()
    return next((line for line in detail.splitlines() if line.strip()), detail)


def run_command(args: list[str]) -> str | None:
    completed = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=False)
    if completed.returncode == 0:
        return None
    return first_output_line(completed)


def check_package_envelope(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    expected = "stage-2-tech-lead-package"
    if package.get("artifact_type") != expected:
        add_failure(failures, "artifact_type", f"must be {expected}")
    if package.get("status") != "pass":
        add_failure(failures, "status", "must be pass")
    if package.get("input_origin") != "stage-2-test-design-package":
        add_failure(failures, "input_origin", "must be stage-2-test-design-package")
    if package.get("handoff_to") != "delivery-owner":
        add_failure(failures, "handoff_to", "must be delivery-owner")
    if package.get("resume_condition") != "delivery_owner_stage2_ready":
        add_failure(failures, "resume_condition", "must be delivery_owner_stage2_ready")
    return make_check("package_envelope", failures)


def check_test_design_package_binding(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    test_design_package = require_object(package, "test_design_package", failures)
    if test_design_package is None:
        return make_check("test_design_package_binding", failures)
    result = validate_test_design_package(test_design_package)
    if result.get("status") != "pass":
        add_failure(
            failures,
            "test_design_package",
            f"must pass test-design package gate: {result.get('failed_checks')}",
        )
    if result.get("next_standard_chain_role") != "tech-lead":
        add_failure(
            failures,
            "test_design_package.next_standard_chain_role",
            "must be tech-lead",
        )
    return make_check("test_design_package_binding", failures)


def check_plan_shape(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    plan = require_object(package, "plan", failures)
    tasks = package.get("tasks")
    if plan is None:
        return make_check("plan_artifact", failures)
    if plan.get("artifact_type") != "plan":
        add_failure(failures, "plan.artifact_type", "must be plan")
    if plan.get("producer") != "tech-lead":
        add_failure(failures, "plan.producer", "must be tech-lead")
    if plan.get("planning_mode") != "standard-chain":
        add_failure(failures, "plan.planning_mode", "must be standard-chain")
    if plan.get("planning_readiness", {}).get("status") != "READY":
        add_failure(failures, "plan.planning_readiness.status", "must be READY")
    if plan.get("planning_readiness", {}).get("blocking_gaps"):
        add_failure(failures, "plan.planning_readiness.blocking_gaps", "must be empty")
    for field in ("implementation_path", "goal_fidelity_review", "task_list", "scope_freeze"):
        value = plan.get(field)
        if not isinstance(value, (dict, list)) or not value:
            add_failure(failures, f"plan.{field}", "must be non-empty")
    require_confirmed_user_confirmation(plan, "plan", failures)
    if isinstance(tasks, dict) and plan.get("plan_version") != tasks.get("plan_version"):
        add_failure(failures, "plan.plan_version", "must match tasks.plan_version")
    return make_check("plan_artifact", failures)


def check_tasks_shape(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    tasks_artifact = require_object(package, "tasks", failures)
    if tasks_artifact is None:
        return make_check("tasks_artifact", failures)
    if tasks_artifact.get("artifact_type") != "tasks":
        add_failure(failures, "tasks.artifact_type", "must be tasks")
    if tasks_artifact.get("producer") != "tech-lead":
        add_failure(failures, "tasks.producer", "must be tech-lead")
    require_confirmed_user_confirmation(tasks_artifact, "tasks", failures)
    tasks = tasks_artifact.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        add_failure(failures, "tasks.tasks", "must be non-empty array")
        return make_check("tasks_artifact", failures)
    required_task_fields = {
        "task_id",
        "task_title",
        "phase_ref",
        "unit_refs",
        "scope_item_refs",
        "design_refs",
        "test_refs",
        "depends_on",
        "shared_files",
        "batch",
        "acceptance_targets",
        "proving_command",
        "real_dependency_refs",
        "evidence_target",
        "mock_boundary",
        "wbs_ref",
        "critical_path_role",
        "investment_risk_signals",
    }
    for index, task in enumerate(tasks):
        if not isinstance(task, dict):
            add_failure(failures, f"tasks.tasks[{index}]", "must be object")
            continue
        missing = sorted(field for field in required_task_fields if field not in task)
        if missing:
            add_failure(failures, f"tasks.tasks[{index}]", f"missing fields: {missing}")
        for field in ("scope_item_refs", "design_refs", "test_refs", "acceptance_targets"):
            value = task.get(field)
            if not isinstance(value, list) or not value:
                add_failure(failures, f"tasks.tasks[{index}].{field}", "must be non-empty array")
    return make_check("tasks_artifact", failures)


def check_artifact_registry_shape(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    registry = require_object(package, "artifact_registry", failures)
    if registry is None:
        return make_check("artifact_registry", failures)
    if registry.get("artifact_type") != "artifact-registry":
        add_failure(failures, "artifact_registry.artifact_type", "must be artifact-registry")
    if registry.get("producer") != "delivery-owner":
        add_failure(failures, "artifact_registry.producer", "must be delivery-owner")
    active_revision_id = registry.get("active_revision_id")
    revisions = registry.get("revisions")
    if not isinstance(active_revision_id, str) or not isinstance(revisions, list):
        add_failure(failures, "artifact_registry", "must contain active_revision_id and revisions")
        return make_check("artifact_registry", failures)
    active_revision = next(
        (revision for revision in revisions if isinstance(revision, dict) and revision.get("revision_id") == active_revision_id),
        None,
    )
    if not isinstance(active_revision, dict):
        add_failure(failures, "artifact_registry.active_revision_id", "must resolve to a revision")
        return make_check("artifact_registry", failures)
    entries = active_revision.get("entries")
    if not isinstance(entries, list):
        add_failure(failures, "artifact_registry.active_revision.entries", "must be array")
        return make_check("artifact_registry", failures)
    active_types = {
        entry.get("artifact_type")
        for entry in entries
        if isinstance(entry, dict) and entry.get("active_for_consumption") is True
    }
    expected_types = {"brief", "phase-prd", "unit-definition", "design", "test-cases", "plan", "tasks"}
    missing = sorted(expected_types - active_types)
    if missing:
        add_failure(failures, "artifact_registry.active_revision.entries", f"missing active types: {missing}")
    return make_check("artifact_registry", failures)


def materialization_failures(package: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    test_design_package = package.get("test_design_package")
    if not isinstance(test_design_package, dict):
        failures.append("test_design_package: must be object")
        return failures
    design_package = test_design_package.get("design_package")
    if not isinstance(design_package, dict):
        failures.append("test_design_package.design_package: must be object")
        return failures
    pm_package = design_package.get("product_manager_package")
    if not isinstance(pm_package, dict):
        failures.append("test_design_package.design_package.product_manager_package: must be object")
        return failures
    for key in ("brief", "phase_prd"):
        if not isinstance(pm_package.get(key), dict):
            failures.append(f"product_manager_package.{key}: must be object")
    units = pm_package.get("units")
    if not isinstance(units, list) or not units:
        failures.append("product_manager_package.units: must be non-empty array")
    for key in ("design",):
        if not isinstance(design_package.get(key), dict):
            failures.append(f"design_package.{key}: must be object")
    if not isinstance(test_design_package.get("test_cases"), dict):
        failures.append("test_design_package.test_cases: must be object")
    for key in ("plan", "tasks", "artifact_registry"):
        if not isinstance(package.get(key), dict):
            failures.append(f"{key}: must be object")
    return failures


def write_package_files(package: dict[str, Any], root: Path) -> Path:
    test_design_package = package["test_design_package"]
    design_package = test_design_package["design_package"]
    pm_package = design_package["product_manager_package"]
    feature_dir = root / "docs" / "stage2-feature"
    phase_dir = feature_dir / "phase-1"
    units_dir = phase_dir / "units"
    unit_work_dir = phase_dir / "unit-1"
    units_dir.mkdir(parents=True, exist_ok=True)
    unit_work_dir.mkdir(parents=True, exist_ok=True)
    (feature_dir / "brief.json").write_text(json.dumps(pm_package["brief"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (phase_dir / "phase-prd.json").write_text(json.dumps(pm_package["phase_prd"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for unit in pm_package.get("units", []):
        if isinstance(unit, dict) and isinstance(unit.get("unit_id"), str):
            (units_dir / f"{unit['unit_id']}.json").write_text(json.dumps(unit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (phase_dir / "design.json").write_text(json.dumps(design_package["design"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (unit_work_dir / "test-cases.json").write_text(json.dumps(test_design_package["test_cases"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (phase_dir / "plan.json").write_text(json.dumps(package["plan"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (phase_dir / "tasks.json").write_text(json.dumps(package["tasks"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (phase_dir / "artifact-registry.json").write_text(json.dumps(package["artifact_registry"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return phase_dir


def check_planning_preflight(phase_dir: Path) -> dict[str, Any]:
    failures: list[str] = []
    failure = run_command(
        [
            sys.executable,
            str(ROOT / "shared/skills/tech-lead/scripts/planning_preflight.py"),
            "--phase-dir",
            str(phase_dir),
            "--require-tasks",
        ]
    )
    if failure:
        add_failure(failures, "tech-lead.planning_preflight", failure)
    return make_check("planning_preflight", failures)


def check_planning_semantic_integrity(phase_dir: Path) -> dict[str, Any]:
    failures: list[str] = []
    failure = run_command(
        [
            sys.executable,
            str(ROOT / "tools/community/validate_standard_chain_phase.py"),
            "--phase-dir",
            str(phase_dir),
        ]
    )
    if failure:
        add_failure(failures, "validate_standard_chain_phase.py", failure)
    return make_check("planning_semantic_integrity", failures)


def check_delivery_owner_intake(phase_dir: Path) -> dict[str, Any]:
    failures: list[str] = []
    failure = run_command(
        [
            "bash",
            str(ROOT / "shared/skills/delivery-owner/scripts/intake_preflight_check.sh"),
            "--phase-dir",
            str(phase_dir),
        ]
    )
    if failure:
        add_failure(failures, "delivery-owner.intake_preflight_check", failure)
    return make_check("delivery_owner_intake", failures)


def check_authorization_boundary(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    boundary = package.get("decision_boundary")
    if not isinstance(boundary, dict):
        return make_check("authorization_boundary", ["decision_boundary: must be object"])
    allowed = boundary.get("allowed_actions")
    blocked = boundary.get("blocked_actions")
    if not isinstance(allowed, list):
        add_failure(failures, "decision_boundary.allowed_actions", "must be array")
        allowed = []
    if not isinstance(blocked, list):
        add_failure(failures, "decision_boundary.blocked_actions", "must be array")
        blocked = []
    for action in TECH_LEAD_ALLOWED_ACTIONS:
        if action not in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must include {action}")
    for action in TECH_LEAD_BLOCKED_ACTIONS:
        if action not in blocked:
            add_failure(failures, "decision_boundary.blocked_actions", f"must include {action}")
        if action in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must not include {action}")
    return make_check("authorization_boundary", failures)


def validate(package: dict[str, Any]) -> dict[str, Any]:
    checks = [
        check_package_envelope(package),
        check_test_design_package_binding(package),
        check_plan_shape(package),
        check_tasks_shape(package),
        check_artifact_registry_shape(package),
        check_authorization_boundary(package),
    ]
    materialization_errors = materialization_failures(package)
    if not materialization_errors:
        with tempfile.TemporaryDirectory(prefix="stage2-tech-lead-package-") as tmp:
            phase_dir = write_package_files(package, Path(tmp))
            checks.append(check_planning_preflight(phase_dir))
            checks.append(check_planning_semantic_integrity(phase_dir))
            checks.append(check_delivery_owner_intake(phase_dir))
    else:
        checks.append(make_check("planning_preflight", materialization_errors))
        checks.append(make_check("planning_semantic_integrity", materialization_errors))
        checks.append(make_check("delivery_owner_intake", materialization_errors))
    failed_checks = [failure for check in checks for failure in check["failures"]]
    ready = not failed_checks
    return {
        "status": "pass" if ready else "fail",
        "stage2_readiness": "tech_lead_ready_for_delivery_owner" if ready else "blocked",
        "next_standard_chain_role": "delivery-owner" if ready else None,
        "failed_checks": failed_checks,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path, help="Stage 2 tech-lead package JSON.")
    args = parser.parse_args()

    payload = validate(load_json(args.package))
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
