#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_PROBLEM_GUIDE="$ROOT/shared/skills/product-director/references/problem-clarification.md"
DIRECTOR_SUCCESS_GUIDE="$ROOT/shared/skills/product-director/references/success-investment-boundary.md"
DIRECTOR_SCOPE_GUIDE="$ROOT/shared/skills/product-director/references/scope-constraints.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
MANAGER_REVIEW_ORCHESTRATION="$ROOT/shared/skills/product-manager/references/review-orchestration.md"
MANAGER_REVIEW_TEMPLATE="$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md"
MANAGER_EVALS="$ROOT/shared/skills/product-manager/evals/evals.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

test -f "$DIRECTOR_SKILL" || fail "missing director skill: $DIRECTOR_SKILL"
test -f "$DIRECTOR_PROBLEM_GUIDE" || fail "missing director problem guide: $DIRECTOR_PROBLEM_GUIDE"
test -f "$DIRECTOR_SUCCESS_GUIDE" || fail "missing director success/investment-boundary guide: $DIRECTOR_SUCCESS_GUIDE"
test -f "$DIRECTOR_SCOPE_GUIDE" || fail "missing director scope/constraints guide: $DIRECTOR_SCOPE_GUIDE"
test -f "$MANAGER_SKILL" || fail "missing manager skill: $MANAGER_SKILL"
test -f "$MANAGER_REVIEW_ORCHESTRATION" || fail "missing manager review orchestration: $MANAGER_REVIEW_ORCHESTRATION"
test -f "$MANAGER_REVIEW_TEMPLATE" || fail "missing manager review template: $MANAGER_REVIEW_TEMPLATE"

# Validated product capabilities must survive the split through explicit
# contracts, not runtime references to retired skills.
assert_present 'references/success-investment-boundary\.md' "$DIRECTOR_SKILL"
assert_present 'references/scope-constraints\.md' "$DIRECTOR_SKILL"
assert_absent 'references/conversation-guide\.md' "$DIRECTOR_SKILL"
assert_absent 'references/product-thinking-contract\.md' "$DIRECTOR_SKILL"
assert_absent '旧 `/product`|旧 /product|retired product|已删除.*product|已验证实践' "$DIRECTOR_SKILL"

assert_present 'references/review-orchestration\.md' "$MANAGER_SKILL"
assert_absent 'references/review-orchestration\.md#|references/[^`[:space:]]+-contract\.md|Contract v1' "$MANAGER_SKILL"
assert_absent '旧 `/product`|旧 /product|retired product|已删除.*product|已验证实践' "$MANAGER_SKILL"

assert_present '召集 agent teams' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '^allowed-tools: .*TeamCreate' "$MANAGER_SKILL"
assert_present '^allowed-tools: .*SendMessage' "$MANAGER_SKILL"
assert_present '^allowed-tools: .*TeamDelete' "$MANAGER_SKILL"
assert_present '"id": "canonical-review-required"' "$MANAGER_EVALS"
assert_present 'PM owner 自检通过后' "$MANAGER_EVALS"
assert_present 'reviewed_bundle_digest' "$MANAGER_SKILL"
assert_present '3[[:space:]]*视角[×x]max10轮|循环上限 10 次|max10轮' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present 'control_action=CONFIRMATION' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '连续 2 轮 FAIL 数不减少' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '同一 issue 连续 3 轮未关闭' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '仅对 FAIL 视角重新提交评审|只重提 FAIL 视角' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '用于确认 PRD 是否完整回答用户问题' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '用于确认需求在当前技术上下文中可落地' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '用于确认 AC 能被真实验证' "$MANAGER_REVIEW_ORCHESTRATION"
assert_present '人类投影视图只能渲染这些字段，不能作为下游控制输入' "$MANAGER_REVIEW_ORCHESTRATION"

assert_present '^\| 视角 \| Verdict \| Review Round \| Issue Count \| 结论摘要 \|$' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'PR-\* / AR-\* / TR-\* / HIS-\*' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'Review Round' "$MANAGER_REVIEW_TEMPLATE"
assert_present '未关闭 Issue IDs' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'Issue Count.*PR-\* / AR-\* / TR-\*' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'HIS-\*' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'Review Round.*首次出现轮次' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'FAIL数.*不统计 WARN' "$MANAGER_REVIEW_TEMPLATE"
assert_present '阻断事实记录.*ASK_USER.*BLOCKED' "$MANAGER_REVIEW_TEMPLATE"

# Inheritance must not reintroduce the removed runtime skill or shared directory.
assert_absent 'product-shared' "$DIRECTOR_SKILL"
assert_absent 'product-shared' "$MANAGER_SKILL"
assert_absent '/product ' "$DIRECTOR_SKILL"
assert_absent '/product ' "$MANAGER_SKILL"

echo "[PASS] product inherited capability parity"
