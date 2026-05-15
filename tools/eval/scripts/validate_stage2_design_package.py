#!/usr/bin/env python3
"""Validate a Stage 2 design package before test-design handoff."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/community"))
sys.path.insert(0, str(ROOT / "tools/eval/scripts"))

from validate_co_creation_ledger import validate as validate_ledger  # noqa: E402
from validate_stage2_product_manager_package import (  # noqa: E402
    validate as validate_product_manager_package,
)


DESIGN_ALLOWED_ACTIONS = [
    "architecture_evidence_capture",
    "constraint_inheritance_confirmation",
    "option_tradeoff",
    "architecture_decision_finalization",
    "interface_contract_definition",
    "module_boundary_design",
    "data_architecture_design",
    "quality_attribute_mapping",
    "verification_mapping",
    "risk_response_design",
    "design_owner_self_check",
    "advisory_review",
    "final_confirmation",
]
DESIGN_BLOCKED_ACTIONS = [
    "implementation_language_finalization",
    "test_case_definition",
    "task_decomposition",
    "code_changes",
    "commit",
    "deploy",
    "auto_send",
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


def is_substantive_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


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
    expected = "stage-2-design-package"
    if package.get("artifact_type") != expected:
        add_failure(failures, "artifact_type", f"must be {expected}")
    if package.get("status") != "pass":
        add_failure(failures, "status", "must be pass")
    if package.get("input_origin") != "stage-2-product-manager-prd-package":
        add_failure(failures, "input_origin", "must be stage-2-product-manager-prd-package")
    if package.get("handoff_to") != "test-design":
        add_failure(failures, "handoff_to", "must be test-design")
    if package.get("resume_condition") != "test_design_stage2_ready":
        add_failure(failures, "resume_condition", "must be test_design_stage2_ready")
    return make_check("package_envelope", failures)


def check_product_manager_binding(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    pm_package = require_object(package, "product_manager_package", failures)
    if pm_package is None:
        return make_check("product_manager_binding", failures)
    result = validate_product_manager_package(pm_package)
    if result.get("status") != "pass":
        add_failure(
            failures,
            "product_manager_package",
            f"must pass product-manager package gate: {result.get('failed_checks')}",
        )
    if result.get("next_standard_chain_role") != "design":
        add_failure(
            failures,
            "product_manager_package.next_standard_chain_role",
            "must be design",
        )
    return make_check("product_manager_binding", failures)


def check_design_shape(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    design = require_object(package, "design", failures)
    pm_package = package.get("product_manager_package") or {}
    if design is None:
        return make_check("design_artifact", failures)
    if design.get("artifact_type") != "design":
        add_failure(failures, "design.artifact_type", "must be design")
    if design.get("producer") != "design":
        add_failure(failures, "design.producer", "must be design")
    pm_brief = pm_package.get("brief") if isinstance(pm_package, dict) else None
    pm_digest = pm_brief.get("chain_registry_digest") if isinstance(pm_brief, dict) else None
    if design.get("chain_registry_digest") != pm_digest:
        add_failure(failures, "design.chain_registry_digest", "must match PM package")
    product_handoff = design.get("product_handoff")
    product_handoff_status = product_handoff.get("status") if isinstance(product_handoff, dict) else None
    if product_handoff_status != "READY":
        add_failure(failures, "design.product_handoff.status", "must be READY")
    for field in ("review_closure", "final_confirmation", "unit_coverage", "verification_mapping"):
        if field not in design:
            add_failure(failures, f"design.{field}", "missing")
    return make_check("design_artifact", failures)


def materialization_failures(package: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    pm_package = package.get("product_manager_package")
    if not isinstance(pm_package, dict):
        failures.append("product_manager_package: must be object")
        return failures
    for key in ("brief", "phase_prd"):
        if not isinstance(pm_package.get(key), dict):
            failures.append(f"product_manager_package.{key}: must be object")
    units = pm_package.get("units")
    if not isinstance(units, list) or not units:
        failures.append("product_manager_package.units: must be non-empty array")
    if not isinstance(package.get("design"), dict):
        failures.append("design: must be object")
    if not isinstance(package.get("design_ledger"), dict):
        failures.append("design_ledger: must be object")
    return failures


def write_package_files(package: dict[str, Any], root: Path) -> tuple[Path, Path]:
    pm_package = package["product_manager_package"]
    feature_dir = root / "stage2-feature"
    phase_dir = feature_dir / "phase-1"
    units_dir = phase_dir / "units"
    units_dir.mkdir(parents=True, exist_ok=True)
    (feature_dir / "brief.json").write_text(
        json.dumps(pm_package["brief"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (phase_dir / "phase-prd.json").write_text(
        json.dumps(pm_package["phase_prd"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for unit in pm_package.get("units", []):
        if not isinstance(unit, dict):
            continue
        unit_id = unit.get("unit_id")
        if is_substantive_string(unit_id):
            (units_dir / f"{unit_id}.json").write_text(
                json.dumps(unit, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    (phase_dir / "design.json").write_text(
        json.dumps(package["design"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (phase_dir / "design-ledger.json").write_text(
        json.dumps(package["design_ledger"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return feature_dir, phase_dir


def check_design_review_digest(package: dict[str, Any], phase_dir: Path) -> dict[str, Any]:
    failures: list[str] = []
    if "design" not in package:
        return make_check("design_review_digest", ["design: missing"])
    failure = run_command(
        [
            sys.executable,
            str(ROOT / "shared/skills/design/scripts/review_digest.py"),
            "--check",
            str(phase_dir / "design.json"),
        ]
    )
    if failure:
        add_failure(failures, "design.review_closure.reviewed_design_digest", failure)
    return make_check("design_review_digest", failures)


def check_design_reference_integrity(phase_dir: Path) -> dict[str, Any]:
    failures: list[str] = []
    commands = [
        [
            "bash",
            str(ROOT / "shared/skills/design/scripts/preflight_check.sh"),
            "--phase-dir",
            str(phase_dir),
        ],
        [
            sys.executable,
            str(ROOT / "tools/community/validate_standard_chain_phase.py"),
            "--phase-dir",
            str(phase_dir),
        ],
        [
            sys.executable,
            str(ROOT / "shared/skills/design/scripts/check_design_reference_integrity.py"),
            "--phase-dir",
            str(phase_dir),
        ],
    ]
    for command in commands:
        failure = run_command(command)
        if failure:
            add_failure(failures, Path(command[1]).name, failure)
    return make_check("design_reference_integrity", failures)


def check_design_ledger(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    ledger = package.get("design_ledger")
    if not isinstance(ledger, dict):
        return make_check("design_ledger", ["design_ledger: must be object"])
    try:
        validate_ledger(ledger, "design", require_finalized=True)
    except ValueError as exc:
        add_failure(failures, "design_ledger", str(exc))
    return make_check("design_ledger", failures)


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
    for action in DESIGN_ALLOWED_ACTIONS:
        if action not in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must include {action}")
    for action in DESIGN_BLOCKED_ACTIONS:
        if action not in blocked:
            add_failure(failures, "decision_boundary.blocked_actions", f"must include {action}")
        if action in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must not include {action}")
    return make_check("authorization_boundary", failures)


def validate(package: dict[str, Any]) -> dict[str, Any]:
    checks = [
        check_package_envelope(package),
        check_product_manager_binding(package),
        check_design_shape(package),
        check_design_ledger(package),
        check_authorization_boundary(package),
    ]
    materialization_errors = materialization_failures(package)
    if not materialization_errors:
        with tempfile.TemporaryDirectory(prefix="stage2-design-package-") as tmp:
            _feature_dir, phase_dir = write_package_files(package, Path(tmp))
            checks.append(check_design_review_digest(package, phase_dir))
            checks.append(check_design_reference_integrity(phase_dir))
    else:
        checks.append(make_check("design_review_digest", materialization_errors))
        checks.append(make_check("design_reference_integrity", materialization_errors))

    failed_checks = [failure for check in checks for failure in check["failures"]]
    ready = not failed_checks
    return {
        "status": "pass" if ready else "fail",
        "stage2_readiness": "design_ready_for_test_design" if ready else "blocked",
        "next_standard_chain_role": "test-design" if ready else None,
        "failed_checks": failed_checks,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path, help="Stage 2 design package JSON.")
    args = parser.parse_args()

    payload = validate(load_json(args.package))
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
