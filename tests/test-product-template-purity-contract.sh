#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MANAGER_BRIEF="$ROOT/shared/skills/product-manager/projections/brief-template.md"
MANAGER_PHASE="$ROOT/shared/skills/product-manager/projections/phase-prd-template.md"
MANAGER_REVIEW="$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md"
DIRECTOR_BRIEF_JSON="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
MANAGER_BRIEF_JSON="$ROOT/shared/skills/product-manager/templates/brief.template.json"
MANAGER_PHASE_JSON="$ROOT/shared/skills/product-manager/templates/phase-prd.template.json"
MANAGER_UNIT_JSON="$ROOT/shared/skills/product-manager/templates/unit-definition.template.json"
EVIDENCE_PLAN="$ROOT/docs/archive/product-role-split-20260414/evidence-and-eval-plan.md"
DEEP_REPORT="$ROOT/docs/archive/product-role-split-20260414/deep-validation-report.md"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Eq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern '$pattern' in $file"
  fi
}

assert_line_count_at_most() {
  local max="$1" file="$2"
  local actual
  actual="$(wc -l < "$file" | tr -d ' ')"
  [ "$actual" -le "$max" ] || fail "$file has $actual lines; expected <= $max"
}

assert_rule_like_count_at_most() {
  local max="$1" file="$2"
  local actual
  actual="$({ grep -En '必须|不得|禁止|仅在|只允许|不要|若|状态枚举|D-G1|M-G1|lock|冻结|通过后|authoritative' "$file" || true; } | wc -l | tr -d ' ')"
  [ "$actual" -le "$max" ] || fail "$file has $actual rule-like lines; expected <= $max"
}

for file in \
  "$MANAGER_BRIEF" \
  "$MANAGER_PHASE" \
  "$MANAGER_REVIEW" \
  "$DIRECTOR_BRIEF_JSON" \
  "$DIRECTOR_PHASE_JSON" \
  "$MANAGER_BRIEF_JSON" \
  "$MANAGER_PHASE_JSON" \
  "$MANAGER_UNIT_JSON"; do
  assert_file "$file"
done

if [ -d "$ROOT/shared/skills/product-director/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi

for file in "$DIRECTOR_BRIEF_JSON" "$DIRECTOR_PHASE_JSON" "$MANAGER_BRIEF_JSON" "$MANAGER_PHASE_JSON" "$MANAGER_UNIT_JSON"; do
  assert_absent 'runtime control decisions|canonical-only runtime control|standard-chain operators|migrate standard-chain|cutover readiness|foundation registry|legacy phase migration|standard-chain canonical planning|downstream skills consume canonical JSON' "$file"
done

jq -e '
  .director_confirmation.locked_fields
  and all(.delivery_plan[]; .iteration_timebox_days == 14)
  and all(.director_confirmation.locked_fields.delivery_plan[]; .iteration_timebox_days == 14)
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
  and (.delivery_confirmation? | not)
' "$DIRECTOR_BRIEF_JSON" >/dev/null || fail "director brief JSON template must stay Director-owned"
jq -e '
  all(.delivery_plan[]; .iteration_timebox_days == 14)
  and all(.director_confirmation.locked_fields.delivery_plan[]; .iteration_timebox_days == 14)
' "$MANAGER_BRIEF_JSON" >/dev/null || fail "manager brief JSON template must carry Phase timeboxes"
jq -e '
  .director_confirmation.locked_fields
  and ((.unit_index // []) | type == "array" and length == 0)
  and (.review_conclusion? | not)
  and (.business_flows? | not)
  and (.user_paths? | not)
' "$DIRECTOR_PHASE_JSON" >/dev/null || fail "director phase JSON template must stay a Director-owned skeleton"

assert_present '^## 交付计划承接$' "$MANAGER_BRIEF"
assert_present '^## 约束与风险承接$' "$MANAGER_BRIEF"
assert_present '^## PM 评审闭环$' "$MANAGER_BRIEF"
assert_present '^## 问题台账$' "$MANAGER_BRIEF"
assert_present '^## 交付确认$' "$MANAGER_BRIEF"
assert_absent 'MVP|最小闭环 UNIT|前置约束执行映射|scope_item_id|test_ref|SCOPE-P1U1|确认备注' "$MANAGER_BRIEF"
assert_present '^## 业务流程$' "$MANAGER_PHASE"
assert_present '^## 功能需求（UNIT 索引）$' "$MANAGER_PHASE"
assert_present '^## Integration Context（集成上下文）$' "$MANAGER_PHASE"
assert_present '^## Verification Plan（验证计划）$' "$MANAGER_PHASE"
assert_absent 'UX-0[0-9]|以上为起始项|按产品实际情况增删|分页规范|敏感信息.*脱敏|前端控制|后端控制|页面功能[[:space:]]*\\|[[:space:]]*各模块入口|表单校验[[:space:]]*\\|[[:space:]]*必填项校验|安全控制[[:space:]]*\\|[[:space:]]*敏感字段|端：前端 / 后端 / 全栈' "$MANAGER_PHASE"
assert_absent 'MVP/增强/扩展|MVP / 增强 / 扩展' "$MANAGER_PHASE"
assert_present '^## 最终结论$' "$MANAGER_REVIEW"
assert_present '^## 审查汇总$' "$MANAGER_REVIEW"
assert_present '^## 审查问题台账$' "$MANAGER_REVIEW"
assert_present '^## 收敛轮次摘要$' "$MANAGER_REVIEW"
assert_present '^## 用户裁决记录$' "$MANAGER_REVIEW"
assert_present '^## 未决阻断$' "$MANAGER_REVIEW"

assert_line_count_at_most 115 "$MANAGER_BRIEF"
assert_line_count_at_most 80 "$MANAGER_REVIEW"
assert_rule_like_count_at_most 6 "$MANAGER_BRIEF"
assert_rule_like_count_at_most 4 "$MANAGER_REVIEW"

assert_file "$EVIDENCE_PLAN"
assert_absent '为什么.*更强|已证明.*最佳实践|完全正确|共享 playbook|shared playbook' "$EVIDENCE_PLAN"

if [ -f "$DEEP_REPORT" ]; then
  assert_absent '为什么.*更强|已证明.*最佳实践|完全正确|共享 playbook|shared playbook' "$DEEP_REPORT"
  assert_present '证据边界|Known Limitations|Scorecard|scorecard' "$DEEP_REPORT"
fi

echo "[PASS] product template purity contract"
