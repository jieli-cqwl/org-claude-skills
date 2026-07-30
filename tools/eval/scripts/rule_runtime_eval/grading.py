"""Blind semantic grading for isolated rule-runtime evaluation evidence."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
from typing import Mapping

from rule_runtime_eval.common import CommandResult, run_command, write_json
from rule_runtime_eval.contracts import EvalCase
from rule_runtime_eval.workspace import RuntimeWorkspace


class GradingError(ValueError):
    """A grader input, process, or structured-output failure."""


def grading_schema(case: EvalCase) -> dict[str, object]:
    """Build the per-case JSON schema passed directly to Codex."""

    return {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "expectations",
            "anti_patterns",
            "blocking_failures",
            "anchors",
            "behavior_verdict",
            "added_ceremony_without_decision_value",
            "rationale",
        ],
        "properties": {
            "expectations": _verdict_array_schema(case.expected_behavior_ids, "met"),
            "anti_patterns": _verdict_array_schema(case.anti_pattern_ids, "present"),
            "blocking_failures": _verdict_array_schema(case.blocking_failure_ids, "present"),
            "anchors": {
                "type": "array",
                "minItems": len(case.expected_anchors),
                "maxItems": len(case.expected_anchors),
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["id", "score", "evidence"],
                    "properties": {
                        "id": {"type": "string", "enum": list(case.expected_anchors)},
                        "score": {"type": "integer", "minimum": 0, "maximum": 2},
                        "evidence": {"type": "string", "minLength": 1},
                    },
                },
            },
            "behavior_verdict": {"type": "string", "enum": ["PASS", "FAIL"]},
            "added_ceremony_without_decision_value": {"type": "boolean"},
            "rationale": {"type": "string", "minLength": 1},
        },
    }


def build_grader_prompt(case: EvalCase, grader_instructions: str, response: str) -> str:
    """Supply only scenario semantics and the final response to the blind judge."""

    payload = {
        "grader_instructions": grader_instructions,
        "case": {
            "prompt": case.prompt,
            "expected_behaviors": [
                {"id": identifier, "text": text}
                for identifier, text in zip(case.expected_behavior_ids, case.expected_behaviors, strict=True)
            ],
            "anti_patterns": [
                {"id": identifier, "text": text}
                for identifier, text in zip(case.anti_pattern_ids, case.anti_patterns, strict=True)
            ],
            "blocking_failures": [
                {"id": identifier, "text": text}
                for identifier, text in zip(case.blocking_failure_ids, case.blocking_failures, strict=True)
            ],
            "anchors": [dict(case.anchor_definitions[identifier]) for identifier in case.expected_anchors],
        },
        "response": response,
    }
    return (
        "Return only JSON matching the supplied output schema. Judge the response against this "
        "scenario; do not infer unavailable context.\n\n"
        + json.dumps(payload, ensure_ascii=False, sort_keys=True)
    )


def validate_judge_workspace(judge: RuntimeWorkspace, configurations: tuple[RuntimeWorkspace, ...]) -> None:
    """Reject a judge that could see an installed candidate or baseline rule tree."""

    judge_home = judge.home.resolve()
    forbidden_homes = {workspace.home.resolve() for workspace in configurations}
    forbidden_codex_homes = {workspace.codex_home.resolve() for workspace in configurations}
    if judge_home in forbidden_homes or judge.codex_home.resolve() in forbidden_codex_homes:
        raise GradingError("judge home must be distinct from every evaluated configuration")
    if (judge.codex_home / "rules").exists() or (judge.codex_home / "reference").exists():
        raise GradingError("judge Codex home must not contain installed runtime rules")


def run_blind_grader(
    case: EvalCase,
    grader_instructions: str,
    response_path: Path,
    judge: RuntimeWorkspace,
    configurations: tuple[RuntimeWorkspace, ...],
    run_dir: Path,
    *,
    codex_bin: str,
    model: str,
    reasoning_effort: str,
    timeout_seconds: int,
) -> dict[str, object]:
    """Run a fresh schema-constrained judge and retain its process evidence separately."""

    validate_judge_workspace(judge, configurations)
    try:
        response = response_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise GradingError("executor response is unavailable for grading") from exc
    schema_path = run_dir / "grader-schema.json"
    output_path = run_dir / "grading.json"
    write_json(schema_path, grading_schema(case))
    judge_cwd = Path(tempfile.mkdtemp(prefix="judge-", dir=judge.home))
    prompt = build_grader_prompt(case, grader_instructions, response)
    args = [
        codex_bin,
        "exec",
        "--ephemeral",
        "--skip-git-repo-check",
        "--sandbox",
        "workspace-write",
        "--model",
        model,
        "-c",
        f'model_reasoning_effort="{reasoning_effort}"',
        "-C",
        str(judge_cwd),
        "--output-schema",
        str(schema_path),
        "--output-last-message",
        str(output_path),
        prompt,
    ]
    env = dict(os.environ)
    env.update({"HOME": str(judge.home), "CODEX_HOME": str(judge.codex_home)})
    try:
        result = run_command(args, cwd=judge_cwd, env=env, timeout_seconds=timeout_seconds)
    except OSError as exc:
        result = _launch_failure(args, exc)
    finally:
        # The judge cwd is intentionally empty and never becomes runtime evidence.
        try:
            judge_cwd.rmdir()
        except OSError:
            pass
    (run_dir / "grader.stderr.log").write_text(result.stderr, encoding="utf-8")
    process = _process_evidence(result)
    if result.timed_out or result.returncode != 0:
        return {"state": "INFRA_BLOCKED_GRADER", "process": process}
    try:
        payload = json.loads(output_path.read_text(encoding="utf-8"))
        validated = validate_grader_output(payload, case)
    except (OSError, json.JSONDecodeError, GradingError):
        return {"state": "INFRA_BLOCKED_GRADER", "process": process}
    write_json(output_path, validated)
    return {"state": "GRADER_OK", "process": process, "result": validated}


def validate_grader_output(payload: object, case: EvalCase) -> dict[str, object]:
    """Fail closed unless every case-owned verdict is explicit and complete."""

    if not isinstance(payload, dict):
        raise GradingError("grader output must be an object")
    required = set(grading_schema(case)["required"])
    if set(payload) != required:
        raise GradingError("grader output has missing or unknown fields")
    _validate_verdicts(payload["expectations"], case.expected_behavior_ids, "met")
    _validate_verdicts(payload["anti_patterns"], case.anti_pattern_ids, "present")
    _validate_verdicts(payload["blocking_failures"], case.blocking_failure_ids, "present")
    _validate_anchors(payload["anchors"], case.expected_anchors)
    if payload["behavior_verdict"] not in {"PASS", "FAIL"}:
        raise GradingError("behavior verdict must be PASS or FAIL")
    expected_behavior_verdict = "PASS" if _details_behavior_pass(payload) else "FAIL"
    if payload["behavior_verdict"] != expected_behavior_verdict:
        raise GradingError("behavior verdict contradicts detailed verdicts")
    if not isinstance(payload["added_ceremony_without_decision_value"], bool):
        raise GradingError("ceremony signal must be boolean")
    if not _nonempty_string(payload["rationale"]):
        raise GradingError("grader rationale is required")
    return payload


def _verdict_array_schema(ids: tuple[str, ...], verdict_field: str) -> dict[str, object]:
    return {
        "type": "array",
        "minItems": len(ids),
        "maxItems": len(ids),
        "items": {
            "type": "object",
            "additionalProperties": False,
            "required": ["id", verdict_field, "evidence"],
            "properties": {
                "id": {"type": "string", "enum": list(ids)},
                verdict_field: {"type": "boolean"},
                "evidence": {"type": "string", "minLength": 1},
            },
        },
    }


def _validate_verdicts(value: object, expected_ids: tuple[str, ...], verdict_field: str) -> None:
    if not isinstance(value, list) or len(value) != len(expected_ids):
        raise GradingError("grader verdict list is incomplete")
    seen: set[str] = set()
    for item in value:
        if not isinstance(item, dict) or set(item) != {"id", verdict_field, "evidence"}:
            raise GradingError("grader verdict shape is invalid")
        identifier = item["id"]
        if not isinstance(identifier, str) or identifier not in expected_ids or identifier in seen:
            raise GradingError("grader verdict ID is invalid")
        if not isinstance(item[verdict_field], bool) or not _nonempty_string(item["evidence"]):
            raise GradingError("grader verdict value is invalid")
        seen.add(identifier)
    if seen != set(expected_ids):
        raise GradingError("grader verdict IDs are incomplete")


def _validate_anchors(value: object, expected_ids: tuple[str, ...]) -> None:
    if not isinstance(value, list) or len(value) != len(expected_ids):
        raise GradingError("grader anchor list is incomplete")
    seen: set[str] = set()
    for item in value:
        if not isinstance(item, dict) or set(item) != {"id", "score", "evidence"}:
            raise GradingError("grader anchor shape is invalid")
        identifier = item["id"]
        score = item["score"]
        if (
            not isinstance(identifier, str)
            or identifier not in expected_ids
            or identifier in seen
            or not isinstance(score, int)
            or isinstance(score, bool)
            or score not in {0, 1, 2}
            or not _nonempty_string(item["evidence"])
        ):
            raise GradingError("grader anchor value is invalid")
        seen.add(identifier)
    if seen != set(expected_ids):
        raise GradingError("grader anchor IDs are incomplete")


def _details_behavior_pass(payload: Mapping[str, object]) -> bool:
    """Derive semantic pass from all case-owned detailed verdicts."""

    return all(
        item.get("met") is True
        for item in payload["expectations"]
        if isinstance(item, Mapping)
    ) and all(
        item.get("present") is False
        for item in payload["anti_patterns"]
        if isinstance(item, Mapping)
    ) and all(
        item.get("present") is False
        for item in payload["blocking_failures"]
        if isinstance(item, Mapping)
    )


def _process_evidence(result: CommandResult) -> dict[str, object]:
    return {
        "returncode": result.returncode,
        "timed_out": result.timed_out,
        "started_at": result.started_at,
        "ended_at": result.ended_at,
        "duration_seconds": result.duration_seconds,
    }


def _launch_failure(args: list[str], error: OSError) -> CommandResult:
    return CommandResult(
        args=args,
        returncode=127,
        stdout="",
        stderr=f"grader launch failed: {error.__class__.__name__}",
        timed_out=False,
        started_at="",
        ended_at="",
        duration_seconds=0.0,
    )


def _nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())
