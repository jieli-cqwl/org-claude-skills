#!/usr/bin/env python3
"""Validate deterministic senior-architect invariants for design.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REQUIRED_CONCERNS = {"auth", "error", "log", "config"}
REQUIRED_REVIEWERS = {"architecture", "product", "test"}
WEAK_RUNTIME_EVIDENCE = {
    "design.json#input_analysis",
    "design.json#runtime_facts",
}


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise SystemExit((2, f"design file not found: {path}"))
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit((2, f"malformed JSON: {path}: {exc}")) from exc
    if not isinstance(payload, dict):
        raise SystemExit((2, f"design file must contain a JSON object: {path}"))
    return payload


def violation(kind: str, location: str, message: str) -> dict[str, str]:
    return {"type": kind, "location": location, "message": message}


def evidence_value(fact: str) -> str:
    marker = "evidence="
    if marker not in fact:
        return ""
    rest = fact.split(marker, 1)[1]
    for separator in (";", "；"):
        if separator in rest:
            rest = rest.split(separator, 1)[0]
    return rest.strip()


def collect_verification_refs(design: dict[str, Any]) -> set[str]:
    mapping = design.get("verification_mapping", [])
    if not isinstance(mapping, list):
        return set()
    return {
        row["evidence_ref"]
        for row in mapping
        if isinstance(row, dict) and isinstance(row.get("evidence_ref"), str) and row["evidence_ref"].strip()
    }


def check_runtime_facts(design: dict[str, Any]) -> list[dict[str, str]]:
    violations: list[dict[str, str]] = []
    facts = design.get("runtime_facts", [])
    if not isinstance(facts, list):
        return [violation("runtime_facts_not_array", "design.json#runtime_facts", "runtime_facts must be an array")]
    for index, fact in enumerate(facts):
        if not isinstance(fact, str):
            violations.append(violation("runtime_fact_not_string", f"design.json#runtime_facts[{index}]", "runtime fact must be a string"))
            continue
        evidence = evidence_value(fact)
        if not evidence or evidence in WEAK_RUNTIME_EVIDENCE:
            violations.append(violation("runtime_fact_weak_evidence", f"design.json#runtime_facts[{index}]", "runtime fact evidence must point to a reviewable source outside input_analysis/runtime_facts self-reference"))
    return violations


def check_interfaces(design: dict[str, Any]) -> list[dict[str, str]]:
    violations: list[dict[str, str]] = []
    interfaces = design.get("interfaces", [])
    boundary = design.get("interface_boundary", [])
    evidence_refs = collect_verification_refs(design)
    if not isinstance(interfaces, list):
        return [violation("interfaces_not_array", "design.json#interfaces", "interfaces must be an array")]
    if not isinstance(boundary, list) or not boundary:
        violations.append(violation("interface_boundary_missing", "design.json#interface_boundary", "interface_boundary must explain changed or unchanged interface contracts"))
    for index, interface in enumerate(interfaces):
        if not isinstance(interface, dict):
            violations.append(violation("interface_not_object", f"design.json#interfaces[{index}]", "interface must be an object"))
            continue
        behaviors = interface.get("boundary_behaviors")
        if not isinstance(behaviors, list) or not behaviors:
            violations.append(violation("interface_missing_boundary_behaviors", f"design.json#interfaces[{index}].boundary_behaviors", "changed interfaces must define boundary behaviors"))
            continue
        for behavior_index, behavior in enumerate(behaviors):
            if not isinstance(behavior, dict):
                violations.append(violation("boundary_behavior_not_object", f"design.json#interfaces[{index}].boundary_behaviors[{behavior_index}]", "boundary behavior must be an object"))
                continue
            verification_ref = behavior.get("verification_ref")
            if not isinstance(verification_ref, str) or verification_ref not in evidence_refs:
                violations.append(violation("boundary_behavior_verification_ref_unresolved", f"design.json#interfaces[{index}].boundary_behaviors[{behavior_index}].verification_ref", "boundary behavior verification_ref must resolve to verification_mapping[].evidence_ref"))
    return violations


def check_cross_cutting(design: dict[str, Any]) -> list[dict[str, str]]:
    concerns = design.get("cross_cutting_concerns", [])
    if not isinstance(concerns, list):
        return [violation("cross_cutting_not_array", "design.json#cross_cutting_concerns", "cross_cutting_concerns must be an array")]
    seen = [row.get("concern") for row in concerns if isinstance(row, dict)]
    violations: list[dict[str, str]] = []
    missing = sorted(REQUIRED_CONCERNS - {name for name in seen if isinstance(name, str)})
    extra = sorted({name for name in seen if isinstance(name, str)} - REQUIRED_CONCERNS)
    duplicates = sorted({name for name in seen if isinstance(name, str) and seen.count(name) > 1})
    if missing:
        violations.append(violation("cross_cutting_missing_concern", "design.json#cross_cutting_concerns", f"missing concerns: {missing}"))
    if extra:
        violations.append(violation("cross_cutting_unknown_concern", "design.json#cross_cutting_concerns", f"unknown concerns: {extra}"))
    if duplicates:
        violations.append(violation("cross_cutting_duplicate_concern", "design.json#cross_cutting_concerns", f"duplicate concerns: {duplicates}"))
    return violations


def check_risk_response(design: dict[str, Any]) -> list[dict[str, str]]:
    risks = design.get("risks", [])
    responses = design.get("risk_response", [])
    if not isinstance(risks, list) or not isinstance(responses, list):
        return [violation("risk_sections_not_arrays", "design.json#risks", "risks and risk_response must be arrays")]
    risk_ids = {row.get("risk_id") for row in risks if isinstance(row, dict) and isinstance(row.get("risk_id"), str)}
    response_ids = {row.get("risk_id") for row in responses if isinstance(row, dict) and isinstance(row.get("risk_id"), str)}
    return [
        violation("risk_without_response", "design.json#risk_response", f"risk has no response: {risk_id}")
        for risk_id in sorted(risk_ids - response_ids)
    ]


def check_decision_options(design: dict[str, Any]) -> list[dict[str, str]]:
    options = design.get("option_analysis", [])
    decisions = design.get("key_decisions", [])
    if not isinstance(options, list) or not isinstance(decisions, list):
        return [violation("decision_sections_not_arrays", "design.json#key_decisions", "key_decisions and option_analysis must be arrays")]
    grouped: dict[str, set[str]] = {}
    for option in options:
        if isinstance(option, dict) and isinstance(option.get("decision_ref"), str) and isinstance(option.get("option_id"), str):
            grouped.setdefault(option["decision_ref"], set()).add(option["option_id"])
    violations: list[dict[str, str]] = []
    for index, decision in enumerate(decisions):
        if not isinstance(decision, dict):
            continue
        decision_id = decision.get("decision_id")
        option_ids = grouped.get(decision_id, set()) if isinstance(decision_id, str) else set()
        if len(option_ids) < 2:
            violations.append(violation("decision_options_too_few", f"design.json#key_decisions[{index}]", f"{decision_id} has fewer than two options"))
    return violations


def check_reviewers(design: dict[str, Any]) -> list[dict[str, str]]:
    closure = design.get("review_closure", {})
    reviewers = closure.get("reviewers") if isinstance(closure, dict) else None
    if not isinstance(reviewers, list):
        return [violation("reviewers_not_array", "design.json#review_closure.reviewers", "reviewers must be an array")]
    names = [row.get("reviewer") for row in reviewers if isinstance(row, dict)]
    name_set = {name for name in names if isinstance(name, str)}
    if name_set != REQUIRED_REVIEWERS or len(names) != len(name_set):
        return [violation("reviewer_set_invalid", "design.json#review_closure.reviewers", f"expected unique reviewers {sorted(REQUIRED_REVIEWERS)}, got {names}")]
    return []


def check_design(design: dict[str, Any]) -> list[dict[str, str]]:
    violations: list[dict[str, str]] = []
    violations.extend(check_runtime_facts(design))
    violations.extend(check_interfaces(design))
    violations.extend(check_cross_cutting(design))
    violations.extend(check_risk_response(design))
    violations.extend(check_decision_options(design))
    violations.extend(check_reviewers(design))
    return violations


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--design", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    design = load_json(args.design)
    violations = check_design(design)
    if not violations:
        print(json.dumps({"status": "PASS", "checks": ["runtime_fact_evidence", "interface_boundary_behaviors", "boundary_behavior_verification_refs", "cross_cutting_exact_set", "risk_response_coverage", "decision_option_coverage", "reviewer_exact_set"]}, ensure_ascii=False, sort_keys=True))
        return 0
    for item in violations:
        print(json.dumps(item, ensure_ascii=False, sort_keys=True), file=sys.stderr)
    print(json.dumps({"status": "FAIL", "violation_count": len(violations)}, ensure_ascii=False, sort_keys=True))
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except SystemExit as exc:
        if isinstance(exc.code, tuple):
            code, message = exc.code
            print(message, file=sys.stderr)
            raise SystemExit(code) from None
        raise
