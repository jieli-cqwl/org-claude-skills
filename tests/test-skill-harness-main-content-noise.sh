#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
CASES="$ROOT/tests/fixtures/skill-harness/cases"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-harness-main-content-noise.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

expect_fail() {
  label="$1"
  expected="$2"
  shift
  shift
  stdout_file="$(mktemp "$TMP_DIR/stdout.XXXXXX")"
  stderr_file="$(mktemp "$TMP_DIR/stderr.XXXXXX")"
  set +e
  "$@" >"$stdout_file" 2>"$stderr_file"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    fail "$label expected failure did not happen"
  fi
  if ! grep -Fq "$expected" "$stdout_file" "$stderr_file"; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label did not report $expected"
  fi
}

python3 "$CHECKER" "$CASES/delivery-owner-practice-risk.json"
expect_fail "illegal dimension" "dimension must be one of" python3 "$CHECKER" "$CASES/illegal-dimension.json"
expect_fail "legacy label active output" "legacy_baseline_label is allowed only for" python3 "$CHECKER" "$CASES/legacy-label-active-output.json"
printf '[PASS] skill-harness main content noise\n'
