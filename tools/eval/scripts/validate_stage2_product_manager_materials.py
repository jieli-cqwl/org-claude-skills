#!/usr/bin/env python3
"""Validate Stage 2 product-manager materials without entering qft-pai."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

from render_stage2_product_director_handoff import ROOT, render
from validate_stage2_confirmed_brief_materials import (
    build_package as build_confirmed_package,
)
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate
from validate_stage2_product_manager_materials_builder import build_pm_package
from validate_stage2_product_manager_package import BLOCKED_ACTIONS, validate


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

    package = build_pm_package(build_confirmed_package(handoff))
    package_result = validate(package)
    if package_result["status"] != "pass":
        failures.append("valid product-manager package did not pass")

    broken = copy.deepcopy(package)
    broken["decision_boundary"]["blocked_actions"] = [
        action
        for action in broken["decision_boundary"]["blocked_actions"]
        if action != "auto_send"
    ]
    broken["decision_boundary"]["allowed_actions"].append("language_selection")
    if validate(broken)["status"] == "pass":
        failures.append(
            "product-manager package did not enforce authorization boundary"
        )

    broken_unit = copy.deepcopy(package)
    broken_unit["units"][0].pop("acceptance_criteria", None)
    if validate(broken_unit)["status"] == "pass":
        failures.append(
            "product-manager package did not enforce UNIT acceptance criteria"
        )

    return {
        "status": "fail" if failures else "pass",
        "stage2_readiness": package_result.get("stage2_readiness"),
        "next_standard_chain_role": package_result.get("next_standard_chain_role"),
        "validated_blocked_actions": BLOCKED_ACTIONS,
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
