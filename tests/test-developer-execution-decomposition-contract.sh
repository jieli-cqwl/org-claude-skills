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
DEV_REPORT_PROJECTION="$ROOT/shared/skills/developer/projections/developer-report-template.md"
DEV_SELF_REVIEW="$ROOT/shared/skills/developer/references/self-review-methodology.md"
DEV_DECOMP_GUIDE="$ROOT/shared/skills/developer/references/execution-decomposition-guide.md"
TL_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
TL_TEMPLATE="$ROOT/shared/skills/tech-lead/projections/plan-template.md"

# ── Developer: execution decomposition guide wiring ──

assert_present \
  "developer SKILL.md 引用 execution-decomposition-guide" \
  "execution-decomposition-guide" \
  "$DEV_SKILL"

# ── Developer: 执行拆解方法论文件存在 ──

if [ -f "$DEV_DECOMP_GUIDE" ]; then
  pass "execution-decomposition-guide.md 文件存在"
else
  fail "execution-decomposition-guide.md 文件不存在"
fi

# ── Developer: active projection template is intentionally removed ──

if [ -e "$DEV_REPORT_PROJECTION" ]; then
  fail "active developer projection template should be deleted: $DEV_REPORT_PROJECTION"
else
  pass "active developer projection template 已删除"
fi

assert_absent \
  "developer SKILL.md 不再引用 deleted projection template" \
  "projections/developer-report-template" \
  "$DEV_SKILL"

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
