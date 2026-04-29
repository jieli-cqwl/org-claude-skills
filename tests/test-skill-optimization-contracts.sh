#!/usr/bin/env bash
# 文件职责：验证本轮 Skill 优化合同锚点已写入 product-manager 与 developer。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_MANAGER="$ROOT/shared/skills/product-manager/SKILL.md"
DEVELOPER="$ROOT/shared/skills/developer/SKILL.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local label="$1"
  local needle="$2"
  local file="$3"
  grep -Fq "$needle" "$file" || fail "$label missing optimization phrase: $needle"
}

assert_absent() {
  local label="$1"
  local needle="$2"
  local file="$3"
  if grep -Fq "$needle" "$file"; then
    fail "$label contains retired/noise phrase: $needle"
  fi
}

test -f "$PRODUCT_MANAGER" || fail "missing product-manager skill"
test -f "$DEVELOPER" || fail "missing developer skill"

assert_present "product-manager" "## Response Contract" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-1 UNIT 闭环锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-2 AC 与排除项追踪锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-3 阻断回答仍保留下游锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "输入 / 触发 / 核心行为 / 可观察结果" "$PRODUCT_MANAGER"
assert_present "product-manager" "Verification Plan 映射" "$PRODUCT_MANAGER"
assert_present "product-manager" "排除项追踪字段" "$PRODUCT_MANAGER"

assert_present "developer" "## 输入识别" "$DEVELOPER"
assert_present "developer" "## 流程图" "$DEVELOPER"
assert_present "developer" "digraph developer_flow" "$DEVELOPER"
assert_present "developer" "RED/GREEN/REFACTOR" "$DEVELOPER"
assert_present "developer" "developer-report.json" "$DEVELOPER"
assert_present "developer" "默认输出是当前 Task 的 \`developer-report.json\`" "$DEVELOPER"
assert_absent "developer" "shared/skills/developer/scripts/completion_check.sh" "$DEVELOPER"
assert_absent "developer" "shared/hooks/registry.json" "$DEVELOPER"
assert_absent "developer" "completion gate" "$DEVELOPER"
assert_absent "developer" "常用证据组包括" "$DEVELOPER"
assert_absent "developer" "projections/developer-report-template.md" "$DEVELOPER"

printf '[PASS] skill optimization contracts\n'
