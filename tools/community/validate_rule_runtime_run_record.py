#!/usr/bin/env python3
"""Validate one rule-runtime team-readiness run record against the pack contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

FORBIDDEN_AGGREGATE_ANCHORS = {
    "#codex-pressure-runs",
    "#claude-pressure-runs",
    "#decision",
    "#promotion-decision",
}
PLACEHOLDER_OPERATIONAL_VALUES = {
    "not required for pass",
    "not promotion-impacting",
}
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
HTML_ANCHOR_RE = re.compile(r"<a\s+[^>]*\bid=[\"']([^\"']+)[\"'][^>]*>", re.IGNORECASE)
FENCED_BLOCK_RE = re.compile(r"```[^\n]*\n(.*?)```", re.DOTALL)
FAILURE_EVIDENCE_FIELD_RE = re.compile(
    r"^\s*-?\s*(failure_evidence|sanitized_output_excerpt):\s*(.+?)\s*$",
    re.MULTILINE,
)
REQUIRED_COMMAND_OUTPUT_MARKERS = {
    "bash install.sh --target codex --dry-run": [
        "[dry-run] codex",
        "安装流程完成",
    ],
    "bash install.sh --target codex --force --check quick": [
        "[install]",
        "target=codex",
        "Quick Check 通过",
        "安装流程完成",
    ],
    "bash tests/run-all.sh --quick": [
        "[28/28]",
        "All tests passed",
    ],
    "bash tests/run-all.sh": [
        "[167/167]",
        "All tests passed",
    ],
    "bash tests/test-rule-runtime-team-readiness-pack.sh": [
        "[PASS] rule runtime team readiness pack",
    ],
}
FORBIDDEN_COMMAND_OUTPUT_MARKERS = {
    "bash install.sh --target codex --force --check quick": [
        "[dry-run]",
        "dry-run 模式",
        "跳过安装后检查",
    ],
}
COMMAND_FAILURE_MARKER_RE = re.compile(
    r"(\[FAIL\]|\bFAIL(?:ED)?\b|\bERROR\b|Error|Traceback|exit code|non-zero|"
    r"PROMOTION_BLOCKED|BLOCKED|失败|错误)",
    re.IGNORECASE,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--record", type=Path, required=True)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON: {path}") from exc
    if not isinstance(payload, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return payload


def require_non_empty_string(record: dict[str, Any], field: str) -> None:
    value = record.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"run record field must be a non-empty string: {field}")


def require_integer(record: dict[str, Any], field: str) -> None:
    value = record.get(field)
    if not isinstance(value, int) or value < 1:
        raise ValueError(f"run record field must be a positive integer: {field}")


def require_string_array(record: dict[str, Any], field: str) -> None:
    value = record.get(field)
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"run record field must be a string array: {field}")


def require_string_array_contract(contract: dict[str, Any], field: str) -> list[str]:
    value = contract.get(field)
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"run_record_contract {field} must be a string array")
    return value


def assert_known_case_id(pack: dict[str, Any], record: dict[str, Any]) -> None:
    cases = pack.get("pressure_cases")
    if not isinstance(cases, list):
        raise ValueError("acceptance pack pressure_cases must be an array")
    case_ids = {case.get("id") for case in cases if isinstance(case, dict)}
    if record.get("case_id") not in case_ids:
        raise ValueError(
            f"case_id must match acceptance pack pressure_cases: {record.get('case_id')!r}"
        )


def assert_single_runtime(record: dict[str, Any]) -> None:
    runtime_target = str(record.get("runtime_target", "")).lower()
    if re.search(r"\b(and|or)\b|[,/&+]", runtime_target):
        raise ValueError("runtime_target must describe one runtime target")
    if "codex" in runtime_target and "claude" in runtime_target:
        raise ValueError("runtime_target must not aggregate Codex and Claude")
    if re.search(r"\ball[- ]runtime\b|\bbroad\b.*\brollout\b", runtime_target):
        raise ValueError("runtime_target must not describe aggregate rollout scope")


def command_failure_evidence_text(output_section: str) -> str:
    fenced_blocks = FENCED_BLOCK_RE.findall(output_section)
    field_values = [
        match.group(2)
        for match in FAILURE_EVIDENCE_FIELD_RE.finditer(output_section)
    ]
    return "\n".join([*fenced_blocks, *field_values])


def assert_single_observed_run(record: dict[str, Any]) -> None:
    combined = "\n".join(
        [
            str(record.get("run_id", "")),
            str(record.get("run_output_ref", "")),
            str(record.get("agent_output_ref", "")),
            *[str(item) for item in record.get("observed_pass_signals", [])],
            *[str(item) for item in record.get("observed_fail_signals", [])],
        ]
    ).lower()
    has_run_1 = re.search(r"\brun[- ]?1\b", combined) is not None
    has_run_2 = re.search(r"\brun[- ]?2\b", combined) is not None
    if has_run_1 and has_run_2:
        raise ValueError("run record must describe one observed run")


def markdown_heading_slug(text: str) -> str:
    text = re.sub(r"`([^`]+)`", r"\1", text.strip().lower())
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_-]+", "-", text).strip("-")
    return text


def markdown_anchor_sections(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    sections: dict[str, str] = {}
    for index, line in enumerate(lines):
        heading = HEADING_RE.match(line)
        if heading:
            anchor = markdown_heading_slug(heading.group(2))
            level = len(heading.group(1))
            end = len(lines)
            for next_index in range(index + 1, len(lines)):
                next_heading = HEADING_RE.match(lines[next_index])
                if next_heading and len(next_heading.group(1)) <= level:
                    end = next_index
                    break
            sections[anchor] = digestable_markdown_section(lines[index + 1 : end])
        for html_anchor in HTML_ANCHOR_RE.findall(line):
            end = len(lines)
            for next_index in range(index + 1, len(lines)):
                if HEADING_RE.match(lines[next_index]) or HTML_ANCHOR_RE.search(lines[next_index]):
                    end = next_index
                    break
            sections[html_anchor] = digestable_markdown_section(lines[index + 1 : end])
    return sections


def digestable_markdown_section(lines: list[str]) -> str:
    body = [
        line
        for line in lines
        if not line.strip().startswith("- output_digest:")
    ]
    return "\n".join(body).strip() + "\n"


def repository_ref_section(repo_root: Path, ref: str, field: str) -> str | None:
    if not ref.startswith("docs/"):
        return None
    path_part, _, anchor = ref.partition("#")
    path = repo_root / path_part
    if not path.is_file():
        raise ValueError(f"{field} repository evidence path does not exist: {path_part}")
    if anchor and f"#{anchor}" in FORBIDDEN_AGGREGATE_ANCHORS:
        raise ValueError(f"{field} must not point to aggregate evidence anchor: #{anchor}")
    if anchor:
        sections = markdown_anchor_sections(path)
        if anchor not in sections:
            raise ValueError(f"{field} repository evidence anchor does not exist: {ref}")
        return sections[anchor]
    return None


def assert_repository_ref_exists(repo_root: Path, ref: str, field: str) -> None:
    repository_ref_section(repo_root, ref, field)


def markdown_field_value(section: str, field: str) -> str | None:
    prefix = f"- {field}:"
    for line in section.splitlines():
        stripped = line.strip()
        if not stripped.startswith(prefix):
            continue
        value = stripped[len(prefix) :].strip()
        return value.strip("\"'` ")
    return None


def assert_sanitized_output_excerpt(section: str) -> None:
    value = markdown_field_value(section, "sanitized_output_excerpt")
    if value is None:
        raise ValueError(
            "run_output_ref evidence section must include sanitized_output_excerpt"
        )
    if len(value) < 30 or value.lower() in {"pass", "passed", "ok", "n/a", "none", "todo"}:
        raise ValueError(
            "run_output_ref evidence section sanitized_output_excerpt must be concrete"
        )


def assert_stable_evidence_refs(record: dict[str, Any], repo_root: Path) -> None:
    refs: dict[str, str] = {}
    for field in ("run_output_ref", "agent_output_ref"):
        ref = str(record.get(field, ""))
        if ref.startswith(("artifact://", "docs/")):
            refs[field] = ref
            section = repository_ref_section(repo_root, ref, field)
            if ref.startswith("docs/"):
                if section is None or not section.strip():
                    raise ValueError(f"{field} repository evidence section must be non-empty")
                for value_field in ("run_id", "case_id", "runtime_target"):
                    if str(record.get(value_field, "")).strip() not in section:
                        raise ValueError(f"{field} evidence section missing {value_field}")
                if field == "run_output_ref" and "evidence_kind: run_output" not in section:
                    raise ValueError("run_output_ref evidence section missing run output marker")
                if field == "run_output_ref":
                    assert_sanitized_output_excerpt(section)
                if field == "agent_output_ref" and "evidence_kind: independent_review" not in section:
                    raise ValueError("agent_output_ref evidence section missing independent review marker")
            continue
        raise ValueError(
            f"{field} must be a stable repository evidence ref or artifact:// ref"
        )
    if refs.get("run_output_ref") == refs.get("agent_output_ref"):
        raise ValueError("run_output_ref and agent_output_ref must be distinct refs")


def assert_required_command_results(
    pack: dict[str, Any],
    payload: dict[str, Any],
    repo_root: Path,
) -> None:
    rollout_gate = pack.get("rollout_gate")
    if not isinstance(rollout_gate, dict):
        raise ValueError("acceptance pack missing rollout_gate")
    required_commands = rollout_gate.get("required_commands")
    if not isinstance(required_commands, list) or not all(
        isinstance(item, str) and item.strip() for item in required_commands
    ):
        raise ValueError("rollout_gate required_commands must be a non-empty string array")
    commands_required_for_record_set = list(required_commands)
    pilot_start_required_commands = rollout_gate.get("pilot_start_required_commands", [])
    if not isinstance(pilot_start_required_commands, list) or not all(
        isinstance(item, str) and item.strip() for item in pilot_start_required_commands
    ):
        raise ValueError("rollout_gate pilot_start_required_commands must be a string array")
    if payload.get("promotion_effect") == "PROMOTION_ALLOWED":
        commands_required_for_record_set.extend(pilot_start_required_commands)
    promotion_allowed = payload.get("promotion_effect") == "PROMOTION_ALLOWED"

    contract = pack.get("run_record_contract")
    if not isinstance(contract, dict):
        raise ValueError("acceptance pack missing run_record_contract")
    required_fields = contract.get("record_set_required_command_result_fields")
    if required_fields != [
        "command",
        "executed_at",
        "exit_code",
        "output_ref",
        "output_digest",
    ]:
        raise ValueError("run_record_contract record_set_required_command_result_fields mismatch")

    results = payload.get("required_command_results")
    if not isinstance(results, list) or not results:
        raise ValueError("record set required_command_results must be a non-empty array")

    seen: list[str] = []
    for index, result in enumerate(results, start=1):
        if not isinstance(result, dict):
            raise ValueError(f"required_command_results[{index}] must be an object")
        if set(result) != set(required_fields):
            missing = sorted(set(required_fields) - set(result))
            extra = sorted(set(result) - set(required_fields))
            raise ValueError(
                f"required_command_results[{index}] fields mismatch: "
                f"missing={missing} extra={extra}"
            )
        command = result.get("command")
        if not isinstance(command, str) or not command.strip():
            raise ValueError(f"required_command_results[{index}] command must be non-empty")
        executed_at = result.get("executed_at")
        if not isinstance(executed_at, str) or not executed_at.strip():
            raise ValueError(f"required_command_results[{index}] executed_at must be non-empty")
        exit_code = result.get("exit_code")
        if not isinstance(exit_code, int):
            raise ValueError(f"required_command_results[{index}] exit_code must be integer")
        output_ref = result.get("output_ref")
        if not isinstance(output_ref, str) or not output_ref.strip():
            raise ValueError(f"required_command_results[{index}] output_ref must be non-empty")
        if not output_ref.startswith("docs/"):
            raise ValueError(
                f"required_command_results[{index}] output_ref must be docs evidence with digestable content"
            )
        assert_repository_ref_exists(
            repo_root,
            output_ref,
            f"required_command_results[{index}].output_ref",
        )
        output_digest = result.get("output_digest")
        if not isinstance(output_digest, str) or not SHA256_RE.match(output_digest):
            raise ValueError(
                f"required_command_results[{index}] output_digest must be sha256:<64 hex>"
            )
        output_section = repository_ref_section(
            repo_root,
            output_ref,
            f"required_command_results[{index}].output_ref",
        )
        if output_section is None or not output_section.strip():
            raise ValueError(
                f"required_command_results[{index}] output_ref must resolve to non-empty content"
            )
        recorded_command = markdown_field_value(output_section, "command")
        if recorded_command != command:
            raise ValueError(
                f"required_command_results[{index}] output_ref command must match command: {command}"
            )
        if exit_code != 0 and promotion_allowed:
            raise ValueError(
                f"required command must pass before PROMOTION_ALLOWED: {command} exit_code={exit_code}"
            )
        if exit_code != 0 and not COMMAND_FAILURE_MARKER_RE.search(
            command_failure_evidence_text(output_section)
        ):
            raise ValueError(
                f"non-zero required_command_results[{index}] must include failure evidence: {command}"
            )
        if exit_code == 0 or promotion_allowed:
            for marker in REQUIRED_COMMAND_OUTPUT_MARKERS.get(command, []):
                if marker not in output_section:
                    raise ValueError(
                        f"required_command_results[{index}] output_ref missing required command output marker"
                    )
        for marker in FORBIDDEN_COMMAND_OUTPUT_MARKERS.get(command, []):
            if marker in output_section:
                raise ValueError(
                    f"required_command_results[{index}] output_ref contains forbidden command output marker: {marker}"
                )
        actual_digest = "sha256:" + hashlib.sha256(
            output_section.encode("utf-8")
        ).hexdigest()
        if output_digest != actual_digest:
            raise ValueError(
                f"required_command_results[{index}] output_digest does not match output_ref content"
            )
        seen.append(command)

    if len(seen) != len(set(seen)):
        raise ValueError("required_command_results must not contain duplicate commands")
    if set(seen) != set(commands_required_for_record_set):
        missing = sorted(set(commands_required_for_record_set) - set(seen))
        extra = sorted(set(seen) - set(commands_required_for_record_set))
        raise ValueError(
            "required_command_results must cover rollout_gate.required_commands"
            " and pilot_start_required_commands exactly before PROMOTION_ALLOWED: "
            f"missing={missing} extra={extra}"
        )


def assert_promotion_runtime_target(
    rollout_gate: dict[str, Any],
    payload: dict[str, Any],
) -> None:
    targets = rollout_gate.get("promotion_runtime_targets")
    if not isinstance(targets, list) or not targets:
        raise ValueError("rollout_gate promotion_runtime_targets must be a non-empty array")
    valid_targets: list[tuple[str, str]] = []
    for index, target in enumerate(targets, start=1):
        if not isinstance(target, dict):
            raise ValueError(f"promotion_runtime_targets[{index}] must be an object")
        runtime_id = target.get("runtime_id")
        runtime_target = target.get("runtime_target")
        if not isinstance(runtime_id, str) or not runtime_id.strip():
            raise ValueError(f"promotion_runtime_targets[{index}] runtime_id must be non-empty")
        if not isinstance(runtime_target, str) or not runtime_target.strip():
            raise ValueError(
                f"promotion_runtime_targets[{index}] runtime_target must be non-empty"
            )
        valid_targets.append((runtime_id, runtime_target))
    if payload.get("promotion_effect") != "PROMOTION_ALLOWED":
        return
    observed_runtime_id = str(payload.get("runtime_id", "")).strip()
    observed_runtime_target = str(payload.get("runtime_target", "")).strip()
    if not any(
        observed_runtime_id == runtime_id
        and runtime_target_matches(observed_runtime_target, runtime_target)
        for runtime_id, runtime_target in valid_targets
    ):
        raise ValueError(
            "PROMOTION_ALLOWED is scoped to rollout_gate.promotion_runtime_targets "
            "(Codex-only controlled pilot)"
        )


def runtime_target_matches(observed: str, configured: str) -> bool:
    if observed == configured:
        return True
    if not observed.startswith(f"{configured} "):
        return False
    lower_observed = observed.lower()
    if re.search(
        r"\bclaude\b|\ball[- ]runtime\b|\bbroad\b.*\brollout\b|"
        r"\bteam\b.*\brollout\b|\b(and|or)\b|[,/&+]",
        lower_observed,
    ):
        return False
    suffix = observed[len(configured) + 1 :].strip()
    return re.match(r"^(v?\d[\w.+-]*|build[- ][\w.+-]+)$", suffix, re.IGNORECASE) is not None


def require_concrete_operational_fields(
    record: dict[str, Any], fields: list[str], context: str
) -> None:
    for field in fields:
        value = record.get(field)
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{context} must include non-empty {field}")
        if value.strip().lower() in PLACEHOLDER_OPERATIONAL_VALUES:
            raise ValueError(f"{context} must include concrete {field}")


def validate_record(
    pack: dict[str, Any],
    record: dict[str, Any],
    repo_root: Path,
    *,
    allow_promotion: bool = False,
) -> None:
    template = pack.get("run_record_template")
    if not isinstance(template, dict):
        raise ValueError("acceptance pack missing run_record_template")
    contract = pack.get("run_record_contract")
    if not isinstance(contract, dict):
        raise ValueError("acceptance pack missing run_record_contract")

    expected_fields = set(template)
    actual_fields = set(record)
    if actual_fields != expected_fields:
        missing = sorted(expected_fields - actual_fields)
        extra = sorted(actual_fields - expected_fields)
        raise ValueError(f"run record fields mismatch: missing={missing} extra={extra}")

    required_string_fields = require_string_array_contract(
        contract, "required_string_fields"
    )
    required_string_array_fields = require_string_array_contract(
        contract, "required_string_array_fields"
    )
    required_integer_fields = require_string_array_contract(
        contract, "required_integer_fields"
    )
    for field in required_string_fields:
        require_non_empty_string(record, field)
    for field in required_string_array_fields:
        require_string_array(record, field)
    for field in required_integer_fields:
        require_integer(record, field)
    if contract.get("single_runtime_required") is True:
        assert_single_runtime(record)
    if contract.get("single_observed_run_required") is True:
        assert_single_observed_run(record)
    if contract.get("stable_evidence_ref_required") is True:
        assert_stable_evidence_refs(record, repo_root)
    assert_known_case_id(pack, record)

    independent_fields = contract.get("independent_reviewer_fields")
    if not isinstance(independent_fields, list) or not all(
        isinstance(item, str) for item in independent_fields
    ):
        raise ValueError(
            "run_record_contract independent_reviewer_fields must be a string array"
        )
    for field in independent_fields:
        if field not in record:
            raise ValueError(f"run record missing independent reviewer field: {field}")
    if contract.get("independent_reviewer_required") is True:
        if record.get("reviewer_is_independent") is not True:
            raise ValueError("reviewer_is_independent must be true")
        if record.get("reviewer") == record.get("rule_change_author"):
            raise ValueError("reviewer must differ from rule_change_author")
        require_non_empty_string(record, "reviewer_independence_evidence")

    behavior_values = contract.get("behavior_verdict_values")
    if not isinstance(behavior_values, list) or not all(
        isinstance(item, str) for item in behavior_values
    ):
        raise ValueError(
            "run_record_contract behavior_verdict_values must be a string array"
        )
    behavior_verdict = record.get("behavior_verdict")
    if behavior_verdict not in behavior_values:
        raise ValueError(
            f"behavior_verdict must be one of {behavior_values}: {behavior_verdict!r}"
        )

    if not isinstance(record.get("model_failure_observed"), bool):
        raise ValueError("model_failure_observed must be boolean")
    if contract.get("rollback_required_when_model_failure_observed") is not True:
        raise ValueError(
            "run_record_contract rollback_required_when_model_failure_observed must be true"
        )

    promotion_values = contract.get("promotion_effect_values")
    if not isinstance(promotion_values, list) or not all(
        isinstance(item, str) for item in promotion_values
    ):
        raise ValueError(
            "run_record_contract promotion_effect_values must be a string array"
        )
    promotion_effect = record.get("promotion_effect")
    if promotion_effect not in promotion_values:
        raise ValueError(
            f"promotion_effect must be one of {promotion_values}: {promotion_effect!r}"
        )
    rollback_when = contract.get("rollback_required_when")
    rollback_fields = contract.get("rollback_required_fields")
    if not isinstance(rollback_when, list) or not all(
        isinstance(item, str) for item in rollback_when
    ):
        raise ValueError(
            "run_record_contract rollback_required_when must be a string array"
        )
    if not isinstance(rollback_fields, list) or not all(
        isinstance(item, str) for item in rollback_fields
    ):
        raise ValueError(
            "run_record_contract rollback_required_fields must be a string array"
        )
    for field in rollback_fields:
        value = record.get(field)
        if not isinstance(value, str):
            raise ValueError(f"run record field must be a string: {field}")
    if behavior_verdict in rollback_when or record.get("model_failure_observed") is True:
        if promotion_effect != "PROMOTION_BLOCKED":
            raise ValueError(
                "behavior failure or model_failure_observed requires PROMOTION_BLOCKED"
            )
        require_concrete_operational_fields(record, rollback_fields, "run record")
    elif promotion_effect == "PROMOTION_ALLOWED" and not allow_promotion:
        raise ValueError(
            "single observed run must not set PROMOTION_ALLOWED; use a complete record set"
        )


def is_placeholder_execution_timestamp(value: str) -> bool:
    return bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}T00:00:00Z", value.strip()))


def assert_promotion_grade_run_output(section: str, record_index: int) -> None:
    if "evidence_grade: promotion_raw_or_sufficiently_redacted" not in section:
        raise ValueError(
            f"PROMOTION_ALLOWED records[{record_index}] run_output_ref must include promotion-grade evidence"
        )
    raw_output_digest = markdown_field_value(section, "raw_output_digest")
    source_transcript_ref = markdown_field_value(section, "source_transcript_ref")
    if raw_output_digest is None and source_transcript_ref is None:
        raise ValueError(
            f"PROMOTION_ALLOWED records[{record_index}] run_output_ref must include raw_output_digest or source_transcript_ref"
        )
    if raw_output_digest is not None and not SHA256_RE.match(raw_output_digest):
        raise ValueError(
            f"PROMOTION_ALLOWED records[{record_index}] raw_output_digest must be sha256:<64 hex>"
        )


def assert_promotion_record_evidence(
    payload: dict[str, Any],
    record: dict[str, Any],
    repo_root: Path,
    record_index: int,
) -> None:
    install_ref = str(payload.get("install_evidence_ref", "")).strip()
    install_evidence = str(record.get("install_evidence", "")).strip()
    if install_evidence != install_ref:
        raise ValueError(
            f"PROMOTION_ALLOWED records[{record_index}] install_evidence must bind to install_evidence_ref"
        )
    executed_at = str(record.get("executed_at", "")).strip()
    if is_placeholder_execution_timestamp(executed_at):
        raise ValueError(
            f"PROMOTION_ALLOWED records[{record_index}] executed_at must not use midnight placeholder"
        )
    run_output_ref = str(record.get("run_output_ref", "")).strip()
    run_output_section = repository_ref_section(
        repo_root,
        run_output_ref,
        f"records[{record_index}].run_output_ref",
    )
    if run_output_section is not None:
        assert_promotion_grade_run_output(run_output_section, record_index)


def rollout_gate_artifact_evidence_fields(rollout_gate: dict[str, Any]) -> set[str]:
    gates = rollout_gate.get("pilot_start_required_artifacts", [])
    if gates is None:
        return set()
    if not isinstance(gates, list):
        raise ValueError("rollout_gate pilot_start_required_artifacts must be an array")
    fields: set[str] = set()
    for index, gate in enumerate(gates, start=1):
        if not isinstance(gate, dict):
            raise ValueError(f"pilot_start_required_artifacts[{index}] must be an object")
        for field in (
            "artifact",
            "required_evidence_ref_field",
            "promotion_threshold",
            "feedback_standard_ref",
        ):
            value = gate.get(field)
            if not isinstance(value, str) or not value.strip():
                raise ValueError(
                    f"pilot_start_required_artifacts[{index}] {field} must be non-empty"
                )
        minimum_runs = gate.get("minimum_runs_per_case")
        if not isinstance(minimum_runs, int) or minimum_runs < 1:
            raise ValueError(
                f"pilot_start_required_artifacts[{index}] minimum_runs_per_case must be positive"
            )
        fields.add(str(gate["required_evidence_ref_field"]))
    return fields


def assert_pilot_start_artifact_evidence(
    rollout_gate: dict[str, Any],
    payload: dict[str, Any],
    repo_root: Path,
) -> None:
    fields = rollout_gate_artifact_evidence_fields(rollout_gate)
    for field in fields:
        value = payload.get(field)
        if not isinstance(value, str):
            raise ValueError(f"record set {field} must be a string")
        if payload.get("promotion_effect") == "PROMOTION_ALLOWED":
            if not value.strip():
                raise ValueError(
                    f"PROMOTION_ALLOWED requires pilot-start artifact evidence field: {field}"
                )
            assert_repository_ref_exists(repo_root, value, field)


def validate_record_set(pack: dict[str, Any], payload: dict[str, Any], repo_root: Path) -> None:
    rollout_gate = pack.get("rollout_gate")
    if not isinstance(rollout_gate, dict):
        raise ValueError("acceptance pack missing rollout_gate")
    artifact_evidence_fields = rollout_gate_artifact_evidence_fields(rollout_gate)
    expected_fields = {
        "record_set_id",
        "runtime_id",
        "runtime_version",
        "runtime_target",
        "promotion_effect",
        "promotion_decision",
        "reviewer",
        "rule_change_author",
        "reviewer_is_independent",
        "reviewer_independence_evidence",
        "install_evidence_ref",
        "required_command_results",
        *artifact_evidence_fields,
        "rollback_trigger",
        "rollback_action",
        "escalation_owner",
        "escalation_path",
        "resume_condition",
        "records",
    }
    actual_fields = set(payload)
    if actual_fields != expected_fields:
        missing = sorted(expected_fields - actual_fields)
        extra = sorted(actual_fields - expected_fields)
        raise ValueError(f"run record set fields mismatch: missing={missing} extra={extra}")

    for field in (
        "record_set_id",
        "runtime_id",
        "runtime_version",
        "runtime_target",
        "promotion_effect",
        "promotion_decision",
        "reviewer",
        "rule_change_author",
        "reviewer_independence_evidence",
        "install_evidence_ref",
    ):
        require_non_empty_string(payload, field)
    if payload.get("reviewer_is_independent") is not True:
        raise ValueError("record set reviewer_is_independent must be true")
    if payload.get("reviewer") == payload.get("rule_change_author"):
        raise ValueError("record set reviewer must differ from rule_change_author")
    assert_single_runtime(payload)
    configured_promotion_decision = rollout_gate.get("promotion_decision")
    if not isinstance(configured_promotion_decision, str) or not configured_promotion_decision.strip():
        raise ValueError("rollout_gate promotion_decision must be non-empty")
    if (
        payload.get("promotion_effect") == "PROMOTION_ALLOWED"
        and payload.get("promotion_decision") != configured_promotion_decision
    ):
        raise ValueError(
            "PROMOTION_ALLOWED record set promotion_decision must match "
            f"rollout_gate.promotion_decision: {configured_promotion_decision}"
        )
    assert_promotion_runtime_target(rollout_gate, payload)

    assert_repository_ref_exists(repo_root, str(payload["install_evidence_ref"]), "install_evidence_ref")
    assert_required_command_results(pack, payload, repo_root)
    assert_pilot_start_artifact_evidence(rollout_gate, payload, repo_root)

    contract = pack.get("run_record_contract")
    if not isinstance(contract, dict):
        raise ValueError("acceptance pack missing run_record_contract")
    promotion_values = contract.get("promotion_effect_values")
    if payload.get("promotion_effect") not in promotion_values:
        raise ValueError(f"record set promotion_effect must be one of {promotion_values}")
    rollback_fields = contract.get("rollback_required_fields")
    if not isinstance(rollback_fields, list) or not all(
        isinstance(item, str) for item in rollback_fields
    ):
        raise ValueError("run_record_contract rollback_required_fields must be a string array")
    if payload.get("promotion_effect") in {"PROMOTION_ALLOWED", "PROMOTION_BLOCKED"}:
        require_concrete_operational_fields(payload, rollback_fields, "promotion record set")

    records = payload.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("record set records must be a non-empty array")

    minimum_runs = rollout_gate.get("minimum_runs_per_case")
    if not isinstance(minimum_runs, int) or minimum_runs < 1:
        raise ValueError("rollout_gate minimum_runs_per_case must be a positive integer")
    cases = pack.get("pressure_cases")
    if not isinstance(cases, list):
        raise ValueError("acceptance pack pressure_cases must be an array")
    case_ids = {case.get("id") for case in cases if isinstance(case, dict)}
    expected_coverage = {
        (case_id, sequence)
        for case_id in case_ids
        for sequence in range(1, minimum_runs + 1)
    }
    actual_coverage: set[tuple[str, int]] = set()
    rollback_when = contract.get("rollback_required_when")
    if not isinstance(rollback_when, list) or not all(
        isinstance(item, str) for item in rollback_when
    ):
        raise ValueError("run_record_contract rollback_required_when must be a string array")

    for index, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            raise ValueError(f"record set records[{index}] must be an object")
        validate_record(pack, record, repo_root, allow_promotion=False)
        for field in ("runtime_id", "runtime_version", "runtime_target"):
            if record.get(field) != payload.get(field):
                raise ValueError(f"record set records[{index}] {field} drifts from set")
        record_requires_block = (
            record.get("behavior_verdict") in rollback_when
            or record.get("model_failure_observed") is True
        )
        if record_requires_block:
            if record.get("promotion_effect") != "PROMOTION_BLOCKED":
                raise ValueError(
                    "failed or model-failure run records in a set must be PROMOTION_BLOCKED"
                )
        elif record.get("promotion_effect") != "NO_PROMOTION_IMPACT":
            raise ValueError(
                "passing individual run records in a set must be NO_PROMOTION_IMPACT"
            )
        if payload.get("promotion_effect") == "PROMOTION_ALLOWED":
            if record.get("behavior_verdict") != "PASS":
                raise ValueError("PROMOTION_ALLOWED record set requires every run to PASS")
            if record.get("model_failure_observed") is not False:
                raise ValueError("PROMOTION_ALLOWED record set requires no model failures")
            assert_promotion_record_evidence(payload, record, repo_root, index)
        actual_coverage.add((str(record.get("case_id")), int(record.get("observed_run_sequence"))))

    if payload.get("promotion_effect") == "PROMOTION_ALLOWED":
        executed_at_values = [str(record.get("executed_at", "")).strip() for record in records]
        if len(executed_at_values) > 1 and len(set(executed_at_values)) == 1:
            raise ValueError("PROMOTION_ALLOWED records executed_at values must not all be identical")

    if actual_coverage != expected_coverage:
        missing = sorted(expected_coverage - actual_coverage)
        extra = sorted(actual_coverage - expected_coverage)
        raise ValueError(
            "record set must cover every pressure case for minimum_runs_per_case: "
            f"missing={missing} extra={extra}"
        )


def main() -> int:
    args = parse_args()
    pack = load_json(args.pack)
    payload = load_json(args.record)
    repo_root = args.pack.resolve().parents[2]
    if "records" in payload:
        validate_record_set(pack, payload, repo_root)
    else:
        validate_record(pack, payload, repo_root)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        raise SystemExit(str(exc)) from exc
