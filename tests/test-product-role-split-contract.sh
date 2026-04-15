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

SHARED_BRIEF_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/brief-template.md"
SHARED_PHASE_TEMPLATE="$ROOT/shared/skills/product-shared/references/templates/phase-prd-template.md"
PRODUCT_DIRECTOR_ROOT="$ROOT/shared/skills/product-director"
PRODUCT_MANAGER_ROOT="$ROOT/shared/skills/product-manager"

test -f "$SHARED_BRIEF_TEMPLATE" || fail "missing shared brief template: $SHARED_BRIEF_TEMPLATE"
test -f "$SHARED_PHASE_TEMPLATE" || fail "missing shared phase template: $SHARED_PHASE_TEMPLATE"
test -d "$PRODUCT_DIRECTOR_ROOT" || fail "missing product-director root: $PRODUCT_DIRECTOR_ROOT"
test -d "$PRODUCT_MANAGER_ROOT" || fail "missing product-manager root: $PRODUCT_MANAGER_ROOT"

assert_present '^## 产品总监确认$' "$SHARED_BRIEF_TEMPLATE"
assert_present '^## 共创摘要$' "$SHARED_BRIEF_TEMPLATE"
assert_present '^\| 阶段 \| 技能 \| 关键提问 \| 用户回应 \| 对产品的影响 \|$' "$SHARED_BRIEF_TEMPLATE"
assert_present '^## 引用锚点合同$' "$SHARED_BRIEF_TEMPLATE"
assert_present 'Director 定义约束事实，PM 只补执行映射字段' "$SHARED_BRIEF_TEMPLATE"
assert_present '不得改 Phase 级结构字段（标题、入口条件、出口条件、交付价值）' "$SHARED_BRIEF_TEMPLATE"
assert_present '^## 引用锚点合同$' "$SHARED_PHASE_TEMPLATE"
assert_present 'Director 已确认的阶段骨架字段' "$SHARED_PHASE_TEMPLATE"

echo "[PASS] product role split contract"
