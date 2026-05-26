#!/usr/bin/env python3
"""Validate skill-quality-audit report artifacts."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_DIMENSIONS = (
    "Real Use Capability",
    "Trigger And Routing",
    "Instruction Contract",
    "Workflow Causality",
    "Output And Handoff",
    "Determinism And Validation",
    "Runtime Integration",
    "Evidence And Evals",
    "Noise And Maintainability",
)
REQUIRED_DIMENSION_SET = set(REQUIRED_DIMENSIONS)
REQUIRED_SCOPE_SURFACES = (
    "SKILL.md",
    "agents/openai.yaml",
    "references",
    "scripts",
    "templates",
    "contracts",
    "test prompts",
    "evals",
    "fixtures",
    "runtime surface",
    "install hooks",
    "gate plan",
    "run-all",
    "focused runner",
    "README",
    "downstream consumers",
)
REQUIRED_SCOPE_SURFACE_SET = set(REQUIRED_SCOPE_SURFACES)
VALID_VERDICTS = {"fit", "conditional", "unfit", "blocked"}
VALID_SEVERITIES = {"P0", "P1", "P2", "P3"}
VALID_EVIDENCE_LEVELS = {"E0", "E1", "E2", "E3", "E4"}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{path}: invalid JSON: {exc}")
    if not isinstance(data, dict):
        fail(f"{path}: report must be a JSON object")
    return data


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def score_for(report: dict[str, Any], dimension: str) -> float:
    for item in report.get("dimension_scores", []):
        if item.get("dimension") == dimension:
            score = item.get("score")
            require(isinstance(score, (int, float)), f"{dimension} score must be numeric")
            return float(score)
    fail(f"missing dimension score: {dimension}")


def validate_top_level(report: dict[str, Any]) -> None:
    required = {
        "artifact_type",
        "target_skill",
        "verdict",
        "overall_score",
        "scope_evidence",
        "dimension_scores",
        "findings",
        "repair_handoff",
    }
    missing = sorted(required - report.keys())
    require(not missing, f"missing top-level fields: {', '.join(missing)}")
    require(report["artifact_type"] == "skill-audit-report", "artifact_type must be skill-audit-report")
    require(report["verdict"] in VALID_VERDICTS, "verdict must be fit, conditional, unfit, or blocked")
    require(isinstance(report["overall_score"], (int, float)), "overall_score must be numeric")
    require(0 <= float(report["overall_score"]) <= 10, "overall_score must be between 0 and 10")


def validate_scope(report: dict[str, Any]) -> None:
    scope = report.get("scope_evidence")
    require(isinstance(scope, list) and scope, "scope_evidence must be a non-empty array")
    seen: set[str] = set()
    for index, item in enumerate(scope):
        require(isinstance(item, dict), f"scope_evidence[{index}] must be an object")
        surface = item.get("surface")
        require(isinstance(surface, str) and surface, f"scope_evidence[{index}].surface is required")
        require(surface not in seen, f"duplicate scope surface: {surface}")
        seen.add(surface)
        require(item.get("status") in {"checked", "absent", "blocked"}, f"scope_evidence[{index}].status is invalid")
    unknown = sorted(seen - REQUIRED_SCOPE_SURFACE_SET)
    require(not unknown, f"unknown scope surfaces: {', '.join(unknown)}")
    missing = [surface for surface in REQUIRED_SCOPE_SURFACES if surface not in seen]
    require(not missing, f"missing required scope surfaces: {', '.join(missing)}")


def validate_dimensions(report: dict[str, Any]) -> None:
    items = report.get("dimension_scores")
    require(isinstance(items, list) and items, "dimension_scores must be a non-empty array")
    seen: set[str] = set()
    for index, item in enumerate(items):
        require(isinstance(item, dict), f"dimension_scores[{index}] must be an object")
        dimension = item.get("dimension")
        require(isinstance(dimension, str) and dimension, f"dimension_scores[{index}].dimension is required")
        require(dimension not in seen, f"duplicate dimension score: {dimension}")
        seen.add(dimension)
        score = item.get("score")
        require(isinstance(score, (int, float)), f"{dimension} score must be numeric")
        require(0 <= float(score) <= 10, f"{dimension} score must be between 0 and 10")
        require(item.get("evidence_level") in VALID_EVIDENCE_LEVELS, f"{dimension} evidence_level is invalid")
        require(isinstance(item.get("reason"), str) and item["reason"], f"{dimension} reason is required")
    unknown = sorted(seen - REQUIRED_DIMENSION_SET)
    require(not unknown, f"unknown dimensions: {', '.join(unknown)}")
    missing = [dimension for dimension in REQUIRED_DIMENSIONS if dimension not in seen]
    require(not missing, f"missing required dimensions: {', '.join(missing)}")


def validate_findings(report: dict[str, Any]) -> None:
    findings = report.get("findings")
    require(isinstance(findings, list), "findings must be an array")
    for index, finding in enumerate(findings):
        require(isinstance(finding, dict), f"findings[{index}] must be an object")
        severity = finding.get("severity")
        require(severity in VALID_SEVERITIES, f"findings[{index}].severity is invalid")
        for field in ("id", "title", "evidence", "impact"):
            require(isinstance(finding.get(field), str) and finding[field], f"findings[{index}].{field} is required")
        if severity in {"P0", "P1"}:
            for field in ("repair_target", "verification_hint"):
                require(isinstance(finding.get(field), str) and finding[field], f"{severity} finding {finding.get('id', index)} missing {field}")


def validate_verdict_rules(report: dict[str, Any]) -> None:
    verdict = report["verdict"]
    instruction = score_for(report, "Instruction Contract")
    runtime = score_for(report, "Runtime Integration")
    evidence = score_for(report, "Evidence And Evals")
    severities = {finding.get("severity") for finding in report.get("findings", [])}
    if "P0" in severities:
        require(verdict in {"blocked", "unfit"}, "P0 finding must force blocked or unfit verdict")
    if instruction < 5:
        require(verdict == "unfit", "Instruction Contract score below 5 must force unfit verdict")
    elif instruction < 7:
        require(verdict != "fit", "Instruction Contract score below 7 caps verdict at conditional")
    if runtime < 5:
        require(verdict in {"unfit", "blocked"}, "Runtime Integration below 5 must force unfit or blocked")
    if verdict == "fit":
        require(not (severities & {"P0", "P1"}), "fit verdict cannot have P0/P1 findings")
        require(instruction >= 7, "fit verdict requires Instruction Contract >= 7")
        require(runtime >= 7, "fit verdict requires Runtime Integration >= 7")
        require(evidence >= 7, "fit verdict requires Evidence And Evals >= 7")
        require(float(report["overall_score"]) >= 8, "fit verdict requires overall_score >= 8")


def validate_repair_handoff(report: dict[str, Any]) -> None:
    handoff = report.get("repair_handoff")
    require(isinstance(handoff, list), "repair_handoff must be an array")
    for index, item in enumerate(handoff):
        require(isinstance(item, dict), f"repair_handoff[{index}] must be an object")
        for field in ("target", "action", "owner"):
            require(isinstance(item.get(field), str) and item[field], f"repair_handoff[{index}].{field} is required")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_skill_audit_report.py <report.json>", file=sys.stderr)
        return 2
    report = load_json(Path(argv[1]))
    validate_top_level(report)
    validate_scope(report)
    validate_dimensions(report)
    validate_findings(report)
    validate_verdict_rules(report)
    validate_repair_handoff(report)
    print("[PASS] skill audit report valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
