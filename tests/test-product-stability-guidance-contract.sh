#!/usr/bin/env bash
# shellcheck disable=SC2016
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

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

SKILL="$ROOT/shared/skills/product-director/SKILL.md"
THINKING_CONTRACT="$ROOT/shared/skills/product-director/references/product-thinking-contract.md"
BRIEF_TEMPLATE="$ROOT/shared/skills/product-director/references/templates/brief-template.md"
PHASE_TEMPLATE="$ROOT/shared/skills/product-director/references/templates/phase-prd-template.md"
CONVERSATION_GUIDE="$ROOT/shared/skills/product-director/references/conversation-guide.md"
PHASE_GUIDE="$ROOT/shared/skills/product-director/references/phase-splitting-guide.md"
CHECK_SCRIPT="$ROOT/shared/skills/product-director/scripts/completion_check.sh"
PRODUCT_ARTIFACT_CONTRACT="$ROOT/contracts/product-artifacts.yaml"

test -f "$SKILL" || fail "missing director skill: $SKILL"
test -f "$THINKING_CONTRACT" || fail "missing director thinking contract: $THINKING_CONTRACT"
test -f "$BRIEF_TEMPLATE" || fail "missing director brief template: $BRIEF_TEMPLATE"
test -f "$PHASE_TEMPLATE" || fail "missing director phase template: $PHASE_TEMPLATE"
test -f "$CONVERSATION_GUIDE" || fail "missing director conversation guide: $CONVERSATION_GUIDE"
test -f "$PHASE_GUIDE" || fail "missing director phase guide: $PHASE_GUIDE"
test -f "$CHECK_SCRIPT" || fail "missing director completion check: $CHECK_SCRIPT"
test -f "$PRODUCT_ARTIFACT_CONTRACT" || fail "missing product artifact contract: $PRODUCT_ARTIFACT_CONTRACT"

assert_present '^name: product-director$' "$SKILL"
assert_present 'D-S1 \| 静默信息收集' "$SKILL"
assert_present 'D-G1 \| 总监确认门' "$SKILL"
assert_present 'brief\.lock\.json' "$SKILL"
assert_present 'phase-\{N\}/prd\.lock\.json' "$SKILL"
assert_present '/product-manager' "$SKILL"
assert_present 'references/product-thinking-contract\.md' "$SKILL"
assert_present 'Product-Thinking Contract v1' "$SKILL"
assert_absent 'product-shared' "$SKILL"
assert_absent '旧 `/product`|旧 /product|已验证实践' "$SKILL"

assert_present '价值假设验证' "$THINKING_CONTRACT"
assert_present 'MVP 范围界定' "$THINKING_CONTRACT"
assert_present '警示信号' "$THINKING_CONTRACT"

assert_present '^## 产品总监确认$' "$BRIEF_TEMPLATE"
assert_present 'brief_lock:' "$PRODUCT_ARTIFACT_CONTRACT"
assert_present '产品总监确认' "$PRODUCT_ARTIFACT_CONTRACT"
assert_present '前置约束' "$PRODUCT_ARTIFACT_CONTRACT"
assert_absent '^## 共创摘要$' "$BRIEF_TEMPLATE"
assert_absent '^## 审查结论$' "$BRIEF_TEMPLATE"
assert_absent '^## 交接项$' "$BRIEF_TEMPLATE"

assert_present '^## 入口与出口条件$' "$PHASE_TEMPLATE"
assert_present 'prd_lock:' "$PRODUCT_ARTIFACT_CONTRACT"
assert_present '深度路由' "$CONVERSATION_GUIDE"
assert_present '不要维护阶段流水账或固定阶段表' "$CONVERSATION_GUIDE"
assert_present '默认单 Phase' "$PHASE_GUIDE"
assert_present 'validate_director_confirmation' "$CHECK_SCRIPT"
assert_present 'validate_brief_lock_snapshot' "$CHECK_SCRIPT"
assert_present 'validate_phase_prd_lock_snapshots' "$CHECK_SCRIPT"

echo "[PASS] product stability guidance contract"
