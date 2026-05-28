#!/usr/bin/env bash
# shellcheck disable=SC2016
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
  if rg -n "$pattern" "$file" >/tmp/product_eval_absent.out 2>&1; then
    cat /tmp/product_eval_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

RUNNER="$ROOT/tools/eval/run_skill_eval.sh"
BENCHMARK_ROOT="$ROOT/tools/eval/results/product-split-benchmark-20260415/iteration-1"
GRADER_DIRECTOR="$ROOT/tools/eval/graders/product-director-thinking-grader.md"
GRADER_MANAGER="$ROOT/tools/eval/graders/product-manager-unit-quality-grader.md"
SCENARIO_DIRECTOR_P1="$ROOT/tools/eval/scenarios/product-director-p1-clear-single-phase.md"
SCENARIO_DIRECTOR_P2="$ROOT/tools/eval/scenarios/product-director-p2-solution-anchoring.md"
SCENARIO_DIRECTOR_P3="$ROOT/tools/eval/scenarios/product-director-p3-multi-phase-value-slicing.md"
SCENARIO_MANAGER_P1="$ROOT/tools/eval/scenarios/product-manager-p1-handoff-readiness.md"
SCENARIO_MANAGER_P2="$ROOT/tools/eval/scenarios/product-manager-p2-lock-drift-blocking.md"
SCENARIO_MANAGER_P3="$ROOT/tools/eval/scenarios/product-manager-p3-unit-boundary-cocreation.md"
PM_EVALS="$ROOT/shared/skills/product-manager/evals/evals.json"
PM_LIFECYCLE="$ROOT/shared/skills/product-manager/evals/lifecycle-review.json"
PM_DOGFOOD="$ROOT/shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/dogfood-result.json"
PM_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
PM_TEST_PROMPTS="$ROOT/shared/skills/product-manager/test-prompts.json"
DIRECTOR_EVALS="$ROOT/shared/skills/product-director/evals/evals.json"
DIRECTOR_TEST_PROMPTS="$ROOT/shared/skills/product-director/test-prompts.json"

test -f "$GRADER_DIRECTOR" || fail "missing product-director grader: $GRADER_DIRECTOR"
test -f "$GRADER_MANAGER" || fail "missing product-manager grader: $GRADER_MANAGER"
test -f "$SCENARIO_DIRECTOR_P1" || fail "missing director eval scenario: $SCENARIO_DIRECTOR_P1"
test -f "$SCENARIO_DIRECTOR_P2" || fail "missing director eval scenario: $SCENARIO_DIRECTOR_P2"
test -f "$SCENARIO_DIRECTOR_P3" || fail "missing director eval scenario: $SCENARIO_DIRECTOR_P3"
test -f "$SCENARIO_MANAGER_P1" || fail "missing manager eval scenario: $SCENARIO_MANAGER_P1"
test -f "$SCENARIO_MANAGER_P2" || fail "missing manager eval scenario: $SCENARIO_MANAGER_P2"
test -f "$SCENARIO_MANAGER_P3" || fail "missing manager eval scenario: $SCENARIO_MANAGER_P3"
test -f "$PM_EVALS" || fail "missing product-manager evals: $PM_EVALS"
test -f "$PM_LIFECYCLE" || fail "missing product-manager lifecycle review: $PM_LIFECYCLE"
test -f "$PM_DOGFOOD" || fail "missing product-manager dogfood result: $PM_DOGFOOD"
test -f "$PM_SKILL" || fail "missing product-manager skill: $PM_SKILL"
test -f "$PM_TEST_PROMPTS" || fail "missing product-manager test prompts: $PM_TEST_PROMPTS"
test -f "$DIRECTOR_EVALS" || fail "missing product-director evals: $DIRECTOR_EVALS"
test -f "$DIRECTOR_TEST_PROMPTS" || fail "missing product-director test prompts: $DIRECTOR_TEST_PROMPTS"
test -d "$BENCHMARK_ROOT" || fail "missing product split benchmark results root: $BENCHMARK_ROOT"

if rg -n '\(\([^)]*(\+\+|--)[^)]*\)\)' "$RUNNER" >/dev/null; then
  fail "run_skill_eval.sh must avoid arithmetic inc/dec command status under set -e"
fi

python3 - "$PM_EVALS" "$PM_LIFECYCLE" "$PM_DOGFOOD" "$DIRECTOR_EVALS" "$DIRECTOR_TEST_PROMPTS" <<'PY'
import json
import sys
from pathlib import Path

