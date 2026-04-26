#!/usr/bin/env bash
# File role: prove skill-harness consumes the Skill quality standard without becoming a second source of truth.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-harness/SKILL.md"
AUDIT="$ROOT/shared/skills/skill-harness/references/audit-method.md"
STANDARD="$ROOT/shared/reference/Skill质量标准.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#"$ROOT"/}: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in ${file#"$ROOT"/}: $needle"
  fi
}

test -f "$STANDARD" || fail "missing Skill quality standard"
assert_absent 'skill-harness 消费本标准' "$STANDARD"
assert_absent 'Phase 1' "$STANDARD"
assert_absent 'MVP' "$STANDARD"

for file in "$SKILL" "$AUDIT"; do
  assert_present '{{RUNTIME_HOME}}/reference/Skill质量标准.md' "$file"
  assert_present 'consumes the Skill quality standard' "$file"
  assert_present 'must not define a parallel quality standard' "$file"
  assert_present '质量裁决项' "$file"
  assert_absent 'Phase 1' "$file"
  assert_absent 'MVP' "$file"
  assert_absent 'D9 readiness' "$file"
  assert_absent 'proven-effectiveness' "$file"
done

printf '[PASS] skill-harness authority boundary\n'
