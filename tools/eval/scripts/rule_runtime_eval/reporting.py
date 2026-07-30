"""Freshness, paired comparison, and report projections for rule-runtime evidence."""

from __future__ import annotations

from pathlib import Path
from typing import Mapping

from rule_runtime_eval.common import write_json
from rule_runtime_eval.contracts import EvalCase


_FRESH_COMPLETE = frozenset({"FRESH_PASS", "BEHAVIOR_FAIL"})


def compute_freshness(record: Mapping[str, object] | None, current_identity: Mapping[str, object]) -> dict[str, object]:
    """Compute status from evidence inputs; callers cannot stamp a freshness verdict."""

    if record is None:
        return {"state": "MISSING"}
    evidence = dict(record)
    execution_state = evidence.get("execution_state")
    grading_state = evidence.get("grading_state")
    if (
        not isinstance(execution_state, str)
        or execution_state.startswith("INFRA_BLOCKED")
        or grading_state == "INFRA_BLOCKED_GRADER"
    ):
        return {**evidence, "state": "INFRA_BLOCKED"}
    if evidence.get("identity") != dict(current_identity):
        return {**evidence, "state": "STALE"}
    grading = evidence.get("grading")
    if not isinstance(grading, dict):
        return {**evidence, "state": "INFRA_BLOCKED"}
    behavior_pass = grading.get("behavior_verdict") == "PASS" and not any(
        item.get("present") is True
        for item in grading.get("blocking_failures", [])
        if isinstance(item, dict)
    )
    state = "FRESH_PASS" if evidence.get("route_pass") is True and behavior_pass else "BEHAVIOR_FAIL"
    return {**evidence, "state": state}


def compare_pair(
    case: EvalCase,
    candidate: Mapping[str, object] | None,
    baseline: Mapping[str, object] | None,
    changed_sources: tuple[str, ...],
    expected_scene_sources: tuple[str, ...],
) -> dict[str, object]:
    """Compare only fresh compatible evidence and otherwise preserve the blocking reason."""

    if candidate is None or baseline is None or candidate.get("state") == "MISSING" or baseline.get("state") == "MISSING":
        return _pair_base(case, "MISSING", candidate, baseline)
    candidate_state = candidate.get("state")
    baseline_state = baseline.get("state")
    if candidate_state == "INFRA_BLOCKED" or baseline_state == "INFRA_BLOCKED":
        return _pair_base(case, "INFRA_BLOCKED", candidate, baseline)
    if candidate_state == "STALE" or baseline_state == "STALE":
        return _pair_base(case, "STALE", candidate, baseline)
    if candidate_state not in _FRESH_COMPLETE or baseline_state not in _FRESH_COMPLETE:
        return _pair_base(case, "MISSING", candidate, baseline)
    if not _matching_comparison_identity(candidate, baseline):
        return _pair_base(case, "STALE", candidate, baseline)
    candidate_outcome = _outcome(candidate)
    baseline_outcome = _outcome(baseline)
    relevant_sources = sorted(set(changed_sources) & set(expected_scene_sources))
    attribution = None
    if candidate_outcome != baseline_outcome and relevant_sources:
        attribution = {"changed_sources": relevant_sources, "reason": "changed_sources_intersect_expected_scenes"}
    marginal_effect = (
        {"result": "observed_difference", "candidate": candidate_outcome, "baseline": baseline_outcome}
        if candidate_outcome != baseline_outcome
        else {"result": "no_observed_marginal_effect"}
    )
    return {
        **_pair_base(case, "COMPLETE", candidate, baseline),
        "candidate_outcome": candidate_outcome,
        "baseline_outcome": baseline_outcome,
        "attribution": attribution,
        "marginal_effect": marginal_effect,
        "evidence": _evidence_links(candidate, baseline),
    }


def coverage_projection(runtime_sources: tuple[str, ...], selected_evidence: list[Mapping[str, object]]) -> dict[str, object]:
    """Identify only sources that have fresh evidence through a selected case."""

    covered = {
        source
        for item in selected_evidence
        if item.get("freshness") in _FRESH_COMPLETE
        for source in item.get("sources", [])
        if isinstance(source, str)
    }
    return {
        "covered_sources": sorted(covered),
        "uncovered_sources": sorted(set(runtime_sources) - covered),
    }