for source in map(Path, sys.argv[1:]):
    artifact = json.loads(source.read_text(encoding="utf-8"))
    stack = [((), artifact)]
    while stack:
        path, value = stack.pop()
        if isinstance(value, dict):
            stack.extend((path + (key,), child) for key, child in value.items())
            continue
        if isinstance(value, list):
            stack.extend((path + (str(index),), child) for index, child in enumerate(value))
            continue
        if not isinstance(value, str):
            continue
        if path and (path[-1] in {"id", "eval_id", "with_skill_ref", "without_skill_ref"} or "files" in path):
            continue
        if any(term in value for term in ("standard-chain", "canonical", "真源", "accepted_warning")):
            raise SystemExit(f"old eval wording in {source}:{'.'.join(path)}: {value}")
PY

python3 - "$PM_SKILL" "$PM_EVALS" "$PM_TEST_PROMPTS" <<'PY'
import sys
from pathlib import Path

for source in map(Path, sys.argv[1:]):
    text = source.read_text(encoding="utf-8")
    for forbidden in ("PM co-creation ledger", "PM 台账"):
        if forbidden in text:
            raise SystemExit(f"deprecated PM ledger anchor in {source}: {forbidden}")

skill_text = Path(sys.argv[1]).read_text(encoding="utf-8")
for bad in (
    "阻断、open question、WARN 和漂移写入拥有该问题的 `issue_ledger`",
    "阻断、WARN、漂移和 open question 写 `issue_ledger`",
    "`issue_ledger` 记录阻断、open question、WARN 和漂移",
):
    if bad in skill_text:
        raise SystemExit(f"PM open issue state must not route directly to issue_ledger: {bad}")
for source in map(Path, sys.argv[2:]):
    text = source.read_text(encoding="utf-8")
    if "分类结果写入对应 JSON 的 `issue_ledger`" in text:
        raise SystemExit(f"PM pre-review classification must route to pre_review_issue_ledger: {source}")
PY

test -f "$BENCHMARK_ROOT/eval-0/with_skill/run-1/outputs/response.md" || fail "missing split benchmark response"
test -f "$BENCHMARK_ROOT/eval-0/without_skill/run-1/outputs/response.md" || fail "missing monolith benchmark response"
test -f "$BENCHMARK_ROOT/eval-0/with_skill/run-1/grading.json" || fail "missing split benchmark grading"
test -f "$BENCHMARK_ROOT/eval-0/without_skill/run-1/grading.json" || fail "missing monolith benchmark grading"
test -f "$BENCHMARK_ROOT/eval-5/without_skill/run-3/timing.json" || fail "missing benchmark timing metadata"

RESPONSE_COUNT="$(find "$BENCHMARK_ROOT" -path '*/outputs/response.md' | wc -l | tr -d ' ')"
[ "$RESPONSE_COUNT" = "36" ] || fail "unexpected benchmark response count: $RESPONSE_COUNT"
GRADING_COUNT="$(find "$BENCHMARK_ROOT" -name grading.json | wc -l | tr -d ' ')"
[ "$GRADING_COUNT" = "36" ] || fail "unexpected benchmark grading count: $GRADING_COUNT"
TIMING_COUNT="$(find "$BENCHMARK_ROOT" -name timing.json | wc -l | tr -d ' ')"
[ "$TIMING_COUNT" = "36" ] || fail "unexpected benchmark timing count: $TIMING_COUNT"
METADATA_COUNT="$(find "$BENCHMARK_ROOT" -name eval_metadata.json | wc -l | tr -d ' ')"
[ "$METADATA_COUNT" = "36" ] || fail "unexpected benchmark metadata count: $METADATA_COUNT"

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

