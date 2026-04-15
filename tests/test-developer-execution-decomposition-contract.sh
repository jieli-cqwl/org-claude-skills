#!/usr/bin/env bash
set -euo pipefail

# developer execution-decomposition contract test
# 验证 developer skill 包含执行拆解阶段，tech-lead 不再包含 impact_files

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

PASS=0
FAIL=0

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  FAIL=$((FAIL + 1))
}

pass() {
  printf '[PASS] %s\n' "$*"
  PASS=$((PASS + 1))
}

assert_present() {
  local desc="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc — missing pattern '$pattern' in $file"
  fi
}

assert_absent() {
  local desc="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "$desc — unexpected pattern '$pattern' found in $file"
  else
    pass "$desc"
  fi
}

DEV_SKILL="$ROOT/shared/skills/developer/SKILL.md"
DEV_REPORT="$ROOT/shared/skills/developer/references/templates/developer-report-template.md"
DEV_SELF_REVIEW="$ROOT/shared/skills/developer/references/self-review-methodology.md"
DEV_DECOMP_GUIDE="$ROOT/shared/skills/developer/references/execution-decomposition-guide.md"
TL_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
TL_TEMPLATE="$ROOT/shared/skills/tech-lead/references/templates/plan-template.md"

# ── Developer: 执行拆解阶段存在性 ──

assert_present \
  "developer SKILL.md 包含执行拆解步骤" \
  "执行拆解" \
  "$DEV_SKILL"

assert_present \
  "developer SKILL.md 包含代码探索子步骤" \
  "代码探索" \
  "$DEV_SKILL"

assert_present \
  "developer SKILL.md 包含模式识别子步骤" \
  "模式识别" \
  "$DEV_SKILL"

assert_present \
  "developer SKILL.md 包含步骤规划子步骤" \
  "步骤规划" \
  "$DEV_SKILL"

assert_present \
  "developer SKILL.md 包含风险标注子步骤" \
  "风险标注" \
  "$DEV_SKILL"

assert_present \
  "developer SKILL.md 引用 execution-decomposition-guide" \
  "execution-decomposition-guide" \
  "$DEV_SKILL"

# ── Developer: 执行拆解方法论文件存在 ──

if [ -f "$DEV_DECOMP_GUIDE" ]; then
  pass "execution-decomposition-guide.md 文件存在"

  assert_present \
    "方法论包含代码探索方法" \
    "代码探索" \
    "$DEV_DECOMP_GUIDE"

  assert_present \
    "方法论包含模式识别清单" \
    "模式识别" \
    "$DEV_DECOMP_GUIDE"

  assert_present \
    "方法论包含步骤规划格式" \
    "步骤规划" \
    "$DEV_DECOMP_GUIDE"

  assert_present \
    "方法论包含风险标注触发条件" \
    "风险标注" \
    "$DEV_DECOMP_GUIDE"

  assert_absent \
    "方法论不再包含比例缩放" \
    "比例缩放|缩放判断|轻量条件（全部满足才可降级）" \
    "$DEV_DECOMP_GUIDE"

  assert_present \
    "方法论要求完成全部执行拆解步骤" \
    "所有 Task 均需完成 1a-1e" \
    "$DEV_DECOMP_GUIDE"
else
  fail "execution-decomposition-guide.md 文件不存在"
fi

# ── Developer: 报告模板包含执行拆解区块 ──

assert_present \
  "developer-report 模板包含执行拆解区块" \
  "执行拆解" \
  "$DEV_REPORT"

assert_present \
  "developer-report 模板包含代码探索结论" \
  "代码探索结论" \
  "$DEV_REPORT"

assert_present \
  "developer-report 模板包含复用候选" \
  "复用候选" \
  "$DEV_REPORT"

assert_present \
  "developer-report 模板包含实现步骤" \
  "实现步骤" \
  "$DEV_REPORT"

assert_present \
  "developer-report 模板包含执行拆解结论" \
  "执行拆解结论" \
  "$DEV_REPORT"

# ── Developer: 自审包含执行拆解遵循度维度 ──

assert_present \
  "self-review 包含执行拆解遵循度维度" \
  "执行拆解遵循" \
  "$DEV_SELF_REVIEW"

# ── Tech-lead: impact_files 已移除 ──

assert_absent \
  "tech-lead plan-template 不包含 impact_files 字段" \
  "impact_files" \
  "$TL_TEMPLATE"

assert_absent \
  "tech-lead SKILL.md 不要求 impact_files" \
  "impact_files" \
  "$TL_SKILL"

# ── Tech-lead: shared_files 保留 ──

assert_present \
  "tech-lead plan-template 保留 shared_files" \
  "shared_files" \
  "$TL_TEMPLATE"

# ── Summary ──

printf '\n── Summary ──\n'
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
