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
PLAN_DOC="$ROOT/docs/product-skill-evidence-plan-20260412/evidence-and-eval-plan.md"
GRADER="$ROOT/tools/eval/graders/product-thinking-grader.md"
SCENARIO_P1="$ROOT/tools/eval/scenarios/p1-clear-single-phase.md"
SCENARIO_P2="$ROOT/tools/eval/scenarios/p2-solution-anchoring.md"
SCENARIO_P3="$ROOT/tools/eval/scenarios/p3-multi-phase-value-slicing.md"

test -f "$PLAN_DOC" || fail "missing product evidence plan: $PLAN_DOC"
test -f "$GRADER" || fail "missing product grader: $GRADER"
test -f "$SCENARIO_P1" || fail "missing product eval scenario: $SCENARIO_P1"
test -f "$SCENARIO_P2" || fail "missing product eval scenario: $SCENARIO_P2"
test -f "$SCENARIO_P3" || fail "missing product eval scenario: $SCENARIO_P3"

assert_present 'product-thinking-grader\.md' "$RUNNER"
assert_present 'p1-clear-single-phase\.md' "$RUNNER"
assert_present 'p2-solution-anchoring\.md' "$RUNNER"
assert_present 'p3-multi-phase-value-slicing\.md' "$RUNNER"

assert_present "场景 ID：\`p1-clear-single-phase\`" "$PLAN_DOC"
assert_present "场景 ID：\`p2-solution-anchoring\`" "$PLAN_DOC"
assert_present "场景 ID：\`p3-multi-phase-value-slicing\`" "$PLAN_DOC"

assert_present 'tools/eval/graders/product-thinking-grader\.md' "$SCENARIO_P1"
assert_present 'tools/eval/graders/product-thinking-grader\.md' "$SCENARIO_P2"
assert_present 'tools/eval/graders/product-thinking-grader\.md' "$SCENARIO_P3"

assert_present 'brief\.md' "$SCENARIO_P1"
assert_present 'brief\.md' "$SCENARIO_P2"
assert_present 'phase-\{N\}/prd\.md' "$SCENARIO_P3"

echo "[PASS] product eval contract"
