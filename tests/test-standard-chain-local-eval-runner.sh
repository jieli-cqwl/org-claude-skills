#!/usr/bin/env bash
# 文件职责：验证 standard-chain skill-local eval runner 能执行、评分并暴露失败项。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tools/eval/scripts/run_standard_chain_local_eval.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

test -f "$RUNNER" || fail "missing local eval runner: $RUNNER"

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-local-eval.XXXXXX")"
FAKE_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-fake-codex.XXXXXX")"
DRY_RUN_OUT="$(mktemp "${TMPDIR:-/tmp}/standard-chain-local-eval-dry.XXXXXX.out")"
trap 'rm -rf "$OUT_DIR" "$FAKE_CODEX_BIN"; rm -f "$DRY_RUN_OUT"' EXIT

python3 "$RUNNER" --skills product-director --dry-run >"$DRY_RUN_OUT"
assert_present '^product-director: 3 evals$' "$DRY_RUN_OUT"
assert_present 'director-baseline-no-prd' "$DRY_RUN_OUT"

cat > "$FAKE_CODEX_BIN/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

output_path=""
is_judge=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output_path="$2"
      shift 2
      ;;
    --output-schema)
      is_judge=1
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$is_judge" = "1" ]; then
  cat <<'JSON'
{
  "expectations": [
    {
      "text": "复述目标、边界和预期产物",
      "passed": true,
      "evidence": "synthetic response mentioned the target"
    },
    {
      "text": "说明 D-S1 只收集线索且不裁决根问题",
      "passed": false,
      "evidence": "synthetic response omitted D-S1 boundary"
    }
  ],
  "notes": ["D-S1 边界表达缺失"],
  "optimization_findings": [
    {
      "issue": "D-S1 boundary is too easy to omit",
      "suggested_change": "Strengthen the eval expectation and skill wording around D-S1 non-decision."
    }
  ]
}
JSON
  exit 0
fi

test -n "$output_path"
mkdir -p "$(dirname "$output_path")"
printf '我会先复述目标和边界，然后进入 D-S2 提问。\n' > "$output_path"
SH
chmod +x "$FAKE_CODEX_BIN/codex"

PATH="$FAKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-director \
  --eval-ids director-baseline-no-prd \
  --runs-per-eval 1 \
  --output-dir "$OUT_DIR" \
  --allow-failures

REL_OUT_DIR="tmp-standard-chain-local-eval-relative"
rm -rf "$REL_OUT_DIR"
PATH="$FAKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-director \
  --eval-ids director-baseline-no-prd \
  --runs-per-eval 1 \
  --output-dir "$REL_OUT_DIR" \
  --allow-failures
test -f "$REL_OUT_DIR/product-director/director-baseline-no-prd/run-1/outputs/response.md" || fail "relative output dir did not create response output"
rm -rf "$REL_OUT_DIR"

RUN_DIR="$OUT_DIR/product-director/director-baseline-no-prd/run-1"
test -f "$RUN_DIR/outputs/response.md" || fail "missing response output"
test -f "$RUN_DIR/grading.json" || fail "missing grading output"
test -f "$OUT_DIR/summary.json" || fail "missing summary json"
test -f "$OUT_DIR/summary.md" || fail "missing summary markdown"

python3 - <<'PY' "$RUN_DIR/grading.json" "$OUT_DIR/summary.json"
import json
import sys
from pathlib import Path

grading = json.loads(Path(sys.argv[1]).read_text())
summary = json.loads(Path(sys.argv[2]).read_text())

expectations = grading["expectations"]
assert expectations, "missing expectations"
for expectation in expectations:
    assert set(["text", "passed", "evidence"]).issubset(expectation), expectation
assert grading["summary"]["failed"] == 1, grading["summary"]
assert summary["summary"]["failed_expectations"] == 1, summary["summary"]
assert summary["runs"][0]["failed_expectations"] == ["说明 D-S1 只收集线索且不裁决根问题"], summary["runs"][0]
assert summary["optimization_findings"][0]["issue"] == "D-S1 boundary is too easy to omit"
PY

assert_present 'D-S1 boundary is too easy to omit' "$OUT_DIR/summary.md"
printf '[PASS] standard-chain local eval runner contract\n'
