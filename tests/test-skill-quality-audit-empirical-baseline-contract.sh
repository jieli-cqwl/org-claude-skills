#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="$ROOT/shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json"
LIFECYCLE="$ROOT/shared/skills/skill-quality-audit/evals/lifecycle-review.json"
EVALS="$ROOT/shared/skills/skill-quality-audit/evals/evals.json"
GATE_PLAN="$ROOT/tests/gate-plan.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" "$PLAN" "$LIFECYCLE" "$EVALS" "$GATE_PLAN" <<'PY'
import json
import sys
from pathlib import Path

root, plan_path, lifecycle_path, evals_path, gate_plan_path = map(Path, sys.argv[1:])


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


require(plan_path.is_file(), "missing skill-quality-audit empirical baseline plan")
plan = json.loads(plan_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))
evals = json.loads(evals_path.read_text(encoding="utf-8"))
gate_plan = json.loads(gate_plan_path.read_text(encoding="utf-8"))


def resolve_repo_path(path_text: str) -> Path:
    path = Path(path_text)
    return path if path.is_absolute() else root / path

require(
    plan.get("artifact_type") == "skill-quality-audit-empirical-baseline-plan",
    "empirical baseline plan artifact_type drift",
)
require(plan.get("status") == "completed_agent_runs", "baseline plan status must reflect completed agent runs")
require(plan.get("minimum_real_skill_reviews") == 2, "baseline plan must require two real Skill reviews")
require(
    plan.get("readiness_target") == "team-ready",
    "baseline plan must target team-ready decision",
)
run_id = plan.get("run_id")
require(
    run_id == "2026-06-04-sqa-fresh-baseline-001",
    "baseline plan must record the fresh run_id",
)
require(
    plan.get("source_boundary") == "repository custom team-use readiness",
    "baseline plan must record repository custom source boundary",
)
require(lifecycle.get("run_id") == run_id, "lifecycle run_id must match baseline plan")
require(
    lifecycle.get("source_boundary") == plan.get("source_boundary"),
    "lifecycle source_boundary must match baseline plan",
)
delta_review_ref = plan.get("delta_review_ref")
require(
    isinstance(delta_review_ref, str) and delta_review_ref.endswith("delta-review.json"),
    "baseline plan must define delta_review_ref",
)
delta_review = json.loads(resolve_repo_path(delta_review_ref).read_text(encoding="utf-8"))
require(delta_review.get("run_id") == run_id, "delta review run_id must match baseline plan")
require(
    delta_review.get("source_boundary") == plan.get("source_boundary"),
    "delta review source_boundary must match baseline plan",
)
require(
    plan.get("grader_dimensions") == lifecycle["capability_uplift"]["grader_dimensions"],
    "baseline grader_dimensions must match lifecycle capability_uplift",
)

cases = plan.get("cases")
require(isinstance(cases, list) and len(cases) >= 2, "baseline plan must include at least two cases")
case_ids = set()
required_readiness = {
    "Scenario Capability",
    "Structure-Content Coherence",
    "Evidence Integrity",
    "Repairable Handoff",
    "Attention Economy",
}
for index, case in enumerate(cases):
    case_id = case.get("id")
    require(isinstance(case_id, str) and case_id, f"case[{index}] missing id")
    require(case_id not in case_ids, f"duplicate case id: {case_id}")
    case_ids.add(case_id)
    target_skill = case.get("target_skill")
    require(isinstance(target_skill, str) and (root / target_skill).exists(), f"{case_id} target_skill missing: {target_skill}")
    require(isinstance(case.get("prompt"), str) and case["prompt"], f"{case_id} missing prompt")
    for run_mode in ("with_skill", "without_skill"):
        run = case.get(run_mode)
        require(isinstance(run, dict), f"{case_id} missing {run_mode}")
        output_dir = run.get("output_dir")
        summary_ref = run.get("summary_ref")
        require(isinstance(output_dir, str) and output_dir, f"{case_id} missing {run_mode}.output_dir")
        require(isinstance(summary_ref, str) and summary_ref.endswith("summary.json"), f"{case_id} missing {run_mode}.summary_ref")
        require(output_dir in summary_ref, f"{case_id} {run_mode}.summary_ref must live under output_dir")
        summary = json.loads(resolve_repo_path(summary_ref).read_text(encoding="utf-8"))
        require(summary.get("run_id") == run_id, f"{case_id} {run_mode}.summary run_id must match baseline plan")
        require(
            summary.get("source_boundary") == plan.get("source_boundary"),
            f"{case_id} {run_mode}.summary source_boundary must match baseline plan",
        )
        raw_output_ref = summary.get("raw_output_ref")
        require(isinstance(raw_output_ref, str) and raw_output_ref, f"{case_id} {run_mode}.summary missing raw_output_ref")
        raw_output = resolve_repo_path(raw_output_ref).read_text(encoding="utf-8")
        require(run_id in raw_output, f"{case_id} {run_mode}.raw_output_ref must record run_id")
    readiness_checks = set(case.get("readiness_checks", []))
    missing = sorted(required_readiness - readiness_checks)
    require(not missing, f"{case_id} missing readiness checks: {missing}")

