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

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_registry_codex_supported() {
  local registry_file="$1"
  local skill_name="$2"
  local expected="$3"
  local actual

  actual=$(jq -r --arg skill "$skill_name" '.skill_completion_gates[] | select(.skill == $skill) | .codex.supported' "$registry_file")
  [ "$actual" = "$expected" ] || fail "unexpected codex.supported for $skill_name: expected $expected, got ${actual:-<empty>}"
}

SHARED_BRIEF_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/brief-template.md"
SHARED_PHASE_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/phase-prd-template.md"
PRODUCT_DIRECTOR_ROOT="$ROOT/shared/skills/product-director"
PRODUCT_MANAGER_ROOT="$ROOT/shared/skills/product-manager"
CHAIN_CONTRACT="$ROOT/contracts/skill-chain.yaml"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
PRODUCT_COMPAT_SKILL="$ROOT/shared/skills/product/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
TEST_DESIGN_SKILL="$ROOT/shared/skills/test-design/SKILL.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
DELIVERY_OWNER_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
FIX_SKILL="$ROOT/shared/skills/fix/SKILL.md"
DESIGN_DECISION_TEMPLATES="$ROOT/shared/skills/design/references/decision-templates.md"
PRODUCT_MANAGER_CHECK="$ROOT/shared/skills/product-manager/scripts/completion_check.sh"

test -f "$SHARED_BRIEF_TEMPLATE" || fail "missing shared brief template: $SHARED_BRIEF_TEMPLATE"
test -f "$SHARED_PHASE_TEMPLATE" || fail "missing shared phase template: $SHARED_PHASE_TEMPLATE"
test -d "$PRODUCT_DIRECTOR_ROOT" || fail "missing product-director root: $PRODUCT_DIRECTOR_ROOT"
test -d "$PRODUCT_MANAGER_ROOT" || fail "missing product-manager root: $PRODUCT_MANAGER_ROOT"

assert_present '^## 产品总监确认$' "$SHARED_BRIEF_TEMPLATE"
assert_present '^## 共创摘要$' "$SHARED_BRIEF_TEMPLATE"
assert_present '^\| 阶段 \| 技能 \| 关键提问 \| 用户回应 \| 对产品的影响 \|$' "$SHARED_BRIEF_TEMPLATE"
assert_present '^## 引用锚点合同$' "$SHARED_BRIEF_TEMPLATE"
assert_present 'Director 定义约束事实，PM 只补执行映射字段' "$SHARED_BRIEF_TEMPLATE"
assert_present '`影响 UNIT` 由 Director 标注初始受影响范围' "$SHARED_BRIEF_TEMPLATE"
assert_present '不得改 Phase 级结构字段（标题、入口条件、出口条件、交付价值）' "$SHARED_BRIEF_TEMPLATE"
assert_absent 'SCOPE-P\{phase\}U\{unit\}-\{seq\}' "$SHARED_BRIEF_TEMPLATE"
assert_present 'brief\.md#前置约束-con-001' "$SHARED_BRIEF_TEMPLATE"
assert_absent '\| CON-001 \| \[env/runtime/shared-service/compliance/rollout/preflight\] \| \[不可违反的前置约束\] \| \[负责确认该前提的人/角色\] \| \[由 PM handoff 后补齐\] \| \[由 PM handoff 后补齐\] \| \[由 PM handoff 后补齐\] \| \[由 PM handoff 后补齐\] \| \[KNOWN / BLOCKED / VERIFIED\] \|' "$SHARED_BRIEF_TEMPLATE"
assert_absent '^\| UNIT-1 \| phase-1/units/UNIT-1\.md \| phase-1/unit-1/ \| NOT_STARTED \|$' "$SHARED_BRIEF_TEMPLATE"
assert_absent '^\| UNIT-2 \| phase-1/units/UNIT-2\.md \| phase-1/unit-2/ \| NOT_STARTED \|$' "$SHARED_BRIEF_TEMPLATE"
assert_absent '^\| UNIT-3 \| phase-2/units/UNIT-3\.md \| phase-2/unit-3/ \| NOT_STARTED \|$' "$SHARED_BRIEF_TEMPLATE"
assert_absent '^\| UNIT-4 \| phase-2/units/UNIT-4\.md \| phase-2/unit-4/ \| NOT_STARTED \|$' "$SHARED_BRIEF_TEMPLATE"
assert_present '^## 引用锚点合同$' "$SHARED_PHASE_TEMPLATE"
assert_present 'Director 已确认的阶段骨架字段' "$SHARED_PHASE_TEMPLATE"
assert_absent '^\| UNIT-1 \|' "$SHARED_PHASE_TEMPLATE"
assert_absent '^\| UNIT-2 \|' "$SHARED_PHASE_TEMPLATE"
assert_present 'name: product-director' "$CHAIN_CONTRACT"
assert_present 'name: product-manager' "$CHAIN_CONTRACT"
assert_present '"skill"[[:space:]]*:[[:space:]]*"product-director"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"product-manager"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"product"' "$HOOK_REGISTRY"
assert_registry_codex_supported "$HOOK_REGISTRY" "product-director" "true"
assert_registry_codex_supported "$HOOK_REGISTRY" "product-manager" "true"
assert_registry_codex_supported "$HOOK_REGISTRY" "product" "false"
assert_present '/product-director' "$PRODUCT_COMPAT_SKILL"
assert_present '/product-manager' "$PRODUCT_COMPAT_SKILL"
assert_present '兼容入口' "$PRODUCT_COMPAT_SKILL"
assert_absent '^## HARD-GATE$' "$PRODUCT_COMPAT_SKILL"
assert_absent '^## 输出$' "$PRODUCT_COMPAT_SKILL"
assert_absent '完整流程：`/product → /design → /test-design → /tech-lead → /delivery-owner`' "$PRODUCT_COMPAT_SKILL"
assert_present '/product-manager' "$DESIGN_SKILL"
assert_present 'product-director → /product-manager' "$DESIGN_SKILL"
assert_present '/product-manager' "$TEST_DESIGN_SKILL"
assert_present '/product-manager' "$TECH_LEAD_SKILL"
assert_present '/product-manager' "$DELIVERY_OWNER_SKILL"
assert_present '/product-director' "$FIX_SKILL"
assert_present 'M-HG-8' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present 'M-HG-9' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present 'product-manager' "$DESIGN_DECISION_TEMPLATES"
assert_present '\.\./\.\./product-manager/references/conversation-guide\.md' "$DESIGN_DECISION_TEMPLATES"
assert_absent '^> 核心参考：`\.\./product-manager/references/conversation-guide\.md`（对话节奏）$' "$DESIGN_DECISION_TEMPLATES"
assert_absent 'shared/skills/product/scripts/completion_check\.sh' "$PRODUCT_MANAGER_CHECK"
assert_absent '^LEGACY_PRODUCT_CHECK=' "$PRODUCT_MANAGER_CHECK"

echo "[PASS] product role split contract"
