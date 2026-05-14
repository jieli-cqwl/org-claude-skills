#!/usr/bin/env bash
# File role: prove research has enough evidence to move from optimize to retain.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFECYCLE="$ROOT/shared/skills/research/evals/lifecycle-review.json"
EVIDENCE="$ROOT/shared/skills/research/evals/retain-gate-2026-05-12/research-retain-evidence.json"
VALIDATOR="$ROOT/shared/skills/research/scripts/validate_retain_evidence.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for file in "$LIFECYCLE" "$EVIDENCE" "$VALIDATOR"; do
  test -f "$file" || fail "missing research retain file: ${file#"$ROOT"/}"
done

if rg -n 'research-workspace|benchmark_grade_retain|benchmark-grade-retain|run_benchmark_grade_eval' \
  "$ROOT/shared/skills/research" \
  "$ROOT/tests/run-all.sh" >/dev/null 2>&1; then
  fail "research retain gate still references removed benchmark workspace artifacts"
fi

jq empty "$LIFECYCLE" "$EVIDENCE" >/dev/null || fail "invalid JSON in research retain artifacts"
python3 -m py_compile "$VALIDATOR"
python3 "$VALIDATOR" "$EVIDENCE"

jq -e '
  .skill_name == "research"
  and .eval_type == "mixed"
  and .decision == "retain"
  and .review_date == "2026-05-12"
  and .capability_uplift.measurement_status == "retain_gate_passed"
  and .capability_uplift.with_avg >= 4
  and .capability_uplift.without_avg <= 3
  and .capability_uplift.uplift >= 1
  and .capability_uplift.with_sample_size >= 7
  and .capability_uplift.without_sample_size >= 7
  and .encoded_preference.measurement_status == "retain_gate_passed"
  and .encoded_preference.fidelity >= 0.8
  and .encoded_preference.sample_size >= 7
  and (.evidence_refs | index("shared/skills/research/evals/retain-gate-2026-05-12/research-retain-evidence.json") != null)
  and (.evidence_refs | index("tests/test-research-skill-retain-gate.sh") != null)
' "$LIFECYCLE" >/dev/null || fail "research lifecycle does not satisfy retain gate"

jq -e '
  .artifact_type == "research-retain-evidence"
  and .schema_version == 1
  and .comparative_summary.scenario_count >= 7
  and .comparative_summary.current_wins >= 7
  and .comparative_summary.current_avg >= 4
  and .comparative_summary.baseline_avg <= 3
  and .comparative_summary.uplift >= 1
  and .comparative_summary.critical_failures == 0
  and (.contract_checks | length) >= 5
  and (.verification_commands | index("bash tests/test-research-skill-retain-gate.sh") != null)
' "$EVIDENCE" >/dev/null || fail "research retain evidence summary below threshold"

for command in \
  "bash tests/test-research-skill-refiner-eval.sh" \
  "bash tests/test-research-skill-contract.sh" \
  "bash tests/test-deep-research-skill-contract.sh" \
  "bash tests/test-github-repo-radar-contract.sh"; do
  jq -e --arg command "$command" '
    any(.contract_checks[]; .command == $command and .status == "pass")
  ' "$EVIDENCE" >/dev/null || fail "retain evidence missing contract check: $command"
done

run_all_list="$(bash "$ROOT/tests/run-all.sh" --quick --list)"
grep -Eq 'test-research-skill-retain-gate\.sh' <<<"$run_all_list" \
  || fail "run-all quick plan must include research retain gate"

printf '[PASS] research retain gate\n'
