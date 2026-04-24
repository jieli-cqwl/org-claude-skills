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

test -f "$PRODUCT_MANAGER" || fail "missing product-manager skill"
test -f "$DEVELOPER" || fail "missing developer skill"

assert_present "product-manager" "## Response Contract" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-1 UNIT 闭环锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-2 AC 与排除项追踪锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-3 阻断回答仍保留下游锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "输入 / 触发 / 核心行为 / 可观察结果" "$PRODUCT_MANAGER"
assert_present "product-manager" "Verification Plan 映射" "$PRODUCT_MANAGER"
assert_present "product-manager" "排除项追踪字段" "$PRODUCT_MANAGER"

assert_present "developer" "## 流程合规输出合同" "$DEVELOPER"
assert_present "developer" "DEV-FLOW-1 说明模式仍输出 canonical gates" "$DEVELOPER"
assert_present "developer" "DEV-FLOW-2 每条 AC 的 RED/GREEN/REFACTOR 证据索引" "$DEVELOPER"
assert_present "developer" "DEV-FLOW-3 developer-report.json 骨架字段" "$DEVELOPER"
assert_present "developer" "DEV-FLOW-4 缺少 canonical 输入时 BLOCKED" "$DEVELOPER"
assert_present "developer" "tdd_evidence_index" "$DEVELOPER"
assert_present "developer" "reviewable_anchor" "$DEVELOPER"
assert_present "developer" "task_scope" "$DEVELOPER"

printf '[PASS] skill optimization contracts\n'
