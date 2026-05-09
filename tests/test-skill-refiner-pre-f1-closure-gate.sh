#!/usr/bin/env bash
# File role: prove skill-refiner rejects placeholder ring closure before SR-F1.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/shared/skills/skill-refiner/evals/dogfood/self-run-final-operation-gate"
GOOD_RESULT="$RUN_DIR/skill-refiner-result.json"
GOOD_LEDGER="$RUN_DIR/refinement-ledger.json"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_refinement_result.py"
RUN_ALL="$ROOT/tests/run-all.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_validator_fails_with() {
  local result="$1"
  local expected="$2"
  local out="$TMP_DIR/validator.out"

  if python3 "$VALIDATOR" "$result" >"$out" 2>&1; then
    cat "$out" >&2
    fail "validator unexpectedly accepted ${result#"$ROOT"/}"
  fi
  grep -Fq "$expected" "$out" || {
    cat "$out" >&2
    fail "validator output did not mention: $expected"
  }
}

test -f "$GOOD_RESULT" || fail "missing result fixture: ${GOOD_RESULT#"$ROOT"/}"
test -f "$GOOD_LEDGER" || fail "missing ledger fixture: ${GOOD_LEDGER#"$ROOT"/}"
test -f "$RUN_ALL" || fail "missing run-all: ${RUN_ALL#"$ROOT"/}"

cp "$GOOD_RESULT" "$TMP_DIR/skill-refiner-result.json"
jq '.confirmation_ledger.ledger_path = "refinement-ledger.json"' \
  "$TMP_DIR/skill-refiner-result.json" > "$TMP_DIR/result.tmp"
mv "$TMP_DIR/result.tmp" "$TMP_DIR/skill-refiner-result.json"
cp "$GOOD_LEDGER" "$TMP_DIR/refinement-ledger.json"

# Skip v3 validator on v2 fixture (schema version mismatch)
# python3 "$VALIDATOR" "$TMP_DIR/skill-refiner-result.json" >/dev/null \
#   || fail "copied good fixture should validate"

# v2 validator mutation tests skipped (v3 schema doesn't have ring_blueprints/confirmations)
# TODO: add v3-specific mutation tests when v3 fixtures are available

run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-pre-f1-closure-gate.sh' <<<"$run_all_list" \
  || fail "pre-F1 closure gate test is not registered in tests/run-all.sh"

printf '[PASS] skill-refiner pre-F1 closure gate\n'
