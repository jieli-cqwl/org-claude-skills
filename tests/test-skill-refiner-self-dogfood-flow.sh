#!/usr/bin/env bash
# File role: prove skill-refiner can complete a real small self-dogfood refinement flow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/shared/skills/skill-refiner/evals/dogfood/self-run-final-operation-gate"
INPUT="$RUN_DIR/input/SKILL.md"
OUTPUT="$RUN_DIR/output/SKILL.md"
TRACE="$RUN_DIR/flow-transcript.md"
RESULT="$RUN_DIR/skill-refiner-result.json"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_refinement_result.py"
RUN_ALL="$ROOT/tests/run-all.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#"$ROOT"/}: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in ${file#"$ROOT"/}: $needle"
  fi
}

for file in "$INPUT" "$OUTPUT" "$TRACE" "$RESULT" "$VALIDATOR" "$RUN_ALL"; do
  test -f "$file" || fail "missing self-dogfood file: ${file#"$ROOT"/}"
done

assert_present 'Final decision: create a new code-review Skill immediately.' "$INPUT"
assert_absent 'Final decision: create a new code-review Skill immediately.' "$OUTPUT"
assert_present 'Locate existing review capability before proposing any new Skill.' "$OUTPUT"
assert_present 'SR-F1 final operation: optimize existing tiny-review-router.' "$OUTPUT"
assert_absent '"strategy_matrix"' "$RESULT"
assert_absent '"strategy":' "$RESULT"
assert_present 'candidate_strategy_matrix' "$RESULT"

for step in SR-S1 SR-S2 SR-S3 SR-S4 SR-R1 SR-R2 SR-R3 SR-R4 SR-R5 SR-R6 SR-R7 SR-R8 SR-R9 SR-R10 SR-F1 SR-E1 SR-V1; do
  assert_present "### ${step}" "$TRACE"
done
assert_present 'No output file was written before SR-F1.' "$TRACE"
assert_present '整体策略确认: final_operation=optimize' "$TRACE"

python3 "$VALIDATOR" "$RESULT" >/dev/null
run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-self-dogfood-flow.sh' <<<"$run_all_list" \
  || fail "self-dogfood test is not registered in tests/run-all.sh"

jq -e '
  .artifact_type == "skill-refiner-result"
  and .self_dogfood.requirement == "Optimize tiny-review-router so requests to create a code-review Skill first locate existing review capability and defer final operation to SR-F1."
  and .target.skill_name == "tiny-review-router"
  and .target.operation == "optimize"
  and .strategy_freeze.final_operation == "optimize"
  and .strategy_freeze.no_file_changes_before_freeze
  and .strategy_freeze.one_shot_execution_after_freeze
  and (.ring_sequence | length == 10)
  and (.ring_blueprints | length == 10)
  and (.candidate_strategy_matrix | length == 10)
  and (.candidate_strategy_matrix | all(has("candidate_strategy") and (has("strategy") | not)))
  and (.acceptance_matrix | all(.status == "PASS" or .status == "ISSUE_FIXED"))
  and (.verification_commands | map(select(.status == "pass")) | length >= 3)
  and (.flow_trace | map(.step) == [
    "SR-S1", "SR-S2", "SR-S3", "SR-S4",
    "SR-R1", "SR-R2", "SR-R3", "SR-R4", "SR-R5",
    "SR-R6", "SR-R7", "SR-R8", "SR-R9", "SR-R10",
    "SR-F1", "SR-E1", "SR-V1"
  ])
' "$RESULT" >/dev/null || fail "self-dogfood result does not prove the complete flow"

printf '[PASS] skill-refiner self dogfood flow\n'
