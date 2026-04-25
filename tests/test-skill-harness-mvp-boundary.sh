#!/usr/bin/env bash
# File role: prove skill-harness consumes the Phase 1 MVP standard without becoming a second source of truth.
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
assert_present 'skill-harness 消费本标准，不定义本标准' "$STANDARD"

for file in "$SKILL" "$AUDIT"; do
  assert_present '{{RUNTIME_HOME}}/reference/Skill质量标准.md' "$file"
  assert_present 'consumes the Phase 1 MVP standard' "$file"
  assert_present 'must not define the standard' "$file"
  assert_present 'must not self-certify' "$file"
  assert_present 'must not make final lifecycle decisions' "$file"
  assert_present 'MVP quality concern' "$file"
  assert_present 'D9 readiness evidence must not produce retain, retire, or proven-effectiveness conclusions' "$file"
  assert_absent 'evidence-backed retain/optimize/retire routing' "$file"
done

printf '[PASS] skill-harness MVP boundary\n'
