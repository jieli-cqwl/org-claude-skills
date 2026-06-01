#!/usr/bin/env python3
"""Deterministic grader for the DO-002 Stage 1 dry-run artifact."""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any


EXPECTED_ASSERTIONS = [
    "OA-INPUT-ORIGIN",
    "OA-ADVISORY-CONSUMED",
    "OA-ONLY_T1_RELEASED",
    "OA-T2_T5_LOCKED",
    "OA-VERIFIER_GATE",
    "OA-TASK_PACKET_COMPLETE",
    "OA-NO_REAL_STATE_OR_COMMIT",
    "OA-PACKET_SCRIPT_VALIDATE",
    "OA-AUTOMATION_EXTERNALIZATION",
]
EXPECTED_FINDING = "BCA-DO002-01"
EXPECTED_TASK = "TL002-T1"


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(f"failed to read {path}: {exc}") from exc


def has_all(text: str, patterns: list[str]) -> bool:
    return all(re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE) for pattern in patterns)


def yaml_block(text: str) -> str:
    match = re.search(r"```yaml\n(.*?)\n```", text, flags=re.DOTALL)
    return match.group(1) if match else ""


def scalar(block: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}:\s*(.+)$", block, flags=re.MULTILINE)
    return match.group(1).strip() if match else ""


def section(block: str, key: str) -> str:
    lines = block.splitlines()
    start = None
    for index, line in enumerate(lines):
        if re.match(rf"^{re.escape(key)}:\s*(>|$)", line):
            start = index + 1
            break
    if start is None:
        return ""
    captured: list[str] = []
    for line in lines[start:]:
        if re.match(r"^[A-Za-z_]+:", line):
            break
        captured.append(line)
    return "\n".join(captured).strip()


def load_task_packet_validator(repo_root: Path) -> Any:
    path = repo_root / "shared/skills/delivery-owner/scripts/task_packet_check.py"
    spec = importlib.util.spec_from_file_location("task_packet_check", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"failed to load task packet validator: {path}")
    module = importlib.util.module_from_spec(spec)
    script_dir = str(path.parent)
    inserted_path = False
    if script_dir not in sys.path:
        sys.path.insert(0, script_dir)
        inserted_path = True
    try:
        spec.loader.exec_module(module)
    finally:
        if inserted_path:
            sys.path.remove(script_dir)
    return module


def packet_from_output(output_text: str) -> dict[str, Any]:
    block = yaml_block(output_text)
    return {
        "task_ref": scalar(block, "task_ref"),
        "role": scalar(block, "role"),
        "goal": section(block, "goal"),
        "allowed_scope_refs": scalar(block, "allowed_scope_refs"),
        "test_refs": scalar(block, "test_refs"),
        "depends_on": scalar(block, "depends_on"),
        "advisory_constraints": section(block, "advisory_constraints"),
        "forbidden_scope": section(block, "forbidden_scope"),
        "input_refs": section(block, "input_refs"),
        "expected_evidence": section(block, "expected_evidence"),
        "stop_condition": section(block, "stop_condition"),
        "forbidden_actions": section(block, "forbidden_actions"),
    }


def validate_packet(output_text: str) -> tuple[bool, dict[str, Any]]:
    repo_root = Path(__file__).resolve().parents[3]
    validator = load_task_packet_validator(repo_root)
    packet = packet_from_output(output_text)
    try:
        result = validator.validate(packet)
    except Exception as exc:  # noqa: BLE001 - preserve validator failure as grader evidence.
        return False, {"status": "BLOCKED", "reason": str(exc), "packet": packet}
    return result.get("status") == "PASS" and result.get("task_ref") == EXPECTED_TASK, result


def build_checks(input_text: str, output_text: str, evaluator_text: str) -> tuple[list[dict], dict[str, Any], list[str]]:
    packet_passed, packet_result = validate_packet(output_text)
    evaluator_assertions = [item for item in EXPECTED_ASSERTIONS if item in evaluator_text]
    checks = [
        {
            "id": "synthetic_boundary",
            "passed": has_all(input_text, [r"`input_origin`:\s*`synthetic`", r"`status`:\s*`frozen_for_eval_only`"])
            and has_all(output_text, [r"input_origin=`synthetic`|input_origin=synthetic", r"不是 `qft-pai` 真实交付证据"]),
        },
        {
            "id": "advisory_consumed",
            "passed": has_all(output_text, [EXPECTED_FINDING, r"consumed|已消费", r"TL002-T1.*串行 gate|serial gate"]),
        },
        {
            "id": "only_t1_released",
            "passed": has_all(output_text, [r"status: DISPATCH_READY", r"active_tasks: TL002-T1 only", r"task_ref: TL002-T1", r"role: developer"]),
        },
        {
            "id": "t2_t5_locked",
            "passed": has_all(output_text, [r"TL002-T2~T5", r"不得释放|remain unreleased|全部冻结", r"verifier PASS"]),
        },
        {
            "id": "verifier_gate",
            "passed": has_all(output_text, [r"developer.*先派 verifier|developer.*verifier", r"verify-result", r"next_gate: verifier"]),
        },
        {
            "id": "task_packet_complete",
            "passed": has_all(
                output_text,
                [
                    r"allowed_scope_refs",
                    r"test_refs",
                    r"depends_on",
                    r"advisory_constraints",
                    r"input_refs",
                    r"expected_evidence",
                    r"stop_condition",
                    r"forbidden_actions",
                ],
            ),
        },
        {
            "id": "no_real_state_or_commit",
            "passed": has_all(output_text, [r"不写真实 delivery-state/signoff/commit", r"不真实派发|no real dispatch", r"git commit|/commit"]),
        },
        {"id": "packet_validate", "passed": packet_passed},
        {
            "id": "evaluator_owner_action",
            "passed": has_all(evaluator_text, [r"judgment: warn", r"chain_status: continue", r"grade: P2", r"owner: script"]),
        },
    ]
    return checks, packet_result, evaluator_assertions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="DO-002 synthetic fixture path")
    parser.add_argument("--output", required=True, type=Path, help="DO-002 delivery-owner output path")
    parser.add_argument("--evaluator", required=True, type=Path, help="DO-002 evaluator output path")
    args = parser.parse_args()

    input_text = read_text(args.input)
    output_text = read_text(args.output)
    evaluator_text = read_text(args.evaluator)
    checks, packet_result, evaluator_assertions = build_checks(input_text, output_text, evaluator_text)
    failed = [check["id"] for check in checks if not check["passed"]]
    payload = {
        "case": "DO-002",
        "status": "fail" if failed else "pass",
        "failed_checks": failed,
        "task_ref": EXPECTED_TASK,
        "advisory_finding": EXPECTED_FINDING,
        "packet_validation": packet_result,
        "evaluator_objective_assertions": evaluator_assertions,
        "checks": checks,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
