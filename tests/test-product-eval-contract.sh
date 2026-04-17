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
BENCHMARK_ROOT="$ROOT/tools/eval/results/product-split-benchmark-20260415/iteration-1"
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
test -d "$BENCHMARK_ROOT" || fail "missing product split benchmark results root: $BENCHMARK_ROOT"

assert_present '^## 严格验证边界$' "$PLAN_DOC"
assert_present '接线存在性不是输出质量证明' "$PLAN_DOC"
assert_present '历史 benchmark 只能作为参考证据' "$PLAN_DOC"
assert_present "human-reviewable artifacts：保留 \`benchmark\.json / review\.html / comparison-\*\.json / report\.md\`" "$PLAN_DOC"
assert_present 'Case 1：Entry Routing' "$PLAN_DOC"
assert_present "ID：\`entry-routing-recommendation-rebuild\`" "$PLAN_DOC"
assert_present "ID：\`solution-anchoring-growth-dashboard\`" "$PLAN_DOC"
assert_present "ID：\`handoff-boundary-loyalty-phase-change\`" "$PLAN_DOC"
assert_present "ID：\`legacy-brief-migration-pricing-center\`" "$PLAN_DOC"
assert_present "ID：\`review-orchestration-internal-approval\`" "$PLAN_DOC"
assert_present "ID：\`phase-planning-partner-onboarding\`" "$PLAN_DOC"
assert_present 'product split benchmark contract' "$PLAN_DOC"
assert_present 'tools/eval/results/product-split-benchmark-20260415/iteration-1/' "$PLAN_DOC"
assert_present 'docs/product-role-split-20260414/deep-validation-report\.md' "$PLAN_DOC"

test -f "$BENCHMARK_ROOT/eval-0/with_skill/run-1/executor.log" || fail "missing split benchmark executor log"
test -f "$BENCHMARK_ROOT/eval-0/without_skill/run-1/executor.log" || fail "missing monolith benchmark executor log"
test -f "$BENCHMARK_ROOT/eval-5/without_skill/run-3/timing.json" || fail "missing benchmark timing metadata"

EXECUTOR_LOG_COUNT="$(find "$BENCHMARK_ROOT" -name executor.log | wc -l | tr -d ' ')"
[ "$EXECUTOR_LOG_COUNT" = "36" ] || fail "unexpected benchmark executor log count: $EXECUTOR_LOG_COUNT"

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
