#!/usr/bin/env python3
"""Deterministic content-quality evaluator for Product Director artifacts."""

from __future__ import annotations

# pyright: reportMissingImports=false
import argparse
import json
import sys
from pathlib import Path
from typing import Any

from content_quality_common import (
    CAUSE_TERMS,
    COST_TERMS,
    DOWNSTREAM_RISK_TERMS,
    ENTRY_GATE_TERMS,
    EXIT_PLANNING_TERMS,
    FORBIDDEN_BRIEF_FIELDS,
    FORBIDDEN_PHASE_FIELDS,
    GENERIC_SUMMARY_TERMS,
    MAX_DIMENSION_SCORE,
    NOISE_TERMS,
    REPEATED_TOKEN_RE,
    TARGET_TERMS,
    TIME_TERMS,
    as_list,
    dimension,
    has_any,
    has_number,
    load_json,
    lower_text,
    text_of,
)


def known_roles(brief: dict[str, Any]) -> list[str]:
    roles: list[str] = []
    for profile in as_list(brief.get("user_profile")):
        if isinstance(profile, dict) and isinstance(profile.get("who"), str):
            roles.append(profile["who"].lower())
    return roles


def root_problem_quality(brief: dict[str, Any]) -> dict[str, Any]:
    root_problem = str(brief.get("root_problem") or "")
    text = root_problem.lower()
    roles = known_roles(brief)
    names_role = bool(roles) and any(role in text for role in roles)
    has_cause = has_any(text, CAUSE_TERMS)
    has_cost = has_any(text, COST_TERMS)
    evidence: list[str] = []
    issues: list[str] = []
    if names_role:
        evidence.append("root problem names the affected role from user_profile")
    else:
        issues.append("root problem must name the affected role")
    if has_cause:
        evidence.append("root problem explains the causal mechanism")
    else:
        issues.append("root problem must explain why the problem happens")
    if has_cost:
        evidence.append("root problem states observable cost")
    else:
        issues.append("root problem must state observable cost")
    return dimension(
        "root_problem_quality", [names_role, has_cause, has_cost], evidence, issues
    )


