#!/usr/bin/env python3
"""Validate skill-quality-audit empirical baseline artifacts."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

REQUIRED_READINESS = {
    "Scenario Capability",
    "Structure-Content Coherence",
    "Evidence Integrity",
    "Repairable Handoff",
    "Attention Economy",
}
RUN_MODES = ("with_skill", "without_skill")
PILOT_STATUS = "pilot_empirical_sample_recorded"


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"{path}: file does not exist")
    except json.JSONDecodeError as exc:
        fail(f"{path}: invalid JSON: {exc}")
    require(isinstance(data, dict), f"{path}: must be a JSON object")
    return data


def resolve_path(path_text: str, root: Path) -> Path:
    path = Path(path_text)
    return path if path.is_absolute() else root / path


def is_under(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def require_text(value: Any, label: str) -> str:
    require(isinstance(value, str) and value.strip(), f"{label} is required")
    return str(value)


def require_number(value: Any, label: str) -> float:
    require(isinstance(value, (int, float)), f"{label} must be numeric")
    number = float(value)
    require(0 <= number <= 1, f"{label} must be between 0 and 1")
    return number


def require_existing_text_file(path_text: Any, label: str, root: Path) -> Path:
    value = require_text(path_text, label)
    path = resolve_path(value, root)
    require(path.is_file(), f"{label} must exist")
    require(path.read_text(encoding="utf-8").strip(), f"{label} must be non-empty")
    return path


def validate_run_ref(case_id: str, run_mode: str, run: Any, root: Path) -> None:
    require(isinstance(run, dict), f"{case_id} missing {run_mode}")
    output_text = require_text(run.get("output_dir"), f"{case_id}.{run_mode}.output_dir")
    summary_text = require_text(run.get("summary_ref"), f"{case_id}.{run_mode}.summary_ref")
    output_dir = resolve_path(output_text, root)
    summary_ref = resolve_path(summary_text, root)
    require(summary_ref.name == "summary.json", f"{case_id}.{run_mode}.summary_ref must end with summary.json")
    require(is_under(summary_ref, output_dir), f"{case_id}.{run_mode}.summary_ref must live under output_dir")


def validate_case(case: Any, index: int, seen: set[str], root: Path) -> dict[str, Any]:
    require(isinstance(case, dict), f"cases[{index}] must be an object")
    case_id = require_text(case.get("id"), f"cases[{index}].id")
    require(case_id not in seen, f"duplicate case id: {case_id}")
    seen.add(case_id)
    target_skill = require_text(case.get("target_skill"), f"{case_id}.target_skill")
    require(resolve_path(target_skill, root).exists(), f"{case_id}.target_skill missing: {target_skill}")
    require_text(case.get("prompt"), f"{case_id}.prompt")
    readiness_checks = case.get("readiness_checks")
    require(isinstance(readiness_checks, list), f"{case_id}.readiness_checks must be an array")
    missing = sorted(REQUIRED_READINESS - set(readiness_checks))
    require(not missing, f"{case_id} missing readiness checks: {missing}")
    for run_mode in RUN_MODES:
        validate_run_ref(case_id, run_mode, case.get(run_mode), root)
    return case


def validate_plan(plan: dict[str, Any], lifecycle: dict[str, Any], root: Path) -> list[dict[str, Any]]:
    require(plan.get("artifact_type") == "skill-quality-audit-empirical-baseline-plan", "plan artifact_type drift")
    require(plan.get("readiness_target") == "team-ready", "plan.readiness_target must be team-ready")
    minimum = plan.get("minimum_real_skill_reviews")
    require(isinstance(minimum, int) and minimum >= 2, "plan.minimum_real_skill_reviews must be >= 2")
    require_text(plan.get("delta_review_ref"), "plan.delta_review_ref")
    validate_plan_gate(plan.get("team_ready_gate"))
    expected = lifecycle.get("capability_uplift", {}).get("grader_dimensions")
    require(plan.get("grader_dimensions") == expected, "plan.grader_dimensions must match lifecycle capability_uplift")
    cases = plan.get("cases")
    require(isinstance(cases, list) and len(cases) >= minimum, "plan.cases must meet minimum_real_skill_reviews")
    seen: set[str] = set()
    return [validate_case(case, index, seen, root) for index, case in enumerate(cases)]


def validate_plan_gate(gate: Any) -> None:
    require(isinstance(gate, dict), "plan.team_ready_gate must be an object")
    require_number(gate.get("min_with_skill_anchor_fidelity"), "plan.team_ready_gate.min_with_skill_anchor_fidelity")
    max_failures = gate.get("max_infra_failures")
    require(isinstance(max_failures, int) and max_failures >= 0, "plan.team_ready_gate.max_infra_failures must be >= 0")
    for field in (
        "requires_human_delta_review",
        "requires_validator_pass_for_with_skill_reports",
        "requires_without_skill_delta",
    ):
        require(gate.get(field) is True, f"plan.team_ready_gate.{field} must be true")


def validate_pending_lifecycle(plan_path: Path, lifecycle: dict[str, Any]) -> None:
    evidence_refs = lifecycle.get("evidence_refs", [])
    refs_text = " ".join(str(ref) for ref in evidence_refs)
    require(
        str(plan_path) in evidence_refs or "empirical-baseline/plan.json" in refs_text,
        "lifecycle.evidence_refs must include empirical baseline plan",
    )
    status = lifecycle.get("capability_uplift", {}).get("measurement_status")
    require(status in {"needs_empirical_baseline", PILOT_STATUS}, "capability_uplift.measurement_status is invalid")


def validate_summary(path_text: str, case: dict[str, Any], run_mode: str, root: Path) -> dict[str, Any]:
    path = resolve_path(path_text, root)
    summary = load_json(path)
    label = f"{case['id']}.{run_mode}.summary"
    require(summary.get("artifact_type") == "skill-quality-audit-empirical-run-summary", f"{label}.artifact_type drift")
    require(summary.get("case_id") == case["id"], f"{label}.case_id mismatch")
    require(summary.get("run_mode") == run_mode, f"{label}.run_mode mismatch")
    require(summary.get("target_skill") == case["target_skill"], f"{label}.target_skill mismatch")
    require(summary.get("graded") is True, f"{label}.graded must be true")
    pass_rate = require_number(summary.get("pass_rate"), f"{label}.pass_rate")
    anchor_passed = summary.get("anchor_passed")
    anchor_total = summary.get("anchor_total")
    require(isinstance(anchor_passed, int) and isinstance(anchor_total, int), f"{label}.anchor counts must be integers")
    require(0 <= anchor_passed <= anchor_total and anchor_total > 0, f"{label}.anchor counts are invalid")
    require(abs(pass_rate - (anchor_passed / anchor_total)) < 0.0001, f"{label}.pass_rate must match anchors")
    infra_failures = summary.get("infra_failures")
    require(isinstance(infra_failures, int) and infra_failures >= 0, f"{label}.infra_failures must be >= 0")
    checks = summary.get("readiness_checks")
    require(isinstance(checks, dict), f"{label}.readiness_checks must be an object")
    missing = sorted(set(case["readiness_checks"]) - set(checks))
    require(not missing, f"{label}.readiness_checks missing: {missing}")
    require_existing_text_file(summary.get("raw_output_ref"), f"{label}.raw_output_ref", root)
    if run_mode == "with_skill":
        require(summary.get("validator_status") == "PASS", f"{label}.validator_status must be PASS")
        report_ref = require_text(summary.get("formal_report_ref"), f"{label}.formal_report_ref")
        validate_formal_report(report_ref, case, label, root)
        not_passed = [name for name in case["readiness_checks"] if checks.get(name) != "PASS"]
        require(not not_passed, f"{label}.readiness_checks must all PASS: {not_passed}")
    else:
        require(summary.get("validator_status") == "NOT_APPLICABLE", f"{label}.validator_status must be NOT_APPLICABLE")
        require(summary.get("formal_report_ref") in {None, ""}, f"{label}.formal_report_ref must be empty")
    return summary


def validate_formal_report(path_text: str, case: dict[str, Any], label: str, root: Path) -> None:
    path = resolve_path(path_text, root)
    require(path.is_file(), f"{label}.formal_report_ref must exist")
    validator = Path(__file__).with_name("validate_skill_audit_report.py")
    result = subprocess.run(
        [sys.executable, str(validator), str(path)],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    output = (result.stdout + result.stderr).strip()
    require(
        result.returncode == 0,
        f"{label}.formal_report_ref failed validate_skill_audit_report.py: {output}",
    )
    report = load_json(path)
    require(
        report.get("target_skill") == case["target_skill"],
        f"{label}.formal_report_ref target_skill mismatch",
    )


def collect_summaries(cases: list[dict[str, Any]], root: Path) -> dict[str, dict[str, dict[str, Any]]]:
    summaries: dict[str, dict[str, dict[str, Any]]] = {}
    for case in cases:
        case_summaries: dict[str, dict[str, Any]] = {}
        for run_mode in RUN_MODES:
            case_summaries[run_mode] = validate_summary(case[run_mode]["summary_ref"], case, run_mode, root)
        summaries[case["id"]] = case_summaries
    return summaries


def average(summaries: dict[str, dict[str, dict[str, Any]]], run_mode: str) -> float:
    values = [float(item[run_mode]["pass_rate"]) for item in summaries.values()]
    return round(sum(values) / len(values), 4)


def with_anchor_counts(summaries: dict[str, dict[str, dict[str, Any]]]) -> tuple[int, int]:
    passed = sum(item["with_skill"]["anchor_passed"] for item in summaries.values())
    total = sum(item["with_skill"]["anchor_total"] for item in summaries.values())
    return passed, total


def with_anchor_fidelity(summaries: dict[str, dict[str, dict[str, Any]]]) -> float:
    passed, total = with_anchor_counts(summaries)
    return round(passed / total, 4)


def total_infra_failures(summaries: dict[str, dict[str, dict[str, Any]]]) -> int:
    return sum(item[mode]["infra_failures"] for item in summaries.values() for mode in RUN_MODES)


def validate_delta_review(
    plan: dict[str, Any],
    cases: list[dict[str, Any]],
    summaries: dict[str, dict[str, dict[str, Any]]],
    root: Path,
) -> dict[str, Any]:
    delta = load_json(resolve_path(plan["delta_review_ref"], root))
    require(delta.get("artifact_type") == "skill-quality-audit-empirical-delta-review", "delta_review.artifact_type drift")
    require(delta.get("measurement_status") == "completed_human_delta_review", "delta_review.measurement_status invalid")
    reviewed = delta.get("reviewed_cases")
    require(isinstance(reviewed, list), "delta_review.reviewed_cases must be an array")
    reviewed_ids = {item.get("case_id") for item in reviewed if isinstance(item, dict)}
    case_ids = {case["id"] for case in cases}
    require(reviewed_ids == case_ids, "delta_review.reviewed_cases must cover all plan cases")
    for item in reviewed:
        validate_reviewed_case(item, {case["id"]: case for case in cases})
    gate = delta.get("team_ready_gate")
    require(isinstance(gate, dict), "delta_review.team_ready_gate must be an object")
    min_fidelity = float(plan["team_ready_gate"]["min_with_skill_anchor_fidelity"])
    fidelity = require_number(gate.get("with_skill_anchor_fidelity"), "team_ready_gate.with_skill_anchor_fidelity")
    require(fidelity >= min_fidelity, "team_ready_gate.with_skill_anchor_fidelity below minimum")
    require(abs(fidelity - with_anchor_fidelity(summaries)) < 0.0001, "team_ready_gate.with_skill_anchor_fidelity must match summaries")
    require(gate.get("infra_failures") == total_infra_failures(summaries), "team_ready_gate.infra_failures must match summaries")
    require(gate.get("infra_failures") <= plan["team_ready_gate"]["max_infra_failures"], "team_ready_gate.infra_failures too high")
    require(gate.get("without_skill_delta_observed") is True, "team_ready_gate.without_skill_delta_observed must be true")
    require(gate.get("validator_pass_for_with_skill_reports") is True, "team_ready_gate.validator_pass_for_with_skill_reports must be true")
    require(delta.get("conclusion") == "team-ready", "delta_review.conclusion must be team-ready")
    return delta


def validate_reviewed_case(item: Any, cases_by_id: dict[str, dict[str, Any]]) -> None:
    require(isinstance(item, dict), "delta_review.reviewed_cases items must be objects")
    case = cases_by_id.get(item.get("case_id"))
    require(case is not None, "delta_review.reviewed_cases contains unknown case")
    require(item.get("with_skill_summary_ref") == case["with_skill"]["summary_ref"], f"{case['id']} with_skill_summary_ref mismatch")
    require(item.get("without_skill_summary_ref") == case["without_skill"]["summary_ref"], f"{case['id']} without_skill_summary_ref mismatch")
    require_text(item.get("finding"), f"{case['id']}.delta_review.finding")


def validate_complete_lifecycle(
    plan: dict[str, Any],
    lifecycle: dict[str, Any],
    summaries: dict[str, dict[str, dict[str, Any]]],
) -> None:
    refs = lifecycle.get("evidence_refs", [])
    required_refs = [plan["delta_review_ref"]]
    for case in plan["cases"]:
        required_refs.extend([case["with_skill"]["summary_ref"], case["without_skill"]["summary_ref"]])
    missing_refs = [ref for ref in required_refs if ref not in refs]
    require(not missing_refs, f"lifecycle.evidence_refs missing empirical artifacts: {missing_refs}")
    capability = lifecycle.get("capability_uplift", {})
    preference = lifecycle.get("encoded_preference", {})
    require(capability.get("measurement_status") == PILOT_STATUS, "capability_uplift.measurement_status must be pilot_empirical_sample_recorded")
    require(preference.get("measurement_status") == PILOT_STATUS, "encoded_preference.measurement_status must be pilot_empirical_sample_recorded")
    require(capability.get("with_sample_size") == len(plan["cases"]), "capability_uplift.with_sample_size mismatch")
    require(capability.get("without_sample_size") == len(plan["cases"]), "capability_uplift.without_sample_size mismatch")
    with_avg = average(summaries, "with_skill")
    without_avg = average(summaries, "without_skill")
    uplift = round(with_avg - without_avg, 4)
    require(abs(float(capability.get("with_avg")) - with_avg) < 0.0001, "capability_uplift.with_avg mismatch")
    require(abs(float(capability.get("without_avg")) - without_avg) < 0.0001, "capability_uplift.without_avg mismatch")
    require(abs(float(capability.get("uplift")) - uplift) < 0.0001, "capability_uplift.uplift mismatch")
    require(uplift > 0, "capability_uplift.uplift must be positive")
    anchor_passed, anchor_total = with_anchor_counts(summaries)
    require(preference.get("anchor_passed") == anchor_passed, "encoded_preference.anchor_passed mismatch")
    require(preference.get("anchor_total") == anchor_total, "encoded_preference.anchor_total mismatch")
    min_fidelity = float(plan["team_ready_gate"]["min_with_skill_anchor_fidelity"])
    fidelity = with_anchor_fidelity(summaries)
    require(abs(float(preference.get("fidelity")) - fidelity) < 0.0001, "encoded_preference.fidelity mismatch")
    require(fidelity >= min_fidelity, "encoded_preference.fidelity below team-ready gate")
    review = lifecycle.get("human_read_delta_review", {})
    require(review.get("measurement_status") == "completed_human_delta_review", "human_read_delta_review.measurement_status invalid")
    require(review.get("delta_review_ref") == plan["delta_review_ref"], "human_read_delta_review.delta_review_ref mismatch")
    require(review.get("conclusion") == "team-ready", "human_read_delta_review.conclusion must be team-ready")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("plan")
    parser.add_argument("lifecycle")
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args(argv[1:])

    root = Path.cwd()
    plan_path = Path(args.plan)
    plan = load_json(plan_path)
    if args.require_complete:
        require(plan.get("status") == "completed_agent_runs", "plan.status must be completed_agent_runs")
    else:
        require(plan.get("status") in {"pending_agent_runs", "completed_agent_runs"}, "plan.status is invalid")
    lifecycle = load_json(Path(args.lifecycle))
    cases = validate_plan(plan, lifecycle, root)
    validate_pending_lifecycle(plan_path, lifecycle)
    if args.require_complete:
        summaries = collect_summaries(cases, root)
        validate_delta_review(plan, cases, summaries, root)
        validate_complete_lifecycle(plan, lifecycle, summaries)
        print("[PASS] skill-quality-audit empirical baseline complete")
    else:
        print("[PASS] skill-quality-audit empirical baseline plan")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
