#!/usr/bin/env python3
"""Grade the E2E-RESUME-001 cross-role resume-chain dry run."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
CASE_DIR = Path("docs/feature--agent-delivery-operating-system/dry-runs/e2e-resume-001")
EXPECTED_ROLES = [
    "product-director",
    "product-manager",
    "design",
    "test-design",
    "tech-lead",
    "delivery-owner",
]


def read_text(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"missing required file: {path}")
    return path.read_text(encoding="utf-8")


def has_all(text: str, patterns: list[str]) -> bool:
    return all(re.search(pattern, text, re.IGNORECASE | re.MULTILINE) for pattern in patterns)


def extract_role_order(output_text: str) -> list[str]:
    roles: list[str] = []
    in_section = False
    for line in output_text.splitlines():
        if line.strip() == "## Role Order":
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if in_section:
            match = re.match(r"^[0-9]+\. ([a-z-]+)$", line.strip())
            if match:
                roles.append(match.group(1))
    return roles


def check(name: str, passed: bool) -> dict[str, Any]:
    return {"id": name, "passed": passed}


def grade(input_text: str, output_text: str, evaluator_text: str, decision_text: str) -> dict[str, Any]:
    role_order = extract_role_order(output_text)
    checks = [
        check("input_origin", has_all(input_text + output_text, [r"input_origin:\s*synthetic_resume_package"])),
        check("role_order", role_order == EXPECTED_ROLES),
        check(
            "director_resume",
            has_all(
                output_text,
                [
                    r"## Product Director",
                    r"artifact:\s*confirmed_brief",
                    r"status:\s*continue",
                    r"handoff_to:\s*product-manager",
                ],
            ),
        ),
        check(
            "pm_units",
            has_all(
                output_text,
                [
                    r"## Product Manager",
                    r"artifact:\s*phase_prd_and_units",
                    r"UNIT-1 callback intake",
                    r"UNIT-5 failure takeover",
                    r"execution_context",
                    r"handoff_to:\s*design",
                ],
            ),
        ),
        check(
            "design_interfaces",
            has_all(
                output_text,
                [
                    r"## Design",
                    r"artifact:\s*design_interface_contract",
                    r"IF-CALLBACK-IN",
                    r"IF-CONTEXT-BUILD",
                    r"IF-AGENT-DISPATCH",
                    r"IF-HUMAN-HANDOFF",
                    r"error_codes",
                    r"idempotency",
                    r"rollback",
                    r"observability",
                ],
            ),
        ),
        check(
            "test_design_handoff",
            has_all(
                output_text,
                [
                    r"## Test Design",
                    r"artifact:\s*test_cases_and_handoff",
                    r"TDO-01",
                    r"TDO-08",
                    r"status:\s*NO_GAPS",
                    r"handoff_to:\s*tech-lead",
                ],
            ),
        ),
        check(
            "tech_lead_task_contract",
            has_all(
                output_text,
                [
                    r"## Tech Lead",
                    r"artifact:\s*plan_and_tasks",
                    r"readiness_gate:\s*TL-RDY-01",
                    r"batch_1",
                    r"batch_4",
                    r"task_contract",
                    r"stop_condition",
                    r"handoff_to:\s*delivery-owner",
                ],
            ),
        ),
        check(
            "delivery_owner_boundary",
            has_all(
                output_text,
                [
                    r"## Delivery Owner",
                    r"artifact:\s*delivery_decision",
                    r"status:\s*pass_to_pause",
                    r"dry_run_dispatch_ready:\s*true",
                    r"task_packet_gate:\s*DISPATCH_READY",
                    r"real_execution_allowed:\s*false",
                ],
            ),
        ),
        check("delivery_owner_resume_condition", has_all(output_text, [r"^resume_condition:"])),
        check(
            "evaluator_verdict",
            has_all(
                evaluator_text,
                [
                    r"judgment:\s*pass",
                    r"chain_status:\s*pass_to_pause",
                    r"grade:\s*none",
                    r"synthetic resume-chain eval|synthetic_resume",
                ],
            ),
        ),
        check(
            "decision_boundary",
            has_all(
                decision_text,
                [
                    r"跨角色链路",
                    r"Stage 1 仍不能进入 Stage 2",
                    r"不派发 developer",
                    r"不替 human/business owner 接受业务风险",
                ],
            ),
        ),
        check(
            "no_real_project_overreach",
            not re.search(r"/Users/lijieli/project/qft-pai|real_execution_allowed:\s*true|已真实上线|已真实提交", output_text),
        ),
    ]
    failed = [item["id"] for item in checks if not item["passed"]]
    return {
        "case": "E2E-RESUME-001",
        "status": "fail" if failed else "pass",
        "failed_checks": failed,
        "checks": checks,
        "roles": role_order,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--evaluator", type=Path)
    parser.add_argument("--decision", type=Path)
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    input_path = args.input or repo_root / CASE_DIR / "input.md"
    output_path = args.output or repo_root / CASE_DIR / "chain-output.md"
    evaluator_path = args.evaluator or repo_root / CASE_DIR / "evaluator-output.md"
    decision_path = args.decision or repo_root / CASE_DIR / "decision.md"

    payload = grade(
        read_text(input_path),
        read_text(output_path),
        read_text(evaluator_path),
        read_text(decision_path),
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
