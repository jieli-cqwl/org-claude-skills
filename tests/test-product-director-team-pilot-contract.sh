#!/usr/bin/env bash
# File responsibility: lock the product-director team pilot readiness contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
READINESS="$ROOT/shared/skills/product-director/evals/dogfood/team-pilot-readiness.json"
LIFECYCLE="$ROOT/shared/skills/product-director/evals/lifecycle-review.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$READINESS" || fail "missing product-director team pilot readiness artifact"
test -f "$LIFECYCLE" || fail "missing product-director lifecycle review"

python3 - "$READINESS" "$LIFECYCLE" <<'PY'
import json
import sys
from pathlib import Path

readiness_path = Path(sys.argv[1])
lifecycle_path = Path(sys.argv[2])
readiness = json.loads(readiness_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))


def walk_strings(value, path=()):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from walk_strings(child, path + (str(key),))
        return
    if isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_strings(child, path + (str(index),))
        return
    if isinstance(value, str):
        yield ".".join(path), value


for artifact_name, artifact in (("readiness", readiness), ("lifecycle", lifecycle)):
    for key_path, value in walk_strings(artifact):
        for forbidden in ("fast path", "fast-path", "快路径", "闭合事实快路径"):
            if forbidden in value:
                raise SystemExit(f"{artifact_name} preserves obsolete branch term at {key_path}: {forbidden}")

if readiness.get("artifact_type") != "product-director-team-pilot-readiness":
    raise SystemExit("readiness artifact_type drift")
if readiness.get("schema_version") != "0.1.0":
    raise SystemExit("readiness schema_version drift")
if readiness.get("skill_under_test") != "shared/skills/product-director":
    raise SystemExit("readiness skill_under_test drift")
if readiness.get("deployment_status") != "team_pilot_ready":
    raise SystemExit("product-director must be team-pilot ready, not silently promoted")
if readiness.get("next_action") != "review_5_real_complex_demand_transcripts_before_promotion":
    raise SystemExit("readiness next_action must point to real transcript review")
if readiness.get("default_scope") != "complex_demand_intake_only":
    raise SystemExit("product-director default scope must stay complex-demand intake only")
if readiness.get("not_daily_default") is not True:
    raise SystemExit("product-director must not be the daily/simple default skill")
if readiness.get("full_production_default") is not False:
    raise SystemExit("product-director must not claim full production default readiness")

promotion = readiness.get("promotion_gate", {})
if promotion.get("required_real_transcripts") != 5:
    raise SystemExit("promotion gate must require 5 real transcripts")
if promotion.get("sample_type") != "real_complex_demand_transcripts":
    raise SystemExit("promotion sample type must be real complex-demand transcripts")
if promotion.get("required_outcome") != "no_in_scope_blockers_across_all_review_dimensions":
    raise SystemExit("promotion outcome must require no in-scope blockers across all review dimensions")
if promotion.get("promotion_target") != "default_complex_demand_entry":
    raise SystemExit("promotion target must stay limited to complex-demand entry")

required_dimensions = {
    "no_interrogation",
    "no_pretend_closure",
    "no_stage_jump",
    "success_standard_closure",
    "director_why_only",
    "explicit_confirmation_before_finalization",
    "handoff_to_product_manager_only",
    "simple_request_reroute",
}
dimensions = readiness.get("review_dimensions", [])
dimension_ids = {item.get("id") for item in dimensions if isinstance(item, dict)}
missing_dimensions = sorted(required_dimensions - dimension_ids)
if missing_dimensions:
    raise SystemExit(f"readiness missing review dimensions: {missing_dimensions}")
for item in dimensions:
    if item.get("id") in required_dimensions:
        for field in ("pass_condition", "blocker_signal", "evidence_required"):
            if not isinstance(item.get(field), str) or not item[field].strip():
                raise SystemExit(f"review dimension {item.get('id')} missing {field}")

out_of_scope = set(readiness.get("out_of_scope", []))
required_out_of_scope = {
    "simple_daily_questions",
    "direct_implementation_requests",
    "product_manager_detail_design_before_director_confirmation",
}
if not required_out_of_scope.issubset(out_of_scope):
    raise SystemExit(f"readiness out_of_scope missing: {sorted(required_out_of_scope - out_of_scope)}")

evidence_refs = set(readiness.get("evidence_refs", []))
required_evidence_refs = {
    "shared/skills/product-director/SKILL.md",
    "shared/skills/product-director/evals/evals.json",
    "tests/test-product-director-cocreation-contract.sh",
    "tests/test-standard-chain-interaction-eval.sh",
    "tools/eval/results/standard-chain-systemic-baseline-2026-06-11/pd-hardening-6-cases-closed-facts-direct-recommendation-low-reasoning/summary.json",
    "tools/eval/results/standard-chain-systemic-baseline-2026-06-11/pd-hardening-regression-after-review-fix-low-reasoning/summary.json",
}
if not required_evidence_refs.issubset(evidence_refs):
    raise SystemExit(f"readiness evidence refs missing: {sorted(required_evidence_refs - evidence_refs)}")

lifecycle_refs = set(lifecycle.get("evidence_refs", []))
readiness_ref = "shared/skills/product-director/evals/dogfood/team-pilot-readiness.json"
if readiness_ref not in lifecycle_refs:
    raise SystemExit("lifecycle review must reference product-director team pilot readiness")
if lifecycle.get("next_action") != "Review 5 real complex-demand transcripts against team-pilot readiness before promoting product-director to default complex-demand entry.":
    raise SystemExit("lifecycle next_action must point to the team pilot transcript gate")

team_pilot = lifecycle.get("team_pilot_readiness", {})
if team_pilot.get("status") != "team_pilot_ready":
    raise SystemExit("lifecycle team_pilot_readiness.status drift")
if team_pilot.get("readiness_ref") != readiness_ref:
    raise SystemExit("lifecycle team_pilot_readiness.readiness_ref drift")
if team_pilot.get("default_scope") != "complex_demand_intake_only":
    raise SystemExit("lifecycle team_pilot_readiness.default_scope drift")
if team_pilot.get("required_real_transcripts_before_promotion") != 5:
    raise SystemExit("lifecycle must keep the 5-transcript promotion gate")
if team_pilot.get("full_production_default") is not False:
    raise SystemExit("lifecycle must not promote product-director to full production default")
PY

printf '[PASS] product-director team pilot contract\n'
