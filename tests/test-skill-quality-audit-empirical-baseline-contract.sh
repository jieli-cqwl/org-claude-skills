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
delta_review_ref = plan.get("delta_review_ref")
require(
    isinstance(delta_review_ref, str) and delta_review_ref.endswith("delta-review.json"),
    "baseline plan must define delta_review_ref",
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
PY

printf '[PASS] skill-quality-audit empirical baseline contract\n'
