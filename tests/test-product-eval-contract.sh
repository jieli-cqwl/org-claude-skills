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

assert_present 'product-director-thinking-grader\.md' "$RUNNER"
assert_present 'product-manager-unit-quality-grader\.md' "$RUNNER"
assert_present 'product-director-p1-clear-single-phase\.md' "$RUNNER"
assert_present 'product-director-p2-solution-anchoring\.md' "$RUNNER"
assert_present 'product-director-p3-multi-phase-value-slicing\.md' "$RUNNER"
assert_present 'product-manager-p1-handoff-readiness\.md' "$RUNNER"
assert_present 'product-manager-p2-lock-drift-blocking\.md' "$RUNNER"
assert_present 'product-manager-p3-unit-boundary-cocreation\.md' "$RUNNER"

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
assert_present 'brief\.lock\.json' "$SCENARIO_MANAGER_P1"
assert_present 'prd\.lock\.json' "$SCENARIO_MANAGER_P2"

echo "[PASS] product eval contract"
