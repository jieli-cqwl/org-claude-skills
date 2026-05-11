#!/usr/bin/env bash
# File responsibility: dogfood /design on real standard-chain phase artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFLIGHT="$ROOT/shared/skills/design/scripts/preflight_check.sh"
DIGEST="$ROOT/shared/skills/design/scripts/review_digest.py"
COMPLETION="$ROOT/shared/skills/design/scripts/completion_check.sh"
PHASE_VALIDATOR="$ROOT/tools/community/validate_standard_chain_phase.py"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/design-dogfood.XXXXXX")"

trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2" label="${3:-$2}"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${label#"$ROOT"/}: $pattern"
}

run_hook() {
  local workspace="$1"
  local feature="$2"
  local payload_cwd="${3:-$workspace}"
  local transcript_path="$workspace/transcript.log"
  local design_path="docs/$feature/phase-1/design.json"
  local payload status

  printf '%s\n' "$design_path" >"$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$payload_cwd" \
    --arg sid "design-dogfood" \
    --arg tp "$transcript_path" \
    --arg fp "$design_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  if (cd "$payload_cwd" && bash "$COMPLETION" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" >"$workspace/hook.status"
}

prepare_workspace() {
  local target="$1"
  local source_feature="$2"
  local feature="$3"
  mkdir -p "$target/docs"
  cp -R "$source_feature" "$target/docs/$feature"
}

dogfood_positive_case() {
  local label="$1"
  local source_feature="$2"
  local feature="$3"
  local workspace="$TMP_ROOT/$label-workspace"
  local phase_dir design_json preflight_out review_json reviewed_design_digest_out expected_digest actual_digest

  prepare_workspace "$workspace" "$source_feature" "$feature"
  phase_dir="$workspace/docs/$feature/phase-1"
  design_json="$phase_dir/design.json"

  preflight_out="$TMP_ROOT/$label-preflight.json"
  bash "$PREFLIGHT" --phase-dir "$phase_dir" >"$preflight_out"
  jq -e --arg feature "$feature" '
    .status == "PASS"
    and (.brief | endswith("docs/" + $feature + "/brief.json"))
    and (.phase_prd | endswith("docs/" + $feature + "/phase-1/phase-prd.json"))
    and (.units | length == 1)
    and (.units[0] | endswith("docs/" + $feature + "/phase-1/units/UNIT-1.json"))
  ' "$preflight_out" >/dev/null || fail "$label: design preflight did not return stable canonical input paths"

  review_json="$TMP_ROOT/$label-design-review.json"
  jq 'del(.review_closure, .final_confirmation)' "$design_json" >"$review_json"
  reviewed_design_digest_out="$TMP_ROOT/$label-review-digest.json"
  python3 "$DIGEST" --review-payload "$review_json" >"$reviewed_design_digest_out"
  expected_digest="$(jq -r '.review_closure.reviewed_design_digest' "$design_json")"
  actual_digest="$(jq -r '.reviewed_design_digest' "$reviewed_design_digest_out")"
  [ "$actual_digest" = "$expected_digest" ] || fail "$label: reviewed design digest does not match review_closure"

  python3 "$PHASE_VALIDATOR" --phase-dir "$phase_dir" >"$TMP_ROOT/$label-phase-validator.out"

  run_hook "$workspace" "$feature"
  [ "$(cat "$workspace/hook.status")" = "0" ] || {
    cat "$workspace/hook.stderr" >&2
    fail "$label: design completion gate rejected dogfood design"
  }
  assert_present '"decision":"allow"|\"decision\": \"allow\"' "$workspace/hook.stdout" "$label positive hook stdout"
}

dogfood_positive_case \
  "golden" \
  "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" \
  "sample-feature"
dogfood_positive_case \
  "feedback" \
  "$ROOT/tests/fixtures/standard-chain-pilots/feedback-thanks-pilot" \
  "feedback-thanks-pilot"
dogfood_positive_case \
  "login" \
  "$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot" \
  "login-homepage-pilot"

DESIGN_JSON="$TMP_ROOT/golden-workspace/docs/sample-feature/phase-1/design.json"
review_json="$TMP_ROOT/golden-design-review.json"

