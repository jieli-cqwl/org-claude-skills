#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tests/run-focused.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local label="$3"

  if ! grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$label missing: $needle"
  fi
}

assert_not_contains() {
  local needle="$1"
  local haystack="$2"
  local label="$3"

  if grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$label should not include: $needle"
  fi
}

bash -n "$RUNNER"

help_output="$(bash "$RUNNER" --help)"
assert_contains "design" "$help_output" "help output"
assert_contains "--list" "$help_output" "help output"

design_plan="$(bash "$RUNNER" design --list)"
assert_contains "profile=design" "$design_plan" "design plan"
assert_contains "steps=" "$design_plan" "design plan"
assert_contains "bash $ROOT/tests/test-design-skill-governance-redesign.sh" "$design_plan" "design plan"
assert_contains "bash $ROOT/tests/test-design-architect-capability-contract.sh" "$design_plan" "design plan"
assert_contains "python3 $ROOT/tests/test-design-architect-contract.py" "$design_plan" "design plan"
assert_contains "bash $ROOT/tests/test-design-dogfood-e2e.sh" "$design_plan" "design plan"
assert_contains "bash $ROOT/tests/test-stage2-design-package.sh" "$design_plan" "design plan"
assert_contains "bash $ROOT/tests/test-standard-chain-login-homepage-pilot.sh" "$design_plan" "design plan"
assert_contains "bash $ROOT/tests/test-standard-chain-feedback-thanks-pilot.sh" "$design_plan" "design plan"
assert_contains "bash $ROOT/tests/test-skill-output-and-gate-contract.sh" "$design_plan" "design plan"
assert_not_contains "tests/test-install-runtime.sh" "$design_plan" "design plan"
assert_not_contains "tests/test-product-manager-dogfood-e2e.sh" "$design_plan" "design plan"
assert_not_contains "tests/test-release-metadata.sh" "$design_plan" "design plan"

if bash "$RUNNER" unknown --list >/tmp/org_run_focused_unknown.out 2>&1; then
  fail "unknown profile should fail"
fi
unknown_output="$(</tmp/org_run_focused_unknown.out)"
assert_contains "unknown profile" "$unknown_output" "unknown profile output"
assert_contains "design" "$unknown_output" "unknown profile output"

echo "run-focused runner contract ok"
