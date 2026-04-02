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
  if rg -n "$pattern" "$file" >/tmp/org_skill_gate_absent.out 2>&1; then
    cat /tmp/org_skill_gate_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

extract_function_body() {
  local function_name="$1"
  local file="$2"
  awk -v function_name="$function_name" '
    $0 ~ ("^[[:space:]]*" function_name "\\(\\)[[:space:]]*\\{") { in_func=1 }
    in_func { print }
    in_func && $0 ~ /^[[:space:]]*}[[:space:]]*$/ { exit }
  ' "$file"
}

assert_confirmation_time_contract() {
  local file="$1"
  local label="$2"
  local placeholder_func
  local valid_time_func
  local script_content

  placeholder_func="$(extract_function_body "is_placeholder_text" "$file")"
  valid_time_func="$(extract_function_body "is_valid_confirmation_time" "$file")"
  [ -n "$placeholder_func" ] || fail "${label}: missing is_placeholder_text()"
  [ -n "$valid_time_func" ] || fail "${label}: missing is_valid_confirmation_time()"

  script_content="$(printf '%s\n%s\n%s\n' "$placeholder_func" "$valid_time_func" "is_valid_confirmation_time \"\$TEST_VALUE\"")"

  if TEST_VALUE="YYYY-MM-DD HH:mm" bash -s >/dev/null 2>&1 <<<"$script_content"; then
    fail "${label}: placeholder time unexpectedly passes"
  fi
  if ! TEST_VALUE="2026-03-26 18:00" bash -s >/dev/null 2>&1 <<<"$script_content"; then
    fail "${label}: valid confirmation time unexpectedly fails"
  fi
  if TEST_VALUE="2026/03/26 18:00" bash -s >/dev/null 2>&1 <<<"$script_content"; then
    fail "${label}: invalid format unexpectedly passes"
  fi
}

PRODUCT_SKILL="$ROOT/shared/skills/product/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
TEST_DESIGN_SKILL="$ROOT/shared/skills/test-design/SKILL.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
PM_SKILL="$ROOT/shared/skills/project-manager/SKILL.md"
REVIEW_SKILL="$ROOT/shared/skills/review/SKILL.md"
PRODUCT_CONVERSATION_GUIDE="$ROOT/shared/skills/product/references/conversation-guide.md"
DESIGN_DECISION_TEMPLATES="$ROOT/shared/skills/design/references/decision-templates.md"
PM_PHASE3_DOC="$ROOT/shared/skills/project-manager/references/phase3-dispatch.md"
PRODUCT_REVIEW_ITERATION="$ROOT/shared/skills/product/references/review-iteration-protocol.md"
SHARED_REVIEW_FIX="$ROOT/shared/protocols/review-fix-loop-protocol.md"
SHARED_REVIEW_ITERATION="$ROOT/shared/protocols/review-iteration-protocol.md"
PHASE_SELECTION_PROTOCOL="$ROOT/shared/protocols/phase-selection-protocol.md"
PRODUCT_CHECK="$ROOT/shared/skills/product/scripts/completion_check.sh"

for skill in "$PRODUCT_SKILL" "$DESIGN_SKILL" "$TEST_DESIGN_SKILL" "$TECH_LEAD_SKILL" "$PM_SKILL"; do
  assert_absent '^## 输出呈现$' "$skill"
done

assert_absent '^hooks:$' "$PRODUCT_SKILL"
assert_absent '^hooks:$' "$DESIGN_SKILL"
assert_absent '^hooks:$' "$TEST_DESIGN_SKILL"
assert_absent '^hooks:$' "$TECH_LEAD_SKILL"
assert_absent '^hooks:$' "$PM_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh` 并通过，无 FAIL 项' "$PRODUCT_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh` 并通过，无 FAIL 项' "$DESIGN_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh` 并通过，无 FAIL 项' "$TEST_DESIGN_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh` 并通过，无 FAIL 项' "$TECH_LEAD_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh` 并通过，无 FAIL 项' "$PM_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh`' "$TEST_DESIGN_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh`' "$TECH_LEAD_SKILL"
assert_present '显式执行 `scripts/completion_check\.sh`' "$PM_SKILL"
assert_absent 'Stop hook（`completion_check\.sh`）执行通过，无 FAIL 项' "$PRODUCT_SKILL"
assert_absent 'Stop hook（`completion_check\.sh`）执行通过，无 FAIL 项' "$DESIGN_SKILL"
assert_absent 'Stop hook（`completion_check\.sh`）执行通过，无 FAIL 项' "$TEST_DESIGN_SKILL"
assert_absent 'Stop hook（`completion_check\.sh`）执行通过，无 FAIL 项' "$TECH_LEAD_SKILL"
assert_absent 'Stop hook（`completion_check\.sh`）执行通过，无 FAIL 项' "$PM_SKILL"
assert_present '^## 中途插问处理$' "$PRODUCT_CONVERSATION_GUIDE"
assert_present '当前步骤保持不变' "$PRODUCT_CONVERSATION_GUIDE"
assert_present '^## 中途插问处理$' "$DESIGN_DECISION_TEMPLATES"
assert_present '当前步骤保持不变' "$DESIGN_DECISION_TEMPLATES"