bad_review_payload="$TMP_ROOT/bad-review-payload.json"
jq '.review_closure = {"reviewed_design_digest":"sha256:bad"}' "$review_json" >"$bad_review_payload"
if python3 "$DIGEST" --review-payload "$bad_review_payload" >"$TMP_ROOT/bad-review-payload.out" 2>"$TMP_ROOT/bad-review-payload.err"; then
  fail "review_digest accepted review payload with post-review fields"
fi
assert_present 'post-review fields' "$TMP_ROOT/bad-review-payload.err" "bad review payload digest stderr"

bad_review="$TMP_ROOT/bad-review-design.json"
jq '.review_closure.reviewers[0].reviewed_design_digest = "sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  "$DESIGN_JSON" >"$bad_review"
if python3 "$DIGEST" --check "$bad_review" >"$TMP_ROOT/bad-review.out" 2>"$TMP_ROOT/bad-review.err"; then
  fail "review_digest accepted mismatched reviewer digest"
fi
assert_present 'reviewed_design_digest mismatch' "$TMP_ROOT/bad-review.err" "bad review digest stderr"

BAD_WORKSPACE="$TMP_ROOT/bad-workspace"
prepare_workspace "$BAD_WORKSPACE" "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "sample-feature"
jq '.candidate_design_json = {}' \
  "$BAD_WORKSPACE/docs/sample-feature/phase-1/design.json" \
  >"$BAD_WORKSPACE/docs/sample-feature/phase-1/design.tmp.json"
mv "$BAD_WORKSPACE/docs/sample-feature/phase-1/design.tmp.json" \
  "$BAD_WORKSPACE/docs/sample-feature/phase-1/design.json"
run_hook "$BAD_WORKSPACE" "sample-feature"
if [ "$(cat "$BAD_WORKSPACE/hook.status")" = "0" ]; then
  cat "$BAD_WORKSPACE/hook.stdout" >&2
  fail "design completion gate accepted review wrapper fields in design.json"
fi
assert_present 'review wrapper fields' "$BAD_WORKSPACE/hook.stderr" "negative hook stderr"

MISSING_STAGE_WORKSPACE="$TMP_ROOT/missing-stage-workspace"
prepare_workspace "$MISSING_STAGE_WORKSPACE" "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "sample-feature"
jq '.co_creation_summary |= map(select(.stage_id != "S8"))' \
  "$MISSING_STAGE_WORKSPACE/docs/sample-feature/phase-1/design.json" \
  >"$MISSING_STAGE_WORKSPACE/docs/sample-feature/phase-1/design.tmp.json"
mv "$MISSING_STAGE_WORKSPACE/docs/sample-feature/phase-1/design.tmp.json" \
  "$MISSING_STAGE_WORKSPACE/docs/sample-feature/phase-1/design.json"
run_hook "$MISSING_STAGE_WORKSPACE" "sample-feature"
if [ "$(cat "$MISSING_STAGE_WORKSPACE/hook.status")" = "0" ]; then
  cat "$MISSING_STAGE_WORKSPACE/hook.stdout" >&2
  fail "design completion gate accepted design without S8 co-creation stage"
fi
assert_present 'co-creation|co_creation|S2-S8' "$MISSING_STAGE_WORKSPACE/hook.stderr" "missing stage hook stderr"

NO_UNIT_WORKSPACE="$TMP_ROOT/no-unit-workspace"
prepare_workspace "$NO_UNIT_WORKSPACE" "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "sample-feature"
rm -f "$NO_UNIT_WORKSPACE/docs/sample-feature/phase-1/units/UNIT-1.json"
if bash "$PREFLIGHT" --phase-dir "$NO_UNIT_WORKSPACE/docs/sample-feature/phase-1" >"$TMP_ROOT/no-unit.out" 2>"$TMP_ROOT/no-unit.err"; then
  fail "design preflight accepted a phase without UNIT files"
fi
assert_present 'MISSING_INPUT|no UNIT-\*\.json files found' "$TMP_ROOT/no-unit.out" "missing UNIT preflight output"

printf '[PASS] design dogfood e2e\n'
