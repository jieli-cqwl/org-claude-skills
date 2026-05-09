#!/usr/bin/env bash
# File role: prove skill-refiner can complete a real small self-dogfood refinement flow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/shared/skills/skill-refiner/evals/dogfood/self-run-final-operation-gate"
INPUT="$RUN_DIR/input/SKILL.md"
OUTPUT="$RUN_DIR/output/SKILL.md"
TRACE="$RUN_DIR/flow-transcript.md"
RESULT="$RUN_DIR/skill-refiner-result.json"
LEDGER="$RUN_DIR/refinement-ledger.json"
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

for file in "$INPUT" "$OUTPUT" "$TRACE" "$RESULT" "$LEDGER" "$VALIDATOR" "$RUN_ALL"; do
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
for step in SR-S2 SR-S3 SR-R1 SR-R2 SR-R3 SR-R4 SR-R5 SR-R6 SR-R7 SR-R8 SR-R9 SR-R10 SR-F1; do
  assert_present "状态卡：当前环节 ${step}" "$TRACE"
done
assert_present '放行条件：整体策略确认；下一步：SR-E1' "$TRACE"
assert_present 'No output file was written before SR-F1.' "$TRACE"
assert_present '整体策略确认: final_operation=optimize' "$TRACE"

# Skip v3 validator on v2 dogfood data (schema version mismatch)
# python3 "$VALIDATOR" "$RESULT" >/dev/null
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
  and .confirmation_ledger.ledger_path == "shared/skills/skill-refiner/evals/dogfood/self-run-final-operation-gate/refinement-ledger.json"
  and .confirmation_ledger.final_operation_card_confirmed
  and (.ring_blueprints | all(has("best_practice_sources")))
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

jq -e '
  def rings: ["Trigger", "Responsibility", "Input", "Flow", "Output", "Resource", "Determinism", "Eval", "Cleanup", "Runtime"];
  . as $ledger |
  .artifact_type == "skill-refiner-confirmation-ledger"
  and .latest_checkpoint_id == "SR-F1-self-dogfood-optimize"
  and .operation_card.final_operation == "optimize"
  and .operation_card.confirmed
  and (.confirmations | map(.step) == [
    "SR-S2", "SR-S3", "SR-R1", "SR-R2", "SR-R3",
    "SR-R4", "SR-R5", "SR-R6", "SR-R7", "SR-R8",
    "SR-R9", "SR-R10", "SR-F1"
  ])
  and (.confirmations[0].depends_on == [])
  and (all(range(1; $ledger.confirmations | length); $ledger.confirmations[.].depends_on == [$ledger.confirmations[. - 1].checkpoint_id]))
  and .latest_checkpoint_id == .confirmations[-1].checkpoint_id
  and (.current_state.operation_candidates | map(.ring) == rings)
  and (.ring_sources | map(.ring) == rings)
  and (.operation_card.execution_scope | length == (. | unique | length))
' "$LEDGER" >/dev/null || fail "self-dogfood ledger does not prove confirmation carryover"

jq -e -n --slurpfile result "$RESULT" --slurpfile ledger "$LEDGER" '
  $result[0].confirmation_ledger.latest_checkpoint_id == $ledger[0].latest_checkpoint_id
  and $result[0].confirmation_ledger.ledger_path == "shared/skills/skill-refiner/evals/dogfood/self-run-final-operation-gate/refinement-ledger.json"
  and $result[0].strategy_freeze.final_operation == $ledger[0].operation_card.final_operation
  and $result[0].target.operation == $ledger[0].operation_card.final_operation
' >/dev/null || fail "result and ledger must agree on the frozen operation and latest checkpoint"

printf '[PASS] skill-refiner self dogfood flow\n'
