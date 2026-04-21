#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
CASES="$ROOT/tests/fixtures/skill-harness/cases"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

expect_fail() {
  label="$1"; shift
  if "$@" >/tmp/skill-harness-main-content-noise.out 2>&1; then
    fail "$label expected failure did not happen"
  fi
}

python3 "$CHECKER" "$CASES/delivery-owner-practice-risk.json"
expect_fail "illegal dimension" python3 "$CHECKER" "$CASES/illegal-dimension.json"
expect_fail "legacy label active output" python3 "$CHECKER" "$CASES/legacy-label-active-output.json"
printf '[PASS] skill-harness main content noise\n'
