#!/usr/bin/env bash
# File role: validate skill-harness deterministic gate checker and calibration fixtures.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
CASES="$ROOT/tests/fixtures/skill-harness/cases"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local label="$1"
  local code="$2"
  shift
  shift
  set +e
  "$@" >/tmp/skill_harness_expected_fail.out 2>/tmp/skill_harness_expected_fail.err
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat /tmp/skill_harness_expected_fail.out
    cat /tmp/skill_harness_expected_fail.err >&2
    fail "$label unexpectedly passed"
  fi
  if ! grep -Fq "$code" /tmp/skill_harness_expected_fail.out /tmp/skill_harness_expected_fail.err; then
    cat /tmp/skill_harness_expected_fail.out
    cat /tmp/skill_harness_expected_fail.err >&2
    fail "$label did not report $code"
  fi
}

[ -x "$CHECKER" ] || fail "missing executable checker"
python3 "$CHECKER" "$CASES/good-markdown-audit.json"
python3 "$CHECKER" "$CASES/delivery-owner-practice-risk.json"
expect_fail "no evidence FAIL" "NEED_EVIDENCE" python3 "$CHECKER" "$CASES/no-evidence-fail.json"
expect_fail "missing manifest command" "MISSING_COMMAND" python3 "$CHECKER" "$CASES/missing-command.json"
expect_fail "active alias" "ACTIVE_ALIAS" python3 "$CHECKER" "$CASES/active-alias.json"
expect_fail "markdown fact source" "MARKDOWN_FACT_SOURCE" python3 "$CHECKER" "$CASES/markdown-fact-source.json"
expect_fail "tail hard gate" "CONTENT_ORDER" python3 "$CHECKER" "$CASES/darwin-tail-hard-gate.json"
expect_fail "json without consumer" "JSON_WITHOUT_CONSUMER" python3 "$CHECKER" "$CASES/json-without-consumer.json"
grep -Fq '"check-contract"' "$ROOT/shared/skills/skill-harness/scripts/manifest.json" || fail "manifest must expose check-contract"

printf '[PASS] skill-harness gates\n'
