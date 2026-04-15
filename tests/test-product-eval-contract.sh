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

RUNNER="$ROOT/tools/eval/run_skill_eval.sh"
PLAN_DOC="$ROOT/docs/product-role-split-20260414/evidence-and-eval-plan.md"
GRADER_DIRECTOR="$ROOT/tools/eval/graders/product-director-thinking-grader.md"
GRADER_MANAGER="$ROOT/tools/eval/graders/product-manager-unit-quality-grader.md"
SCENARIO_DIRECTOR_P1="$ROOT/tools/eval/scenarios/product-director-p1-clear-single-phase.md"
SCENARIO_DIRECTOR_P2="$ROOT/tools/eval/scenarios/product-director-p2-solution-anchoring.md"
SCENARIO_DIRECTOR_P3="$ROOT/tools/eval/scenarios/product-director-p3-multi-phase-value-slicing.md"
SCENARIO_MANAGER_P1="$ROOT/tools/eval/scenarios/product-manager-p1-handoff-readiness.md"
SCENARIO_MANAGER_P2="$ROOT/tools/eval/scenarios/product-manager-p2-lock-drift-blocking.md"
SCENARIO_MANAGER_P3="$ROOT/tools/eval/scenarios/product-manager-p3-unit-boundary-cocreation.md"

test -f "$PLAN_DOC" || fail "missing product role split evidence plan: $PLAN_DOC"
test -f "$GRADER_DIRECTOR" || fail "missing product-director grader: $GRADER_DIRECTOR"
test -f "$GRADER_MANAGER" || fail "missing product-manager grader: $GRADER_MANAGER"
test -f "$SCENARIO_DIRECTOR_P1" || fail "missing director eval scenario: $SCENARIO_DIRECTOR_P1"
test -f "$SCENARIO_DIRECTOR_P2" || fail "missing director eval scenario: $SCENARIO_DIRECTOR_P2"
test -f "$SCENARIO_DIRECTOR_P3" || fail "missing director eval scenario: $SCENARIO_DIRECTOR_P3"
test -f "$SCENARIO_MANAGER_P1" || fail "missing manager eval scenario: $SCENARIO_MANAGER_P1"
test -f "$SCENARIO_MANAGER_P2" || fail "missing manager eval scenario: $SCENARIO_MANAGER_P2"
test -f "$SCENARIO_MANAGER_P3" || fail "missing manager eval scenario: $SCENARIO_MANAGER_P3"

assert_present "场景 ID：\`product-director-p1-clear-single-phase\`" "$PLAN_DOC"
assert_present "场景 ID：\`product-director-p2-solution-anchoring\`" "$PLAN_DOC"
assert_present "场景 ID：\`product-director-p3-multi-phase-value-slicing\`" "$PLAN_DOC"
assert_present "场景 ID：\`product-manager-p1-handoff-readiness\`" "$PLAN_DOC"
assert_present "场景 ID：\`product-manager-p2-lock-drift-blocking\`" "$PLAN_DOC"
assert_present "场景 ID：\`product-manager-p3-unit-boundary-cocreation\`" "$PLAN_DOC"

assert_present 'tools/eval/graders/product-director-thinking-grader\.md' "$SCENARIO_DIRECTOR_P1"
assert_present 'tools/eval/graders/product-director-thinking-grader\.md' "$SCENARIO_DIRECTOR_P2"
assert_present 'tools/eval/graders/product-director-thinking-grader\.md' "$SCENARIO_DIRECTOR_P3"
assert_present 'tools/eval/graders/product-manager-unit-quality-grader\.md' "$SCENARIO_MANAGER_P1"
assert_present 'tools/eval/graders/product-manager-unit-quality-grader\.md' "$SCENARIO_MANAGER_P2"
assert_present 'tools/eval/graders/product-manager-unit-quality-grader\.md' "$SCENARIO_MANAGER_P3"
assert_present 'grading-product-director-thinking\.json' "$SCENARIO_DIRECTOR_P1"
assert_present 'grading-product-director-thinking\.json' "$SCENARIO_DIRECTOR_P2"
assert_present 'grading-product-director-thinking\.json' "$SCENARIO_DIRECTOR_P3"
assert_present 'grading-product-manager-unit-quality\.json' "$SCENARIO_MANAGER_P1"
assert_present 'grading-product-manager-unit-quality\.json' "$SCENARIO_MANAGER_P2"
assert_present 'grading-product-manager-unit-quality\.json' "$SCENARIO_MANAGER_P3"

