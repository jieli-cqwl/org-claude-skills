#!/usr/bin/env bash
# File role: prove skill-refiner closure audit separates formal evidence, fixtures, target scope, and unrelated dirty files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/shared/skills/skill-refiner/evals/dogfood/closure-audit/closure-audit-result.json"
RUN_ALL="$ROOT/tests/run-all.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$AUDIT" || fail "missing closure audit: ${AUDIT#"$ROOT"/}"
jq empty "$AUDIT" >/dev/null || fail "invalid closure audit JSON"

jq -e '
  .artifact_type == "skill-refiner-closure-audit"
  and .decision_authority == "advisory_only"
  and .production_target_changes["shared/skills/github-repo-radar"] == []
  and .production_target_changes.status == "none"
  and (.dogfood_fixtures | map(.id) == [
    "small-output-contract",
    "self-run-final-operation-gate",
    "supersedes-drift-gate",
    "github-repo-radar-external-practice"
  ])
  and (.dogfood_fixtures | all(.production_target_modified == false))
  and (.formal_capability_evidence | map(.capability) | index("conclusion drift handling through supersedes") != null)
  and (.formal_capability_evidence | map(.capability) | index("all-ring external best-practice source depth") != null)
  and (.formal_capability_evidence | all(.status == "closed"))
  and (.registered_tests | index("tests/test-skill-refiner-github-radar-external-practice.sh") != null)
  and (.registered_tests | index("tests/test-skill-refiner-supersedes-drift-gate.sh") != null)
  and (.unrelated_dirty_files_observed == [])
  and (.closure_findings | any(.severity == "INFO" and (.finding | contains("no unrelated dirty files"))))
  and (.next_action | contains("real SR-S2"))
' "$AUDIT" >/dev/null || fail "closure audit content drift"

jq -r '
  [
    .formal_capability_evidence[].refs[],
    .registered_tests[],
    .verification_commands[]
      | select(startswith("bash ") or startswith("python3 "))
      | split(" ")[1]
  ] | unique[]
' "$AUDIT" | while IFS= read -r ref; do
  test -e "$ROOT/$ref" || fail "closure audit references missing path: $ref"
done

run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-closure-audit.sh' <<<"$run_all_list" \
  || fail "closure audit test is not registered in tests/run-all.sh"

printf '[PASS] skill-refiner closure audit\n'
