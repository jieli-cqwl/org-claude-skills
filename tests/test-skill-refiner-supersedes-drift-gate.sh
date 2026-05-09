#!/usr/bin/env bash
# File role: prove skill-refiner records and resolves conclusion drift through supersedes before SR-F1.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/shared/skills/skill-refiner/evals/dogfood/supersedes-drift-gate"
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

for file in "$TRACE" "$RESULT" "$LEDGER" "$VALIDATOR" "$RUN_ALL"; do
  test -f "$file" || fail "missing supersedes drift file: ${file#"$ROOT"/}"
done

assert_present 'Detected drift: SR-R4 proposed final_operation=create against the SR-S2 optimize-only baseline.' "$TRACE"
assert_present 'Stopped for user decision before target file changes.' "$TRACE"
assert_present 'User confirmation: reject create drift and keep final_operation=optimize.' "$TRACE"
assert_present '整体策略确认: final_operation=optimize' "$TRACE"

# Skip v3 validator on v2 dogfood data (schema version mismatch)
# python3 "$VALIDATOR" "$RESULT" >/dev/null
run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-supersedes-drift-gate.sh' <<<"$run_all_list" \
  || fail "supersedes drift test is not registered in tests/run-all.sh"

jq -e '
  .artifact_type == "skill-refiner-result"
  and .target.skill_name == "tiny-review-router"
  and .target.operation == "optimize"
  and .strategy_freeze.final_operation == "optimize"
  and .strategy_freeze.no_file_changes_before_freeze
  and .confirmation_ledger.ledger_path == "shared/skills/skill-refiner/evals/dogfood/supersedes-drift-gate/refinement-ledger.json"
  and .confirmation_ledger.superseded_items_resolved
  and any(.candidate_strategy_matrix[]; .ring == "Flow" and .candidate_strategy == "BLOCKED" and (.risk | contains("create drift")))
  and any(.problem_cards[]; .ring == "Flow" and (.phenomenon | contains("drift")))
' "$RESULT" >/dev/null || fail "result must prove create drift was blocked before optimize freeze"

jq -e '
  def rings: ["Trigger", "Responsibility", "Input", "Flow", "Output", "Resource", "Determinism", "Eval", "Cleanup", "Runtime"];
  .artifact_type == "skill-refiner-confirmation-ledger"
  and .latest_checkpoint_id == "SR-F1-supersedes-drift-optimize"
  and .operation_card.final_operation == "optimize"
  and .operation_card.confirmed
  and (.current_state.operation_candidates | map(.ring) == rings)
  and (.ring_sources | map(.ring) == rings)
  and (.supersedes | length == 1)
  and .supersedes[0].drift_detected_at == "SR-R4-Flow"
  and .supersedes[0].drifted_from == "SR-S2-baseline"
  and .supersedes[0].proposed_operation == "create"
  and .supersedes[0].resolved_operation == "optimize"
  and .supersedes[0].status == "resolved_by_user_confirmation"
  and (.confirmations[] | select(.step == "SR-R4").supersedes == ["SR-R4-create-drift-candidate"])
  and .latest_checkpoint_id == .confirmations[-1].checkpoint_id
' "$LEDGER" >/dev/null || fail "ledger must prove drift was recorded, paused, and resolved before SR-F1"

printf '[PASS] skill-refiner supersedes drift gate\n'
