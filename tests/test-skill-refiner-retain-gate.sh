#!/usr/bin/env bash
# File role: prove skill-refiner has enough empirical evidence to be retained.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFECYCLE="$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
RETAIN_EVIDENCE="$ROOT/shared/skills/skill-refiner/evals/retain-gate-2026-05-12/retain-evidence.json"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_retain_evidence.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for file in "$LIFECYCLE" "$RETAIN_EVIDENCE" "$VALIDATOR"; do
  test -f "$file" || fail "missing file: ${file#"$ROOT"/}"
done

jq empty "$LIFECYCLE" >/dev/null || fail "invalid JSON: ${LIFECYCLE#"$ROOT"/}"
jq empty "$RETAIN_EVIDENCE" >/dev/null || fail "invalid JSON: ${RETAIN_EVIDENCE#"$ROOT"/}"
python3 -m py_compile "$VALIDATOR"
python3 "$VALIDATOR" "$RETAIN_EVIDENCE"

jq -e '
  .decision == "retain"
  and .review_date == "2026-05-12"
  and (.decision_label | test("retain"; "i"))
  and .capability_uplift.measurement_status == "retain_gate_passed"
  and .capability_uplift.with_avg >= 4
  and .capability_uplift.without_avg <= 3
  and .capability_uplift.uplift >= 1
  and .capability_uplift.with_sample_size >= 6
  and .capability_uplift.without_sample_size >= 6
  and .encoded_preference.measurement_status == "retain_gate_passed"
  and .encoded_preference.fidelity >= 0.8
  and .encoded_preference.sample_size >= 6
  and (.evidence_refs | index("shared/skills/skill-refiner/evals/retain-gate-2026-05-12/retain-evidence.json") != null)
  and (.evidence_refs | index("tests/test-skill-refiner-retain-gate.sh") != null)
' "$LIFECYCLE" >/dev/null || fail "lifecycle review does not satisfy retain gate"

jq -e '
  .artifact_type == "skill-refiner-retain-evidence"
  and .schema_version == 1
  and .blind_pairwise.summary.scenario_count >= 6
  and .blind_pairwise.summary.current_wins >= 5
  and .blind_pairwise.summary.current_avg >= 4
  and .blind_pairwise.summary.baseline_avg <= 3
  and .blind_pairwise.summary.uplift >= 1
  and .blind_pairwise.summary.critical_failures == 0
  and (.real_use_pilots | length) >= 3
  and (.verification_commands | index("bash tests/test-skill-refiner-retain-gate.sh") != null)
' "$RETAIN_EVIDENCE" >/dev/null || fail "retain evidence summary below threshold"

while IFS= read -r result_ref; do
  test -n "$result_ref" || continue
  result_path="$ROOT/$result_ref"
  test -f "$result_path" || fail "missing real-use pilot result: $result_ref"
  schema_version="$(jq -r '.schema_version' "$result_path")"
  case "$schema_version" in
    "3.0.0")
      python3 "$ROOT/shared/skills/skill-refiner/scripts/validate_refinement_result.py" "$result_path" >/dev/null
      ;;
    "2.0.0")
      jq -e '
        .artifact_type == "skill-refiner-result"
        and .target.operation == "optimize"
        and .completion_assessment.overall_status == "pass"
      ' "$result_path" >/dev/null || fail "legacy pilot result is not a passing optimize result: $result_ref"
      ;;
    *)
      fail "unsupported pilot result schema_version ${schema_version}: $result_ref"
      ;;
  esac
done < <(jq -r '.real_use_pilots[].result_ref' "$RETAIN_EVIDENCE")

run_all_list="$(bash "$ROOT/tests/run-all.sh" --quick --list)"
grep -Fq "test-skill-refiner-retain-gate.sh" <<<"$run_all_list" \
  || fail "run-all quick plan must include retain gate"

printf '[PASS] skill-refiner retain gate\n'
