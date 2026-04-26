#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_THINKING_CONTRACT="$ROOT/shared/skills/product-director/references/product-thinking-contract.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
MANAGER_REVIEW_CONTRACT="$ROOT/shared/skills/product-manager/references/review-orchestration-contract.md"
MANAGER_REVIEW_TEMPLATE="$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md"

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
test -f "$DIRECTOR_THINKING_CONTRACT" || fail "missing director thinking contract: $DIRECTOR_THINKING_CONTRACT"
test -f "$MANAGER_SKILL" || fail "missing manager skill: $MANAGER_SKILL"
test -f "$MANAGER_REVIEW_CONTRACT" || fail "missing manager review contract: $MANAGER_REVIEW_CONTRACT"
test -f "$MANAGER_REVIEW_TEMPLATE" || fail "missing manager review template: $MANAGER_REVIEW_TEMPLATE"

# Validated product capabilities must survive the split through explicit
# contracts, not runtime references to retired skills.
assert_present 'references/product-thinking-contract\.md' "$DIRECTOR_SKILL"
assert_present 'Product-Thinking Contract v1' "$DIRECTOR_SKILL"
assert_absent '旧 `/product`|旧 /product|retired product|已删除.*product|已验证实践' "$DIRECTOR_SKILL"

assert_present '^# Product-Thinking Contract v1$' "$DIRECTOR_THINKING_CONTRACT"
assert_present '价值假设验证' "$DIRECTOR_THINKING_CONTRACT"
assert_present '当前基线' "$DIRECTOR_THINKING_CONTRACT"
assert_present '目标值或方向' "$DIRECTOR_THINKING_CONTRACT"
assert_present '观测窗口' "$DIRECTOR_THINKING_CONTRACT"
assert_present '数据来源' "$DIRECTOR_THINKING_CONTRACT"
assert_present 'MVP 范围界定' "$DIRECTOR_THINKING_CONTRACT"
assert_present '^## 警示信号$' "$DIRECTOR_THINKING_CONTRACT"
assert_present '用户已经给了方案，我直接整理成需求' "$DIRECTOR_THINKING_CONTRACT"
assert_present '先全部标 MVP' "$DIRECTOR_THINKING_CONTRACT"

assert_present 'references/review-orchestration-contract\.md' "$MANAGER_SKILL"
assert_present 'Review-Orchestration Contract v1' "$MANAGER_SKILL"
assert_absent '旧 `/product`|旧 /product|retired product|已删除.*product|已验证实践' "$MANAGER_SKILL"

assert_present 'Agent 工具' "$MANAGER_REVIEW_CONTRACT"
assert_present '^allowed-tools: .*Agent' "$MANAGER_SKILL"
assert_absent 'TeamCreate' "$MANAGER_SKILL"
assert_absent 'TeamCreate' "$MANAGER_REVIEW_CONTRACT"
assert_present '3[[:space:]]*视角[×x]max10轮|循环上限 10 次|max10轮' "$MANAGER_REVIEW_CONTRACT"
assert_present '首轮全 PASS.*CONFIRMATION|首轮全 PASS.*确认轮' "$MANAGER_REVIEW_CONTRACT"
assert_present '连续 2 轮 FAIL 数不减少' "$MANAGER_REVIEW_CONTRACT"
assert_present '同一 issue 连续 3 轮未关闭' "$MANAGER_REVIEW_CONTRACT"
assert_present '仅对 FAIL 视角重新提交评审|只重提 FAIL 视角' "$MANAGER_REVIEW_CONTRACT"
assert_present 'Issue Count' "$MANAGER_REVIEW_CONTRACT"
assert_present 'HIS-\*' "$MANAGER_REVIEW_CONTRACT"
assert_present '用于确认 PRD 是否完整回答用户问题' "$MANAGER_REVIEW_CONTRACT"
assert_present '用于确认需求在当前技术上下文中可落地' "$MANAGER_REVIEW_CONTRACT"
assert_present '用于确认 AC 能被真实验证' "$MANAGER_REVIEW_CONTRACT"
assert_present '^## 人类投影视图收口规则$' "$MANAGER_REVIEW_CONTRACT"
assert_present '人类投影视图只能渲染这些字段，不能作为下游控制输入' "$MANAGER_REVIEW_CONTRACT"
assert_present '需要渲染人类投影视图时使用以下收口规则，不要依赖 gate 去猜' "$MANAGER_REVIEW_CONTRACT"
assert_present '审查问题台账.*不能留空' "$MANAGER_REVIEW_CONTRACT"
assert_present '即使首轮全 PASS，也至少保留 1 条 `HIS-\*`' "$MANAGER_REVIEW_CONTRACT"
assert_present 'Review Round.*只写 issue 首次出现轮次' "$MANAGER_REVIEW_CONTRACT"
assert_present 'FAIL数.*不把 WARN 混进去' "$MANAGER_REVIEW_CONTRACT"
assert_present '用户裁决记录.*只在 `ASK_USER` 或 `BLOCKED` 时填写' "$MANAGER_REVIEW_CONTRACT"

assert_present '^## 审查汇总$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^\| 视角 \| Verdict \| Review Round \| Issue Count \| 结论摘要 \|$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 审查问题台账$' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'PR-\* / AR-\* / TR-\* / HIS-\*' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'Review Round' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 收敛轮次摘要$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '未关闭 Issue IDs' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 用户裁决记录$' "$MANAGER_REVIEW_TEMPLATE"

# Inheritance must not reintroduce the removed runtime skill or shared directory.
assert_absent 'product-shared' "$DIRECTOR_SKILL"
assert_absent 'product-shared' "$MANAGER_SKILL"
assert_absent '/product ' "$DIRECTOR_SKILL"
assert_absent '/product ' "$MANAGER_SKILL"

echo "[PASS] product inherited capability parity"
