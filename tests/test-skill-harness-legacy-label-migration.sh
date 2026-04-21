#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
CASES="$ROOT/tests/fixtures/skill-harness/cases"
fail() { echo "[FAIL] $*" >&2; exit 1; }
expect_fail() {
  label="$1"; shift
  if "$@" >/tmp/skill-harness-negative.out 2>&1; then
    fail "$label expected failure did not happen"
  fi
}

python3 "$CHECKER" "$CASES/delivery-owner-practice-risk.json"
expect_fail "legacy label active output" python3 "$CHECKER" "$CASES/legacy-label-active-output.json"
expect_fail "illegal dimension" python3 "$CHECKER" "$CASES/illegal-dimension.json"
expect_fail "illegal verdict" python3 "$CHECKER" "$CASES/illegal-verdict.json"
expect_fail "missing audit_proof_type" python3 "$CHECKER" "$CASES/missing-audit-proof-type.json"
expect_fail "standalone proof_type" python3 "$CHECKER" "$CASES/standalone-proof-type.json"
printf '[PASS] skill-harness legacy label migration\n'
