#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_OUTPUT="$ROOT/shared/skills/product-director/references/output.md"
DIRECTOR_PROBLEM_GUIDE="$ROOT/shared/skills/product-director/references/problem-clarification.md"
DIRECTOR_SUCCESS_GUIDE="$ROOT/shared/skills/product-director/references/success-investment-boundary.md"
DIRECTOR_SCOPE_GUIDE="$ROOT/shared/skills/product-director/references/scope-constraints.md"
DIRECTOR_RISKS_GUIDE="$ROOT/shared/skills/product-director/references/risks-unknowns.md"
DIRECTOR_PHASE_GUIDE="$ROOT/shared/skills/product-director/references/phase-planning.md"
DIRECTOR_BRIEF_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
MANAGER_OUTPUT="$ROOT/shared/skills/product-manager/references/output.md"
MANAGER_UNIT_SPEC="$ROOT/shared/skills/product-manager/references/closed-loop-unit-spec.md"
MANAGER_CHECKLIST="$ROOT/shared/skills/product-manager/references/completeness-checklist.md"
MANAGER_GUIDE="$ROOT/shared/skills/product-manager/references/conversation-guide.md"
MANAGER_REVIEW_ORCHESTRATION="$ROOT/shared/skills/product-manager/references/review-orchestration.md"
MANAGER_PRD_REVIEWER="$ROOT/shared/skills/product-manager/references/prd-reviewer-prompt.md"
MANAGER_TEST_REVIEWER="$ROOT/shared/skills/product-manager/references/tester-reviewer-prompt.md"
MANAGER_ARCH_REVIEWER="$ROOT/shared/skills/product-manager/references/architect-reviewer-prompt.md"
MANAGER_PHASE_TEMPLATE="$ROOT/shared/skills/product-manager/projections/phase-prd-template.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

for file in \
  "$DIRECTOR_SKILL" "$DIRECTOR_OUTPUT" "$DIRECTOR_PROBLEM_GUIDE" "$DIRECTOR_SUCCESS_GUIDE" \
  "$DIRECTOR_SCOPE_GUIDE" "$DIRECTOR_RISKS_GUIDE" "$DIRECTOR_PHASE_GUIDE" \
  "$DIRECTOR_BRIEF_JSON_TEMPLATE" "$DIRECTOR_PHASE_JSON_TEMPLATE" "$MANAGER_SKILL" \
  "$MANAGER_OUTPUT" "$MANAGER_UNIT_SPEC" "$MANAGER_CHECKLIST" "$MANAGER_GUIDE" \
  "$MANAGER_REVIEW_ORCHESTRATION" "$MANAGER_PRD_REVIEWER" "$MANAGER_TEST_REVIEWER" \
  "$MANAGER_ARCH_REVIEWER" "$MANAGER_PHASE_TEMPLATE"; do
  assert_file "$file"
