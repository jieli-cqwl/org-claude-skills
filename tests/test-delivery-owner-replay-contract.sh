#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPLAY_DOC="$ROOT/docs/archive/delivery-owner-role-20260411/replay-scenarios.md"
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
assert_present '^3\. fixed full gate regression after risk increase$' "$REPLAY_DOC"
assert_present '^4\. goal closure mismatch despite green gates$' "$REPLAY_DOC"

assert_present 'assert_standard_chain_control_contract' "$BEHAVIOR_TEST"
assert_present 'assert_canonical_runtime_artifacts' "$BEHAVIOR_TEST"
assert_present 'assert_canonical_only_scripts' "$BEHAVIOR_TEST"
assert_present 'assert_canonical_hooks_pass' "$BEHAVIOR_TEST"
assert_present 'qa canonical gate should block ambiguous Stop candidates' "$BEHAVIOR_TEST"

timeout 600 bash "$BEHAVIOR_TEST"

echo "[PASS] delivery-owner replay contract"
