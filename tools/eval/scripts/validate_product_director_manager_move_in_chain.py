#!/usr/bin/env python3
"""Validate Director->PM chain output against the move-in PRD golden rubric."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
FIXTURE_DIR = ROOT / "tests/fixtures/product-director-manager-move-in-chain"
DEFAULT_RUBRIC = FIXTURE_DIR / "golden-rubric.json"

sys.path.insert(0, str(ROOT / "tools/eval/scripts"))
sys.path.insert(0, str(ROOT / "tools/community"))

from validate_product_director_manager_move_in_chain_builders import build_package  # noqa: E402
from validate_stage2_confirmed_brief_package import (  # noqa: E402
    validate as validate_director_package,
)
from validate_stage2_product_manager_package import validate as validate_pm_package  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def add_failure(failures: list[str], field: str, reason: str) -> None:
    failures.append(f"{field}: {reason}")


def make_check(name: str, failures: list[str]) -> dict[str, Any]:
    return {
        "check": name,
        "status": "fail" if failures else "pass",
        "failures": failures,
    }


def text_blob(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def check_package_envelope(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    if package.get("artifact_type") != "product-director-manager-move-in-chain-package":
        add_failure(
            failures,
            "artifact_type",
            "must be product-director-manager-move-in-chain-package",
        )
    if package.get("source_demand", {}).get("not_copied_from_golden_prd") is not True:
        add_failure(
            failures, "source_demand.not_copied_from_golden_prd", "must be true"
        )
    return make_check("package_envelope", failures)


def check_director_boundary(
    package: dict[str, Any], rubric: dict[str, Any]
) -> dict[str, Any]:
    failures: list[str] = []
    confirmed = package.get("confirmed_brief_package") or {}
    result = validate_director_package(confirmed)
    if result.get("status") != "pass":
        add_failure(
            failures, "confirmed_brief_package", str(result.get("failed_checks"))
        )
    director_text = text_blob(confirmed.get("brief")) + text_blob(
        confirmed.get("phase_prd")
    )
    for term in rubric.get("director_must_include_terms", []):
        if term not in director_text:
            add_failure(failures, "director_boundary", f"missing term: {term}")
    return make_check("director_boundary", failures)


def check_product_manager_package(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    pm_package = package.get("product_manager_package")
    if not isinstance(pm_package, dict):
        return make_check(
            "product_manager_package", ["product_manager_package: must be object"]
        )
    result = validate_pm_package(pm_package)
    if result.get("status") != "pass":
        add_failure(
            failures, "product_manager_package", str(result.get("failed_checks"))
        )
    return make_check("product_manager_package", failures)


def check_golden_prd_rubric(
    package: dict[str, Any], rubric: dict[str, Any]
) -> dict[str, Any]:
    failures: list[str] = []
    phase = package.get("product_manager_package", {}).get("phase_prd", {})
    units = package.get("product_manager_package", {}).get("units", [])
    coverage = phase.get("coverage_matrix", [])
    tech = phase.get("technical_evidence_requirements", [])
    evidence = phase.get("evidence_sources", [])
    business_types = {
        item.get("business_type") for item in coverage if isinstance(item, dict)
    }
    platforms = {item.get("platform") for item in coverage if isinstance(item, dict)}
    actions = {
        item.get("action_or_path") for item in coverage if isinstance(item, dict)
    }
    domains = {item.get("domain") for item in tech if isinstance(item, dict)}
    source_types = {
        item.get("source_type") for item in evidence if isinstance(item, dict)
    }
    ac_ids = {
        criterion.get("ac_id")
        for unit in units
        for criterion in unit.get("acceptance_criteria", [])
        if isinstance(criterion, dict)
    }
    for term in rubric["required_business_types"]:
        if term not in business_types:
            add_failure(failures, "coverage_matrix.business_type", f"missing {term}")
    for term in rubric["required_platforms"]:
        if term not in platforms:
            add_failure(failures, "coverage_matrix.platform", f"missing {term}")
    for term in rubric["required_actions"]:
        if term not in actions:
            add_failure(failures, "coverage_matrix.action_or_path", f"missing {term}")
    for term in rubric["required_technical_domains"]:
        if term not in domains:
            add_failure(
                failures, "technical_evidence_requirements.domain", f"missing {term}"
            )
    for term in rubric["required_evidence_source_types"]:
        if term not in source_types:
            add_failure(failures, "evidence_sources.source_type", f"missing {term}")
    for term in rubric["required_ac_refs"]:
        if term not in ac_ids:
            add_failure(failures, "acceptance_criteria", f"missing {term}")
    risk_text = text_blob(phase.get("risk_ledger"))
    for term in rubric["required_risk_terms"]:
        if term not in risk_text:
            add_failure(failures, "risk_ledger", f"missing {term}")
    release = phase.get("release_readiness", {})
    for platform in rubric["conditional_platforms"]:
        if platform not in release.get("conditional_platforms", []):
            add_failure(
                failures,
                "release_readiness.conditional_platforms",
                f"missing {platform}",
            )
    return make_check("golden_prd_rubric", failures)


def check_downstream_consumability(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    pm_package = package.get("product_manager_package", {})
    phase = pm_package.get("phase_prd", {})
    if not phase.get("design_decision_candidates"):
        add_failure(
            failures, "phase_prd.design_decision_candidates", "must be non-empty"
        )
    for unit in pm_package.get("units", []):
        for item in unit.get("verification_plan", []):
            if not item.get("evidence_types") or not item.get("covers_refs"):
                add_failure(
                    failures,
                    f"{unit.get('unit_id')}.verification_plan",
                    "must carry evidence_types and covers_refs",
                )
    for item in phase.get("coverage_matrix", []):
        if not item.get("evidence_targets"):
            add_failure(
                failures,
                "coverage_matrix.evidence_targets",
                f"missing for {item.get('coverage_id')}",
            )
    return make_check("downstream_consumability", failures)


def validate_package(package: dict[str, Any], rubric: dict[str, Any]) -> dict[str, Any]:
    checks = [
        check_package_envelope(package),
        check_director_boundary(package, rubric),
        check_product_manager_package(package),
        check_golden_prd_rubric(package, rubric),
        check_downstream_consumability(package),
    ]
    failed = [failure for check in checks for failure in check["failures"]]
    return {
        "status": "pass" if not failed else "fail",
        "stage2_readiness": "director_manager_chain_meets_move_in_prd_rubric"
        if not failed
        else "blocked",
        "failed_checks": failed,
        "checks": checks,
        "rubric_summary": {"coverage": "complete" if not failed else "incomplete"},
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--rubric", type=Path, default=DEFAULT_RUBRIC)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root.")
    parser.add_argument("--emit-package", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rubric = load_json(args.rubric)
    if args.emit_package:
        print(
            json.dumps(
                build_package(rubric), ensure_ascii=False, indent=2, sort_keys=True
            )
        )
        return 0
    package = (
        load_json(args.package) if args.package is not None else build_package(rubric)
    )
    result = validate_package(package, rubric)
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if result["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
