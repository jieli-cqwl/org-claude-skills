#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPLAY_DOC="$ROOT/docs/delivery-owner-role-20260411/replay-scenarios.md"
BEHAVIOR_TEST="$ROOT/tests/test-skill-output-and-gate-contract.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2"
  if ! grep -qE "$pattern" "$file"; then
    fail "missing pattern [$pattern] in ${file}"
  fi
}

assert_present '^1\. readiness failure$' "$REPLAY_DOC"
assert_present '^2\. execution drift and replan$' "$REPLAY_DOC"
assert_present '^3\. quality escalation after risk increase$' "$REPLAY_DOC"
assert_present '^4\. goal closure mismatch despite green gates$' "$REPLAY_DOC"

assert_present 'delivery-owner missing preflight evidence should fail' "$BEHAVIOR_TEST"
assert_present 'delivery-owner replan without recovery fields should fail' "$BEHAVIOR_TEST"
assert_present 'delivery-owner replan recovery with refreshed plan version should pass' "$BEHAVIOR_TEST"
assert_present 'delivery-owner high-risk drift without escalation should fail' "$BEHAVIOR_TEST"
assert_present 'delivery-owner high-risk drift with escalation should pass' "$BEHAVIOR_TEST"
assert_present 'delivery-owner unmet goal should fail sign-off' "$BEHAVIOR_TEST"
assert_present 'delivery-owner goal closure must cover every upstream goal' "$BEHAVIOR_TEST"

timeout 600 bash "$BEHAVIOR_TEST"

echo "[PASS] delivery-owner replay contract"
