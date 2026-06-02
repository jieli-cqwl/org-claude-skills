#!/usr/bin/env bash
# Run a real canonical test-design flow against the golden-pilot fixture.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_FEATURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
PREFLIGHT="$ROOT/shared/skills/test-design/scripts/preflight_check.sh"
COMPLETION="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
PHASE_VALIDATOR="$ROOT/tools/community/validate_standard_chain_phase.py"
DOGFOOD_RESULT="$ROOT/shared/skills/test-design/evals/dogfood/sample-feature-flow/dogfood-result.json"
ANCHOR_FIDELITY="$ROOT/shared/skills/test-design/evals/dogfood/sample-feature-flow/anchor-fidelity.json"
LIFECYCLE_REVIEW="$ROOT/shared/skills/test-design/evals/lifecycle-review.json"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$DOGFOOD_RESULT" || fail "missing dogfood result"
test -f "$ANCHOR_FIDELITY" || fail "missing anchor fidelity evidence"

workspace="$TMP_DIR/workspace"
mkdir -p "$workspace/docs"
cp -R "$BASE_FEATURE" "$workspace/docs/sample-feature"

phase_dir="$workspace/docs/sample-feature/phase-1"
test_cases="$phase_dir/unit-1/test-cases.json"

bash "$PREFLIGHT" --phase-dir "$phase_dir" --unit UNIT-1 >"$workspace/preflight.out" 2>&1 || {
  cat "$workspace/preflight.out" >&2
  fail "preflight failed in dogfood flow"
}
jq -e '.status == "PASS"' "$workspace/preflight.out" >/dev/null || {
  cat "$workspace/preflight.out" >&2
  fail "preflight did not emit PASS"
}

transcript_path="$workspace/transcript.log"
printf '%s\n' "docs/sample-feature/phase-1/unit-1/test-cases.json" >"$transcript_path"
payload="$(jq -nc \
  --arg cwd "$workspace" \
  --arg sid "test-design-dogfood-flow" \
  --arg tp "$transcript_path" \
  --arg fp "docs/sample-feature/phase-1/unit-1/test-cases.json" \
  '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

if (cd "$workspace" && bash "$COMPLETION" <<<"$payload") >"$workspace/completion.out" 2>"$workspace/completion.err"; then
  :
else
  cat "$workspace/completion.out" >&2
  cat "$workspace/completion.err" >&2
  fail "completion hook blocked dogfood test-cases.json"
fi
jq -e '.decision == "allow"' "$workspace/completion.out" >/dev/null || {
  cat "$workspace/completion.out" >&2
  fail "completion hook did not allow dogfood test-cases.json"
}

python3 "$PHASE_VALIDATOR" --phase-dir "$phase_dir" >"$workspace/phase-validator.out" 2>"$workspace/phase-validator.err" || {
  cat "$workspace/phase-validator.err" >&2
  fail "phase validator failed in dogfood flow"
}
jq -e 'any(.artifacts[]?; .artifact_type == "test-cases" and .artifact_id == "sample-feature.phase-1.unit-1.test-cases")' "$workspace/phase-validator.out" >/dev/null || {
  fail "phase validator output did not include test-cases artifact"
}

jq -e '
  .review_conclusion.review_round == "R2"
  and any(.review_conclusion.convergence_evidence[]?; .control_action == "CONFIRMATION")
  and ([.review_conclusion.reviewer_verdicts[].perspective] | sort == ["architecture", "product", "test_quality"])
  and all(.review_conclusion.reviewer_verdicts[]; .verdict != "FAIL")
' "$test_cases" >/dev/null || {
  jq '.review_conclusion' "$test_cases" >&2
  fail "dogfood review loop evidence is incomplete"
}

jq -e '
  .measurement_status == "completed_dogfood_flow"
  and .anchor_fidelity_ref == "shared/skills/test-design/evals/dogfood/sample-feature-flow/anchor-fidelity.json"
  and (.claim_boundary | test("not a model-level"))
' "$DOGFOOD_RESULT" >/dev/null || {
  jq '.' "$DOGFOOD_RESULT" >&2
  fail "dogfood result metadata is incomplete"
}

jq -e '
  .artifact_type == "test-design-anchor-fidelity"
  and .run_mode == "with_skill"
  and .expected_anchor_count == 6
  and .passed_anchor_count == 6
  and .fidelity == 1
  and all(.anchors[]; .passed == true and (.evidence | length > 0))
  and (.claim_boundary | test("not a with_skill/without_skill capability uplift"))
' "$ANCHOR_FIDELITY" >/dev/null || {
  jq '.' "$ANCHOR_FIDELITY" >&2
  fail "anchor fidelity evidence is incomplete"
}

jq -e '
  .decision == "optimize"
  and .dogfood_flow.result == "PASS"
  and .dogfood_flow.anchor_fidelity_ref == "shared/skills/test-design/evals/dogfood/sample-feature-flow/anchor-fidelity.json"
  and .capability_uplift.measurement_status == "pilot_empirical_sample_recorded"
  and .capability_uplift.with_sample_size == 9
  and .capability_uplift.without_sample_size == 9
  and .capability_uplift.with_avg == 1
  and .capability_uplift.without_avg < .capability_uplift.with_avg
  and .capability_uplift.uplift > 0
  and .encoded_preference.measurement_status == "pilot_empirical_sample_recorded"
  and .encoded_preference.fidelity >= 0.8
  and .encoded_preference.sample_size == 9
  and .encoded_preference.anchor_passed == 17
  and .encoded_preference.anchor_total == 19
  and .pilot_empirical.with_skill.infra_failures == 0
  and .pilot_empirical.without_skill.infra_failures == 0
  and .pilot_empirical.with_skill.anchor_fidelity > .pilot_empirical.without_skill.anchor_fidelity
' "$LIFECYCLE_REVIEW" >/dev/null || {
  jq '.' "$LIFECYCLE_REVIEW" >&2
  fail "lifecycle dogfood/effectiveness evidence is incomplete"
}

printf '[PASS] test-design dogfood flow\n'
