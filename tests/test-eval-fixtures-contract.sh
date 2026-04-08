#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_no_legacy_review_artifact_ref() {
  local file="$1"
  assert_absent 'product-[^[:space:]`"]*review\.md' "$file"
  assert_absent 'design-[^[:space:]`"]*review\.md' "$file"
  assert_absent 'testdesign-[^[:space:]`"]*review\.md' "$file"
}

FIXTURE_PRD="$ROOT/tools/eval/fixtures/weekly-report/prd.md"
RUNNER="$ROOT/tools/eval/run_skill_eval.sh"
SCENARIO_S1="$ROOT/tools/eval/scenarios/s1-design-execution.md"
SCENARIO_S2="$ROOT/tools/eval/scenarios/s2-review-planted.md"
VARIANT_WITH_WHY="$ROOT/tools/eval/scenarios/skill-variants/design-with-why.md"
VARIANT_NO_WHY="$ROOT/tools/eval/scenarios/skill-variants/design-no-why.md"
GRADER="$ROOT/tools/eval/graders/hard-gate-grader.md"

test -f "$FIXTURE_PRD" || fail "missing fixture PRD: $FIXTURE_PRD"

assert_present 'tools/eval/fixtures/weekly-report/prd.md' "$RUNNER"
assert_absent 'docs/weekly-report/prd.md' "$RUNNER"

assert_present 'tools/eval/fixtures/weekly-report/prd.md' "$SCENARIO_S1"
assert_absent 'docs/weekly-report/' "$SCENARIO_S1"
assert_no_legacy_review_artifact_ref "$SCENARIO_S1"

assert_present 'tools/eval/fixtures/weekly-report/prd.md' "$SCENARIO_S2"
assert_absent 'docs/weekly-report/' "$SCENARIO_S2"
assert_no_legacy_review_artifact_ref "$SCENARIO_S2"

assert_no_legacy_review_artifact_ref "$VARIANT_WITH_WHY"
assert_no_legacy_review_artifact_ref "$VARIANT_NO_WHY"
assert_present 'design.md \+ ADR 文件 \+ 共创摘要' "$GRADER"
assert_no_legacy_review_artifact_ref "$GRADER"

echo "[PASS] eval fixtures contract"
