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
OUT_FILE="$(mktemp "${TMPDIR:-/tmp}/eval-summary-XXXXXX.out")"
trap 'rm -f "$OUT_FILE"' EXIT

bash "$RUNNER" summary >"$OUT_FILE"

assert_present '^=== 评测结果汇总 ===$' "$OUT_FILE"
assert_present '^--- Track 4: Product Thinking ---$' "$OUT_FILE"
assert_present '^--- Track 5: Problem Discovery ---$' "$OUT_FILE"
assert_present '^--- Track 6: Phase Slicing Quality ---$' "$OUT_FILE"
assert_present '^--- Track 7: Process Lightness ---$' "$OUT_FILE"
assert_present '^  p2-solution-anchoring:$' "$OUT_FILE"

echo "[PASS] eval summary compatibility"
