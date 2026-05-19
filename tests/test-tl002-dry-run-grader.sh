#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRADER="$ROOT/tools/eval/scripts/grade_tl002_dry_run.py"
INPUT="$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-002/input.md"
OUTPUT="$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-002/tech-lead/output.md"
EVALUATOR="$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-002/tech-lead/evaluator-output.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

test -f "$GRADER" || fail "missing TL-002 grader: $GRADER"
test -f "$INPUT" || fail "missing TL-002 input fixture: $INPUT"
test -f "$OUTPUT" || fail "missing TL-002 output: $OUTPUT"
test -f "$EVALUATOR" || fail "missing TL-002 evaluator output: $EVALUATOR"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tl002-grader.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

GOOD_JSON="$TMP_DIR/good.json"
python3 "$GRADER" --input "$INPUT" --output "$OUTPUT" --evaluator "$EVALUATOR" >"$GOOD_JSON"
assert_present '"status": "pass"' "$GOOD_JSON"
assert_present '"TL002-RDY-01"' "$GOOD_JSON"
assert_present '"GAP-TD002-01"' "$GOOD_JSON"
assert_present '"GAP-TD002-02"' "$GOOD_JSON"
assert_present '"OA-TASK-CONTRACT"' "$GOOD_JSON"

BAD_OUTPUT="$TMP_DIR/bad-output.md"
cat >"$BAD_OUTPUT" <<'BAD'
TL-002 dry-run uses a synthetic fixture.

We can split work into frontend, backend, and docs tasks, then let delivery start.
BAD

BAD_JSON="$TMP_DIR/bad.json"
if python3 "$GRADER" --input "$INPUT" --output "$BAD_OUTPUT" --evaluator "$EVALUATOR" >"$BAD_JSON" 2>&1; then
  fail "generic TL-002 output should fail deterministic grader"
fi
assert_present '"status": "fail"' "$BAD_JSON"
assert_present 'gap_readiness_gate' "$BAD_JSON"
assert_present 'risk_driven_batches' "$BAD_JSON"
assert_present 'task_contracts' "$BAD_JSON"
assert_present 'downstream_gate' "$BAD_JSON"

printf '[PASS] TL-002 dry-run grader contract\n'
