#!/usr/bin/env python3
"""Deterministic grader for the TL-002 Stage 1 dry-run artifact."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


EXPECTED_TASKS = ["TL002-RDY-01", "TL002-T1", "TL002-T2", "TL002-T3", "TL002-T4", "TL002-T5"]
EXPECTED_GAPS = ["GAP-TD002-01", "GAP-TD002-02"]
EXPECTED_BATCHES = [
    ("B0", "TL002-RDY-01"),
    ("B1", "TL002-T1"),
    ("B2", "TL002-T2"),
    ("B3", "TL002-T3"),
    ("B4", "TL002-T4"),
    ("B5", "TL002-T5"),
]
EXPECTED_EVALUATOR_ASSERTIONS = [
    "OA-INPUT-ORIGIN",
    "OA-NO-FORBIDDEN-SCOPE",
    "OA-GAP-NOT-BURIED",
    "OA-RISK-BATCHING",
    "OA-TASK-CONTRACT",
    "OA-DEPENDENCY_AND_PARALLELISM",
    "OA-DOWNSTREAM_GATE",
    "OA-AUTOMATION-EXTERNALIZATION",
]


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(f"failed to read {path}: {exc}") from exc


def has_all(text: str, patterns: list[str]) -> bool:
    return all(re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE) for pattern in patterns)


def table_row_for(text: str, token: str) -> str:
    for line in text.splitlines():
        if token in line and line.strip().startswith("|"):
            return line
    return ""


def contract_row_for(text: str, token: str) -> str:
    for line in text.splitlines():
        if token in line and "dry-runs/tl-002/evidence/" in line and line.strip().startswith("|"):
            return line
    return ""


def ordered_tokens(text: str, pairs: list[tuple[str, str]]) -> bool:
    position = -1
    for left, right in pairs:
        match = re.search(rf"{re.escape(left)}.*{re.escape(right)}", text, flags=re.IGNORECASE | re.DOTALL)
        if not match or match.start() <= position:
            return False
        position = match.start()
    return True


def check_task_contracts(output_text: str) -> tuple[bool, list[str]]:
    present = [task for task in EXPECTED_TASKS if contract_row_for(output_text, task)]
    if present != EXPECTED_TASKS:
        return False, present
    for task in EXPECTED_TASKS:
        row = contract_row_for(output_text, task)
        if task != "TL002-RDY-01" and "TDO-" not in row:
            return False, present
        if not re.search(r"停止|风险|不可验收", row):
            return False, present
    return True, present


def check_risk_batches(output_text: str) -> bool:
    if not ordered_tokens(output_text, EXPECTED_BATCHES):
        return False
    return has_all(output_text, [r"最大未知项前置", r"不是先做包装|最后收口"])


def check_tdo_coverage(output_text: str) -> bool:
    return has_all(
        output_text,
        [
            r"TDO-01~13",
            r"TDO-11/12/13",
            r"TDO-01/02/03/04/12/13",
            r"TDO-05/06/12/13",
            r"TDO-07/08/09/10/12/13",
        ],
    )


def build_checks(input_text: str, output_text: str, evaluator_text: str) -> tuple[list[dict], list[str], list[str], list[str]]:
    task_contracts_passed, tasks = check_task_contracts(output_text)
    evaluator_assertions = [item for item in EXPECTED_EVALUATOR_ASSERTIONS if item in evaluator_text]
    checks = [
        {
            "id": "synthetic_boundary",
            "passed": has_all(input_text, [r"`input_origin`:\s*`synthetic`", r"`status`:\s*`frozen_for_eval_only`"])
            and has_all(output_text, [r"synthetic planning fixture", r"未进入 `/Users/lijieli/project/qft-pai`"]),
        },
        {
            "id": "no_forbidden_scope",
            "passed": has_all(
                output_text,
                [
                    r"不写真实 `tasks\.json/plan\.json`",
                    r"禁止语言、框架、数据库、云产品选择",
                    r"禁止派发 developer",
                    r"禁止真实排期",
                    r"禁止声明 Stage 1 通过",
                ],
            ),
        },
        {
            "id": "gap_readiness_gate",
            "passed": has_all(
                output_text,
                [
                    r"TL002-RDY-01",
                    r"GAP-TD002-01",
                    r"GAP-TD002-02",
                    r"channel_id",
                    r"bot_id",
                    r"样板触发语",
                    r"chain_record",
                    r"停止释放 `TL002-T1~T5`",
                ],
            ),
        },
        {"id": "risk_driven_batches", "passed": check_risk_batches(output_text)},
        {
            "id": "dependency_chain",
            "passed": has_all(output_text, [r"TL002-RDY-01 -> TL002-T1 -> TL002-T2 -> TL002-T3 -> TL002-T4 -> TL002-T5"]),
        },
        {"id": "task_contracts", "passed": task_contracts_passed},
        {"id": "tdo_coverage", "passed": check_tdo_coverage(output_text)},
        {
            "id": "downstream_gate",
            "passed": has_all(output_text, [r"给 Delivery-owner 的消费提示", r"未通过时不得释放任何后续任务"]),
        },
        {
            "id": "evaluator_owner_action",
            "passed": has_all(evaluator_text, [r"judgment: warn", r"chain_status: continue", r"grade: P2", r"owner: script"]),
        },
    ]
    return checks, tasks, EXPECTED_GAPS, evaluator_assertions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="TL-002 synthetic fixture path")
    parser.add_argument("--output", required=True, type=Path, help="TL-002 tech-lead output path")
    parser.add_argument("--evaluator", required=True, type=Path, help="TL-002 evaluator output path")
    args = parser.parse_args()

    input_text = read_text(args.input)
    output_text = read_text(args.output)
    evaluator_text = read_text(args.evaluator)
    checks, tasks, gaps, evaluator_assertions = build_checks(input_text, output_text, evaluator_text)
    failed = [check["id"] for check in checks if not check["passed"]]
    payload = {
        "case": "TL-002",
        "status": "fail" if failed else "pass",
        "failed_checks": failed,
        "tasks": tasks,
        "readiness_gaps": gaps,
        "evaluator_objective_assertions": evaluator_assertions,
        "checks": checks,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
