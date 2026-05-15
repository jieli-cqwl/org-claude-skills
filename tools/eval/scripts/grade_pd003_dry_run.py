#!/usr/bin/env python3
"""Deterministic grader for the PD-003 Stage 1 dry-run artifact."""

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
            "id": "input_boundary",
            "passed": has_all(input_text, [r"`input_origin`:\s*`user_prompt`", r"老板满意"])
            and has_all(output_text, [r"Stage 1.*dry-run|Stage 1.*user_prompt", r"不证明真实业务成功"]),
        },
        {
            "id": "reject_subjective_standard",
            "passed": has_all(output_text, [r"不允许进入 product-manager", r"老板满意 / 看起来能跑", r"主观口径"]),
        },
        {
            "id": "observable_success_criteria",
            "passed": has_all(
                output_text,
                [r"可观察目标", r"成功标准", r"数据来源", r"当前缺口", r"owner", r"恢复条件"],
            ),
        },
        {
            "id": "human_decision_points",
            "passed": has_all(output_text, [r"最终验收人", r"业务样板", r"Stage 2", r"P1 风险", r"投入边界"]),
        },
        {
            "id": "no_forbidden_scope",
            "passed": has_all(output_text, [r"不进 `qft-pai`", r"不做语言选型", r"不做架构设计", r"不允许继续真实 PM/PRD/设计/开发链路"]),
        },
        {
            "id": "evaluator_verdict",
            "passed": has_all(evaluator_text, [r"judgment:\s*`pass`", r"chain_status:\s*`pass_to_pause`", r"grade:\s*`none`"]),
        },
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="PD-003 input path")
    parser.add_argument("--output", required=True, type=Path, help="PD-003 product-director output path")
    parser.add_argument("--evaluator", required=True, type=Path, help="PD-003 evaluator output path")
    args = parser.parse_args()

    checks = build_checks(read_text(args.input), read_text(args.output), read_text(args.evaluator))
    failed = [check["id"] for check in checks if not check["passed"]]
    print(json.dumps({"case": "PD-003", "status": "fail" if failed else "pass", "failed_checks": failed, "checks": checks}, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