assert_present 'brief\.md' "$SCENARIO_DIRECTOR_P1"
assert_present '产品总监确认' "$SCENARIO_MANAGER_P1"
assert_present 'brief\.lock\.json' "$SCENARIO_MANAGER_P1"
assert_present '产品总监确认' "$SCENARIO_MANAGER_P2"
assert_present 'prd\.lock\.json' "$SCENARIO_MANAGER_P2"
assert_present '产品总监确认' "$SCENARIO_MANAGER_P3"

STATUS_OUT="$(mktemp "${TMPDIR:-/tmp}/product-eval-status.XXXXXX.out")"
CHECK_OUT="$(mktemp "${TMPDIR:-/tmp}/product-eval-check.XXXXXX.out")"
SUMMARY_OUT="$(mktemp "${TMPDIR:-/tmp}/product-eval-summary.XXXXXX.out")"
trap 'rm -f "$CHECK_OUT" "$STATUS_OUT" "$SUMMARY_OUT"' EXIT

bash "$RUNNER" check >"$CHECK_OUT"
assert_present 'graders/product-director-thinking-grader\.md' "$CHECK_OUT"
assert_present 'graders/product-manager-unit-quality-grader\.md' "$CHECK_OUT"
assert_present 'scenarios/product-director-p1-clear-single-phase\.md' "$CHECK_OUT"
assert_present 'scenarios/product-manager-p3-unit-boundary-cocreation\.md' "$CHECK_OUT"

bash "$RUNNER" status >"$STATUS_OUT"
assert_present 'product-director-p1-clear-single-phase-run-1' "$STATUS_OUT"
assert_present 'product-director-p1-clear-single-phase-run-2' "$STATUS_OUT"
assert_present 'product-director-p1-clear-single-phase-run-3' "$STATUS_OUT"
assert_present 'product-director-p2-solution-anchoring-run-1' "$STATUS_OUT"
assert_present 'product-director-p2-solution-anchoring-run-2' "$STATUS_OUT"
assert_present 'product-director-p2-solution-anchoring-run-3' "$STATUS_OUT"
assert_present 'product-director-p3-multi-phase-value-slicing-run-1' "$STATUS_OUT"
assert_present 'product-director-p3-multi-phase-value-slicing-run-2' "$STATUS_OUT"
assert_present 'product-director-p3-multi-phase-value-slicing-run-3' "$STATUS_OUT"
assert_present 'product-manager-p1-handoff-readiness-run-1' "$STATUS_OUT"
assert_present 'product-manager-p1-handoff-readiness-run-2' "$STATUS_OUT"
assert_present 'product-manager-p1-handoff-readiness-run-3' "$STATUS_OUT"
assert_present 'product-manager-p2-lock-drift-blocking-run-1' "$STATUS_OUT"
assert_present 'product-manager-p2-lock-drift-blocking-run-2' "$STATUS_OUT"
assert_present 'product-manager-p2-lock-drift-blocking-run-3' "$STATUS_OUT"
assert_present 'product-manager-p3-unit-boundary-cocreation-run-1' "$STATUS_OUT"
assert_present 'product-manager-p3-unit-boundary-cocreation-run-2' "$STATUS_OUT"
assert_present 'product-manager-p3-unit-boundary-cocreation-run-3' "$STATUS_OUT"

bash "$RUNNER" summary >"$SUMMARY_OUT"
assert_present '^--- Track 8: Product Director Thinking ---$' "$SUMMARY_OUT"
assert_present '^--- Track 9: Product Manager Unit Quality ---$' "$SUMMARY_OUT"
assert_present '^  product-director-p1-clear-single-phase:$' "$SUMMARY_OUT"
assert_present '^  product-director-p2-solution-anchoring:$' "$SUMMARY_OUT"
assert_present '^  product-director-p3-multi-phase-value-slicing:$' "$SUMMARY_OUT"
assert_present '^  product-manager-p1-handoff-readiness:$' "$SUMMARY_OUT"
assert_present '^  product-manager-p2-lock-drift-blocking:$' "$SUMMARY_OUT"
assert_present '^  product-manager-p3-unit-boundary-cocreation:$' "$SUMMARY_OUT"

echo "[PASS] product eval contract"
