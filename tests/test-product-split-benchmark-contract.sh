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
REVIEW="$ROOT/tools/eval/scripts/product_split_benchmark_review.py"
EVAL_SET="$ROOT/tools/eval/scenarios/product-split-benchmark-evals.json"
RESULT_DIR="$ROOT/tools/eval/results/product-split-benchmark-20260415/iteration-4"
BENCHMARK_JSON="$RESULT_DIR/benchmark.json"
BENCHMARK_MD="$RESULT_DIR/benchmark.md"
BENCHMARK_ANALYSIS="$RESULT_DIR/benchmark-analysis.json"
REVIEW_HTML="$RESULT_DIR/review.html"

test -f "$RUNNER" || fail "missing benchmark runner: $RUNNER"
test -f "$CORE" || fail "missing benchmark core: $CORE"
test -f "$REVIEW" || fail "missing benchmark review helpers: $REVIEW"
test -f "$EVAL_SET" || fail "missing benchmark eval set: $EVAL_SET"

DRY_RUN_OUT="$(mktemp "${TMPDIR:-/tmp}/product-benchmark-dry-run.XXXXXX.out")"
TMP_EVAL_SET="$(mktemp "${TMPDIR:-/tmp}/product-benchmark-evals.XXXXXX.json")"
TMP_RESULT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/product-benchmark-smoke.XXXXXX")"
trap 'rm -f "$DRY_RUN_OUT" "$TMP_EVAL_SET"; rm -rf "$TMP_RESULT_DIR" "${FAKE_CODEX_BIN:-}" "${FAKE_JUDGE_CODEX_BIN:-}" "${FAKE_SMOKE_CODEX_BIN:-}"' EXIT
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
assert_present 'run_structured_judge' "$REVIEW"
assert_present 'generate_review' "$REVIEW"
if rg -n 'mapped = "with_split" if winner == "A"' "$CORE" "$REVIEW" >/dev/null 2>&1; then
  fail "blind comparison still assumes A is with_split"
fi

FAKE_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/product-benchmark-fake-codex.XXXXXX")"
cat > "$FAKE_CODEX_BIN/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output_path=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ] && [ "$#" -ge 2 ]; then
    output_path="$2"
    shift 2
    continue
  fi
  shift
done
if [ -n "$output_path" ]; then
  mkdir -p "$(dirname "$output_path")"
  printf 'this response matches the keyword\n' > "$output_path"
fi
exit 7
SH
chmod +x "$FAKE_CODEX_BIN/codex"
PATH="$FAKE_CODEX_BIN:$PATH" python3 - <<'PY' "$CORE" "$TMP_RESULT_DIR"
import importlib.util
import sys
from pathlib import Path

core_path = Path(sys.argv[1])
workspace = Path(sys.argv[2]) / "nonzero-workspace"
run_dir = Path(sys.argv[2]) / "nonzero-run"
workspace.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("product_split_benchmark_core", core_path)
core = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = core
spec.loader.exec_module(core)

eval_item = {
    "id": 0,
    "name": "nonzero executor",
    "prompt": "return keyword",
    "expected_output": "keyword",
    "expectations": [{"text": "keyword", "pattern": "keyword"}],
}
try:
    core.run_executor(
        eval_item,
        core.BenchmarkConfig("with_skill", "with_split"),
        workspace,
        run_dir,
        model=None,
        timeout_sec=30,
    )
except RuntimeError:
    pass
else:
    raise SystemExit("run_executor must fail when codex writes a response but exits non-zero")
PY

FAKE_JUDGE_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/product-benchmark-fake-judge.XXXXXX")"
cat > "$FAKE_JUDGE_CODEX_BIN/codex" <<'SH'
#!/usr/bin/env bash
printf '{"winner":"Tie","reasoning":"synthetic nonzero judge","strengths":{"A":[],"B":[]},"weaknesses":{"A":[],"B":[]}}\n'
exit 7
SH
chmod +x "$FAKE_JUDGE_CODEX_BIN/codex"
PATH="$FAKE_JUDGE_CODEX_BIN:$PATH" python3 - <<'PY' "$CORE" "$REVIEW" "$TMP_RESULT_DIR"
import importlib.util
import sys
from pathlib import Path

core_path = Path(sys.argv[1])
review_path = Path(sys.argv[2])
workspace = Path(sys.argv[3]) / "nonzero-judge"
workspace.mkdir(parents=True, exist_ok=True)

core_spec = importlib.util.spec_from_file_location("product_split_benchmark_core", core_path)
core = importlib.util.module_from_spec(core_spec)
assert core_spec.loader is not None
sys.modules[core_spec.name] = core
core_spec.loader.exec_module(core)

review_spec = importlib.util.spec_from_file_location("product_split_benchmark_review", review_path)
review = importlib.util.module_from_spec(review_spec)
assert review_spec.loader is not None
sys.modules[review_spec.name] = review
review_spec.loader.exec_module(review)

try:
    review.run_structured_judge(
        "judge prompt",
        workspace / "comparison.json",
        workspace / "comparison.log",
        model=None,
    )
except RuntimeError:
    pass
