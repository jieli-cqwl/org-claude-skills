#!/usr/bin/env python3
"""Deterministic grader for the TD-003 Stage 1 dry-run artifact."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(f"failed to read {path}: {exc}") from exc


def has_all(text: str, patterns: list[str]) -> bool:
    return all(re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE) for pattern in patterns)


def build_checks(input_text: str, output_text: str, evaluator_text: str) -> list[dict]:
    return [
        {
            "id": "synthetic_boundary",
            "passed": has_all(input_text, [r"`input_origin`:\s*`synthetic`"])
            and has_all(output_text, [r"Stage 1.*synthetic", r"不进入 `/Users/lijieli/project/qft-pai`"]),
        },
        {
            "id": "typed_blocking_gap",
            "passed": has_all(
                output_text,
                [
                    r"DESIGN_GAP",
                    r"blocking=true",
                    r"rollback_strategy",
                    r"manual_takeover_policy",
                    r"response_dispatch_partial_failure",
                    r"risk_acceptance_owner",
                    r"owner.*design owner",
                    r"next_action",
                    r"resume_condition",
                ],
            ),
        },
        {
            "id": "downstream_blocked",
            "passed": has_all(
                output_text,
                [
                    r"不允许进入 `tech-lead planning`",
                    r"BLOCKED / stop handoff",
                    r"tech-lead.*不得拆开发任务",
                    r"delivery-owner.*不得派发 developer/QA",
                ],
            ),
        },
        {
            "id": "no_mock_bypass",
            "passed": has_all(output_text, [r"不能用 mock|不得.*mock", r"后续补充.*绕过|不能.*后续补充"]),
        },
        {
            "id": "draft_not_frozen",
            "passed": has_all(output_text, [r"可列草稿，不冻结", r"必须等 Design 补齐", r"整体 `test plan`.*不能冻结"]),
        },
        {
            "id": "evaluator_verdict",
            "passed": has_all(evaluator_text, [r"judgment:\s*`pass`", r"chain_status:\s*`pass_to_pause`", r"grade:\s*`none`"]),
        },
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="TD-003 synthetic fixture path")
    parser.add_argument("--output", required=True, type=Path, help="TD-003 test-design output path")
    parser.add_argument("--evaluator", required=True, type=Path, help="TD-003 evaluator output path")
    args = parser.parse_args()

    checks = build_checks(read_text(args.input), read_text(args.output), read_text(args.evaluator))
    failed = [check["id"] for check in checks if not check["passed"]]
    payload = {
        "case": "TD-003",
        "status": "fail" if failed else "pass",
        "failed_checks": failed,
        "checks": checks,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
