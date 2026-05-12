#!/usr/bin/env python3
"""Validate skill-refiner-result.json against the v3 capability-based schema."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from collections.abc import Sequence
from typing import Any


DIMENSIONS = (
    "Trigger Responsibility Input Flow Output Resource Determinism Eval Runtime".split()
)
EXPECTED_FLOW_STEPS = (
    "承载定位",
    "场景理解",
    "职责定义",
    "消费者盘点",
    "结构诊断",
    "策略制定",
    "执行落地",
    "验收交付",
)
PRIORITIES = {"foundation", "boundary", "craft", "assurance"}
DIAGNOSIS_STATUSES = {"PASS", "ISSUE", "BLOCKED"}
OPERATIONS = {"optimize", "create", "rewrite", "replace", "split", "move", "delete"}
REQUIRED_TOP_LEVEL = (
    "artifact_type schema_version target quality_standard scene_facts professional_domain "
    "practice_flow optimization_goal flow_trace diagnosis problem_cards strategy execution "
    "verification_commands completion_assessment"
).split()
OPTIONAL_TOP_LEVEL = ["self_dogfood", "eval_id", "run_mode"]
EXPECTED_SCHEMA_VERSION = "3.0.0"
SCENE_FIELDS = (
    "real_scenario business_constraint expected_outcome observed_pain "
    "protected_capability entry_point open_questions"
).split()


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON at line {exc.lineno}: {exc.msg}") from exc


def nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def string_list(value: Any) -> bool:
    return isinstance(value, list) and all(nonempty_string(item) for item in value)


def require_fields(
    errors: list[str], obj: Any, fields: Sequence[str], path: str
) -> None:
    if not isinstance(obj, dict):
        errors.append(f"{path} must be an object")
        return
    for field in fields:
        if field not in obj:
            errors.append(f"missing required field {path}.{field}")


def require_nonempty(
    errors: list[str], obj: dict[str, Any], fields: Sequence[str], path: str
) -> None:
    for field in fields:
        if field in obj and not nonempty_string(obj[field]):
            errors.append(f"{path}.{field} must be a non-empty string")


def reject_extra(
    errors: list[str], obj: Any, allowed: Sequence[str], path: str
) -> None:
    if isinstance(obj, dict):
        extra = sorted(set(obj) - set(allowed))
        if extra:
            errors.append(f"{path} has unconsumed fields: {', '.join(extra)}")


def validate_target(errors: list[str], data: dict[str, Any]) -> None:
    target = data.get("target")
    fields = ["skill_name", "path", "operation"]
    require_fields(errors, target, fields, "target")
    reject_extra(errors, target, fields, "target")
    if not isinstance(target, dict):
        return
    require_nonempty(errors, target, fields, "target")
    if target.get("operation") not in OPERATIONS:
        errors.append("target.operation must be a supported operation")


def validate_quality(errors: list[str], data: dict[str, Any]) -> None:
    quality = data.get("quality_standard")
    fields = ["ref", "read", "dimensions"]
    require_fields(errors, quality, fields, "quality_standard")
    reject_extra(errors, quality, fields, "quality_standard")
    if not isinstance(quality, dict):
        return
    if quality.get("read") is not True:
        errors.append("quality_standard.read must be true")
    dimensions = quality.get("dimensions")
    if not isinstance(dimensions, list) or not dimensions:
        errors.append("quality_standard.dimensions must be a non-empty array")
    elif any(item not in DIMENSIONS for item in dimensions):
        errors.append(f"quality_standard.dimensions must use: {', '.join(DIMENSIONS)}")


def validate_scene_facts(errors: list[str], data: dict[str, Any]) -> None:
    facts = data.get("scene_facts")
    require_fields(errors, facts, SCENE_FIELDS, "scene_facts")
    reject_extra(errors, facts, SCENE_FIELDS, "scene_facts")
    if isinstance(facts, dict):
        require_nonempty(errors, facts, SCENE_FIELDS, "scene_facts")


def validate_domain_and_goal(errors: list[str], data: dict[str, Any]) -> None:
    domain = data.get("professional_domain")
    domain_fields = ["name", "responsibilities", "non_goals", "success_boundary"]
    require_fields(errors, domain, domain_fields, "professional_domain")
    reject_extra(errors, domain, domain_fields, "professional_domain")
    if isinstance(domain, dict):
        require_nonempty(
            errors, domain, ["name", "success_boundary"], "professional_domain"
        )
        for field in ("responsibilities", "non_goals"):
            if field in domain and not string_list(domain[field]):
                errors.append(
                    f"professional_domain.{field} must be a non-empty string array"
                )
    if not string_list(data.get("practice_flow")):
        errors.append("practice_flow must be a non-empty string array")
    goal = data.get("optimization_goal")
    goal_fields = ["objective", "success_standards", "exclusions"]
    require_fields(errors, goal, goal_fields, "optimization_goal")
    reject_extra(errors, goal, goal_fields, "optimization_goal")
    if isinstance(goal, dict):
        require_nonempty(errors, goal, ["objective"], "optimization_goal")
        for field in ("success_standards", "exclusions"):
            if field in goal and not string_list(goal[field]):
                errors.append(
                    f"optimization_goal.{field} must be a non-empty string array"
                )


def validate_flow_trace(errors: list[str], data: dict[str, Any]) -> None:
    trace = data.get("flow_trace")
    if not isinstance(trace, list):
        errors.append("flow_trace must be an array")
        return
    actual_steps: list[Any] = []
    allowed_fields = ["step", "status", "evidence", "status_card"]
    for index, entry in enumerate(trace):
        path = f"flow_trace[{index}]"
        require_fields(errors, entry, allowed_fields, path)
        reject_extra(errors, entry, allowed_fields, path)
        if not isinstance(entry, dict):
            continue
        step = entry.get("step")
        actual_steps.append(step)
        if step not in EXPECTED_FLOW_STEPS:
            errors.append(f"{path}.step must be one of {EXPECTED_FLOW_STEPS}")
        require_nonempty(errors, entry, ["step", "status", "evidence", "status_card"], path)
        status = entry.get("status")
        if isinstance(status, str) and status.strip().lower() in {"skip", "skipped"}:
            errors.append(f"{path}.status must not be skipped")
        status_card = entry.get("status_card")
        if isinstance(step, str) and isinstance(status_card, str):
            required_fragments = [f"当前阶段 {step}", "已闭合事实：", "放行条件：", "下一步："]
            for fragment in required_fragments:
                if fragment not in status_card:
                    errors.append(f"{path}.status_card missing fragment: {fragment}")
    if actual_steps != list(EXPECTED_FLOW_STEPS):
        errors.append(
            "flow_trace must follow the 8-stage order exactly: "
            + " -> ".join(EXPECTED_FLOW_STEPS)
        )


def validate_diagnosis(errors: list[str], data: dict[str, Any]) -> None:
    entries = data.get("diagnosis")
    if not isinstance(entries, list) or not entries:
        errors.append("diagnosis must be a non-empty array")
        return
    seen_dimensions: set[str] = set()
    for index, entry in enumerate(entries):
        path = f"diagnosis[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{path} must be an object")
            continue
        dimension = entry.get("dimension")
        if dimension not in DIMENSIONS:
            errors.append(f"{path}.dimension must be one of {DIMENSIONS}")
        elif dimension in seen_dimensions:
            errors.append(f"{path}.dimension '{dimension}' is duplicated")
        else:
            seen_dimensions.add(dimension)
        if entry.get("priority") not in PRIORITIES:
            errors.append(f"{path}.priority must be one of {sorted(PRIORITIES)}")
        status = entry.get("status")
        if status not in DIAGNOSIS_STATUSES:
            errors.append(f"{path}.status must be one of {sorted(DIAGNOSIS_STATUSES)}")
        if status in ("ISSUE", "BLOCKED"):
            detail_fields = [
                "evidence",
                "target_shape",
                "candidate_strategy",
                "verification",
            ]
            for field in detail_fields:
                if not nonempty_string(entry.get(field)):
                    errors.append(f"{path}.{field} is required when status is {status}")
    all_dims: set[str] = set(DIMENSIONS)
    missing = all_dims - seen_dimensions
    if missing:
        errors.append(
            f"diagnosis must cover all 9 dimensions; missing: {', '.join(sorted(missing))}"
        )


def execution_paths(data: dict[str, Any]) -> set[str]:
    execution = data.get("execution")
    if not isinstance(execution, dict):
        return set()
    paths: set[str] = set()
    for field in ("modified_files", "created_files", "deleted_files"):
        value = execution.get(field)
        if isinstance(value, list):
            paths.update(item for item in value if isinstance(item, str) and item)
    return paths


def validate_problem_cards(errors: list[str], data: dict[str, Any]) -> None:
    cards = data.get("problem_cards")
    if not isinstance(cards, list) or not cards:
        errors.append("problem_cards must be a non-empty array")
        return
    fields = [
        "dimension",
        "phenomenon",
        "why_problem",
        "target_shape",
        "change_scope",
        "verification",
        "stop_condition",
    ]
    for index, card in enumerate(cards):
        path = f"problem_cards[{index}]"
        require_fields(errors, card, fields, path)
        reject_extra(errors, card, fields, path)
        if not isinstance(card, dict):
            continue
        require_nonempty(errors, card, [f for f in fields if f != "change_scope"], path)
        if card.get("dimension") not in DIMENSIONS:
            errors.append(f"{path}.dimension must be one of {DIMENSIONS}")
        scope = card.get("change_scope")
        if not string_list(scope):
            errors.append(f"{path}.change_scope must be a non-empty string array")


def validate_strategy(errors: list[str], data: dict[str, Any]) -> None:
    strategy = data.get("strategy")
    fields = [
        "final_operation",
        "scope",
        "exclusions",
        "risk",
        "no_file_changes_before_confirmation",
        "confirmed_by",
        "evidence",
    ]
    require_fields(errors, strategy, fields, "strategy")
    reject_extra(errors, strategy, fields, "strategy")
    if not isinstance(strategy, dict):
        return
    require_nonempty(
        errors,
        strategy,
        ["final_operation", "risk", "confirmed_by", "evidence"],
        "strategy",
    )
    if strategy.get("final_operation") not in OPERATIONS:
        errors.append("strategy.final_operation must be a supported operation")
    target = data.get("target")
    if isinstance(target, dict) and strategy.get("final_operation") != target.get(
        "operation"
    ):
        errors.append("strategy.final_operation must match target.operation")
    if strategy.get("no_file_changes_before_confirmation") is not True:
        errors.append("strategy.no_file_changes_before_confirmation must be true")
    for field in ("scope", "exclusions"):
        if field in strategy and not string_list(strategy[field]):
            errors.append(f"strategy.{field} must be a non-empty string array")


def validate_execution(errors: list[str], data: dict[str, Any]) -> None:
    execution = data.get("execution")
    fields = [
        "started_after_strategy_confirmed",
        "modified_files",
        "created_files",
        "deleted_files",
    ]
    require_fields(errors, execution, fields, "execution")
    reject_extra(errors, execution, fields, "execution")
    if not isinstance(execution, dict):
        return
    if execution.get("started_after_strategy_confirmed") is not True:
        errors.append("execution.started_after_strategy_confirmed must be true")
    for field in ("modified_files", "created_files", "deleted_files"):
        value = execution.get(field)
        if not isinstance(value, list) or any(
            not isinstance(item, str) for item in value
        ):
            errors.append(f"execution.{field} must be a string array")


def skill_has_runtime_artifacts(target_path_str: str) -> tuple[bool, list[str]]:
    """Return (needs_empirical, reasons)."""
    reasons: list[str] = []
    if not target_path_str:
        return False, reasons
    target_path = Path(target_path_str)
    if not target_path.is_absolute():
        # try resolving relative to repo root (parent of skill-refiner/)
        repo_root = Path(__file__).resolve().parents[4]
        target_path = (repo_root / target_path_str).resolve()
    if not target_path.exists():
        return False, reasons
    skill_md = target_path / "SKILL.md" if target_path.is_dir() else target_path
    skill_dir = target_path if target_path.is_dir() else target_path.parent
    scripts_dir = skill_dir / "scripts"
    if scripts_dir.is_dir() and any(scripts_dir.iterdir()):
        reasons.append(f"{scripts_dir} non-empty")
    if skill_md.is_file():
        try:
            content = skill_md.read_text(encoding="utf-8", errors="ignore")
            # inline bash in Claude skills is denoted by a leading `!` before
            # the backticked command; require at least one non-trivial one.
            import re

            for match in re.finditer(r"!`([^`]+)`", content):
                cmd = match.group(1).strip()
                if cmd and not re.fullmatch(r"(echo|ls|pwd|cat|head|tail)\b.*", cmd):
                    reasons.append("SKILL.md contains non-trivial inline bash")
                    break
        except OSError:
            pass
    return bool(reasons), reasons


def validate_verification(errors: list[str], data: dict[str, Any]) -> None:
    commands = data.get("verification_commands")
    if not isinstance(commands, list) or not commands:
        errors.append("verification_commands must be a non-empty array")
        return
    required_fields = ["command", "status", "evidence"]
    allowed_fields = required_fields + ["layer"]
    empirical_count = 0
    for index, item in enumerate(commands):
        path = f"verification_commands[{index}]"
        require_fields(errors, item, required_fields, path)
        reject_extra(errors, item, allowed_fields, path)
        if not isinstance(item, dict):
            continue
        require_nonempty(errors, item, required_fields, path)
        if item.get("status") != "pass":
            errors.append(f"{path}.status must be pass")
        layer = item.get("layer")
        if layer is not None and layer not in {"structural", "empirical"}:
            errors.append(f"{path}.layer must be 'structural' or 'empirical'")
        if layer == "empirical":
            empirical_count += 1

    # Business gate: if target skill ships scripts or non-trivial inline bash,
    # at least one empirical verification command is required.
    target = data.get("target") or {}
    target_path = target.get("path", "") if isinstance(target, dict) else ""
    needs_empirical, reasons = skill_has_runtime_artifacts(target_path)
    if needs_empirical and empirical_count == 0:
        reason_str = "; ".join(reasons)
        errors.append(
            "verification_commands must include at least one layer='empirical' "
            f"entry because target has runtime artifacts ({reason_str})"
        )


def validate_completion(errors: list[str], data: dict[str, Any]) -> None:
    assessment = data.get("completion_assessment")
    fields = ["overall_status", "checks", "residual_risks"]
    require_fields(errors, assessment, fields, "completion_assessment")
    reject_extra(errors, assessment, fields, "completion_assessment")
    if not isinstance(assessment, dict):
        return
    if assessment.get("overall_status") != "pass":
        errors.append("completion_assessment.overall_status must be pass")
    if not string_list(assessment.get("checks")):
        errors.append("completion_assessment.checks must be a non-empty string array")
    if not isinstance(assessment.get("residual_risks"), list):
        errors.append("completion_assessment.residual_risks must be an array")


def validate_optional_dogfood(errors: list[str], data: dict[str, Any]) -> None:
    dogfood = data.get("self_dogfood")
    if dogfood is None:
        return
    fields = ["requirement", "input_ref", "output_ref", "trace_ref"]
    require_fields(errors, dogfood, fields, "self_dogfood")
    reject_extra(errors, dogfood, fields, "self_dogfood")
    if isinstance(dogfood, dict):
        require_nonempty(errors, dogfood, fields, "self_dogfood")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["root must be an object"]
    require_fields(errors, data, REQUIRED_TOP_LEVEL, "$")
    allowed = set(REQUIRED_TOP_LEVEL) | set(OPTIONAL_TOP_LEVEL)
    extra = sorted(set(data) - allowed)
    if extra:
        errors.append(f"top-level has unconsumed fields: {', '.join(extra)}")
    if data.get("artifact_type") != "skill-refiner-result":
        errors.append("artifact_type must be skill-refiner-result")
    if data.get("schema_version") != EXPECTED_SCHEMA_VERSION:
        errors.append(f"schema_version must be {EXPECTED_SCHEMA_VERSION}")
    if "eval_id" in data and not nonempty_string(data["eval_id"]):
        errors.append("eval_id must be a non-empty string when present")
    if "run_mode" in data and data["run_mode"] not in {"with_skill", "without_skill"}:
        errors.append("run_mode must be 'with_skill' or 'without_skill' when present")
    validate_target(errors, data)
    validate_quality(errors, data)
    validate_scene_facts(errors, data)
    validate_domain_and_goal(errors, data)
    validate_flow_trace(errors, data)
    validate_diagnosis(errors, data)
    validate_problem_cards(errors, data)
    validate_strategy(errors, data)
    validate_execution(errors, data)
    validate_verification(errors, data)
    validate_completion(errors, data)
    validate_optional_dogfood(errors, data)
    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in {"--help", "-h"}:
        print("usage: validate_refinement_result.py <skill-refiner-result.json>")
        return 0 if len(argv) == 2 else 2
    path = Path(argv[1])
    try:
        data = load_json(path)
    except ValueError as error:
        print(f"[FAIL] {error}", file=sys.stderr)
        return 1
    errors = validate(data)
    if errors:
        for error in errors:
            print(f"[FAIL] {error}", file=sys.stderr)
        return 1
    print(f"[PASS] skill-refiner result valid: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
