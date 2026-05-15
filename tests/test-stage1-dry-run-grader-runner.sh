#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tools/eval/scripts/run_stage1_dry_run_graders.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

test -f "$RUNNER" || fail "missing Stage 1 dry-run grader runner: $RUNNER"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stage1-dry-run-graders.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

LIST_OUT="$TMP_DIR/list.txt"
python3 "$RUNNER" --list-cases >"$LIST_OUT"
assert_present '^td-002$' "$LIST_OUT"
assert_present '^tl-002$' "$LIST_OUT"
assert_present '^do-002$' "$LIST_OUT"

ALL_JSON="$TMP_DIR/all.json"
python3 "$RUNNER" >"$ALL_JSON"
assert_present '"status": "pass"' "$ALL_JSON"
assert_present '"case": "TD-002"' "$ALL_JSON"
assert_present '"case": "TL-002"' "$ALL_JSON"
assert_present '"case": "DO-002"' "$ALL_JSON"

ONE_JSON="$TMP_DIR/one.json"
python3 "$RUNNER" --case td-002 >"$ONE_JSON"
assert_present '"status": "pass"' "$ONE_JSON"
assert_present '"case": "TD-002"' "$ONE_JSON"
if grep -Eq '"case": "TL-002"|"case": "DO-002"' "$ONE_JSON"; then
  fail "--case td-002 should not run TL-002 or DO-002"
fi

BAD_JSON="$TMP_DIR/bad.json"
if python3 "$RUNNER" --case nope >"$BAD_JSON" 2>&1; then
  fail "unknown case should fail"
fi
assert_present 'unknown case: nope' "$BAD_JSON"

printf '[PASS] Stage 1 dry-run grader runner\n'