else:
    raise SystemExit("run_structured_judge must fail when codex exits non-zero even if stdout is valid JSON")
PY

python3 - <<'PY' "$CORE" "$TMP_RESULT_DIR"
import importlib.util
import json
import sys
from pathlib import Path

core_path = Path(sys.argv[1])
run_dir = Path(sys.argv[2]) / "hollow-rubric-run"
run_dir.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("product_split_benchmark_core", core_path)
core = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = core
spec.loader.exec_module(core)

eval_item = {
    "id": 999,
    "name": "hollow rubric",
    "rubric_type": "outcome_based",
    "outcome_rubric": [
        "明确当前还不是写完整 PRD 的时机",
        "先收敛根问题、目标、范围和阶段边界",
        "给出清晰下一步，不把方案当成已闭合事实",
    ],
    "expectations": [
        {"text": "不直接写完整 PRD", "pattern": "不要直接|先不直接|还不是.*PRD"},
        {"text": "先冻结关键产品基线", "pattern": "根问题|目标|范围|阶段边界|Phase"},
        {"text": "给出下一步推进建议", "pattern": "下一步|先.*确认|先.*收敛|先.*冻结"},
    ],
}
core.grade_run(
    eval_item,
    "不要直接写完整 PRD。根问题 目标 范围 阶段边界。下一步 确认 收敛 冻结 方案。根问题 目标 范围 阶段边界。下一步 确认 收敛 冻结 方案。PRD Phase 基线 上游 细化 改写 迁移候选 产品 架构 测试 PASS 确认轮 重审 ASK_USER BLOCKED。",
    run_dir,
    1.0,
    0,
)
grading = json.loads((run_dir / "grading.json").read_text())
if grading["summary"]["pass_rate"] >= 1.0:
    raise SystemExit("hollow keyword-only response must not receive a perfect outcome score")
rubric_rows = grading.get("rubric_evaluations", [])
if not rubric_rows or all(row.get("passed") for row in rubric_rows):
    raise SystemExit("grading must include failing rubric_evaluations for hollow outcome responses")
PY

python3 - <<'PY' "$CORE" "$TMP_RESULT_DIR"
import importlib.util
import json
import sys
from pathlib import Path

core_path = Path(sys.argv[1])
run_dir = Path(sys.argv[2]) / "keyword-stuffed-rubric-run"
run_dir.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("product_split_benchmark_core", core_path)
core = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = core
spec.loader.exec_module(core)

eval_item = {
    "id": 1000,
    "name": "marker-free keyword stuffing",
    "rubric_type": "outcome_based",
    "outcome_rubric": [
        "明确当前还不是写完整 PRD 的时机",
        "先收敛根问题、目标、范围和阶段边界",
        "给出清晰下一步，不把方案当成已闭合事实",
    ],
    "expectations": [
        {"text": "不直接写完整 PRD", "pattern": "不要直接|先不直接|还不是.*PRD"},
        {"text": "先冻结关键产品基线", "pattern": "根问题|目标|范围|阶段边界|Phase"},
        {"text": "给出下一步推进建议", "pattern": "下一步|先.*确认|先.*收敛|先.*冻结"},
    ],
}
stuffed = (
    "不要直接写完整 PRD。因为需要输出验收标准，所以确认后冻结后再进入下一步。"
    "根问题 目标 范围 阶段边界 Phase 下一步 确认 收敛 冻结 方案。"
    "根问题 目标 范围 阶段边界 Phase 下一步 确认 收敛 冻结 方案。"
    "根问题 目标 范围 阶段边界 Phase 下一步 确认 收敛 冻结 方案。"
    "PRD 基线 上游 细化 改写 迁移候选 产品 架构 测试 PASS 确认轮 重审 ASK_USER BLOCKED。"
)
core.grade_run(eval_item, stuffed, run_dir, 1.0, 0)
grading = json.loads((run_dir / "grading.json").read_text())
if grading["summary"]["pass_rate"] >= 1.0:
    raise SystemExit("marker-free keyword stuffing must not receive a perfect outcome score")
rubric_rows = grading.get("rubric_evaluations", [])
if not rubric_rows or all(row.get("passed") for row in rubric_rows):
    raise SystemExit("grading must fail at least one rubric row for marker-free keyword stuffing")
PY

python3 - <<'PY' "$CORE" "$TMP_RESULT_DIR"
import importlib.util
import json
import sys
from pathlib import Path

core_path = Path(sys.argv[1])
run_dir = Path(sys.argv[2]) / "low-repeat-keyword-stuffed-rubric-run"
run_dir.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("product_split_benchmark_core", core_path)
core = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = core
spec.loader.exec_module(core)