retain_gate = plan.get("team_ready_gate", {})
require(retain_gate.get("min_with_skill_anchor_fidelity") == 0.8, "team-ready gate must require anchor fidelity >= 0.8")
require(retain_gate.get("max_infra_failures") == 0, "team-ready gate must reject infra failures")
require(retain_gate.get("requires_human_delta_review") is True, "team-ready gate must require human delta review")
require(retain_gate.get("requires_validator_pass_for_with_skill_reports") is True, "team-ready gate must require with_skill validator PASS")
require(retain_gate.get("requires_without_skill_delta") is True, "team-ready gate must require without_skill delta")

recording_requirements = "\n".join(plan.get("recording_requirements", []))
require("raw_output_ref" in recording_requirements, "recording requirements must require raw_output_ref")
require("formal_report_ref" in recording_requirements, "recording requirements must require formal_report_ref")
require("validator-passing formal report" in recording_requirements, "recording requirements must require validator-passing formal reports")

evidence_refs = lifecycle.get("evidence_refs", [])
require(
    "shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json" in evidence_refs,
    "lifecycle evidence_refs must include empirical baseline plan",
)
require(
    "shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/delta-review.json" in evidence_refs,
    "lifecycle evidence_refs must include empirical baseline delta review",
)
require(
    "team Skill readiness audits" in lifecycle.get("next_action", ""),
    "lifecycle next_action must describe team-ready usage boundary",
)

step_ids = {step["id"] for step in gate_plan["steps"]}
require(
    "skill-quality-audit-empirical-baseline-contract" in step_ids,
    "gate plan must include empirical baseline contract test",
)
require(
    "skill-quality-audit-empirical-baseline-validator" in step_ids,
    "gate plan must include empirical baseline validator test",
)

eval_ids = {case["id"] for case in evals.get("evals", [])}
require(
    "default-formal-audit-artifacts" in eval_ids and "audit-artifact-triage" in eval_ids,
    "baseline depends on current formal-audit and artifact-triage evals",
)
sample_matrix = evals.get("sample_matrix")
require(isinstance(sample_matrix, list), "evals.sample_matrix must define deterministic sample matrix")
sample_ids = {case.get("id") for case in sample_matrix if isinstance(case, dict)}
required_sample_ids = {
    "positive-formal-audit",
    "light-scan-non-final",
    "audit-artifact-triage",
    "near-miss-should-not-trigger",
    "without-skill-baseline",
    "negative-stale-evidence",
    "negative-missing-handoff",
    "negative-p0-p1-claim-review",
    "repair-handoff-replay",
}
missing_sample_ids = sorted(required_sample_ids - sample_ids)
require(not missing_sample_ids, f"evals.sample_matrix missing cases: {missing_sample_ids}")
for case in sample_matrix:
    require(
        set(case.get("grader_dimensions", [])) <= set(plan["grader_dimensions"]),
        f"sample_matrix {case.get('id')} grader_dimensions must be a subset of baseline grader_dimensions",
    )
    require(
        isinstance(case.get("sample_out_boundary"), str) and case["sample_out_boundary"],
        f"sample_matrix {case.get('id')} must state sample_out_boundary",
    )
PY

printf '[PASS] skill-quality-audit empirical baseline contract\n'
