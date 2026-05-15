#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRADER="$ROOT/tools/eval/scripts/grade_td002_dry_run.py"
INPUT="$ROOT/docs/feature--agent-delivery-operating-system/dry-runs/td-002/input.md"
OUTPUT="$ROOT/docs/feature--agent-delivery-operating-system/dry-runs/td-002/test-design/output.md"
EVALUATOR="$ROOT/docs/feature--agent-delivery-operating-system/dry-runs/td-002/test-design/evaluator-output.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

test -f "$GRADER" || fail "missing TD-002 grader: $GRADER"
test -f "$INPUT" || fail "missing TD-002 input fixture: $INPUT"
test -f "$OUTPUT" || fail "missing TD-002 output: $OUTPUT"
test -f "$EVALUATOR" || fail "missing TD-002 evaluator output: $EVALUATOR"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/td002-grader.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

GOOD_JSON="$TMP_DIR/good.json"
python3 "$GRADER" --input "$INPUT" --output "$OUTPUT" --evaluator "$EVALUATOR" >"$GOOD_JSON"
assert_present '"status": "pass"' "$GOOD_JSON"
assert_present '"TDO-01"' "$GOOD_JSON"
assert_present '"GAP-TD002-01"' "$GOOD_JSON"
assert_present '"GAP-TD002-02"' "$GOOD_JSON"

BAD_OUTPUT="$TMP_DIR/bad-output.md"
cat >"$BAD_OUTPUT" <<'BAD'
TD-002 dry-run uses a synthetic fixture.

It lists some tests and says QA should check things.
BAD

BAD_JSON="$TMP_DIR/bad.json"
if python3 "$GRADER" --input "$INPUT" --output "$BAD_OUTPUT" --evaluator "$EVALUATOR" >"$BAD_JSON" 2>&1; then
  fail "generic TD-002 output should fail deterministic grader"
fi
assert_present '"status": "fail"' "$BAD_JSON"
assert_present 'traceability_matrix' "$BAD_JSON"
assert_present 'typed_gaps' "$BAD_JSON"
assert_present 'qa_handoff' "$BAD_JSON"

printf '[PASS] TD-002 dry-run grader contract\n'
