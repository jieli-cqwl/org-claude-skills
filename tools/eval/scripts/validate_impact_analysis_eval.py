#!/usr/bin/env python3
"""Validate the impact-analysis behavior eval case pack."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REQUIRED_TOP_LEVEL = {
    "protocol_version",
    "reference",
    "goal",
    "run_model",
    "output_schema",
    "rubric",
    "pass_threshold",
    "pilot_rollout",
    "cases",
}
EXPECTED_OUTPUT_SCHEMA = [
    "case_id",
    "direct_change_points",
    "functional_impact_items",
    "technical_touchpoints",
    "regression_verification",
    "coverage_gaps",
    "decision_risks",
    "completion_gate",
]
EXPECTED_CASE_IDS = [f"IA-{index:03d}" for index in range(1, 9)]
EXPECTED_RUBRICS = [f"R{index}" for index in range(1, 9)]
REQUIRED_RUN_MODEL = {
    "freeze_first": [
        "reference_version",
        "case_inputs",
        "output_schema",
        "rubric",
        "pass_threshold",
    ],
    "parallel_safe": ["case_execution", "independent_grading"],
    "serial_required": [
        "protocol_freeze",
        "final_synthesis",
        "reference_change_decision",
    ],
}
REQUIRED_PILOT_RECORD_FIELDS = [
    "task_ref",
    "change_summary",
    "functional_impact_items",
    "technical_touchpoints",
    "regression_verification",
    "coverage_gaps",
    "decision_risks",
    "completion_gate_result",
    "review_findings",
]
REQUIRED_CASE_FOCUS = {
    "IA-001": {"用户可见行为", "回归验证"},
    "IA-002": {"内部实现影响", "行为不变证据"},
    "IA-003": {"runtime 行为约束", "完成声明风险"},
    "IA-004": {"无额外影响依据", "覆盖盲区检查"},
    "IA-005": {"LSP 不可见路径", "动态调用", "待裁决风险"},
    "IA-006": {"schema/script/test 同步", "功能影响项承载"},
    "IA-007": {"门禁覆盖变化", "测试可信度"},
    "IA-008": {"shared_files 不充分", "统一合并验证"},
}


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise SystemExit(f"cannot read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"{path}: root must be an object")
    return payload


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def validate_top_level(payload: dict[str, Any], errors: list[str]) -> None:
    missing = sorted(REQUIRED_TOP_LEVEL - payload.keys())
    require(not missing, f"missing top-level fields: {missing}", errors)
    require(payload.get("protocol_version") == 1, "protocol_version must be 1", errors)
    require(
        payload.get("reference") == "shared/reference/影响范围分析.md",
        "reference must point to shared/reference/影响范围分析.md",
        errors,
    )
    require(
        payload.get("output_schema") == EXPECTED_OUTPUT_SCHEMA,
        "output_schema drifted",
        errors,
    )


def validate_run_model(payload: dict[str, Any], errors: list[str]) -> None:
    run_model = payload.get("run_model")
    if not isinstance(run_model, dict):
        errors.append("run_model must be an object")
        return
    for key, expected_values in REQUIRED_RUN_MODEL.items():
        values = run_model.get(key)
        require(isinstance(values, list), f"run_model.{key} must be a list", errors)
        if isinstance(values, list):
            missing = sorted(set(expected_values) - set(values))
            require(not missing, f"run_model.{key} missing {missing}", errors)


def validate_rubric(payload: dict[str, Any], errors: list[str]) -> None:
    rubric = payload.get("rubric")
    if not isinstance(rubric, list):
        errors.append("rubric must be a list")
        return
    ids = [item.get("id") for item in rubric if isinstance(item, dict)]
    require(ids == EXPECTED_RUBRICS, f"rubric ids must be {EXPECTED_RUBRICS}", errors)
    for item in rubric:
        if not isinstance(item, dict):
            errors.append("rubric items must be objects")
            continue
        require(
            isinstance(item.get("label"), str) and item["label"],
            f"rubric {item.get('id')} missing label",
            errors,
        )
        requires = item.get("requires")
        require(
            isinstance(requires, list)
            and all(isinstance(value, str) and value for value in requires),
            f"rubric {item.get('id')} requires must be non-empty strings",
            errors,
        )


def validate_pilot_rollout(payload: dict[str, Any], errors: list[str]) -> None:
    pilot = payload.get("pilot_rollout")
    if not isinstance(pilot, dict):
        errors.append("pilot_rollout must be an object")
        return
    require(
        pilot.get("status") == "team_pilot_ready",
        "pilot_rollout.status must be team_pilot_ready",
        errors,
    )
    require(
        pilot.get("sample_size") == "3-5 real tasks before hard-gate adoption",
        "pilot_rollout.sample_size must require 3-5 real tasks",
        errors,
    )
    require(
        pilot.get("required_record_fields") == REQUIRED_PILOT_RECORD_FIELDS,
        "pilot_rollout.required_record_fields drifted",
        errors,
    )
    gate = pilot.get("upgrade_gate")
    if not isinstance(gate, dict):
        errors.append("pilot_rollout.upgrade_gate must be an object")
        return
    require(
        gate.get("allowed_after") == "real_task_sample_review",
        "upgrade gate must require real sample review",
        errors,
    )
    require(gate.get("max_p0") == 0, "upgrade gate max_p0 must be 0", errors)
    require(
        gate.get("max_unresolved_p1") == 0,
        "upgrade gate max_unresolved_p1 must be 0",
        errors,
    )
    require(
        gate.get("required_decision") == "human_owner_accepts_hard_gate",
        "upgrade gate must require human owner hard-gate decision",
        errors,
    )
    handling = pilot.get("failure_handling")
    require(
        isinstance(handling, list)
        and len(handling) >= 3
        and all(isinstance(value, str) and value for value in handling),
        "pilot_rollout.failure_handling must contain at least three strings",
        errors,
    )


def validate_cases(payload: dict[str, Any], errors: list[str]) -> None:
    cases = payload.get("cases")
    if not isinstance(cases, list):
        errors.append("cases must be a list")
        return
    ids = [case.get("id") for case in cases if isinstance(case, dict)]
    require(ids == EXPECTED_CASE_IDS, f"case ids must be {EXPECTED_CASE_IDS}", errors)
    for case in cases:
        if not isinstance(case, dict):
            errors.append("case items must be objects")
            continue
        case_id = case.get("id")
        require(
            isinstance(case.get("name"), str) and case["name"],
            f"{case_id}: name required",
            errors,
        )
        require(
            isinstance(case.get("change_prompt"), str)
            and case["change_prompt"].strip(),
            f"{case_id}: change_prompt required",
            errors,
        )
        focus = case.get("expected_focus")
        require(
            isinstance(focus, list)
            and len(focus) >= 4
            and all(isinstance(value, str) and value for value in focus),
            f"{case_id}: expected_focus must contain at least four strings",
            errors,
        )
        if isinstance(focus, list) and isinstance(case_id, str):
            missing = sorted(REQUIRED_CASE_FOCUS.get(case_id, set()) - set(focus))
            require(not missing, f"{case_id}: missing focus {missing}", errors)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case_pack", type=Path)
    args = parser.parse_args()

    payload = load_json(args.case_pack)
    errors: list[str] = []
    validate_top_level(payload, errors)
    validate_run_model(payload, errors)
    validate_rubric(payload, errors)
    validate_pilot_rollout(payload, errors)
    validate_cases(payload, errors)
    if errors:
        print(
            json.dumps(
                {"status": "fail", "errors": errors}, ensure_ascii=False, indent=2
            )
        )
        return 1
    print(
        json.dumps(
            {
                "status": "pass",
                "case_count": len(payload["cases"]),
                "rubric_count": len(payload["rubric"]),
                "pilot_status": payload["pilot_rollout"]["status"],
                "pilot_sample_size": payload["pilot_rollout"]["sample_size"],
                "parallel_safe": payload["run_model"]["parallel_safe"],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
