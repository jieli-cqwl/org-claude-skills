#!/usr/bin/env python3
"""Deterministic content-quality evaluator for Product Director artifacts.

This is a quality proxy, not a semantic oracle. It checks observable signals
that production-ready Director outputs must carry before downstream handoff.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

MAX_DIMENSION_SCORE = 2


def terms(value: str) -> tuple[str, ...]:
    return tuple(value.split("|"))


FORBIDDEN_BRIEF_FIELDS = terms(
    "acceptance_criteria|design_decisions|non_functional_requirements|"
    "business_flows|user_paths|rule_mappings|semantic_draft|"
    "business_semantics_draft|semantics_gaps|review_conclusion|"
    "issue_ledger|delivery_confirmation"
)
FORBIDDEN_PHASE_FIELDS = terms(
    "review_conclusion|issue_ledger|business_flows|user_paths|rule_mappings|"
    "unit_priority_order|semantic_draft|business_semantics_draft|semantics_gaps|"
    "design_decision_candidates"
)
CAUSE_TERMS = terms("because|causing|由于|因为|导致|源于|造成|使得|来自")
COST_TERMS = terms("causing|cost|miss|delay|slow|rework|成本|延迟|遗漏|返工|漏跟进|超时|等待|重复")
TIME_TERMS = ("day", "week", "month", "window", "天", "周", "月", "周期")
TARGET_TERMS = ("zero", "reduce", "increase", "from", "to", "低于", "达到", "从", "降到", "提升", "降低", "消除", "缩短", "以内")
ENTRY_GATE_TERMS = ("director baseline confirmed", "gate", "passed", "确认门", "门禁")
EXIT_PLANNING_TERMS = terms(
    "timebox|10-day|complete design|complete development|"
    "acceptance criteria| ac |完成设计|完成开发"
)
DOWNSTREAM_RISK_TERMS = ("downstream execution risk", "下游执行风险")
GENERIC_SUMMARY_TERMS = (" confirmed for ", "已确认完成", "完成确认")
NOISE_TERMS = ("tbd", "todo", "待补", "待定", "anything vague", "make the process better")
REPEATED_TOKEN_RE = re.compile(r"\b([a-z]{3,})\s+\1\b")


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"{path}: file not found") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: artifact must be a JSON object")
    return data


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def text_of(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(text_of(item) for item in value)
    if isinstance(value, dict):
        return " ".join(text_of(item) for item in value.values())
    return ""


def lower_text(value: Any) -> str:
    return text_of(value).lower()


def has_any(text: str, terms: tuple[str, ...]) -> bool:
    return any(term in text for term in terms)


def has_number(text: str) -> bool:
    return bool(re.search(r"\d", text))


def dimension(
    dimension_id: str,
    checks: list[bool],
    evidence: list[str],
    issues: list[str],
    *,
    must_fail: bool = False,
) -> dict[str, Any]:
    passed = sum(1 for item in checks if item)
    score = MAX_DIMENSION_SCORE if passed == len(checks) else 1 if passed else 0
    if must_fail:
        score = 0
    return {
        "id": dimension_id,
        "score": score,
        "max_score": MAX_DIMENSION_SCORE,
        "evidence": evidence,
        "issues": issues,
        "must_fail": must_fail or bool(issues),
    }


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
    return dimension("root_problem_quality", [names_role, has_cause, has_cost], evidence, issues)


def success_standard_quality(
    brief: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    goals = text_of(brief.get("business_goals"))
    success_checkpoints = [item for item in as_list(ledger.get("confirmations")) if isinstance(item, dict) and ("D-S3" in str(item.get("step", "")) or "success" in str(item.get("decision_summary", "")).lower() or "成功" in str(item.get("decision_summary", "")))]
    ledger_text = lower_text(success_checkpoints)
    text = goals.lower()
    measurable = has_number(text) and has_any(text, TARGET_TERMS)
    has_time_window = has_any(text, TIME_TERMS)
    checkpoint_preserved = bool(success_checkpoints) and has_number(ledger_text) and has_any(ledger_text, TIME_TERMS)
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
    has_exclusions = any(isinstance(item, dict) and item.get("excluded_options") for item in as_list(brief.get("decision_rationale"))) or has_any(rationale_text, ("out", "不", "排除"))
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
    impact_is_bounded = has_any(risk_text, ("phase", "scope", "baseline", "范围", "阶段"))
    no_downstream_risk = not has_any(risk_text, DOWNSTREAM_RISK_TERMS)
    evidence: list[str] = []
    issues: list[str] = []
    if closed:
        evidence.append("risks are resolved or bounded before handoff")
    else:
        issues.append("risks must be resolved or explicitly bounded before handoff")
    if impact_is_bounded:
        evidence.append("risk impact is tied to phase, scope, or baseline")
    else:
        issues.append("risk impact must state phase, scope, or baseline impact")
    if no_downstream_risk:
        evidence.append("risk wording avoids downstream execution ownership")
    else:
        issues.append("risk wording must not push downstream execution risk to later roles")
    return dimension("risk_judgment_quality", [closed, impact_is_bounded, no_downstream_risk], evidence, issues)


def delivery_timebox_ok(brief: dict[str, Any]) -> bool:
    plans = as_list(brief.get("delivery_plan"))
    values = [
        item.get("iteration_timebox_days")
        for item in plans
        if isinstance(item, dict)
    ]
    return bool(values) and all(isinstance(value, int) and 1 <= value <= 14 for value in values)


def phase_value_slice_quality(
    brief: dict[str, Any], phase: dict[str, Any]
) -> dict[str, Any]:
    entry_text = lower_text(phase.get("entry_conditions"))
    exit_text = f" {lower_text(phase.get('exit_conditions'))} "
    timebox_ok = delivery_timebox_ok(brief)
    entry_is_business_fact = not has_any(entry_text, ENTRY_GATE_TERMS)
    exit_is_business_state = not has_any(exit_text, EXIT_PLANNING_TERMS)
    unit_index_empty = as_list(phase.get("unit_index")) == []
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
        issues.append("phase exit conditions must be business states, not planning constraints")
    if unit_index_empty:
        evidence.append("Director phase-prd leaves unit_index empty")
    else:
        issues.append("Director phase-prd must leave unit_index empty")
    return dimension(
        "phase_value_slice_quality",
        [timebox_ok, entry_is_business_fact, exit_is_business_state, unit_index_empty],
        evidence,
        issues,
        must_fail=not entry_is_business_fact or not exit_is_business_state or not unit_index_empty,
    )


def locked_fields_match(artifact: dict[str, Any]) -> bool:
    confirmation = artifact.get("director_confirmation")
    if not isinstance(confirmation, dict):
        return False
    locked = confirmation.get("locked_fields")
    if not isinstance(locked, dict):
        return False
    return all(artifact.get(key) == value for key, value in locked.items())


def handoff_consumability_quality(
    brief: dict[str, Any], phase: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    refs = as_list(ledger.get("handoff_refs"))
    basis = ledger.get("finalization_basis") if isinstance(ledger.get("finalization_basis"), dict) else {}
    accepted = as_list(basis.get("accepted_checkpoint_ids"))
    confirmations = as_list(ledger.get("confirmations"))
    has_artifact_refs = any(str(ref).endswith("/brief.json") for ref in refs) and any(
        str(ref).endswith("/phase-prd.json") for ref in refs
    )
    finalized = basis.get("status") == "confirmed" and bool(accepted)
    locks_match = locked_fields_match(brief) and locked_fields_match(phase)
    checkpoints_covered = len(accepted) == len(confirmations) and len(confirmations) >= 6
    evidence: list[str] = []
    issues: list[str] = []
    if has_artifact_refs:
        evidence.append("ledger handoff_refs include brief and phase-prd")
    else:
        issues.append("ledger handoff_refs must include brief and phase-prd")
    if finalized and checkpoints_covered:
        evidence.append("ledger finalization covers all Director checkpoints")
    else:
        issues.append("ledger finalization must cover all Director checkpoints")
    if locks_match:
        evidence.append("director locked_fields match artifact fields")
    else:
        issues.append("director locked_fields must match artifact fields")
    return dimension(
        "handoff_consumability_quality",
        [has_artifact_refs, finalized and checkpoints_covered, locks_match],
        evidence,
        issues,
    )


def language_and_noise_quality(
    brief: dict[str, Any], phase: dict[str, Any], ledger: dict[str, Any]
) -> dict[str, Any]:
    forbidden = [field for field in FORBIDDEN_BRIEF_FIELDS if field in brief]
    forbidden.extend(field for field in FORBIDDEN_PHASE_FIELDS if field in phase)
    all_text = lower_text([brief, phase, ledger])
    summaries = [str(item.get("decision_summary", "")) for item in as_list(ledger.get("confirmations")) if isinstance(item, dict)]
    generic_summaries = [item for item in summaries if has_any(item.lower(), GENERIC_SUMMARY_TERMS)]
    no_forbidden_fields = not forbidden
    no_noise_terms = not has_any(all_text, NOISE_TERMS)
    no_repeated_tokens = not REPEATED_TOKEN_RE.search(all_text)
    substantive_ledger = not generic_summaries
    evidence: list[str] = []
    issues: list[str] = []
    if no_forbidden_fields:
        evidence.append("artifacts avoid downstream-only fields")
    else:
        issues.append(f"artifacts contain downstream-only fields: {', '.join(sorted(forbidden))}")
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
        issues.append("ledger summaries must be substantive, not generic step confirmations")
    return dimension(
        "language_and_noise_quality",
        [no_forbidden_fields, no_noise_terms, no_repeated_tokens, substantive_ledger],
        evidence,
        issues,
        must_fail=not no_forbidden_fields or not no_noise_terms or not no_repeated_tokens or not substantive_ledger,
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
        handoff_consumability_quality(brief, phase, ledger),
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
    parser = argparse.ArgumentParser(description="Evaluate Product Director content quality.")
    parser.add_argument("--brief", required=True, type=Path)
    parser.add_argument("--phase-prd", required=True, type=Path)
    parser.add_argument("--ledger", required=True, type=Path)
    parser.add_argument("--min-score", default=12, type=int)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = evaluate(load_json(args.brief), load_json(args.phase_prd), load_json(args.ledger), args.min_score)
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
