#!/usr/bin/env python3
"""Validate Stage 1 documentation anchors consumed by the eval gate."""

from __future__ import annotations

from pathlib import Path
from typing import Any


FEATURE_DOCS = Path("docs/feature--agent-delivery-operating-system")
GATE_REPORT = FEATURE_DOCS / "stage-1-gate-report.md"
STRUCTURE_CONTRACT = FEATURE_DOCS / "stage-1-artifact-structure-contract.md"
EVAL_CHARTER = FEATURE_DOCS / "stage-1-eval-charter.md"
GOAL_DOC = FEATURE_DOCS / "goal-and-success-criteria.md"
STAGE2_INTAKE_GUIDE = FEATURE_DOCS / "stage-2-intake-gate.md"


def require(checks: list[str], condition: bool, message: str) -> None:
    if not condition:
        checks.append(message)


def make_check(contract: str, failures: list[str], details: dict[str, Any]) -> dict[str, Any]:
    return {
        "contract": contract,
        "status": "fail" if failures else "pass",
        "failures": failures,
        "details": details,
    }


def read_if_exists(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def check_terms(failures: list[str], text: str, terms: list[str], label: str) -> None:
    missing = [term for term in terms if term not in text]
    require(failures, not missing, f"{label} missing terms: {missing}")


def check_stage1_documentation(repo_root: Path) -> dict[str, Any]:
    failures: list[str] = []
    gate_report = repo_root / GATE_REPORT
    structure_contract = repo_root / STRUCTURE_CONTRACT
    eval_charter = repo_root / EVAL_CHARTER
    goal_doc = repo_root / GOAL_DOC
    stage2_intake_guide = repo_root / STAGE2_INTAKE_GUIDE

    required_terms = ["typed gap", "Task Packet", "signoff gate", "术语表", "设计接口契约", "schema"]
    contract_required_terms = [
        "validate_stage1_artifact_contracts.py",
        "run_stage1_eval_checks.py",
        "不能进入 Stage 2",
        "qft-pai",
    ]
    stage2_entry_terms = [
        "stage-2-intake-facts",
        "validate_stage2_intake_gate.py",
        "render_stage2_product_director_handoff.py",
        "validate_stage2_confirmed_brief_package.py",
        "validate_stage2_product_manager_package.py",
        "validate_stage2_design_package.py",
        "validate_stage2_test_design_package.py",
        "validate_stage2_tech_lead_package.py",
        "product-director",
        "product-manager",
        "design",
        "test-design",
        "tech-lead",
        "delivery-owner",
        "代码修改",
    ]

    require(failures, gate_report.is_file(), "stage 1 gate report doc missing")
    require(failures, structure_contract.is_file(), "stage 1 artifact structure contract doc missing")
    require(failures, eval_charter.is_file(), "stage 1 eval charter doc missing")
    require(failures, goal_doc.is_file(), "goal and success criteria doc missing")
    require(failures, stage2_intake_guide.is_file(), "stage 2 intake gate doc missing")

    check_terms(failures, read_if_exists(gate_report), required_terms, "stage 1 gate report")
    check_terms(failures, read_if_exists(structure_contract), contract_required_terms, "stage 1 artifact contract doc")
    stage2_docs = {
        "stage-1-eval-charter.md": read_if_exists(eval_charter),
        "goal-and-success-criteria.md": read_if_exists(goal_doc),
        "stage-2-intake-gate.md": read_if_exists(stage2_intake_guide),
    }
    for doc_name, doc_text in stage2_docs.items():
        check_terms(failures, doc_text, stage2_entry_terms, doc_name)

    return make_check(
        "stage1_documentation",
        failures,
        {
            "gate_report": str(GATE_REPORT),
            "artifact_structure_contract": str(STRUCTURE_CONTRACT),
            "required_terms": required_terms,
            "stage2_entry_docs": sorted(stage2_docs),
            "stage2_entry_terms": stage2_entry_terms,
        },
    )
