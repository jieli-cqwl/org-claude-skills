#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_FEATURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
CHECK="$ROOT/shared/skills/test-design/scripts/preflight_check.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

prepare_workspace() {
  local name="$1"
  local workspace="$TMP_DIR/$name"
  mkdir -p "$workspace/docs"
  cp -R "$BASE_FEATURE" "$workspace/docs/sample-feature"
  printf '%s\n' "$workspace"
}

prepare_non_docs_workspace() {
  local workspace="$TMP_DIR/non-docs-workspace"
  mkdir -p "$workspace/not-docs"
  cp -R "$BASE_FEATURE" "$workspace/not-docs/sample-feature"
  printf '%s\n' "$workspace"
}

assert_pass() {
  local workspace="$1"
  local out="$workspace/preflight.out"
  bash "$CHECK" --phase-dir "$workspace/docs/sample-feature/phase-1" --unit UNIT-1 >"$out" 2>&1 || {
    cat "$out" >&2
    fail "preflight should pass with canonical inputs"
  }
  jq -e '.status == "PASS"' "$out" >/dev/null || {
    cat "$out" >&2
    fail "preflight should emit PASS JSON"
  }
}

assert_pass_with_unit() {
  local workspace="$1"
  local unit="$2"
  local out="$workspace/preflight-$unit.out"
  bash "$CHECK" --phase-dir "$workspace/docs/sample-feature/phase-1" --unit "$unit" >"$out" 2>&1 || {
    cat "$out" >&2
    fail "preflight should pass with unit selector: $unit"
  }
  jq -e '.status == "PASS"' "$out" >/dev/null || {
    cat "$out" >&2
    fail "preflight should emit PASS JSON for unit selector: $unit"
  }
}

assert_fail() {
  local name="$1"
  local relative="$2"
  local expected="$3"
  local workspace out
  workspace="$(prepare_workspace "$name")"
  rm -f "$workspace/docs/sample-feature/$relative"
  out="$workspace/preflight.out"
  if bash "$CHECK" --phase-dir "$workspace/docs/sample-feature/phase-1" --unit UNIT-1 >"$out" 2>&1; then
    cat "$out" >&2
    fail "preflight should fail when $relative is missing"
  fi
  jq -e '.status == "FAIL"' "$out" >/dev/null || {
    cat "$out" >&2
    fail "preflight should emit FAIL JSON"
  }
  grep -Eq "$expected" "$out" || {
    cat "$out" >&2
    fail "preflight failure should mention $expected"
  }
}

assert_invalid_unit() {
  local unit="$1"
  local workspace out
  workspace="$(prepare_workspace "invalid-unit")"
  out="$workspace/preflight.out"
  if bash "$CHECK" --phase-dir "$workspace/docs/sample-feature/phase-1" --unit "$unit" >"$out" 2>&1; then
    cat "$out" >&2
    fail "preflight should reject invalid unit selector: $unit"
  fi
  jq -e '.status == "FAIL"' "$out" >/dev/null || {
    cat "$out" >&2
    fail "invalid unit selector should emit FAIL JSON"
  }
  grep -Eq 'invalid --unit' "$out" || {
    cat "$out" >&2
    fail "invalid unit failure should mention invalid --unit"
  }
}

assert_invalid_phase_dir() {
  local workspace out
  workspace="$(prepare_non_docs_workspace)"
  out="$workspace/preflight.out"
  if bash "$CHECK" --phase-dir "$workspace/not-docs/sample-feature/phase-1" --unit UNIT-1 >"$out" 2>&1; then
    cat "$out" >&2
    fail "preflight should reject phase-dir outside docs root"
  fi
  jq -e '.status == "FAIL"' "$out" >/dev/null || {
    cat "$out" >&2
    fail "invalid phase-dir should emit FAIL JSON"
  }
  grep -Eq 'invalid --phase-dir root' "$out" || {
    cat "$out" >&2
    fail "invalid phase-dir failure should mention docs root"
  }
}

assert_pass "$(prepare_workspace valid)"
assert_pass_with_unit "$(prepare_workspace valid-unit-alias)" "unit-1.json"
assert_fail missing-brief "brief.json" "brief.json"
assert_fail missing-prd "phase-1/phase-prd.json" "phase-prd.json"
assert_fail missing-design "phase-1/design.json" "design.json"
assert_fail missing-unit "phase-1/units/UNIT-1.json" "UNIT-1.json"
assert_invalid_unit "../UNIT-1"
assert_invalid_unit "unit-x"
assert_invalid_phase_dir

printf '[PASS] test-design preflight\n'
