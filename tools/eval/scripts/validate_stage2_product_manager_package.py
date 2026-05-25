#!/usr/bin/env python3
"""Validate a Stage 2 product-manager PRD package before design handoff."""

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

from validate_co_creation_ledger import validate as validate_ledger  # noqa: E402
from validate_product_closure import (  # noqa: E402
    DIRECTOR_LOCK_FIELDS,
    assert_confirmation,
    assert_director_lock,
    assert_manager_brief_fields,
    assert_unit_definition_fields,
)
from validate_stage2_confirmed_brief_package import (  # noqa: E402
    BLOCKED_ACTIONS,
    validate as validate_confirmed_brief_package,
)


PM_ALLOWED_ACTIONS = [
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
]
POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger", "delivery_confirmation"}


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


def check_package_envelope(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    expected = "stage-2-product-manager-prd-package"
    if package.get("artifact_type") != expected:
        add_failure(failures, "artifact_type", f"must be {expected}")
    if package.get("status") != "pass":
        add_failure(failures, "status", "must be pass")
    if package.get("input_origin") != "stage-2-product-director-confirmed-brief-package":
        add_failure(
            failures,
            "input_origin",
            "must be stage-2-product-director-confirmed-brief-package",
        )
    if package.get("handoff_to") != "design":
        add_failure(failures, "handoff_to", "must be design")
    if package.get("resume_condition") != "design_stage2_ready":
        add_failure(failures, "resume_condition", "must be design_stage2_ready")
    return make_check("package_envelope", failures)


def check_confirmed_brief_binding(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    confirmed = require_object(package, "confirmed_brief_package", failures)
    if confirmed is None:
        return make_check("confirmed_brief_binding", failures)
    result = validate_confirmed_brief_package(confirmed)
    if result.get("status") != "pass":
        add_failure(
            failures,
            "confirmed_brief_package",
            f"must pass confirmed brief package gate: {result.get('failed_checks')}",
        )
    if result.get("next_standard_chain_role") != "product-manager":
        add_failure(
            failures,
            "confirmed_brief_package.next_standard_chain_role",
            "must be product-manager",
        )
    return make_check("confirmed_brief_binding", failures)


def check_director_lock_preservation(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    confirmed = package.get("confirmed_brief_package") or {}
    for key in ["brief", "phase_prd"]:
        current = package.get(key)
        baseline = confirmed.get(key)
        if not isinstance(current, dict) or not isinstance(baseline, dict):
            add_failure(failures, key, "current and confirmed baseline must be objects")
            continue
        try:
            assert_director_lock(current, key)
        except ValueError as exc:
            add_failure(failures, f"{key}.director_lock", str(exc))
        artifact_type = str(current.get("artifact_type", ""))
        for field in DIRECTOR_LOCK_FIELDS.get(artifact_type, ()):
            if current.get(field) != baseline.get(field):
                add_failure(failures, f"{key}.{field}", "Director-owned field drift from confirmed brief")
        if current.get("director_confirmation") != baseline.get("director_confirmation"):
            add_failure(failures, f"{key}.director_confirmation", "must preserve confirmed Director lock")
    return make_check("director_lock_preservation", failures)


def check_phase_prd_fields(phase_prd: dict[str, Any], unit_ids: set[str], failures: list[str]) -> None:
    if phase_prd.get("artifact_type") != "phase-prd":
        add_failure(failures, "phase_prd.artifact_type", "must be phase-prd")
    for field in [
        "coverage_matrix",
        "technical_evidence_requirements",
        "business_flows",
        "user_paths",
        "rule_mappings",
    ]:
        values = phase_prd.get(field)
        if not isinstance(values, list) or not values:
            add_failure(failures, f"phase_prd.{field}", "must be non-empty array")
        elif field in {"business_flows", "user_paths", "rule_mappings"} and not all(
            is_substantive_string(item) for item in values
        ):
            add_failure(failures, f"phase_prd.{field}", "must contain substantive strings")
    release = phase_prd.get("release_readiness")
    if not isinstance(release, dict):
        add_failure(failures, "phase_prd.release_readiness", "must be object")
    else:
        for field in ["supported_platforms", "conditional_platforms", "unsupported_platforms", "residual_risks"]:
            if not isinstance(release.get(field), list):
                add_failure(failures, f"phase_prd.release_readiness.{field}", "must be array")
    if not isinstance(phase_prd.get("design_decision_candidates"), list):
        add_failure(failures, "phase_prd.design_decision_candidates", "must be array")
    unit_index = phase_prd.get("unit_index")
    if not isinstance(unit_index, list) or not unit_index:
        add_failure(failures, "phase_prd.unit_index", "must be non-empty")
    elif set(unit_index) != unit_ids:
        add_failure(failures, "phase_prd.unit_index", f"must match units: {sorted(unit_ids)}")
    priority_order = phase_prd.get("unit_priority_order")
    if not isinstance(priority_order, list) or not priority_order:
        add_failure(failures, "phase_prd.unit_priority_order", "must be non-empty")
    else:
        priority_ids = {item.get("unit_id") for item in priority_order if isinstance(item, dict)}
        if priority_ids != unit_ids:
            add_failure(failures, "phase_prd.unit_priority_order", "must cover every UNIT")
    if "review_conclusion" not in phase_prd:
        add_failure(failures, "phase_prd.review_conclusion", "missing")
    if "issue_ledger" not in phase_prd:
        add_failure(failures, "phase_prd.issue_ledger", "missing")


def check_pm_artifacts(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    brief = require_object(package, "brief", failures)
    phase_prd = require_object(package, "phase_prd", failures)
    units = package.get("units")
    if not isinstance(units, list) or not units:
        add_failure(failures, "units", "must be non-empty array")
        units = []

    unit_ids: set[str] = set()
    for index, unit in enumerate(units):
        if not isinstance(unit, dict):
            add_failure(failures, f"units[{index}]", "must be object")
            continue
        unit_id = unit.get("unit_id")
        if not is_substantive_string(unit_id):
            add_failure(failures, f"units[{index}].unit_id", "must be substantive")
        else:
            unit_ids.add(str(unit_id))
        try:
            assert_unit_definition_fields(unit, f"units[{index}]")
        except ValueError as exc:
            add_failure(failures, f"units[{index}]", str(exc))

    if brief is not None:
        try:
            assert_manager_brief_fields(brief, "brief")
            assert_confirmation(brief, "delivery_confirmation", "confirmed", "brief")
        except ValueError as exc:
            add_failure(failures, "brief", str(exc))
        if "review_conclusion" not in brief:
            add_failure(failures, "brief.review_conclusion", "missing")
        if "issue_ledger" not in brief:
            add_failure(failures, "brief.issue_ledger", "missing")
    if phase_prd is not None:
        check_phase_prd_fields(phase_prd, unit_ids, failures)
    return make_check("pm_artifacts", failures)


def write_package_files(package: dict[str, Any], root: Path) -> tuple[Path, Path]:
    feature_dir = root / "stage2-feature"
    phase_dir = feature_dir / "phase-1"
    units_dir = phase_dir / "units"
    units_dir.mkdir(parents=True, exist_ok=True)
    (feature_dir / "brief.json").write_text(
        json.dumps(package["brief"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (phase_dir / "phase-prd.json").write_text(
        json.dumps(package["phase_prd"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for unit in package.get("units", []):
        if not isinstance(unit, dict):
            continue
        unit_id = unit.get("unit_id")
        if is_substantive_string(unit_id):
            (units_dir / f"{unit_id}.json").write_text(
                json.dumps(unit, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    ledger_path = phase_dir / "product-manager-ledger.json"
    ledger_path.write_text(
        json.dumps(package["product_manager_ledger"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return feature_dir, phase_dir


def run_script(args: list[str]) -> str | None:
    completed = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=False)
    if completed.returncode == 0:
        return None
    return first_output_line(completed)


def check_pm_review_closure(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    required_keys = ["brief", "phase_prd", "product_manager_ledger"]
    missing = [key for key in required_keys if key not in package]
    if missing:
        return make_check("pm_review_closure", [f"missing package keys: {missing}"])
    with tempfile.TemporaryDirectory(prefix="stage2-pm-package-") as tmp:
        _feature_dir, phase_dir = write_package_files(package, Path(tmp))
        commands = [
            [
                sys.executable,
                str(ROOT / "shared/skills/product-manager/scripts/preflight_check.py"),
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
                str(ROOT / "tools/community/validate_product_closure.py"),
                "--artifact",
                str(phase_dir.parent / "brief.json"),
                "--require-review",
                "--require-delivery",
            ],
            [
                sys.executable,
                str(ROOT / "tools/community/validate_product_closure.py"),
                "--artifact",
                str(phase_dir / "phase-prd.json"),
                "--require-review",
            ],
        ]
        for command in commands:
            failure = run_script(command)
            if failure:
                add_failure(failures, Path(command[1]).name, failure)
    return make_check("pm_review_closure", failures)


def check_product_manager_ledger(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    ledger = package.get("product_manager_ledger")
    if not isinstance(ledger, dict):
        return make_check("product_manager_ledger", ["product_manager_ledger: must be object"])
    try:
        validate_ledger(ledger, "product-manager", require_finalized=True)
    except ValueError as exc:
        add_failure(failures, "product_manager_ledger", str(exc))
    return make_check("product_manager_ledger", failures)


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
    for action in PM_ALLOWED_ACTIONS:
        if action not in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must include {action}")
    for action in BLOCKED_ACTIONS:
        if action not in blocked:
            add_failure(failures, "decision_boundary.blocked_actions", f"must include {action}")
        if action in allowed:
            add_failure(failures, "decision_boundary.allowed_actions", f"must not include {action}")
    return make_check("authorization_boundary", failures)


def validate(package: dict[str, Any]) -> dict[str, Any]:
    checks = [
        check_package_envelope(package),
        check_confirmed_brief_binding(package),
        check_director_lock_preservation(package),
        check_pm_artifacts(package),
        check_product_manager_ledger(package),
        check_pm_review_closure(package),
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
        "stage2_readiness": "product_manager_prd_ready_for_design" if ready else "blocked",
        "next_standard_chain_role": "design" if ready else None,
        "failed_checks": failed_checks,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path, help="Stage 2 product-manager package JSON.")
    args = parser.parse_args()

    payload = validate(load_json(args.package))
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