def success_standard_quality(
    brief: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    goals = text_of(brief.get("business_goals"))
    success_terms = ("success", "成功", "目标", "投入", "appetite", "investment")
    success_checkpoints = [
        item
        for item in as_list(ledger.get("confirmations"))
        if isinstance(item, dict)
        and any(
            term in f"{item.get('step', '')} {item.get('decision_summary', '')}".lower()
            for term in success_terms
        )
    ]
    ledger_text = lower_text(success_checkpoints)
    text = goals.lower()
    measurable = has_number(text) and has_any(text, TARGET_TERMS)
    has_time_window = has_any(text, TIME_TERMS)
    checkpoint_preserved = (
        bool(success_checkpoints)
        and has_number(ledger_text)
        and has_any(ledger_text, TIME_TERMS)
    )
    evidence: list[str] = []
    issues: list[str] = []
    if measurable:
        evidence.append("business goals include numeric baseline or target")
    else:
        issues.append("business goals must include numeric baseline or target")
    if has_time_window:
        evidence.append("business goals include an observation window")
    else:
        issues.append("business goals must include an observation window")
    if checkpoint_preserved:
        evidence.append("ledger preserves the success-standard checkpoint")
    else:
        issues.append("ledger must preserve the success-standard checkpoint")
    return dimension(
        "success_standard_quality",
        [measurable, has_time_window, checkpoint_preserved],
        evidence,
        issues,
    )


def scope_tradeoff_quality(brief: dict[str, Any]) -> dict[str, Any]:
    scope_count = len(as_list(brief.get("scope_boundaries")))
    non_goal_count = len(as_list(brief.get("non_goals")))
    rationale_text = lower_text(brief.get("decision_rationale"))
    has_exclusions = any(
        isinstance(item, dict) and item.get("excluded_options")
        for item in as_list(brief.get("decision_rationale"))
    ) or has_any(rationale_text, ("out", "不", "排除"))
    checks = [scope_count >= 3, non_goal_count >= 3, has_exclusions]
    evidence: list[str] = []
    issues: list[str] = []
    evidence.append(f"scope_boundaries={scope_count}, non_goals={non_goal_count}")
    if not checks[0]:
        issues.append("scope must define the minimum business loop")
    if not checks[1]:
        issues.append("non-goals must exclude adjacent value")
    if has_exclusions:
        evidence.append("decision rationale records excluded options")
    else:
        issues.append("decision rationale must record excluded options")
    return dimension("scope_tradeoff_quality", checks, evidence, issues)


def risk_judgment_quality(brief: dict[str, Any]) -> dict[str, Any]:
    risks = as_list(brief.get("risks_and_unknowns"))
    risk_text = lower_text(risks)
    closed = bool(risks) and all(
        str(item.get("status", "")).upper() != "OPEN"
        for item in risks
        if isinstance(item, dict)
    )
    impact_is_bounded = has_any(
        risk_text, ("phase", "scope", "baseline", "范围", "阶段")
    )
    no_downstream_risk = not has_any(risk_text, DOWNSTREAM_RISK_TERMS)
    evidence: list[str] = []
    issues: list[str] = []
    if closed:
        evidence.append("risks are resolved or bounded before finalization")
    else:
        issues.append("risks must be resolved or explicitly bounded before finalization")
    if impact_is_bounded:
        evidence.append("risk impact is tied to phase, scope, or baseline")
    else:
        issues.append("risk impact must state phase, scope, or baseline impact")
    if no_downstream_risk:
        evidence.append("risk wording avoids downstream execution ownership")
    else:
        issues.append(
            "risk wording must not push downstream execution risk to later roles"
        )
    return dimension(
        "risk_judgment_quality",
        [closed, impact_is_bounded, no_downstream_risk],
        evidence,
        issues,
    )


def delivery_timebox_ok(brief: dict[str, Any]) -> bool:
    plans = as_list(brief.get("delivery_plan"))
    values = [
        item.get("iteration_timebox_days") for item in plans if isinstance(item, dict)
    ]
    return bool(values) and all(
        isinstance(value, int) and 1 <= value <= 14 for value in values
    )


def phase_value_slice_quality(
    brief: dict[str, Any], phase: dict[str, Any]
) -> dict[str, Any]:
    entry_text = lower_text(phase.get("entry_conditions"))
    exit_text = f" {lower_text(phase.get('exit_conditions'))} "
    timebox_ok = delivery_timebox_ok(brief)
    entry_is_business_fact = not has_any(entry_text, ENTRY_GATE_TERMS)
    exit_is_business_state = not has_any(exit_text, EXIT_PLANNING_TERMS)
    issues: list[str] = []
    evidence: list[str] = []
    if timebox_ok:
        evidence.append("phase timebox stays within 1-14 days")
    else:
        issues.append("phase timebox must stay within 1-14 days")
    if entry_is_business_fact:
        evidence.append("phase entry conditions are business facts")
    else:
        issues.append("phase entry conditions must be business facts, not gate status")
    if exit_is_business_state:
        evidence.append("phase exit conditions are business states")
    else:
        issues.append(
            "phase exit conditions must be business states, not planning constraints"
        )
    return dimension(
        "phase_value_slice_quality",
        [timebox_ok, entry_is_business_fact, exit_is_business_state],
        evidence,
        issues,
        must_fail=not entry_is_business_fact or not exit_is_business_state,
    )


def finalization_trace_quality(
    brief: dict[str, Any], phase: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    refs = as_list(ledger.get("handoff_refs"))
    raw_basis = ledger.get("finalization_basis")
    basis: dict[str, Any] = raw_basis if isinstance(raw_basis, dict) else {}
    accepted = as_list(basis.get("accepted_checkpoint_ids"))
    confirmations = as_list(ledger.get("confirmations"))
    has_artifact_refs = any(str(ref).endswith("/brief.json") for ref in refs) and any(
        str(ref).endswith("/phase-prd.json") for ref in refs
    )
    finalized = basis.get("status") == "confirmed" and bool(accepted)
    checkpoints_covered = (
        len(accepted) == len(confirmations) and len(confirmations) >= 6
    )
    evidence: list[str] = []
    issues: list[str] = []
    if has_artifact_refs:
        evidence.append("ledger refs include brief and phase-prd")
    else:
        issues.append("ledger refs must include brief and phase-prd")
    if finalized and checkpoints_covered:
        evidence.append("ledger finalization covers all Director checkpoints")
    else:
        issues.append("ledger finalization must cover all Director checkpoints")
    return dimension(
        "finalization_trace_quality",
        [has_artifact_refs, finalized and checkpoints_covered],
        evidence,
        issues,
    )


def language_and_noise_quality(
    brief: dict[str, Any], phase: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    forbidden = [field for field in FORBIDDEN_BRIEF_FIELDS if field in brief]
    forbidden.extend(field for field in FORBIDDEN_PHASE_FIELDS if field in phase)
    all_text = lower_text([brief, phase, ledger])
    summaries = [
        str(item.get("decision_summary", ""))
        for item in as_list(ledger.get("confirmations"))
        if isinstance(item, dict)
    ]
    generic_summaries = [
        item for item in summaries if has_any(item.lower(), GENERIC_SUMMARY_TERMS)
    ]
    no_forbidden_fields = not forbidden
    no_noise_terms = not has_any(all_text, NOISE_TERMS)
    no_repeated_tokens = not REPEATED_TOKEN_RE.search(all_text)
    substantive_ledger = not generic_summaries
    evidence: list[str] = []
    issues: list[str] = []
    if no_forbidden_fields:
        evidence.append("artifacts avoid downstream-only fields")
    else:
        issues.append(
            f"artifacts contain downstream-only fields: {', '.join(sorted(forbidden))}"
        )
    if no_noise_terms:
        evidence.append("artifacts avoid placeholders and TBD/TODO language")
    else:
        issues.append("artifacts must not contain placeholder language")
    if no_repeated_tokens:
        evidence.append("artifacts avoid repeated keyword stuffing")
    else:
        issues.append("artifacts must not rely on repeated keyword stuffing")
    if substantive_ledger:
        evidence.append("ledger summaries are substantive")
    else:
        issues.append(
            "ledger summaries must be substantive, not generic step confirmations"
        )
    return dimension(
        "language_and_noise_quality",
        [no_forbidden_fields, no_noise_terms, no_repeated_tokens, substantive_ledger],
        evidence,
        issues,
        must_fail=not no_forbidden_fields
        or not no_noise_terms
        or not no_repeated_tokens
        or not substantive_ledger,
    )


def evaluate(
    brief: dict[str, Any], phase: dict[str, Any], ledger: dict[str, Any], min_score: int
) -> dict[str, Any]:
    dimensions = [
        root_problem_quality(brief),
        success_standard_quality(brief, ledger),
        scope_tradeoff_quality(brief),
        risk_judgment_quality(brief),
        phase_value_slice_quality(brief, phase),
        finalization_trace_quality(brief, phase, ledger),
        language_and_noise_quality(brief, phase, ledger),
    ]
    score = sum(item["score"] for item in dimensions)
    max_score = len(dimensions) * MAX_DIMENSION_SCORE
    failures = [issue for item in dimensions for issue in item["issues"]]
    if score < min_score:
        failures.append(f"content quality score {score} is below threshold {min_score}")
    verdict = "FAIL" if failures else "PASS"
    return {
        "artifact_type": "product-director-content-quality-evaluation",
        "verdict": verdict,
        "score": score,
        "max_score": max_score,
        "threshold": min_score,
        "dimensions": dimensions,
        "failures": failures,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Evaluate Product Director content quality."
    )
    parser.add_argument("--brief", required=True, type=Path)
    parser.add_argument("--phase-prd", required=True, type=Path)
    parser.add_argument("--ledger", required=True, type=Path)
    parser.add_argument("--min-score", default=12, type=int)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = evaluate(
        load_json(args.brief),
        load_json(args.phase_prd),
        load_json(args.ledger),
        args.min_score,
    )
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
