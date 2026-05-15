#!/usr/bin/env python3
"""Deterministic grader for the TD-002 Stage 1 dry-run artifact."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


EXPECTED_TDOS = [f"TDO-{index:02d}" for index in range(1, 14)]
EXPECTED_GAPS = ["GAP-TD002-01", "GAP-TD002-02"]


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


def check_tdo_traceability(output_text: str) -> tuple[bool, list[str]]:
    present = [tdo for tdo in EXPECTED_TDOS if table_row_for(output_text, tdo)]
    if present != EXPECTED_TDOS:
        return False, present
    for tdo in EXPECTED_TDOS:
        row = table_row_for(output_text, tdo)
        if tdo == "TDO-13":
            if "frozen design" not in row or "IF-" not in row:
                return False, present
            continue
        if not re.search(r"UNIT-\d{2}", row) or "AC-" not in row or "IF-" not in row:
            return False, present
    return True, present


def check_typed_gaps(output_text: str) -> tuple[bool, list[str]]:
    present = [gap for gap in EXPECTED_GAPS if table_row_for(output_text, gap)]
    if present != EXPECTED_GAPS:
        return False, present
    for gap in EXPECTED_GAPS:
        row = table_row_for(output_text, gap)
        if "TESTABILITY_GAP" not in row or not re.search(r"\|\s*false\s*\|", row):
            return False, present
        if not re.search(r"\|\s*[^|]+\s*/\s*[^|]+\s*\|", row):
            return False, present
        if "不阻断" not in row:
            return False, present
    return True, present


def build_checks(input_text: str, output_text: str, evaluator_text: str) -> tuple[list[dict], list[str], list[str]]:
    tdo_passed, tdos = check_tdo_traceability(output_text)
    gaps_passed, gaps = check_typed_gaps(output_text)
    checks = [
        {
            "id": "synthetic_boundary",
            "passed": has_all(input_text, [r"`input_origin`:\s*`synthetic`", r"`status`:\s*`frozen_for_eval_only`"])
            and has_all(output_text, [r"synthetic frozen fixture", r"不是真实 qft-pai 证据"]),
        },
        {
            "id": "no_overreach",
            "passed": has_all(
                output_text,
                [
                    r"不执行 QA",
                    r"不批准发布",
                    r"不拆开发任务",
                    r"不补产品/设计结论",
                    r"不声明 Stage 1 通过",
                ],
            ),
        },
        {"id": "traceability_matrix", "passed": tdo_passed},
        {
            "id": "path_coverage",
            "passed": has_all(output_text, [r"正向", r"范围外", r"阻断", r"失败", r"回滚/补偿", r"证据完整性"]),
        },
        {
            "id": "evidence_expectation",
            "passed": has_all(output_text, [r"chain_id", r"阶段状态", r"证据摘要", r"chain_record", r"not_executed_stages"]),
        },
        {"id": "typed_gaps", "passed": gaps_passed},
        {
            "id": "qa_handoff",
            "passed": has_all(output_text, [r"QA Handoff Contract", r"冒烟必须覆盖", r"QA 证据包"]),
        },
        {
            "id": "tech_lead_binding",
            "passed": has_all(output_text, [r"Tech-Lead", r"每个 Task", r"TDO-\*", r"IF-\*"]),
        },
        {
            "id": "evaluator_owner_action",
            "passed": has_all(evaluator_text, [r"judgment: warn", r"chain_status: continue", r"grade: P2", r"owner: script"]),
        },
    ]
    return checks, tdos, gaps


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="TD-002 synthetic fixture path")
    parser.add_argument("--output", required=True, type=Path, help="TD-002 test-design output path")
    parser.add_argument("--evaluator", required=True, type=Path, help="TD-002 evaluator output path")
    args = parser.parse_args()

    input_text = read_text(args.input)
    output_text = read_text(args.output)
    evaluator_text = read_text(args.evaluator)
    checks, tdos, gaps = build_checks(input_text, output_text, evaluator_text)
    failed = [check["id"] for check in checks if not check["passed"]]
    payload = {
        "case": "TD-002",
        "status": "fail" if failed else "pass",
        "failed_checks": failed,
        "tdos": tdos,
        "typed_gaps": gaps,
        "checks": checks,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
