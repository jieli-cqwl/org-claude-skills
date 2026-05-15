#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRADER="$ROOT/tools/eval/scripts/grade_do002_dry_run.py"
INPUT="$ROOT/docs/feature--agent-delivery-operating-system/dry-runs/do-002/input.md"
OUTPUT="$ROOT/docs/feature--agent-delivery-operating-system/dry-runs/do-002/delivery-owner/output.md"
EVALUATOR="$ROOT/docs/feature--agent-delivery-operating-system/dry-runs/do-002/delivery-owner/evaluator-output.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

test -f "$GRADER" || fail "missing DO-002 grader: $GRADER"
test -f "$INPUT" || fail "missing DO-002 input fixture: $INPUT"
test -f "$OUTPUT" || fail "missing DO-002 output: $OUTPUT"
test -f "$EVALUATOR" || fail "missing DO-002 evaluator output: $EVALUATOR"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/do002-grader.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

GOOD_JSON="$TMP_DIR/good.json"
python3 "$GRADER" --input "$INPUT" --output "$OUTPUT" --evaluator "$EVALUATOR" >"$GOOD_JSON"
assert_present '"status": "pass"' "$GOOD_JSON"
assert_present '"TL002-T1"' "$GOOD_JSON"
assert_present '"BCA-DO002-01"' "$GOOD_JSON"
assert_present '"OA-PACKET_SCRIPT_VALIDATE"' "$GOOD_JSON"

BAD_OUTPUT="$TMP_DIR/bad-output.md"
cat >"$BAD_OUTPUT" <<'BAD'
status: DISPATCH_READY
input_origin=synthetic

All tasks can now be dispatched to developers. The advisory can be handled later.
BAD

BAD_JSON="$TMP_DIR/bad.json"
if python3 "$GRADER" --input "$INPUT" --output "$BAD_OUTPUT" --evaluator "$EVALUATOR" >"$BAD_JSON" 2>&1; then
  fail "generic DO-002 output should fail deterministic grader"
fi
assert_present '"status": "fail"' "$BAD_JSON"
assert_present 'advisory_consumed' "$BAD_JSON"
assert_present 'only_t1_released' "$BAD_JSON"
assert_present 'verifier_gate' "$BAD_JSON"
assert_present 'packet_validate' "$BAD_JSON"

printf '[PASS] DO-002 dry-run grader contract\n'
