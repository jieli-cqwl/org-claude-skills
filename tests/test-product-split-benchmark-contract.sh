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

RUNNER="$ROOT/tools/eval/scripts/run_product_split_benchmark.py"
CORE="$ROOT/tools/eval/scripts/product_split_benchmark_core.py"
EVAL_SET="$ROOT/tools/eval/scenarios/product-split-benchmark-evals.json"
RESULT_DIR="$ROOT/tools/eval/results/product-split-benchmark-20260415/iteration-4"
BENCHMARK_JSON="$RESULT_DIR/benchmark.json"
BENCHMARK_MD="$RESULT_DIR/benchmark.md"
BENCHMARK_ANALYSIS="$RESULT_DIR/benchmark-analysis.json"
REVIEW_HTML="$RESULT_DIR/review.html"
REPORT_DOC="$ROOT/docs/product-role-split-20260414/deep-validation-report.md"
PLAN_DOC="$ROOT/docs/product-role-split-20260414/evidence-and-eval-plan.md"

test -f "$RUNNER" || fail "missing benchmark runner: $RUNNER"
test -f "$CORE" || fail "missing benchmark core: $CORE"
test -f "$EVAL_SET" || fail "missing benchmark eval set: $EVAL_SET"
test -f "$PLAN_DOC" || fail "missing evidence plan: $PLAN_DOC"

DRY_RUN_OUT="$(mktemp "${TMPDIR:-/tmp}/product-benchmark-dry-run.XXXXXX.out")"
TMP_EVAL_SET="$(mktemp "${TMPDIR:-/tmp}/product-benchmark-evals.XXXXXX.json")"
TMP_RESULT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/product-benchmark-smoke.XXXXXX")"
trap 'rm -f "$DRY_RUN_OUT" "$TMP_EVAL_SET"; rm -rf "$TMP_RESULT_DIR"' EXIT
python3 "$RUNNER" --dry-run >"$DRY_RUN_OUT"
assert_present '^Loaded 6 evals$' "$DRY_RUN_OUT"
assert_present 'with_skill => with_split' "$DRY_RUN_OUT"
assert_present 'without_skill => old_monolith' "$DRY_RUN_OUT"

python3 - <<'PY' "$EVAL_SET" "$TMP_EVAL_SET"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text())
payload["evals"] = payload["evals"][:1]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
PY

python3 - <<'PY' "$EVAL_SET"
import json
import re
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text())
assert payload.get("assessment_mode") == "outcome_based", payload.get("assessment_mode")
for item in payload["evals"]:
    assert item.get("rubric_type") == "outcome_based", item
    assert item.get("outcome_rubric"), item
    searchable = "\n".join(
        [
            item.get("expected_output", ""),
            *[expectation.get("text", "") for expectation in item.get("expectations", [])],
            *[expectation.get("pattern", "") for expectation in item.get("expectations", [])],
        ]
    )
    assert not re.search(r"/product(-director|-manager)?\\b|brief\\.lock\\.json|prd\\.lock\\.json|re-signoff", searchable), searchable
PY

assert_present 'median_representative_run' "$CORE"
assert_present 'blind_order_for_eval' "$CORE"
assert_present 'blind_order' "$CORE"
if rg -n 'mapped = "with_split" if winner == "A"' "$CORE" >/dev/null 2>&1; then
  fail "blind comparison still assumes A is with_split"
fi

python3 "$RUNNER" \
  --eval-set "$TMP_EVAL_SET" \
  --output-dir "$TMP_RESULT_DIR" \
  --runs-per-config 1 \
  --model gpt-5.4-mini \
  --judge-model gpt-5.4-mini

test -f "$TMP_RESULT_DIR/eval-0/with_skill/run-1/executor.log" || fail "missing smoke split executor log"
test -f "$TMP_RESULT_DIR/eval-0/without_skill/run-1/executor.log" || fail "missing smoke monolith executor log"
test -f "$TMP_RESULT_DIR/benchmark.json" || fail "missing smoke benchmark.json"
test -f "$TMP_RESULT_DIR/benchmark-analysis.json" || fail "missing smoke benchmark-analysis.json"
test -f "$TMP_RESULT_DIR/review.html" || fail "missing smoke review.html"
test -f "$TMP_RESULT_DIR/comparison-0.json" || fail "missing smoke comparison file"
assert_present '"blind_order"' "$TMP_RESULT_DIR/comparison-0.json"

test -f "$BENCHMARK_JSON" || fail "missing benchmark.json: $BENCHMARK_JSON"
test -f "$BENCHMARK_MD" || fail "missing benchmark.md: $BENCHMARK_MD"
test -f "$BENCHMARK_ANALYSIS" || fail "missing benchmark-analysis.json: $BENCHMARK_ANALYSIS"
test -f "$REVIEW_HTML" || fail "missing review.html: $REVIEW_HTML"
test -f "$REPORT_DOC" || fail "missing deep validation report: $REPORT_DOC"

python3 - <<'PY' "$BENCHMARK_JSON"
import json
import sys
from pathlib import Path

benchmark = json.loads(Path(sys.argv[1]).read_text())
metadata = benchmark["metadata"]
assert metadata["runs_per_configuration"] == 3, metadata
assert metadata["configuration_labels"]["with_skill"] == "with_split", metadata
assert metadata["configuration_labels"]["without_skill"] == "old_monolith", metadata
assert len(metadata["evals_run"]) == 6, metadata
assert benchmark["run_summary"]["with_skill"]["pass_rate"]["mean"] > benchmark["run_summary"]["without_skill"]["pass_rate"]["mean"], benchmark["run_summary"]
assert len(benchmark["notes"]) == 6, benchmark["notes"]
PY

python3 - <<'PY' "$BENCHMARK_ANALYSIS"
import json
import sys
from pathlib import Path

analysis = json.loads(Path(sys.argv[1]).read_text())
counts = analysis["winner_counts"]
assert counts["with_split"] >= 5, counts
assert counts["with_split"] > counts["old_monolith"], counts
assert counts["with_split"] + counts["old_monolith"] + counts["tie"] == 6, counts
assert len(analysis["notes"]) == 6, analysis["notes"]
PY

comparison_count=$(find "$RESULT_DIR" -maxdepth 1 -type f -name 'comparison-*.json' | wc -l | tr -d ' ')
[ "$comparison_count" = "6" ] || fail "expected 6 blind comparison files, got $comparison_count"

assert_present '严格验证边界' "$PLAN_DOC"
assert_present 'Outcome-based Benchmark' "$PLAN_DOC"
assert_present 'Blind Comparison' "$PLAN_DOC"
assert_present 'skill-creator 风格 benchmark' "$REPORT_DOC"
assert_present 'with_split' "$REPORT_DOC"
assert_present 'old_monolith' "$REPORT_DOC"
assert_present 'Blind comparison' "$REPORT_DOC"
assert_present '6 个真实案例' "$REPORT_DOC"
assert_present 'entry-routing-recommendation-rebuild' "$REPORT_DOC"
assert_present 'review-orchestration-internal-approval' "$REPORT_DOC"

echo "[PASS] product split benchmark contract"
