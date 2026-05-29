#!/usr/bin/env python3
"""Validate a Stage 2 test-design package before tech-lead handoff."""

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

from validate_stage2_design_package import validate as validate_design_package  # noqa: E402


TEST_DESIGN_ALLOWED_ACTIONS = [
    "test_basis_analysis",
    "condition_example_mapping",
    "test_case_design",
    "qa_handoff_contract_shaping",
    "specialty_test_design",
    "gap_routing",
    "test_design_owner_self_check",
    "advisory_review",
    "test_cases_freeze",
]
TEST_DESIGN_BLOCKED_ACTIONS = [
    "task_decomposition",
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
    expected = "stage-2-test-design-package"
    if package.get("artifact_type") != expected:
        add_failure(failures, "artifact_type", f"must be {expected}")
    if package.get("status") != "pass":
        add_failure(failures, "status", "must be pass")
    if package.get("input_origin") != "stage-2-design-package":
        add_failure(failures, "input_origin", "must be stage-2-design-package")
    if package.get("handoff_to") != "tech-lead":
        add_failure(failures, "handoff_to", "must be tech-lead")
    if package.get("resume_condition") != "tech_lead_stage2_ready":
        add_failure(failures, "resume_condition", "must be tech_lead_stage2_ready")
    return make_check("package_envelope", failures)


def check_design_package_binding(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    design_package = require_object(package, "design_package", failures)
    if design_package is None:
        return make_check("design_package_binding", failures)
    result = validate_design_package(design_package)
    if result.get("status") != "pass":
        add_failure(
            failures,
            "design_package",
            f"must pass design package gate: {result.get('failed_checks')}",
        )
    if result.get("next_standard_chain_role") != "test-design":
        add_failure(failures, "design_package.next_standard_chain_role", "must be test-design")
    return make_check("design_package_binding", failures)


def check_test_cases_shape(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    test_cases = require_object(package, "test_cases", failures)
    design_package = package.get("design_package") or {}
    if test_cases is None:
        return make_check("test_cases_artifact", failures)
    if test_cases.get("artifact_type") != "test-cases":
        add_failure(failures, "test_cases.artifact_type", "must be test-cases")
    if test_cases.get("producer") != "test-design":
        add_failure(failures, "test_cases.producer", "must be test-design")
    design = design_package.get("design") if isinstance(design_package, dict) else None
    expected_digest = design.get("chain_registry_digest") if isinstance(design, dict) else None
    if test_cases.get("chain_registry_digest") != expected_digest:
        add_failure(failures, "test_cases.chain_registry_digest", "must match design package")
    for field in ("traceability_matrix", "test_cases", "design_gap_report", "review_conclusion", "qa_handoff_contract"):
        if field not in test_cases:
            add_failure(failures, f"test_cases.{field}", "missing")
    return make_check("test_cases_artifact", failures)


def materialization_failures(package: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    design_package = package.get("design_package")
    if not isinstance(design_package, dict):
        return ["design_package: must be object"]
    pm_package = design_package.get("product_manager_package")
    if not isinstance(pm_package, dict):
        failures.append("design_package.product_manager_package: must be object")
        return failures
    for key in ("brief", "phase_prd"):
        if not isinstance(pm_package.get(key), dict):
            failures.append(f"design_package.product_manager_package.{key}: must be object")
    units = pm_package.get("units")
    if not isinstance(units, list) or not units:
        failures.append("design_package.product_manager_package.units: must be non-empty array")
    if not isinstance(design_package.get("design"), dict):
        failures.append("design_package.design: must be object")
    if not isinstance(package.get("test_cases"), dict):
        failures.append("test_cases: must be object")
    return failures


def write_package_files(package: dict[str, Any], root: Path) -> Path:
    design_package = package["design_package"]
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
    (unit_work_dir / "test-cases.json").write_text(json.dumps(package["test_cases"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return phase_dir


def check_test_cases_review_digest(phase_dir: Path) -> dict[str, Any]:
    failures: list[str] = []
    failure = run_command(
        [
            sys.executable,
            str(ROOT / "shared/skills/test-design/scripts/review_digest.py"),
            "--check",
            str(phase_dir / "unit-1/test-cases.json"),
        ]
    )
    if failure:
        add_failure(failures, "test_cases.review_conclusion.reviewed_test_cases_digest", failure)
    return make_check("test_cases_review_digest", failures)


def check_test_cases_semantic_integrity(phase_dir: Path) -> dict[str, Any]:
    failures: list[str] = []
    commands = [
        [
            "bash",
            str(ROOT / "shared/skills/test-design/scripts/preflight_check.sh"),
            "--phase-dir",
            str(phase_dir),
            "--unit",
            "UNIT-1",
        ],
        [
            sys.executable,
            str(ROOT / "tools/community/validate_standard_chain_phase.py"),
            "--phase-dir",
            str(phase_dir),
        ],
    ]
    for command in commands:
        failure = run_command(command)
        if failure:
            add_failure(failures, Path(command[1]).name, failure)
    return make_check("test_cases_semantic_integrity", failures)


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
    for action in TEST_DESIGN_ALLOWED_ACTIONS:
        if action not in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must include {action}")
    for action in TEST_DESIGN_BLOCKED_ACTIONS:
        if action not in blocked:
            add_failure(failures, "decision_boundary.blocked_actions", f"must include {action}")
        if action in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must not include {action}")
    return make_check("authorization_boundary", failures)


def validate(package: dict[str, Any]) -> dict[str, Any]:
    checks = [
        check_package_envelope(package),
        check_design_package_binding(package),
        check_test_cases_shape(package),
        check_authorization_boundary(package),
    ]
    materialization_errors = materialization_failures(package)
    if not materialization_errors:
        with tempfile.TemporaryDirectory(prefix="stage2-test-design-package-") as tmp:
            phase_dir = write_package_files(package, Path(tmp))
            checks.append(check_test_cases_review_digest(phase_dir))
            checks.append(check_test_cases_semantic_integrity(phase_dir))
    else:
        checks.append(make_check("test_cases_review_digest", materialization_errors))
        checks.append(make_check("test_cases_semantic_integrity", materialization_errors))
    failed_checks = [failure for check in checks for failure in check["failures"]]
    ready = not failed_checks
    return {
        "status": "pass" if ready else "fail",
        "stage2_readiness": "test_design_ready_for_tech_lead" if ready else "blocked",
        "next_standard_chain_role": "tech-lead" if ready else None,
        "failed_checks": failed_checks,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path, help="Stage 2 test-design package JSON.")
    args = parser.parse_args()

    payload = validate(load_json(args.package))
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
