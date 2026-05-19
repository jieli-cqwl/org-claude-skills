#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stage1-003-graders.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

run_good() {
  local key="$1"
  local grader="$2"
  local input="$3"
  local output="$4"
  local evaluator="$5"
  local json="$TMP_DIR/$key-good.json"

  test -f "$grader" || fail "missing grader: $grader"
  python3 "$grader" --input "$input" --output "$output" --evaluator "$evaluator" >"$json"
  assert_present '"status": "pass"' "$json"
}

run_bad() {
  local key="$1"
  local grader="$2"
  local input="$3"
  local evaluator="$4"
  local expected_failed_check="$5"
  local bad_output="$TMP_DIR/$key-bad-output.md"
  local bad_json="$TMP_DIR/$key-bad.json"

  printf '%s\n' "Generic dry-run says everything is fine." >"$bad_output"
  if python3 "$grader" --input "$input" --output "$bad_output" --evaluator "$evaluator" >"$bad_json" 2>&1; then
    fail "$key generic output should fail deterministic grader"
  fi
  assert_present '"status": "fail"' "$bad_json"
  assert_present "$expected_failed_check" "$bad_json"
}

run_good \
  pd003 \
  "$ROOT/tools/eval/scripts/grade_pd003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/product-director/output.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/product-director/evaluator-output.md"
run_bad \
  pd003 \
  "$ROOT/tools/eval/scripts/grade_pd003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/product-director/evaluator-output.md" \
  'observable_success_criteria'

run_good \
  pm003 \
  "$ROOT/tools/eval/scripts/grade_pm003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/product-manager/output.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/product-manager/evaluator-output.md"
run_bad \
  pm003 \
  "$ROOT/tools/eval/scripts/grade_pm003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/product-manager/evaluator-output.md" \
  'terminology_conflict'

run_good \
  des003 \
  "$ROOT/tools/eval/scripts/grade_des003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/design/output.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/design/evaluator-output.md"
run_bad \
  des003 \
  "$ROOT/tools/eval/scripts/grade_des003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/design/evaluator-output.md" \
  'interface_contract'

run_good \
  td003 \
  "$ROOT/tools/eval/scripts/grade_td003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/test-design/output.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/test-design/evaluator-output.md"
run_bad \
  td003 \
  "$ROOT/tools/eval/scripts/grade_td003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/test-design/evaluator-output.md" \
  'typed_blocking_gap'

run_good \
  tl003 \
  "$ROOT/tools/eval/scripts/grade_tl003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/tech-lead/output.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/tech-lead/evaluator-output.md"
run_bad \
  tl003 \
  "$ROOT/tools/eval/scripts/grade_tl003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/tech-lead/evaluator-output.md" \
  'real_evidence_gate'

run_good \
  do003 \
  "$ROOT/tools/eval/scripts/grade_do003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/delivery-owner/output.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/delivery-owner/evaluator-output.md"
run_bad \
  do003 \
  "$ROOT/tools/eval/scripts/grade_do003_dry_run.py" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/input.md" \
  "$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/delivery-owner/evaluator-output.md" \
  'authorization_gate'

LIST_OUT="$TMP_DIR/list.txt"
python3 "$ROOT/tools/eval/scripts/run_stage1_dry_run_graders.py" --list-cases >"$LIST_OUT"
assert_present '^pd-003$' "$LIST_OUT"
assert_present '^pm-003$' "$LIST_OUT"
assert_present '^des-003$' "$LIST_OUT"
assert_present '^td-003$' "$LIST_OUT"
assert_present '^tl-003$' "$LIST_OUT"
assert_present '^do-003$' "$LIST_OUT"

ALL_JSON="$TMP_DIR/all.json"
python3 "$ROOT/tools/eval/scripts/run_stage1_dry_run_graders.py" >"$ALL_JSON"
assert_present '"case": "PD-003"' "$ALL_JSON"
assert_present '"case": "PM-003"' "$ALL_JSON"
assert_present '"case": "DES-003"' "$ALL_JSON"
assert_present '"case": "TD-003"' "$ALL_JSON"
assert_present '"case": "TL-003"' "$ALL_JSON"
assert_present '"case": "DO-003"' "$ALL_JSON"
assert_present '"status": "pass"' "$ALL_JSON"

printf '[PASS] Stage 1 003 dry-run graders\n'
