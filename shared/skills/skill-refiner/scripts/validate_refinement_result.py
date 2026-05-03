#!/usr/bin/env python3
"""Validate skill-refiner-result.json as the completion evidence contract."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


RINGS = "Trigger Responsibility Input Flow Output Resource Determinism Eval Cleanup Runtime".split()
REQUIRED_TOP_LEVEL = (
    "artifact_type schema_version target quality_standard co_created_baseline professional_domain "
    "practice_flow optimization_goal ring_sequence ring_blueprints candidate_strategy_matrix "
    "problem_cards strategy_freeze output_contract execution acceptance_matrix verification_commands completion_assessment"
).split()
OPTIONAL_TOP_LEVEL = "self_dogfood flow_trace".split()
BASELINE_FIELDS = (
    "real_scenario business_constraint success_standard known_pain non_loss_capability "
    "entry_point located_carrier open_questions"
).split()
DIMENSION_RE = re.compile(r"^(G[0-2]|S[1-8]|E[1-5])$")
CANDIDATE_STRATEGIES = {"PASS", "PATCH", "REWRITE", "REPLACE", "MOVE", "DELETE", "SPLIT", "BLOCKED"}
ACCEPTANCE = {"PASS", "ISSUE_FIXED"}
OPERATIONS = {"optimize", "create", "rewrite", "replace", "split", "move", "delete"}
SCHEMA_REF = "shared/skills/skill-refiner/contracts/skill-refiner-result.schema.json"
VALIDATOR_REF = "shared/skills/skill-refiner/scripts/validate_refinement_result.py"
FLOW_STEPS = (
    "SR-S1 SR-S2 SR-S3 SR-S4 SR-R1 SR-R2 SR-R3 SR-R4 SR-R5 "
    "SR-R6 SR-R7 SR-R8 SR-R9 SR-R10 SR-F1 SR-E1 SR-V1"
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


def require_fields(errors: list[str], obj: Any, fields: list[str], path: str) -> None:
    if not isinstance(obj, dict):
        errors.append(f"{path} must be an object")
        return
    for field in fields:
        if field not in obj:
            errors.append(f"missing required field {path}.{field}")


def require_nonempty_strings(errors: list[str], obj: dict[str, Any], fields: list[str], path: str) -> None:
    for field in fields:
        if field in obj and not nonempty_string(obj[field]):
            errors.append(f"{path}.{field} must be a non-empty string")


def reject_extra_fields(errors: list[str], obj: Any, fields: list[str], path: str) -> None:
    if isinstance(obj, dict):
        extra = sorted(set(obj) - set(fields))
        if extra:
            errors.append(f"{path} has unconsumed fields: {', '.join(extra)}")


def require_exact_fields(errors: list[str], obj: Any, fields: list[str], path: str) -> None:
    require_fields(errors, obj, fields, path)
    reject_extra_fields(errors, obj, fields, path)

def validate_top_level_keys(errors: list[str], data: dict[str, Any]) -> None:
    allowed = set(REQUIRED_TOP_LEVEL) | set(OPTIONAL_TOP_LEVEL)
    extra = sorted(set(data) - allowed)
    if extra:
        errors.append(f"top-level fields are not consumed by the result contract: {', '.join(extra)}")


def validate_target(errors: list[str], data: dict[str, Any]) -> None:
    target = data.get("target")
    fields = ["skill_name", "path", "operation"]
    require_exact_fields(errors, target, fields, "target")
    if not isinstance(target, dict):
        return
    require_nonempty_strings(errors, target, ["skill_name", "path", "operation"], "target")
    if target.get("operation") not in OPERATIONS:
        errors.append("target.operation must be a supported refinement operation")


def validate_no_legacy_strategy_fields(errors: list[str], data: dict[str, Any]) -> None:
    if "strategy_matrix" in data:
        errors.append("strategy_matrix is deprecated; use candidate_strategy_matrix")
    entries = data.get("candidate_strategy_matrix")
    if isinstance(entries, list):
        for index, entry in enumerate(entries):
            if isinstance(entry, dict) and "strategy" in entry:
                errors.append(f"candidate_strategy_matrix[{index}].strategy is deprecated; use candidate_strategy")


def validate_quality(errors: list[str], data: dict[str, Any]) -> None:
    quality = data.get("quality_standard")
    fields = ["ref", "read", "decision_layer", "dimensions"]
    require_exact_fields(errors, quality, fields, "quality_standard")
    if not isinstance(quality, dict):
        return
    if quality.get("read") is not True:
        errors.append("quality_standard.read must be true")
    if quality.get("decision_layer") not in {"Portable core", "First-party hardening", "Production evidence"}:
        errors.append("quality_standard.decision_layer is unsupported")
    dimensions = quality.get("dimensions")
    if not string_list(dimensions):
        errors.append("quality_standard.dimensions must be a non-empty string array")
    elif any(not DIMENSION_RE.match(item) for item in dimensions):
        errors.append("quality_standard.dimensions must use G0-G2, S1-S8, or E1-E5")


def validate_baseline(errors: list[str], data: dict[str, Any]) -> None:
    baseline = data.get("co_created_baseline")
    require_exact_fields(errors, baseline, BASELINE_FIELDS, "co_created_baseline")
    if isinstance(baseline, dict):
        require_nonempty_strings(errors, baseline, BASELINE_FIELDS, "co_created_baseline")


def validate_domain_and_goal(errors: list[str], data: dict[str, Any]) -> None:
    domain = data.get("professional_domain")
    domain_fields = ["name", "responsibilities", "non_goals", "success_boundary"]
    require_exact_fields(errors, domain, domain_fields, "professional_domain")
    if isinstance(domain, dict):
        require_nonempty_strings(errors, domain, ["name", "success_boundary"], "professional_domain")
        for field in ("responsibilities", "non_goals"):
            if field in domain and not string_list(domain[field]):
                errors.append(f"professional_domain.{field} must be a non-empty string array")
    if not string_list(data.get("practice_flow")):
        errors.append("practice_flow must be a non-empty string array")
    goal = data.get("optimization_goal")
    goal_fields = ["objective", "success_standards", "exclusions"]
    require_exact_fields(errors, goal, goal_fields, "optimization_goal")
    if isinstance(goal, dict):
        require_nonempty_strings(errors, goal, ["objective"], "optimization_goal")
        for field in ("success_standards", "exclusions"):
            if field in goal and not string_list(goal[field]):
                errors.append(f"optimization_goal.{field} must be a non-empty string array")


def sequence(errors: list[str], data: dict[str, Any]) -> list[str]:
    rings = data.get("ring_sequence")
    if not string_list(rings) or len(rings) != len(RINGS):
        errors.append("ring_sequence must contain the 10 skill-refiner rings")
        return []
    if set(rings) != set(RINGS) or len(set(rings)) != len(RINGS):
        errors.append("ring_sequence must cover each ring exactly once")
        return []
    if rings != RINGS:
        errors.append("ring_sequence must follow Trigger -> Responsibility -> Input -> Flow -> Output -> Resource -> Determinism -> Eval -> Cleanup -> Runtime")
        return []
    return list(rings)


def validate_ring_entries(
    errors: list[str],
    data: dict[str, Any],
    field: str,
    rings: list[str],
    required: list[str],
    allowed_status: set[str] | None = None,
) -> None:
    entries = data.get(field)
    if not isinstance(entries, list) or len(entries) != len(RINGS):
        errors.append(f"{field} must contain 10 entries")
        return
    seen = [entry.get("ring") if isinstance(entry, dict) else None for entry in entries]
    if rings and seen != rings:
        errors.append(f"{field} ring order must match ring_sequence")
    for index, entry in enumerate(entries):
        path = f"{field}[{index}]"
        require_exact_fields(errors, entry, required, path)
        if not isinstance(entry, dict):
            continue
        require_nonempty_strings(errors, entry, [item for item in required if item != "change_scope"], path)
        if "change_scope" in required and not string_list(entry.get("change_scope")):
            errors.append(f"{path}.change_scope must be a non-empty string array")
        if allowed_status is not None and entry.get("status") not in allowed_status:
            errors.append(f"{path}.status must be one of {sorted(allowed_status)}")
        if "candidate_strategy" in required and entry.get("candidate_strategy") not in CANDIDATE_STRATEGIES:
            errors.append(f"{path}.candidate_strategy must be one of {sorted(CANDIDATE_STRATEGIES)}")


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
    executed = execution_paths(data)
    strategies = {
        item.get("ring"): item.get("candidate_strategy")
        for item in data.get("candidate_strategy_matrix", [])
        if isinstance(item, dict)
    }
    acceptance = {
        item.get("ring"): item.get("status")
        for item in data.get("acceptance_matrix", [])
        if isinstance(item, dict)
    }
    fields = [
        "ring",
        "next_cut_reason",
        "quality_dimension",
        "decision_layer",
        "phenomenon",
        "why_problem",
        "impact",
        "evidence_ref",
        "target_shape",
        "change_scope",
        "verification",
        "signal_source",
        "counter_evidence",
        "stop_condition",
    ]
    if not isinstance(cards, list) or not cards:
        errors.append("problem_cards must be a non-empty array")
        return
    for index, card in enumerate(cards):
        path = f"problem_cards[{index}]"
        require_exact_fields(errors, card, fields, path)
        if not isinstance(card, dict):
            continue
        require_nonempty_strings(errors, card, [field for field in fields if field != "change_scope"], path)
        ring = card.get("ring")
        if ring not in RINGS:
            errors.append(f"{path}.ring must be one of {RINGS}")
        elif strategies.get(ring) in {None, "PASS"}:
            errors.append(f"{path}.ring must reference a non-PASS candidate_strategy ring")
        elif acceptance.get(ring) not in {None, "ISSUE_FIXED"}:
            errors.append(f"{path}.ring must reference an ISSUE_FIXED acceptance_matrix ring")
        if not DIMENSION_RE.match(str(card.get("quality_dimension", ""))):
            errors.append(f"{path}.quality_dimension must use G0-G2, S1-S8, or E1-E5")
        if card.get("decision_layer") not in {"Portable core", "First-party hardening", "Production evidence"}:
            errors.append(f"{path}.decision_layer is unsupported")
        change_scope = card.get("change_scope")
        if not string_list(change_scope):
            errors.append(f"{path}.change_scope must be a non-empty string array")
        elif not set(change_scope) & executed:
            errors.append(f"{path}.change_scope must reference at least one executed file")


def validate_freeze(errors: list[str], data: dict[str, Any]) -> None:
    freeze = data.get("strategy_freeze")
    fields = [
        "all_rings_confirmed",
        "all_verifications_confirmed",
        "no_file_changes_before_freeze",
        "one_shot_execution_after_freeze",
        "final_operation",
        "frozen_by",
        "evidence",
    ]
    require_exact_fields(errors, freeze, fields, "strategy_freeze")
    if not isinstance(freeze, dict):
        return
    for field in fields[:4]:
        if freeze.get(field) is not True:
            errors.append(f"strategy_freeze.{field} must be true")
    require_nonempty_strings(errors, freeze, ["final_operation", "frozen_by", "evidence"], "strategy_freeze")
    if freeze.get("final_operation") not in OPERATIONS:
        errors.append("strategy_freeze.final_operation must be a supported refinement operation")
    target = data.get("target")
    if isinstance(target, dict) and freeze.get("final_operation") != target.get("operation"):
        errors.append("strategy_freeze.final_operation must match target.operation")


def validate_output_contract(errors: list[str], data: dict[str, Any]) -> None:
    contract = data.get("output_contract")
    fields = ["format", "schema_ref", "validator_command", "required_fields"]
    require_exact_fields(errors, contract, fields, "output_contract")
    if not isinstance(contract, dict):
        return
    if contract.get("format") != "json":
        errors.append("output_contract.format must be json")
    require_nonempty_strings(errors, contract, ["schema_ref", "validator_command"], "output_contract")
    if contract.get("schema_ref") != SCHEMA_REF:
        errors.append(f"output_contract.schema_ref must be {SCHEMA_REF}")
    validator_command = contract.get("validator_command")
    if isinstance(validator_command, str):
        if VALIDATOR_REF not in validator_command:
            errors.append(f"output_contract.validator_command must invoke {VALIDATOR_REF}")
        if "skill-refiner-result.json" not in validator_command:
            errors.append("output_contract.validator_command must target skill-refiner-result.json")
    required = contract.get("required_fields")
    if not string_list(required):
        errors.append("output_contract.required_fields must be a non-empty string array")
    else:
        missing = sorted(set(REQUIRED_TOP_LEVEL) - set(required))
        extra = sorted(set(required) - set(REQUIRED_TOP_LEVEL))
        if missing:
            errors.append(f"output_contract.required_fields missing: {', '.join(missing)}")
        if extra:
            errors.append(f"output_contract.required_fields has unconsumed fields: {', '.join(extra)}")
        if not missing and not extra and required != REQUIRED_TOP_LEVEL:
            errors.append("output_contract.required_fields must follow the canonical field order")


def validate_execution(errors: list[str], data: dict[str, Any]) -> None:
    execution = data.get("execution")
    fields = ["execution_mode", "started_after_strategy_freeze", "modified_files", "created_files", "deleted_files"]
    require_exact_fields(errors, execution, fields, "execution")
    if not isinstance(execution, dict):
        return
    if execution.get("execution_mode") != "single_pass_after_freeze":
        errors.append("execution.execution_mode must be single_pass_after_freeze")
    if execution.get("started_after_strategy_freeze") is not True:
        errors.append("execution.started_after_strategy_freeze must be true")
    for field in ("modified_files", "created_files", "deleted_files"):
        value = execution.get(field)
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            errors.append(f"execution.{field} must be a string array")


def validate_verification(errors: list[str], data: dict[str, Any]) -> None:
    commands = data.get("verification_commands")
    if not isinstance(commands, list) or not commands:
        errors.append("verification_commands must be a non-empty array")
        return
    pass_count = 0
    for index, item in enumerate(commands):
        path = f"verification_commands[{index}]"
        fields = ["command", "status", "evidence"]
        require_exact_fields(errors, item, fields, path)
        if not isinstance(item, dict):
            continue
        require_nonempty_strings(errors, item, ["command", "status", "evidence"], path)
        if item.get("status") == "pass":
            pass_count += 1
        elif item.get("status") in {"fail", "block"}:
            errors.append(f"{path}.status must not be fail/block for completed result")
        else:
            errors.append(f"{path}.status must be pass")
    if pass_count == 0:
        errors.append("verification_commands requires at least one pass command")


def validate_completion(errors: list[str], data: dict[str, Any]) -> None:
    assessment = data.get("completion_assessment")
    fields = ["overall_status", "llm_checks", "residual_risks"]
    require_exact_fields(errors, assessment, fields, "completion_assessment")
    if not isinstance(assessment, dict):
        return
    if assessment.get("overall_status") != "pass":
        errors.append("completion_assessment.overall_status must be pass")
    if not string_list(assessment.get("llm_checks")):
        errors.append("completion_assessment.llm_checks must be a non-empty string array")
    if not isinstance(assessment.get("residual_risks"), list):
        errors.append("completion_assessment.residual_risks must be an array")


def validate_optional_dogfood(errors: list[str], data: dict[str, Any]) -> None:
    dogfood = data.get("self_dogfood")
    if dogfood is not None:
        fields = ["requirement", "input_ref", "output_ref", "trace_ref"]
        require_exact_fields(errors, dogfood, fields, "self_dogfood")
        if isinstance(dogfood, dict):
            require_nonempty_strings(
                errors,
                dogfood,
                ["requirement", "input_ref", "output_ref", "trace_ref"],
                "self_dogfood",
            )
    flow_trace = data.get("flow_trace")
    if flow_trace is not None:
        if not isinstance(flow_trace, list) or len(flow_trace) != len(FLOW_STEPS):
            errors.append("flow_trace must contain the complete SR-S1 -> SR-V1 step trace")
            return
        seen = []
        for index, item in enumerate(flow_trace):
            path = f"flow_trace[{index}]"
            fields = ["step", "status", "evidence"]
            require_exact_fields(errors, item, fields, path)
            if not isinstance(item, dict):
                continue
            require_nonempty_strings(errors, item, ["step", "status", "evidence"], path)
            seen.append(item.get("step"))
        if seen != FLOW_STEPS:
            errors.append("flow_trace step order must follow SR-S1 -> SR-S4, SR-R1 -> SR-R10, SR-F1, SR-E1, SR-V1")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["root must be an object"]
    require_fields(errors, data, REQUIRED_TOP_LEVEL, "$")
    validate_top_level_keys(errors, data)
    if data.get("artifact_type") != "skill-refiner-result":
        errors.append("artifact_type must be skill-refiner-result")
    if not nonempty_string(data.get("schema_version")):
        errors.append("schema_version must be a non-empty string")
    validate_target(errors, data)
    validate_no_legacy_strategy_fields(errors, data)
    validate_quality(errors, data)
    validate_baseline(errors, data)
    validate_domain_and_goal(errors, data)
    rings = sequence(errors, data)
    validate_ring_entries(
        errors,
        data,
        "ring_blueprints",
        rings,
        ["ring", "best_practice_target", "preservation", "evidence", "user_confirmation", "verification"],
    )
    validate_ring_entries(
        errors,
        data,
        "candidate_strategy_matrix",
        rings,
        ["ring", "candidate_strategy", "change_scope", "verification", "risk"],
    )
    validate_problem_cards(errors, data)
    validate_freeze(errors, data)
    validate_output_contract(errors, data)
    validate_execution(errors, data)
    validate_ring_entries(
        errors,
        data,
        "acceptance_matrix",
        rings,
        ["ring", "status", "evidence", "owner_verdict"],
        ACCEPTANCE,
    )
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
