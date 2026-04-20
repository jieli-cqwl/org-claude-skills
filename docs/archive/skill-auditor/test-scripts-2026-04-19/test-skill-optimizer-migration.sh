#!/usr/bin/env bash
# 文件职责：验证 new-skills 退役、安装完整性和 context budget 收敛。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
BUDGET_TEST="$ROOT/tests/test-skill-context-budget.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in $file: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in $file: $needle"
  fi
}

if [ -e "$ROOT/shared/skills/new-skills" ]; then
  fail "shared/skills/new-skills must be retired"
fi

assert_present 'skills/skill-optimizer/SKILL.md' "$INSTALL"
assert_absent 'skills/new-skills/SKILL.md' "$INSTALL"
assert_absent 'skills/new-skills/agents/openai.yaml' "$INSTALL"
assert_present 'skills/skill-optimizer/agents/openai.yaml' "$INSTALL"

assert_present 'skill-optimizer' "$BUDGET_TEST"
assert_absent 'new-skills' "$BUDGET_TEST"
assert_absent 'SKIP (directory not found)' "$BUDGET_TEST"

printf '[PASS] skill-optimizer migration\n'