def project_suite_decision(profile: Mapping[str, object], pairs: list[Mapping[str, object]]) -> dict[str, object]:
    """Project the focused-suite rule without turning it into a promotion decision."""

    complete = [pair for pair in pairs if pair.get("state") == "COMPLETE"]
    blockers: list[str] = []
    if len(complete) != 8:
        blockers.append("focused suite requires 8 complete candidate/baseline pairs")
    if any(pair.get("candidate_outcome") not in {"pass", "route_pass_behavior_fail"} for pair in complete):
        blockers.append("candidate route evidence did not pass every complete case")
    if any(_has_blocking_failure(pair.get("candidate")) for pair in complete):
        blockers.append("candidate blocking failure observed")
    average = _candidate_anchor_average(complete)
    threshold = profile.get("anchor_threshold")
    if not isinstance(threshold, (float, int)) or average is None or average < float(threshold):
        blockers.append("candidate expected-anchor average is below profile threshold")
    marginal_case = profile.get("marginal_effect_case")
    marginal = next((pair for pair in complete if pair.get("case") == marginal_case), None)
    if marginal is None or not isinstance(marginal.get("marginal_effect"), dict):
        blockers.append("named SQL marginal-effect case is incomplete")
    lightness = _lightness_projection(profile.get("lightness_policy"), complete)
    if lightness["material_regression"]:
        blockers.append("candidate has a material lightness regression")
    return {
        "verdict": "PASS" if not blockers else "FAIL",
        "scope": profile.get("id"),
        "blockers": blockers,
        "complete_pairs": len(complete),
        "candidate_anchor_average": average,
        "lightness": lightness,
    }


def render_reports(
    output_root: Path,
    decision: Mapping[str, object],
    pairs: list[Mapping[str, object]],
    coverage: Mapping[str, object],
) -> None:
    """Render machine and human projections that point back to run evidence."""

    machine = {"decision": dict(decision), "pairs": [dict(pair) for pair in pairs], "coverage": dict(coverage)}
    write_json(output_root / "summary.json", machine)
    lines = [
        "# Rule Runtime Evidence Summary",
        "",
        "## Verdict and Scope",
        "",
        f"Verdict: `{decision.get('verdict', 'UNKNOWN')}`. Scope: `{decision.get('scope', 'unknown')}`.",
        "This is a behavior-evidence projection, not a promotion decision.",
        "",
        "## Blockers",
        "",
    ]
    blockers = decision.get("blockers", [])
    lines.extend(f"- {item}" for item in blockers if isinstance(item, str))
    if not blockers:
        lines.append("- None observed within this projection.")
    lines.extend(["", "## Candidate/Baseline Case Matrix", "", "| Case | State | Candidate | Baseline | Evidence |", "| --- | --- | --- | --- | --- |"])
    for pair in pairs:
        links = pair.get("evidence", {})
        candidate_link = links.get("candidate", "") if isinstance(links, dict) else ""
        baseline_link = links.get("baseline", "") if isinstance(links, dict) else ""
        evidence = " / ".join(link for link in (candidate_link, baseline_link) if isinstance(link, str) and link)
        lines.append(
            f"| {pair.get('case', 'unknown')} | {pair.get('state', 'unknown')} | "
            f"{pair.get('candidate_outcome', 'n/a')} | {pair.get('baseline_outcome', 'n/a')} | {evidence or 'n/a'} |"
        )
    lines.extend(["", "## Changed-Source Attribution", ""])
    attributions = [pair for pair in pairs if pair.get("attribution")]
    if attributions:
        lines.extend(f"- {pair.get('case')}: {pair.get('attribution')}" for pair in attributions)
    else:
        lines.append("- No attributable difference was observed in complete fresh pairs.")
    lines.extend(["", "## Coverage/Freshness", "", f"- Fresh-covered runtime sources: {len(coverage.get('covered_sources', []))}", f"- Runtime sources without fresh selected evidence: {', '.join(coverage.get('uncovered_sources', [])) or 'none'}", "", "## Risks, Unknowns and Next Decision", "", "- Missing, stale, or infrastructure-blocked evidence remains unresolved evidence, not behavior attribution.", "- Review the linked run evidence before any separately governed next decision.", ""])
    (output_root / "summary.md").parent.mkdir(parents=True, exist_ok=True)
    (output_root / "summary.md").write_text("\n".join(lines), encoding="utf-8")


