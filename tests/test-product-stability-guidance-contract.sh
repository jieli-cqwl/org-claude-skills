#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

SKILL="$ROOT/shared/skills/product-director/SKILL.md"
BRIEF_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/brief-template.md"
PHASE_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/phase-prd-template.md"
CONVERSATION_GUIDE="$ROOT/shared/skills/product-director/references/conversation-guide.md"
PHASE_GUIDE="$ROOT/shared/skills/product-director/references/phase-splitting-guide.md"
CHECK_SCRIPT="$ROOT/shared/skills/product-director/scripts/completion_check.sh"

test -f "$SKILL" || fail "missing product skill: $SKILL"
test -f "$BRIEF_TEMPLATE" || fail "missing shared product brief template: $BRIEF_TEMPLATE"
test -f "$PHASE_TEMPLATE" || fail "missing shared product phase template: $PHASE_TEMPLATE"
test -f "$CONVERSATION_GUIDE" || fail "missing director conversation guide: $CONVERSATION_GUIDE"
test -f "$PHASE_GUIDE" || fail "missing director phase guide: $PHASE_GUIDE"
test -f "$CHECK_SCRIPT" || fail "missing director completion check: $CHECK_SCRIPT"

assert_present '^name: product-director$' "$SKILL"
assert_present 'D-S1 \| 静默信息收集' "$SKILL"
assert_present 'D-G1 \| 总监确认门' "$SKILL"
assert_present 'brief.lock.json' "$SKILL"
assert_present 'phase-\{N\}/prd.lock.json' "$SKILL"
assert_present '/product-manager' "$SKILL"

assert_present '^## 产品总监确认$' "$BRIEF_TEMPLATE"
assert_present 'brief.lock.json' "$BRIEF_TEMPLATE"
assert_present 'Director 定义约束事实，PM 只补执行映射字段' "$BRIEF_TEMPLATE"
assert_present '^## 引用锚点合同$' "$PHASE_TEMPLATE"
assert_present 'prd.lock.json' "$PHASE_TEMPLATE"

assert_present '深度路由' "$CONVERSATION_GUIDE"
assert_present '默认单 Phase' "$PHASE_GUIDE"
assert_present 'validate_director_confirmation' "$CHECK_SCRIPT"
assert_present 'validate_brief_lock_snapshot' "$CHECK_SCRIPT"
assert_present 'validate_phase_prd_lock_snapshots' "$CHECK_SCRIPT"

echo "[PASS] product stability guidance contract"
