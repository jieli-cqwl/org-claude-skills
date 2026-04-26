#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/tools/community/validate_context_contract.py"
FIX="$ROOT/tests/fixtures/context-contract/validator"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_invalid() {
  local name="$1"
  local reason="$2"
  if python3 "$VALIDATOR" --root "$FIX/$name" >/tmp/context_invalid.out 2>&1; then
    cat /tmp/context_invalid.out >&2
    fail "$name should fail"
  fi
  grep -Fq '"decision": "block"' /tmp/context_invalid.out || fail "$name missing block decision"
  grep -Fq "\"reason\": \"$reason\"" /tmp/context_invalid.out || {
    cat /tmp/context_invalid.out >&2
    fail "$name missing reason $reason"
  }
}

python3 "$VALIDATOR" --root "$FIX/valid-small-chain" >/tmp/context_valid.out
grep -Fq '"decision": "pass"' /tmp/context_valid.out || {
  cat /tmp/context_valid.out >&2
  fail "valid fixture should pass"
}

assert_invalid invalid-missing-worklog worklog_missing
assert_invalid invalid-duplicate-active duplicate_active_feature
assert_invalid invalid-small-chain-task-plan-drift small_chain_task_plan_drift
assert_invalid invalid-standard-chain-control-ref canonical_ref_invalid
assert_invalid invalid-blocked-record blocked_record_field_missing
assert_invalid invalid-ownership-contract ownership_artifact_field_missing

printf '[PASS] context contract validator\n'