def _pair_base(case: EvalCase, state: str, candidate: Mapping[str, object] | None, baseline: Mapping[str, object] | None) -> dict[str, object]:
    return {
        "case": f"{case.pack_id}:{case.id}",
        "state": state,
        "candidate": candidate,
        "baseline": baseline,
        "attribution": None,
        "evidence": _evidence_links(candidate, baseline),
    }


def _matching_comparison_identity(candidate: Mapping[str, object], baseline: Mapping[str, object]) -> bool:
    candidate_identity = candidate.get("identity")
    baseline_identity = baseline.get("identity")
    if not isinstance(candidate_identity, dict) or not isinstance(baseline_identity, dict):
        return False
    return all(candidate_identity.get(key) == baseline_identity.get(key) for key in ("case", "grader", "model", "reasoning"))


def _outcome(record: Mapping[str, object]) -> str:
    grading = record.get("grading")
    behavior_pass = isinstance(grading, dict) and grading.get("behavior_verdict") == "PASS" and not _has_blocking_failure(record)
    route_pass = record.get("route_pass") is True
    if route_pass and behavior_pass:
        return "pass"
    if not route_pass and behavior_pass:
        return "behavior_pass_route_fail"
    if route_pass:
        return "route_pass_behavior_fail"
    return "route_and_behavior_fail"


def _has_blocking_failure(record: object) -> bool:
    if not isinstance(record, Mapping):
        return False
    grading = record.get("grading")
    return isinstance(grading, Mapping) and any(
        item.get("present") is True for item in grading.get("blocking_failures", []) if isinstance(item, Mapping)
    )


def _candidate_anchor_average(pairs: list[Mapping[str, object]]) -> float | None:
    scores = [
        anchor.get("score")
        for pair in pairs
        for anchor in _anchors(pair.get("candidate"))
        if isinstance(anchor.get("score"), int)
    ]
    return round(sum(scores) / len(scores), 4) if scores else None


def _anchors(record: object) -> list[Mapping[str, object]]:
    if not isinstance(record, Mapping) or not isinstance(record.get("grading"), Mapping):
        return []
    anchors = record["grading"].get("anchors", [])
    return [anchor for anchor in anchors if isinstance(anchor, Mapping)] if isinstance(anchors, list) else []


def _lightness_projection(policy: object, pairs: list[Mapping[str, object]]) -> dict[str, object]:
    if not isinstance(policy, Mapping):
        return {"material_regression": True, "reason": "focused profile lightness policy is invalid"}
    pair = next((item for item in pairs if item.get("case") == policy.get("case")), None)
    if pair is None:
        return {"material_regression": True, "reason": "lightness case is incomplete"}
    candidate = pair.get("candidate")
    baseline = pair.get("baseline")
    if not isinstance(candidate, Mapping) or not isinstance(baseline, Mapping):
        return {"material_regression": True, "reason": "lightness pair is incomplete"}
    read_delta = int(candidate.get("irrelevant_successful_reads", 0)) - int(baseline.get("irrelevant_successful_reads", 0))
    candidate_length = int(candidate.get("response_characters", 0))
    baseline_length = int(baseline.get("response_characters", 0))
    ratio = float("inf") if baseline_length == 0 and candidate_length else (candidate_length / baseline_length if baseline_length else 1.0)
    grading = candidate.get("grading")
    ceremony = isinstance(grading, Mapping) and grading.get("added_ceremony_without_decision_value") is True
    read_regression = read_delta > int(policy.get("max_irrelevant_read_delta", 0))
    response_regression = ratio > float(policy.get("max_response_length_ratio", 1)) and (
        not policy.get("requires_grader_ceremony_signal", False) or ceremony
    )
    return {"material_regression": read_regression or response_regression, "irrelevant_successful_read_delta": read_delta, "response_length_ratio": ratio, "added_ceremony_without_decision_value": ceremony}


def _evidence_links(
    candidate: Mapping[str, object] | None, baseline: Mapping[str, object] | None
) -> dict[str, str]:
    return {
        "candidate": _relative_evidence(candidate.get("evidence_path") if candidate is not None else None),
        "baseline": _relative_evidence(baseline.get("evidence_path") if baseline is not None else None),
    }


def _relative_evidence(value: object) -> str:
    return str(value) if isinstance(value, str) else ""
