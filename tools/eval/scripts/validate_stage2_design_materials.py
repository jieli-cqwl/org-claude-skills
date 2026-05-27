#!/usr/bin/env python3
"""Validate Stage 2 design materials without entering qft-pai."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

from render_stage2_product_director_handoff import render
from validate_stage2_confirmed_brief_materials import (
    build_package as build_confirmed_package,
)
from validate_stage2_design_package import (
    DESIGN_ALLOWED_ACTIONS,
    DESIGN_BLOCKED_ACTIONS,
    ROOT,
    validate,
)
from validate_stage2_design_materials_builder import build_design_artifact
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate
from validate_stage2_product_manager_materials import build_pm_package


def build_design_package(pm_package: dict[str, Any]) -> dict[str, Any]:
    return {
        "artifact_type": "stage-2-design-package",
        "status": "pass",
        "input_origin": "stage-2-product-manager-prd-package",
        "product_manager_package": pm_package,
        "design": build_design_artifact(pm_package),
        "decision_boundary": {
            "allowed_actions": DESIGN_ALLOWED_ACTIONS,
            "blocked_actions": DESIGN_BLOCKED_ACTIONS,
        },
        "handoff_to": "test-design",
        "resume_condition": "test_design_stage2_ready",
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
    package = build_design_package(pm_package)
    package_result = validate(package)
    if package_result["status"] != "pass":
        failures.append("valid design package did not pass")

    broken = copy.deepcopy(package)
    broken["decision_boundary"]["blocked_actions"] = [
        action
        for action in broken["decision_boundary"]["blocked_actions"]
        if action != "code_changes"
    ]
    broken["decision_boundary"]["allowed_actions"].append("code_changes")
    if validate(broken)["status"] == "pass":
        failures.append("design package did not enforce implementation boundary")

    broken_coverage = copy.deepcopy(package)
    broken_coverage["design"]["unit_coverage"] = []
    if validate(broken_coverage)["status"] == "pass":
        failures.append("design package did not enforce UNIT coverage")

    return {
        "status": "fail" if failures else "pass",
        "stage2_readiness": package_result.get("stage2_readiness"),
        "next_standard_chain_role": package_result.get("next_standard_chain_role"),
        "validated_blocked_actions": DESIGN_BLOCKED_ACTIONS,
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
