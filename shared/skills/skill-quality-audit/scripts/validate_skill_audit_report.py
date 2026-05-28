#!/usr/bin/env python3
"""Validate skill-quality-audit report artifacts."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

from skill_audit_report_contract import (
    ARTIFACT_PATH_FIELDS,
    DIMENSION_FIELDS,
    EXECUTED_VERIFICATION_FIELDS,
    HANDOFF_FIELDS,
    REQUIRED_DIMENSIONS,
    REQUIRED_DIMENSION_SET,
    REQUIRED_SCOPE_SURFACES,
    REQUIRED_SCOPE_SURFACE_SET,
    SCOPE_FIELDS,
    TOP_LEVEL_FIELDS,
    VALID_EVIDENCE_LEVELS,
    VALID_VERDICTS,
    VALIDATION_FIELDS,
    evidence_level_at_least,
    existing_path_refs,
    fail,
    has_pathish_ref,
    require,
    require_known_fields,
    validate_findings,
    validate_summary,
)


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{path}: invalid JSON: {exc}")
    if not isinstance(data, dict):
        fail(f"{path}: report must be a JSON object")
    return data


def score_for(report: dict[str, Any], dimension: str) -> float:
    for item in report.get("dimension_scores", []):
        if item.get("dimension") == dimension:
            score = item.get("score")
            require(
                isinstance(score, (int, float)), f"{dimension} score must be numeric"
            )
            return float(score)
    fail(f"missing dimension score: {dimension}")


def validate_top_level(report: dict[str, Any]) -> None:
    require_known_fields(report, TOP_LEVEL_FIELDS, "report")
    required = {
        "artifact_type",
        "audit_mode",
        "target_skill",
        "verdict",
        "overall_score",
        "artifact_paths",
        "scope_evidence",
        "dimension_scores",
        "findings",
        "repair_handoff",
        "validation",
        "executed_verification",
    }
    missing = sorted(required - report.keys())
    require(not missing, f"missing top-level fields: {', '.join(missing)}")
    require(
        report["artifact_type"] == "skill-audit-report",
        "artifact_type must be skill-audit-report",
    )
    require(report["audit_mode"] == "formal", "audit_mode must be formal")
    require(
        isinstance(report["target_skill"], str) and report["target_skill"].strip(),
        "target_skill must be a non-empty string",
    )
    require(
        report["verdict"] in VALID_VERDICTS,
        "verdict must be fit, conditional, unfit, or blocked",
    )
    require(
        isinstance(report["overall_score"], (int, float)),
        "overall_score must be numeric",
    )
    require(
        0 <= float(report["overall_score"]) <= 10,
        "overall_score must be between 0 and 10",
    )


def validate_artifact_paths(report: dict[str, Any]) -> None:
    paths = report.get("artifact_paths")
    require(isinstance(paths, dict), "artifact_paths must be an object")
    require_known_fields(paths, ARTIFACT_PATH_FIELDS, "artifact_paths")
    for field in ("report_json", "summary_markdown"):
        value = paths.get(field)
        require(
            isinstance(value, str) and value.strip(),
            f"artifact_paths.{field} is required",
        )
        require(
            has_pathish_ref(value),
            f"artifact_paths.{field} must name an audit artifact path",
        )


def validate_scope(report: dict[str, Any]) -> None:
    scope = report.get("scope_evidence")
    require(
        isinstance(scope, list) and scope, "scope_evidence must be a non-empty array"
    )
    seen: set[str] = set()
    for index, item in enumerate(scope):
        require(isinstance(item, dict), f"scope_evidence[{index}] must be an object")
        require_known_fields(item, SCOPE_FIELDS, f"scope_evidence[{index}]")
        surface = item.get("surface")
        require(
            isinstance(surface, str) and surface,
            f"scope_evidence[{index}].surface is required",
        )
        require(surface not in seen, f"duplicate scope surface: {surface}")
        seen.add(surface)
        status = item.get("status")
        evidence = item.get("evidence")
        require(
            status in {"checked", "absent", "blocked"},
            f"scope_evidence[{index}].status is invalid",
        )
        require(
            isinstance(evidence, str) and evidence.strip(),
            f"scope_evidence[{index}].evidence is required",
        )
        if status == "checked":
            refs = existing_path_refs(evidence)
            if has_pathish_ref(evidence):
                require(
                    refs,
                    f"scope_evidence[{index}] checked evidence path does not exist: {evidence}",
                )
            else:
                require(
                    False,
                    f"scope_evidence[{index}] checked evidence must name an active file or directory",
                )
    unknown = sorted(seen - REQUIRED_SCOPE_SURFACE_SET)
    require(not unknown, f"unknown scope surfaces: {', '.join(unknown)}")
    missing = [surface for surface in REQUIRED_SCOPE_SURFACES if surface not in seen]
    require(not missing, f"missing required scope surfaces: {', '.join(missing)}")


def validate_dimensions(report: dict[str, Any]) -> None:
    items = report.get("dimension_scores")
    require(
        isinstance(items, list) and items, "dimension_scores must be a non-empty array"
    )
    seen: set[str] = set()
    for index, item in enumerate(items):
        require(isinstance(item, dict), f"dimension_scores[{index}] must be an object")
        require_known_fields(item, DIMENSION_FIELDS, f"dimension_scores[{index}]")
        dimension = item.get("dimension")
        require(
            isinstance(dimension, str) and dimension,
            f"dimension_scores[{index}].dimension is required",
        )
        require(dimension not in seen, f"duplicate dimension score: {dimension}")
        seen.add(dimension)
        score = item.get("score")
        require(isinstance(score, (int, float)), f"{dimension} score must be numeric")
        require(0 <= float(score) <= 10, f"{dimension} score must be between 0 and 10")
        require(
            item.get("evidence_level") in VALID_EVIDENCE_LEVELS,
            f"{dimension} evidence_level is invalid",
        )
        require(
            isinstance(item.get("reason"), str) and item["reason"],
            f"{dimension} reason is required",
        )
    unknown = sorted(seen - REQUIRED_DIMENSION_SET)
    require(not unknown, f"unknown dimensions: {', '.join(unknown)}")
    missing = [dimension for dimension in REQUIRED_DIMENSIONS if dimension not in seen]
    require(not missing, f"missing required dimensions: {', '.join(missing)}")


def validate_verdict_rules(report: dict[str, Any]) -> None:
    verdict = report["verdict"]
    severities = {finding.get("severity") for finding in report.get("findings", [])}
    has_blocked_scope = any(
        item.get("status") == "blocked" for item in report.get("scope_evidence", [])
    )
    if verdict == "blocked":
        require(
            has_blocked_scope or "P0" in severities,
            "blocked verdict requires blocked scope evidence or a P0 finding",
        )
        return
    instruction = score_for(report, "Instruction Contract")
    runtime = score_for(report, "Runtime Integration")
    evidence = score_for(report, "Evidence And Evals")
    if "P0" in severities:
        require(
            verdict in {"blocked", "unfit"},
            "P0 finding must force blocked or unfit verdict",
        )
    if instruction < 5:
        require(
            verdict == "unfit",
            "Instruction Contract score below 5 must force unfit verdict",
        )
    elif instruction < 7:
        require(
            verdict != "fit",
            "Instruction Contract score below 7 caps verdict at conditional",
        )
    if runtime < 5:
        require(
            verdict in {"unfit", "blocked"},
            "Runtime Integration below 5 must force unfit or blocked",
        )
    if verdict == "fit":
        require(
            not (severities & {"P0", "P1"}), "fit verdict cannot have P0/P1 findings"
        )
        require(instruction >= 7, "fit verdict requires Instruction Contract >= 7")
        require(runtime >= 7, "fit verdict requires Runtime Integration >= 7")
        require(evidence >= 7, "fit verdict requires Evidence And Evals >= 7")
        require(
            float(report["overall_score"]) >= 8,
            "fit verdict requires overall_score >= 8",
        )
        for dimension in (
            "Instruction Contract",
            "Runtime Integration",
            "Evidence And Evals",
        ):
            for item in report["dimension_scores"]:
                if item["dimension"] == dimension:
                    require(
                        evidence_level_at_least(item["evidence_level"], "E3"),
                        f"fit verdict requires {dimension} evidence_level E3 or higher",
                    )
                    break


def validate_validation(report: dict[str, Any]) -> None:
    validation = report.get("validation")
    require(isinstance(validation, dict), "validation must be an object")
    require_known_fields(validation, VALIDATION_FIELDS, "validation")
    require(validation.get("status") == "PASS", "validation.status must be PASS")
    command = validation.get("command")
    output = validation.get("output")
    require(
        isinstance(command, str) and command.strip(), "validation.command is required"
    )
    require(
        "validate_skill_audit_report.py" in command,
        "validation.command must run validate_skill_audit_report.py",
    )
    report_json = report["artifact_paths"]["report_json"]
    require(
        report_json in command,
        "validation.command must include artifact_paths.report_json",
    )
    require(isinstance(output, str) and output.strip(), "validation.output is required")
    require("[PASS]" in output, "validation.output must include validator PASS output")


def validate_executed_verification(report: dict[str, Any]) -> None:
    items = report.get("executed_verification")
    require(isinstance(items, list), "executed_verification must be an array")
    for index, item in enumerate(items):
        require(
            isinstance(item, dict), f"executed_verification[{index}] must be an object"
        )
        require_known_fields(
            item, EXECUTED_VERIFICATION_FIELDS, f"executed_verification[{index}]"
        )
        for field in ("id", "command", "status", "output"):
            require(
                isinstance(item.get(field), str) and item[field],
                f"executed_verification[{index}].{field} is required",
            )
        require(
            item["status"] in {"PASS", "FAIL", "BLOCKED"},
            f"executed_verification[{index}].status is invalid",
        )
        if "supports" in item:
            supports = item["supports"]
            require(
                isinstance(supports, list)
                and supports
                and all(isinstance(value, str) and value for value in supports),
                f"executed_verification[{index}].supports must be non-empty strings",
            )
    e4_dimensions = [
        item.get("dimension", f"dimension[{index}]")
        for index, item in enumerate(report.get("dimension_scores", []))
        if item.get("evidence_level") == "E4"
    ]
    e4_findings = [
        item.get("id", f"finding[{index}]")
        for index, item in enumerate(report.get("findings", []))
        if item.get("evidence_level") == "E4"
    ]
    if e4_dimensions or e4_findings:
        required_refs = [f"dimension:{name}" for name in e4_dimensions]
        required_refs.extend(f"finding:{name}" for name in e4_findings)
        supported_refs = {
            support
            for item in items
            if item.get("status") == "PASS"
            for support in item.get("supports", [])
        }
        missing = sorted(set(required_refs) - supported_refs)
        require(
            not missing,
            "E4 evidence requires matching PASS executed_verification supports: "
            + ", ".join(missing),
        )


def validate_repair_handoff(report: dict[str, Any]) -> None:
    handoff = report.get("repair_handoff")
    require(isinstance(handoff, list), "repair_handoff must be an array")
    for index, item in enumerate(handoff):
        require(isinstance(item, dict), f"repair_handoff[{index}] must be an object")
        require_known_fields(item, HANDOFF_FIELDS, f"repair_handoff[{index}]")
        for field in ("target", "action", "owner"):
            require(
                isinstance(item.get(field), str) and item[field],
                f"repair_handoff[{index}].{field} is required",
            )


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_skill_audit_report.py <report.json>", file=sys.stderr)
        return 2
    report = load_json(Path(argv[1]))
    validate_top_level(report)
    validate_artifact_paths(report)
    validate_scope(report)
    validate_dimensions(report)
    validate_findings(report)
    validate_summary(report)
    validate_verdict_rules(report)
    validate_validation(report)
    validate_executed_verification(report)
    validate_repair_handoff(report)
    print("[PASS] skill audit report valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
