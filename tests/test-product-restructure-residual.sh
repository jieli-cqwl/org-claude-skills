#!/usr/bin/env bash
# 产品结构重构残留扫描测试
# 验证运行时消费者目录中不存在旧合同形式的引用
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

ERRORS=0
check_no_match() {
  local label="$1" pattern="$2"
  shift 2
  local dirs=("$@")
  local matches
  matches=$(rg -n "$pattern" "${dirs[@]}" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    printf '[FAIL] %s: found residual matches:\n%s\n' "$label" "$matches" >&2
    ERRORS=$((ERRORS + 1))
  fi
}

check_present() {
  local label="$1" pattern="$2" file="$3"
  if ! rg -n "$pattern" "$file" >/dev/null 2>&1; then
    printf '[FAIL] %s: missing expected pattern in %s: %s\n' "$label" "$file" "$pattern" >&2
    ERRORS=$((ERRORS + 1))
  fi
}

# 扫描范围：运行时消费者目录
SCAN_DIRS=(
  "$ROOT/shared/skills"
  "$ROOT/shared/agents"
  "$ROOT/shared/protocols"
  "$ROOT/contracts"
)

# --- 旧合同残留扫描 ---

# 旧文本路径：docs/{feature}/prd.md（非 phase-{N}/prd.md）
# 匹配 docs/任意/prd.md 但排除 docs/任意/phase-数字/prd.md
check_no_match \
  "old top-level prd.md path" \
  'docs/[^/]+/prd\.md' \
  "${SCAN_DIRS[@]}"

# 旧文本路径：docs/{feature}/units/UNIT-*.md（非 phase-{N}/units/）
check_no_match \
  "old top-level units/ path" \
  'docs/[^/]+/units/UNIT-' \
  "${SCAN_DIRS[@]}"

# 旧脚本变量：$FEATURE_DIR/prd.md
# shellcheck disable=SC2016
check_no_match \
  'old $FEATURE_DIR/prd.md variable' \
  '\$FEATURE_DIR/prd\.md' \
  "${SCAN_DIRS[@]}"

# 旧脚本变量：$FEATURE_DIR/units
# shellcheck disable=SC2016
check_no_match \
  'old $FEATURE_DIR/units variable' \
  '\$FEATURE_DIR/units' \
  "${SCAN_DIRS[@]}"

# 旧函数名：_from_prd（全仓库扫描）
FULL_SCAN_MATCHES=$(rg -n '_from_prd' "$ROOT" \
  --glob '!docs/product-restructure/*' \
  --glob '!docs/archive/*' \
  --glob '!.git/*' \
  --glob '!**/tests/test-product-restructure-residual.sh' \
  2>/dev/null || true)
if [ -n "$FULL_SCAN_MATCHES" ]; then
  printf '[FAIL] old _from_prd function name residual:\n%s\n' "$FULL_SCAN_MATCHES" >&2
  ERRORS=$((ERRORS + 1))
fi

# --- 正向断言：核心下游 SKILL.md 必须消费 canonical product baseline ---

for skill_name in design test-design qa; do
  check_present \
    "${skill_name} SKILL.md has brief.json reference" \
    'brief\.json' \
    "$ROOT/shared/skills/${skill_name}/SKILL.md"
  check_present \
    "${skill_name} SKILL.md has phase-prd.json reference" \
    'phase-prd\.json' \
    "$ROOT/shared/skills/${skill_name}/SKILL.md"
done

check_present \
  "tech-lead SKILL.md consumes confirmed product baseline" \
  'scope_item_refs|test_refs|design_refs' \
  "$ROOT/shared/skills/tech-lead/SKILL.md"

# --- 结果 ---

if [ "$ERRORS" -gt 0 ]; then
  fail "product restructure residual scan found $ERRORS issue(s)"
fi

echo "[PASS] product restructure residual scan"