assert_present '交付确认' "$PRODUCT_SKILL"
assert_present 'flow override in S2-S12' "$PRODUCT_SKILL"
assert_present '既有约束继承确认' "$DESIGN_SKILL"
assert_present 'flow override in S3-S8' "$DESIGN_SKILL"
assert_present 'shallow review evidence' "$TEST_DESIGN_SKILL"
assert_present '用户确认记录' "$TECH_LEAD_SKILL"
assert_present '确认状态=确认' "$TECH_LEAD_SKILL"
assert_present 'Phase 3 gate evidence mismatches plan grade matrix' "$PM_SKILL"
assert_present 'protocols/review-iteration-protocol.md' "$PRODUCT_SKILL"
assert_present 'protocols/phase-selection-protocol.md' "$DESIGN_SKILL"
assert_present 'protocols/review-fix-loop-protocol.md' "$DESIGN_SKILL"
assert_present 'protocols/phase-selection-protocol.md' "$TEST_DESIGN_SKILL"
assert_present 'protocols/phase-selection-protocol.md' "$TECH_LEAD_SKILL"
assert_present 'protocols/review-fix-loop-protocol.md' "$PM_SKILL"
assert_present 'protocols/review-iteration-protocol.md' "$REVIEW_SKILL"
assert_present 'protocols/review-fix-loop-protocol.md' "$PM_PHASE3_DOC"
assert_present 'protocols/review-fix-loop-protocol.md' "$PRODUCT_REVIEW_ITERATION"

for file in \
  "$PRODUCT_SKILL" \
  "$DESIGN_SKILL" \
  "$TEST_DESIGN_SKILL" \
  "$TECH_LEAD_SKILL" \
  "$PM_SKILL" \
  "$REVIEW_SKILL" \
  "$PM_PHASE3_DOC" \
  "$PRODUCT_REVIEW_ITERATION" \
  "$SHARED_REVIEW_FIX" \
  "$SHARED_REVIEW_ITERATION"
do
  assert_absent 'reference/(phase-selection-protocol|review-fix-loop-protocol|review-iteration-protocol)\.md' "$file"
done

assert_absent 'equivalence/' "$PHASE_SELECTION_PROTOCOL"

PRODUCT_TEMPLATE="$ROOT/shared/skills/product/references/templates/prd-template.md"
DESIGN_TEMPLATE="$ROOT/shared/skills/design/references/templates/design-template.md"
PLAN_TEMPLATE="$ROOT/shared/skills/tech-lead/references/templates/plan-template.md"
IMPACT_ANALYSIS="$ROOT/shared/reference/影响范围分析.md"
IMPACT_FORMAT="$ROOT/shared/reference/影响文件格式.md"

assert_present '^## 前置约束$' "$PRODUCT_TEMPLATE"
assert_absent '^## 约束$' "$PRODUCT_TEMPLATE"
assert_present "extract_markdown_section \"\\\$prd_file\" \"## 前置约束\"" "$PRODUCT_CHECK"
assert_present '^    "## 前置约束"$' "$PRODUCT_CHECK"
assert_absent "extract_markdown_section \"\\\$prd_file\" \"## 约束\"" "$PRODUCT_CHECK"
assert_absent '^    "## 约束"$' "$PRODUCT_CHECK"
assert_present '^## 交付确认$' "$PRODUCT_TEMPLATE"
assert_present '^\| 交付确认 \| \| \| \|$' "$PRODUCT_TEMPLATE"
assert_present '^## 既有约束继承确认$' "$DESIGN_TEMPLATE"
assert_present '^\| 决策点识别 \| \| \| \|$' "$DESIGN_TEMPLATE"
assert_present '^## 交付确认$' "$DESIGN_TEMPLATE"
assert_present '^## 用户确认记录$' "$PLAN_TEMPLATE"
assert_present 'reference/影响文件格式.md' "$PLAN_TEMPLATE"
assert_present 'reference/影响文件格式.md' "$IMPACT_ANALYSIS"
assert_absent 'plan-template\.md' "$IMPACT_ANALYSIS"
test -f "$IMPACT_FORMAT" || fail "missing shared impact_files format reference"

PRODUCT_CHECK="$ROOT/shared/skills/product/scripts/completion_check.sh"
DESIGN_CHECK="$ROOT/shared/skills/design/scripts/completion_check.sh"
TECH_LEAD_CHECK="$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
TEST_DESIGN_CHECK="$ROOT/shared/skills/test-design/scripts/completion_check.sh"

assert_present '"## 交付确认"' "$PRODUCT_CHECK"
assert_present '"交付确认"; do' "$PRODUCT_CHECK"
assert_present '数据行不足 6 条' "$PRODUCT_CHECK"
assert_present '确认状态必须为「确认」' "$PRODUCT_CHECK"

assert_present 'extract_inheritance_rows' "$DESIGN_CHECK"
assert_present '"## 既有约束继承确认"' "$DESIGN_CHECK"
assert_present '"决策点识别"' "$DESIGN_CHECK"
assert_present '处理方式非法' "$DESIGN_CHECK"
assert_present '"## 交付确认"' "$DESIGN_CHECK"
assert_present 'S10 最终确认' "$DESIGN_CHECK"

assert_present '"## 用户确认记录"' "$TECH_LEAD_CHECK"
assert_present '用户确认记录状态必须为「确认」' "$TECH_LEAD_CHECK"

assert_present '不满足 HARD-GATE 2' "$TEST_DESIGN_CHECK"

assert_confirmation_time_contract "$PRODUCT_CHECK" "product completion_check"
assert_confirmation_time_contract "$DESIGN_CHECK" "design completion_check"
assert_confirmation_time_contract "$TECH_LEAD_CHECK" "tech-lead completion_check"

echo "[PASS] skill output/gate contract"
