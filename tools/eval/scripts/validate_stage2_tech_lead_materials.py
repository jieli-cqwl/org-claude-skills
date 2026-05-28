#!/usr/bin/env python3
"""Validate Stage 2 tech-lead materials without entering qft-pai."""

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
from validate_stage2_design_materials import build_design_package
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate
from validate_stage2_product_manager_materials import build_pm_package
from validate_stage2_tech_lead_materials_builder import build_tech_lead_package
from validate_stage2_tech_lead_package import TECH_LEAD_BLOCKED_ACTIONS, validate
from validate_stage2_test_design_materials import build_test_design_package

ROOT = Path(__file__).resolve().parents[3]


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
    test_design_package = build_test_design_package(design_package)
    package = build_tech_lead_package(test_design_package)
    package_result = validate(package)
    if package_result["status"] != "pass":
        failures.append("valid tech-lead package did not pass")

    broken = copy.deepcopy(package)
    broken["decision_boundary"]["blocked_actions"] = [
        action
        for action in broken["decision_boundary"]["blocked_actions"]
        if action != "code_changes"
    ]
    broken["decision_boundary"]["allowed_actions"].append("code_changes")
    if validate(broken)["status"] == "pass":
        failures.append("tech-lead package did not enforce implementation boundary")

    broken_confirmation = copy.deepcopy(package)
    broken_confirmation["tasks"]["user_confirmation"]["status"] = "PENDING"
    if validate(broken_confirmation)["status"] == "pass":
        failures.append("tech-lead package did not enforce confirmed tasks")

    broken_dependency = copy.deepcopy(package)
    broken_dependency["tasks"]["tasks"][0]["depends_on"] = ["TASK-DOES-NOT-EXIST"]
    if validate(broken_dependency)["status"] == "pass":
        failures.append("tech-lead package did not enforce dependency integrity")

    broken_qa = copy.deepcopy(package)
    broken_qa["test_design_package"]["test_cases"]["qa_handoff_contract"] = []
    if validate(broken_qa)["status"] == "pass":
        failures.append("tech-lead package did not enforce QA handoff baseline")

    return {
        "status": "fail" if failures else "pass",
        "stage2_readiness": package_result.get("stage2_readiness"),
        "next_standard_chain_role": package_result.get("next_standard_chain_role"),
        "validated_blocked_actions": TECH_LEAD_BLOCKED_ACTIONS,
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