done
if [ -d "$ROOT/shared/skills/product-director/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi

assert_present '^## 流程图$' "$DIRECTOR_SKILL"
assert_absent '^## 流程总览$' "$DIRECTOR_SKILL"
assert_absent '节点顺序：' "$DIRECTOR_SKILL"
assert_present '"D-S5\.5 风险与未知项" -> "Pause D-S5\.5 关键风险未闭合" -> "D-S6 Phase 规划"' "$DIRECTOR_SKILL"
assert_present '"D-S6 Phase 规划" -> "Pause D-S6 Phase 假设未闭合" -> "D-G1 总监确认门"' "$DIRECTOR_SKILL"
assert_present '^## 流程细节$' "$DIRECTOR_SKILL"
assert_absent '^### [0-9]+\. D-' "$DIRECTOR_SKILL"
assert_present '^### D-S1 静默信息收集$' "$DIRECTOR_SKILL"
assert_present '^### D-G1 总监确认门$' "$DIRECTOR_SKILL"
assert_present 'D-S2.*用户画像|用户画像.*D-S2' "$DIRECTOR_SKILL"
assert_present 'D-S3.*投入边界|投入边界.*D-S3' "$DIRECTOR_SKILL"
assert_present 'D-S5.*本期不做|本期不做.*D-S5' "$DIRECTOR_SKILL"
assert_present 'D-S5.*可行性约束|可行性约束.*D-S5' "$DIRECTOR_SKILL"
assert_present 'D-S5.*决策理由|决策理由.*D-S5' "$DIRECTOR_SKILL"
assert_present 'D-S5\.5.*风险与未知项|风险与未知项.*D-S5\.5' "$DIRECTOR_SKILL"
assert_present 'Why:' "$DIRECTOR_SKILL"

assert_present '用户画像|user_profile' "$DIRECTOR_OUTPUT"
assert_present 'appetite.*投入边界|投入边界.*appetite' "$DIRECTOR_OUTPUT"
assert_present 'non_goals.*本期不做范围|本期不做范围.*non_goals' "$DIRECTOR_OUTPUT"
assert_present '可行性约束|feasibility_constraints' "$DIRECTOR_OUTPUT"
assert_present '风险与未知项|risks_and_unknowns' "$DIRECTOR_OUTPUT"
assert_present '决策理由|decision_rationale' "$DIRECTOR_OUTPUT"
jq -e '
  .user_profile
  and .appetite
  and .non_goals
  and .feasibility_constraints
  and .risks_and_unknowns
  and .decision_rationale
  and .director_confirmation.locked_fields
' "$DIRECTOR_BRIEF_JSON_TEMPLATE" >/dev/null || fail "director brief JSON template must expose Director fields"
jq -e '
  .phase_goal
  and .entry_conditions
  and .exit_conditions
  and ((.unit_index // []) | type == "array" and length == 0)
  and .director_confirmation.locked_fields
' "$DIRECTOR_PHASE_JSON_TEMPLATE" >/dev/null || fail "director phase JSON template must expose Phase skeleton"
assert_present '用户画像|现有处理方式' "$DIRECTOR_PROBLEM_GUIDE"
assert_present '投入边界' "$DIRECTOR_SUCCESS_GUIDE"
assert_present '最小闭环范围界定' "$DIRECTOR_SCOPE_GUIDE"
assert_present '产品总监 / 产品经理边界' "$DIRECTOR_SCOPE_GUIDE"
assert_present '推翻判断的风险与未知项' "$DIRECTOR_RISKS_GUIDE"
assert_present '默认单 Phase' "$DIRECTOR_PHASE_GUIDE"

assert_present '^## 流程图$' "$MANAGER_SKILL"
assert_absent '^## 流程总览$' "$MANAGER_SKILL"
assert_absent '节点顺序：' "$MANAGER_SKILL"
assert_present '"M-S5\.5 Verification Plan" -> "M-S6 结构化待设计决策"' "$MANAGER_SKILL"
assert_present '"M-G1 PM 收口门" -> "M-S9 交付确认与输出"' "$MANAGER_SKILL"
assert_present '^## 流程细节$' "$MANAGER_SKILL"
assert_absent '^### [0-9]+\. M-' "$MANAGER_SKILL"
assert_present '^### M-S0 内容完整性检查与准入验证$' "$MANAGER_SKILL"
assert_present '^### M-S9 交付确认与输出$' "$MANAGER_SKILL"
assert_present 'M-S0.*内容完整性|内容完整性.*M-S0' "$MANAGER_SKILL"
assert_present 'M-S4.*Integration Context|Integration Context.*M-S4' "$MANAGER_SKILL"
assert_present 'M-S5.*示例驱动|示例驱动.*M-S5' "$MANAGER_SKILL"
assert_present 'M-S5.*失败模式|失败模式.*M-S5' "$MANAGER_SKILL"
assert_present 'M-S5\.5.*Verification Plan|Verification Plan.*M-S5\.5' "$MANAGER_SKILL"
assert_present 'M-S6.*结构化|结构化.*M-S6' "$MANAGER_SKILL"
assert_present 'M-S7.*AI 可执行性|AI 可执行性.*M-S7' "$MANAGER_SKILL"
assert_present 'Why:' "$MANAGER_SKILL"

assert_present '示例输入' "$MANAGER_UNIT_SPEC"
assert_present '预期结果' "$MANAGER_UNIT_SPEC"
assert_present '边界情况' "$MANAGER_UNIT_SPEC"
assert_present '失败模式' "$MANAGER_UNIT_SPEC"
assert_present 'Verification Plan|验证计划' "$MANAGER_UNIT_SPEC"
assert_present 'Integration Context|集成上下文' "$MANAGER_UNIT_SPEC"
assert_present 'P0 / P1 / P2 / P3|P0.*P1.*P2.*P3' "$MANAGER_UNIT_SPEC"
assert_absent 'MVP / 增强 / 扩展|MVP/增强/扩展' "$MANAGER_UNIT_SPEC"
assert_present 'unit-definition|UNIT-\*\.json|JSON Pointer|canonical' "$MANAGER_UNIT_SPEC"
assert_present '\$\.closure_definition|\$\.acceptance_criteria|\$\.verification_plan|\$\.integration_context' "$MANAGER_UNIT_SPEC"
assert_absent '^## 模板$|```markdown|^# UNIT-NNN|^## 背景$|^## 需求描述$|^## 验收标准$' "$MANAGER_UNIT_SPEC"
assert_present 'AI 可执行性' "$MANAGER_CHECKLIST"
assert_present '示例驱动|示例输入' "$MANAGER_PRD_REVIEWER"
assert_present 'AI 可执行性' "$MANAGER_PRD_REVIEWER"
assert_present 'Verification Plan|验证计划' "$MANAGER_TEST_REVIEWER"
assert_present 'Integration Context|集成上下文' "$MANAGER_ARCH_REVIEWER"
assert_present 'Verification Plan|验证计划' "$MANAGER_PHASE_TEMPLATE"
assert_present 'Integration Context|集成上下文' "$MANAGER_PHASE_TEMPLATE"

echo "[PASS] product capability and structure redesign"
