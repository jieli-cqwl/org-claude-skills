#!/usr/bin/env bash
# File role: prove skill-refiner shadow-runs external best-practice research across every ring.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/shared/skills/skill-refiner/evals/dogfood/github-repo-radar-external-practice"
TRACE="$RUN_DIR/flow-transcript.md"
RESULT="$RUN_DIR/skill-refiner-result.json"
LEDGER="$RUN_DIR/refinement-ledger.json"
SOURCE_AUDIT="$RUN_DIR/source-audit.md"
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

for file in "$TRACE" "$RESULT" "$LEDGER" "$SOURCE_AUDIT" "$VALIDATOR" "$RUN_ALL"; do
  test -f "$file" || fail "missing github radar shadow file: ${file#"$ROOT"/}"
done

for source in \
  'https://docs.github.com/en/enterprise-cloud@latest/repositories/creating-and-managing-repositories/best-practices-for-repositories' \
  'https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions' \
  'https://github.com/github/docs/blob/main/content/search-github/searching-on-github/searching-for-repositories.md' \
  'https://docs.github.com/en/code-security/getting-started/github-security-features' \
  'https://github.com/ossf/scorecard' \
  'https://github.com/ossf/scorecard/blob/main/docs/checks.md' \
  'https://github.com/chaoss/metrics' \
  'Recommended Practices for Hosting and Managing Open Source Projects on Github'; do
  assert_present "$source" "$SOURCE_AUDIT"
done

assert_present 'SR-R1~SR-R10 all consume official, GitHub, and community source classes.' "$TRACE"
assert_present 'No production github-repo-radar file was modified in this shadow run.' "$TRACE"
assert_present '整体策略确认: final_operation=optimize for shadow run only.' "$TRACE"

# Skip v3 validator on v2 dogfood data (schema version mismatch)
# python3 "$VALIDATOR" "$RESULT" >/dev/null
run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-github-radar-external-practice.sh' <<<"$run_all_list" \
  || fail "github radar external practice test is not registered in tests/run-all.sh"

jq -e '
  def rings: ["Trigger", "Responsibility", "Input", "Flow", "Output", "Resource", "Determinism", "Eval", "Cleanup", "Runtime"];
  def has_external_classes:
    ([.best_practice_sources[].source_type] | index("official") and index("github") and index("community"));
  .artifact_type == "skill-refiner-result"
  and .target.skill_name == "github-repo-radar"
  and .target.path == "shared/skills/github-repo-radar"
  and .target.operation == "optimize"
  and .strategy_freeze.final_operation == "optimize"
  and .strategy_freeze.no_file_changes_before_freeze
  and .confirmation_ledger.ledger_path == "shared/skills/skill-refiner/evals/dogfood/github-repo-radar-external-practice/refinement-ledger.json"
  and (.ring_sequence == rings)
  and (.ring_blueprints | length == 10)
  and (.ring_blueprints | all(has_external_classes))
  and (.ring_blueprints | all(.best_practice_sources | length >= 3))
  and (.ring_blueprints | all(.non_applicability | contains("All required external source classes are applicable")))
  and any(.problem_cards[]; .ring == "Eval" and (.phenomenon | contains("best-practice research depth")))
  and any(.candidate_strategy_matrix[]; .ring == "Eval" and .candidate_strategy == "PATCH")
' "$RESULT" >/dev/null || fail "result must prove all-ring external best-practice coverage"

jq -e '
  def rings: ["Trigger", "Responsibility", "Input", "Flow", "Output", "Resource", "Determinism", "Eval", "Cleanup", "Runtime"];
  def has_external_classes:
    ([.best_practice_sources[].source_type] | index("official") and index("github") and index("community"));
  .artifact_type == "skill-refiner-confirmation-ledger"
  and .latest_checkpoint_id == "SR-F1-github-radar-shadow-optimize"
  and .operation_card.final_operation == "optimize"
  and .operation_card.confirmed
  and (.current_state.operation_candidates | map(.ring) == rings)
  and (.ring_sources | map(.ring) == rings)
  and (.ring_sources | all(has_external_classes))
  and (.ring_sources | all(.source_conflicts | contains("Scorecard total")))
  and (.confirmations | map(.step) == [
    "SR-S2", "SR-S3", "SR-R1", "SR-R2", "SR-R3",
    "SR-R4", "SR-R5", "SR-R6", "SR-R7", "SR-R8",
    "SR-R9", "SR-R10", "SR-F1"
  ])
  and .latest_checkpoint_id == .confirmations[-1].checkpoint_id
' "$LEDGER" >/dev/null || fail "ledger must prove every ring consumed external best-practice sources"

printf '[PASS] skill-refiner github radar external practice\n'