assert_present '未收到用户明确回复 `产品总监确认` 前，不写 `brief\.json` 或 `phase-\{N\}/phase-prd\.json`' "$SCENARIO_DIRECTOR_P1"
assert_present '未收到用户明确回复 `产品总监确认` 前，不写 `brief\.json` 或 `phase-\{N\}/phase-prd\.json`' "$SCENARIO_DIRECTOR_P2"
assert_present '未收到用户明确回复 `产品总监确认` 前，不写 `brief\.json` 或 `phase-\{N\}/phase-prd\.json`' "$SCENARIO_DIRECTOR_P3"
assert_absent '等待确认|明确 产品总监确认' "$SCENARIO_DIRECTOR_P1"
assert_absent '等待确认|明确 产品总监确认' "$SCENARIO_DIRECTOR_P2"
assert_absent '等待确认|明确 产品总监确认' "$SCENARIO_DIRECTOR_P3"
assert_present '只提出一个会改变基线的待验证事实' "$SCENARIO_DIRECTOR_P1"
assert_present '方案线索' "$SCENARIO_DIRECTOR_P2"
assert_present '按业务价值提出 Phase 切分推荐' "$SCENARIO_DIRECTOR_P3"
assert_present 'director_confirmation' "$SCENARIO_MANAGER_P1"
assert_present 'brief\.json' "$SCENARIO_MANAGER_P1"
assert_present 'phase-1/phase-prd\.json' "$SCENARIO_MANAGER_P1"
assert_present 'director_confirmation' "$SCENARIO_MANAGER_P2"
assert_present 'phase-1/phase-prd\.json' "$SCENARIO_MANAGER_P2"
assert_present 'review_conclusion' "$SCENARIO_MANAGER_P3"

assert_present '"id": "clear-goal-default-judgment"' "$DIRECTOR_EVALS"
assert_present '不机械重问已闭合的基础事实' "$DIRECTOR_EVALS"
assert_present '给出 Director 推荐基线和推荐理由' "$DIRECTOR_EVALS"
assert_present '"id": "vague-success-criteria-rejected"' "$DIRECTOR_EVALS"
assert_present '"id": "business-semantics-recommendation-with-gaps"' "$DIRECTOR_EVALS"
assert_present '"id": "upstream-fact-replacement-backtracks"' "$DIRECTOR_EVALS"
assert_present '"id": "PA-9"' "$DIRECTOR_EVALS"
assert_present '"id": "PA-10"' "$DIRECTOR_EVALS"
assert_present '已闭合上游事实变化' "$DIRECTOR_EVALS"
assert_present '"id": "technical-demand-framed-before-solution"' "$DIRECTOR_EVALS"
assert_present '"id": "PA-14"' "$DIRECTOR_EVALS"
assert_present '"id": "finalization-renders-projection-view"' "$DIRECTOR_EVALS"
assert_present '"id": "PA-16"' "$DIRECTOR_EVALS"
assert_absent '等待确认' "$DIRECTOR_EVALS"
assert_absent '等待用户确认' "$DIRECTOR_EVALS"
assert_absent '只确认 WHY' "$DIRECTOR_EVALS"
assert_absent '收到明确确认' "$DIRECTOR_EVALS"
assert_absent '明确 产品总监确认' "$DIRECTOR_EVALS"
assert_absent '进入产品总监确认' "$DIRECTOR_EVALS"
assert_absent '要求先确认' "$DIRECTOR_EVALS"
assert_absent '缺少总监确认' "$DIRECTOR_EVALS"
assert_absent '等待确认' "$DIRECTOR_TEST_PROMPTS"
assert_absent '等待用户确认' "$DIRECTOR_TEST_PROMPTS"
assert_absent '只确认 WHY' "$DIRECTOR_TEST_PROMPTS"
assert_absent '收到明确确认' "$DIRECTOR_TEST_PROMPTS"
assert_absent '明确 产品总监确认' "$DIRECTOR_TEST_PROMPTS"
assert_absent '进入产品总监确认' "$DIRECTOR_TEST_PROMPTS"
assert_absent '要求先确认' "$DIRECTOR_TEST_PROMPTS"
assert_absent '缺少总监确认' "$DIRECTOR_TEST_PROMPTS"
python3 - "$PM_EVALS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
cases = {case.get("id"): case for case in data.get("evals", [])}
case = cases.get("high-risk-review-on-demand")
if not case:
    raise SystemExit(f"{path}: missing eval high-risk-review-on-demand")
anchors = set(case.get("expected_anchors", []))
if "high-risk-review" not in anchors:
    raise SystemExit(f"{path}: high-risk-review-on-demand must anchor high-risk-review")
text = "\n".join(
    [item for item in case.get("expectations", []) if isinstance(item, str)]
)
required_signals = ["High-Risk Signals", "不追加高风险检查"]
missing = [signal for signal in required_signals if signal not in text]
if missing:
    raise SystemExit(
        f"{path}: high-risk-review-on-demand missing behavior signals {missing}"
    )
PY

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
