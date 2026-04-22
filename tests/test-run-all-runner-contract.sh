#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tests/run-all.sh"

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

help_output="$(bash "$RUNNER" --help)"
assert_contains "--quick" "$help_output" "help output"
assert_contains "--profile" "$help_output" "help output"
assert_contains "--list" "$help_output" "help output"

full_plan="$(bash "$RUNNER" --list)"
assert_contains "mode=full" "$full_plan" "full plan"
assert_contains "steps=" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-core.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-runtime-smoke.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-safety.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-runtime.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-migration.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-standard-chain-readiness-gate.sh" "$full_plan" "full plan"
assert_not_contains "test-install-smoke.sh" "$full_plan" "full plan"
assert_not_contains "test-install-systematic.sh" "$full_plan" "full plan"
assert_not_contains "test-install-runtime-audit.sh" "$full_plan" "full plan"

quick_plan="$(bash "$RUNNER" --quick --list)"
assert_contains "mode=quick" "$quick_plan" "quick plan"
assert_contains "steps=" "$quick_plan" "quick plan"
assert_contains "full_only_excluded=4" "$quick_plan" "quick plan"
assert_contains "excluded: tests/test-install-safety.sh" "$quick_plan" "quick plan"
assert_contains "excluded: tests/test-install-runtime.sh" "$quick_plan" "quick plan"
assert_contains "excluded: tests/test-install-migration.sh" "$quick_plan" "quick plan"
assert_contains "excluded: tests/test-install-retired-skill-cleanup.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tools/validate-contracts.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-install-core.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-install-runtime-smoke.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-runtime-integrity.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-safety.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-runtime.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-migration.sh" "$quick_plan" "quick plan"
assert_not_contains "bash $ROOT/tests/test-install-retired-skill-cleanup.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-smoke.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-systematic.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-runtime-audit.sh" "$quick_plan" "quick plan"

if bash "$RUNNER" --does-not-exist >/tmp/org_run_all_bad_option.out 2>&1; then
  fail "unknown option should fail"
fi
grep -Fq "unknown option" /tmp/org_run_all_bad_option.out || fail "unknown option message missing"

echo "run-all runner contract ok"
