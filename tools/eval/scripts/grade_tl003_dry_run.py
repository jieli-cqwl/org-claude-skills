#!/usr/bin/env python3
"""Deterministic grader for the TL-003 Stage 1 dry-run artifact."""

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
            and has_all(output_text, [r"Stage 1.*synthetic", r"不得进入 `/Users/lijieli/project/qft-pai`"]),
        },
        {
            "id": "reject_mock_completion",
            "passed": has_all(output_text, [r"不接受.*mock.*就算完成", r"mock-only.*验收伪造|mock-only.*标成完成"]),
        },
        {
            "id": "mock_allowed_scope",
            "passed": has_all(
                output_text,
                [r"开发隔离", r"异常", r"开发前预检", r"demo-only", r"precheck_only / mock_only"],
            ),
        },
        {
            "id": "real_evidence_gate",
            "passed": has_all(
                output_text,
                [r"必须作为最终 gate 的真实路径证据", r"真实三方消息回调", r"真实前置处理", r"真实链路证据记录"],
            ),
        },
        {
            "id": "delivery_owner_boundary",
            "passed": has_all(
                output_text,
                [r"给 Delivery-owner 的验收边界", r"BLOCKED / NEEDS_REAL_EVIDENCE", r"真实路径 evidence ref"],
            ),
        },
        {
            "id": "no_forbidden_scope",
            "passed": has_all(output_text, [r"不派发 developer", r"不写代码", r"不写真实提交计划", r"不.*上线"]),
        },
        {
            "id": "evaluator_verdict",
            "passed": has_all(evaluator_text, [r"`judgment`:\s*`pass`", r"`chain_status`:\s*`continue`", r"`grade`:\s*`none`"]),
        },
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="TL-003 synthetic fixture path")
    parser.add_argument("--output", required=True, type=Path, help="TL-003 tech-lead output path")
    parser.add_argument("--evaluator", required=True, type=Path, help="TL-003 evaluator output path")
    args = parser.parse_args()

    checks = build_checks(read_text(args.input), read_text(args.output), read_text(args.evaluator))
    failed = [check["id"] for check in checks if not check["passed"]]
    payload = {
        "case": "TL-003",
        "status": "fail" if failed else "pass",
        "failed_checks": failed,
        "checks": checks,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
