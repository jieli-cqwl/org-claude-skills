#!/usr/bin/env bash
# Run a real canonical test-design flow against the golden-pilot fixture.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_FEATURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
PREFLIGHT="$ROOT/shared/skills/test-design/scripts/preflight_check.sh"
COMPLETION="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
PHASE_VALIDATOR="$ROOT/tools/community/validate_standard_chain_phase.py"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

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

printf '[PASS] test-design dogfood flow\n'