eval_item = {
    "id": 1001,
    "name": "low-repeat marker-free keyword stuffing",
    "rubric_type": "outcome_based",
    "outcome_rubric": [
        "明确当前还不是写完整 PRD 的时机",
        "先收敛根问题、目标、范围和阶段边界",
        "给出清晰下一步，不把方案当成已闭合事实",
    ],
    "expectations": [
        {"text": "不直接写完整 PRD", "pattern": "不要直接|先不直接|还不是.*PRD"},
        {"text": "先冻结关键产品基线", "pattern": "根问题|目标|范围|阶段边界|Phase"},
        {"text": "给出下一步推进建议", "pattern": "下一步|先.*确认|先.*收敛|先.*冻结"},
    ],
}
stuffed = (
    "不要直接写完整 PRD。因为需要输出验收标准，所以确认后冻结后再进入下一步。"
    "根问题 目标 范围 阶段边界 Phase 下一步 确认 收敛 冻结 方案 需求 成功标准。"
    "PRD 基线 上游 细化 改写 迁移候选 产品 架构 测试 PASS 确认轮 重审 ASK_USER BLOCKED。"
)
core.grade_run(eval_item, stuffed, run_dir, 1.0, 0)
grading = json.loads((run_dir / "grading.json").read_text())
if grading["summary"]["pass_rate"] >= 1.0:
    raise SystemExit("low-repeat marker-free keyword stuffing must not receive a perfect outcome score")
rubric_rows = grading.get("rubric_evaluations", [])
if not rubric_rows or all(row.get("passed") for row in rubric_rows):
    raise SystemExit("grading must fail at least one rubric row for low-repeat marker-free keyword stuffing")
PY

python3 - <<'PY' "$CORE" "$TMP_RESULT_DIR"
import importlib.util
import json
import sys
from pathlib import Path

core_path = Path(sys.argv[1])
run_dir = Path(sys.argv[2]) / "distributed-keyword-stuffed-rubric-run"
run_dir.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("product_split_benchmark_core", core_path)
core = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = core
spec.loader.exec_module(core)

eval_item = {
    "id": 1002,
    "name": "distributed marker-free keyword stuffing",
    "rubric_type": "outcome_based",
    "outcome_rubric": [
        "明确当前还不是写完整 PRD 的时机",
        "先收敛根问题、目标、范围和阶段边界",
        "给出清晰下一步，不把方案当成已闭合事实",
    ],
    "expectations": [
        {"text": "不直接写完整 PRD", "pattern": "不要直接|先不直接|还不是.*PRD"},
        {"text": "先冻结关键产品基线", "pattern": "根问题|目标|范围|阶段边界|Phase"},
        {"text": "给出下一步推进建议", "pattern": "下一步|先.*确认|先.*收敛|先.*冻结"},
    ],
}
stuffed = (
    "不要直接写完整 PRD，因为需要输出验收标准。"
    "根问题要确认。目标要确认。范围要确认。阶段边界要确认。Phase 要确认。"
    "下一步要收敛。冻结后再推进。方案不能先放行。需求要细化。"
    "基线、上游、改写、迁移候选、产品、架构、测试、PASS、确认轮、重审、ASK_USER、BLOCKED。"
)
core.grade_run(eval_item, stuffed, run_dir, 1.0, 0)
grading = json.loads((run_dir / "grading.json").read_text())
if grading["summary"]["pass_rate"] >= 1.0:
    raise SystemExit("distributed marker-free keyword stuffing must not receive a perfect outcome score")
rubric_rows = grading.get("rubric_evaluations", [])
if not rubric_rows or all(row.get("passed") for row in rubric_rows):
    raise SystemExit("grading must fail at least one rubric row for distributed marker-free keyword stuffing")
PY

FAKE_SMOKE_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/product-benchmark-fake-smoke-codex.XXXXXX")"
cat > "$FAKE_SMOKE_CODEX_BIN/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output_path=""
is_structured_judge=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output_path="$2"
      shift 2
      ;;
    --output-schema)
      is_structured_judge=1
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [ "$is_structured_judge" = "1" ]; then
  printf '{"winner":"Tie","reasoning":"synthetic smoke judge","strengths":{"A":["answers the prompt"],"B":["answers the prompt"]},"weaknesses":{"A":[],"B":[]}}\n'
  exit 0
fi
if [ -n "$output_path" ]; then
  mkdir -p "$(dirname "$output_path")"
  cat > "$output_path" <<'MD'
不要直接开始写完整 PRD。下一步先确认并收敛根问题、目标、范围和阶段边界，把 dashboard 方案还原成待验证假设，再冻结 Phase 基线后进入细化。
MD
fi
exit 0
SH
chmod +x "$FAKE_SMOKE_CODEX_BIN/codex"
PATH="$FAKE_SMOKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --eval-set "$TMP_EVAL_SET" \
  --output-dir "$TMP_RESULT_DIR" \
  --runs-per-config 1 \
  --timeout-sec 30 \
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
python3 - <<'PY' "$RESULT_DIR"
import json
import sys
from pathlib import Path

result_dir = Path(sys.argv[1])
for eval_id in range(6):
    path = result_dir / f"comparison-{eval_id}.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    expected = (
        {"A": "with_split", "B": "old_monolith"}
        if eval_id % 2 == 0
        else {"A": "old_monolith", "B": "with_split"}
    )
    if payload.get("blind_order") != expected:
        raise SystemExit(f"{path.name} blind_order mismatch: {payload.get('blind_order')} != {expected}")
PY

echo "[PASS] product split benchmark contract"
