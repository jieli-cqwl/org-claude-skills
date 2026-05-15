#!/usr/bin/env python3
"""Deterministic grader for the DES-003 Stage 1 dry-run artifact."""

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
            and has_all(output_text, [r"Stage 1 synthetic", r"未进入 `/Users/lijieli/project/qft-pai`"]),
        },
        {
            "id": "interface_contract",
            "passed": has_all(output_text, [r"IF-001", r"IF-002", r"IF-003", r"IF-004", r"IF-005", r"IF-006", r"input", r"output", r"error"]),
        },
        {
            "id": "reliability_boundaries",
            "passed": has_all(output_text, [r"message_idempotency_key", r"重试边界", r"降级边界", r"回滚边界"]),
        },
        {
            "id": "failure_paths",
            "passed": has_all(output_text, [r"重复回调", r"乱序", r"三方超时", r"agent 超时", r"响应回写失败", r"链路记录失败"]),
        },
        {
            "id": "observability",
            "passed": has_all(output_text, [r"指标", r"结构化日志字段", r"告警", r"trace_id", r"correlation_id"]),
        },
        {
            "id": "downstream_boundary",
            "passed": has_all(output_text, [r"test-design 可以直接生成", r"test-design 不能脑补", r"真实三方字段名", r"真实 SLA"]),
        },
        {
            "id": "evaluator_verdict",
            "passed": has_all(evaluator_text, [r"judgment:\s*`pass`", r"chain_status:\s*`pass_to_pause`", r"grade:\s*`none`"]),
        },
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="DES-003 input path")
    parser.add_argument("--output", required=True, type=Path, help="DES-003 design output path")
    parser.add_argument("--evaluator", required=True, type=Path, help="DES-003 evaluator output path")
    args = parser.parse_args()

    checks = build_checks(read_text(args.input), read_text(args.output), read_text(args.evaluator))
    failed = [check["id"] for check in checks if not check["passed"]]
    print(json.dumps({"case": "DES-003", "status": "fail" if failed else "pass", "failed_checks": failed, "checks": checks}, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
