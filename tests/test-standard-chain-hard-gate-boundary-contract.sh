#!/usr/bin/env bash
# shellcheck disable=SC2016
# File role: prove standard-chain HARD-GATE sections contain blocking invariants, not execution scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  test -f "$1" || fail "missing file: ${1#"$ROOT"/}"
}

assert_present() {
  local needle="$1" file="$2"
  grep -Fq "$needle" "$file" || fail "missing content in ${file#"$ROOT"/}: $needle"
}

hard_gate_block() {
  awk '
    /^## HARD-GATE$/ { in_block = 1; next }
    in_block && /^## / { exit }
    in_block { print }
  ' "$1"
}

assert_hard_gate_absent() {
  local needle="$1" file="$2" block
  block="$(hard_gate_block "$file")"
  test -n "$block" || fail "missing HARD-GATE block in ${file#"$ROOT"/}"
  ! grep -Fq "$needle" <<<"$block" || fail "HARD-GATE contains execution detail in ${file#"$ROOT"/}: $needle"
}

for file in "$DIRECTOR_SKILL" "$MANAGER_SKILL" "$DESIGN_SKILL"; do
  assert_file "$file"
  assert_hard_gate_absent 'python3 ' "$file"
  assert_hard_gate_absent 'bash ' "$file"
  assert_hard_gate_absent 'validate_co_creation_ledger.py' "$file"
done

assert_hard_gate_absent 'preflight_check.sh --arguments' "$DESIGN_SKILL"

assert_present '确认检查点未闭合不得冻结' "$DIRECTOR_SKILL"
assert_present '确认检查点未闭合不得 handoff' "$MANAGER_SKILL"
assert_present '确认检查点未闭合不得冻结设计' "$DESIGN_SKILL"

assert_present 'python3 tools/community/validate_co_creation_ledger.py --artifact "docs/{feature}/product-director-ledger.json" --producer product-director --require-finalized' "$DIRECTOR_SKILL"
assert_present 'python3 tools/community/validate_co_creation_ledger.py --artifact "$PHASE_DIR/product-manager-ledger.json" --producer product-manager --require-finalized' "$MANAGER_SKILL"
assert_present 'python3 tools/community/validate_co_creation_ledger.py --artifact "$PHASE_DIR/design-ledger.json" --producer design --require-finalized' "$DESIGN_SKILL"
assert_present 'bash shared/skills/design/scripts/preflight_check.sh --arguments "$ARGUMENTS"' "$DESIGN_SKILL"

printf '[PASS] standard-chain hard-gate boundary contract\n'
