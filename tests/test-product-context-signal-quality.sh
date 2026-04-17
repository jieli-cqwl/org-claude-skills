#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

failures=0

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

assert_present() {
  local pattern="$1"
  local file="$2"
  local scope="${3:-}"
  if ! rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "${scope:+$scope: }missing pattern in $file: $pattern"
  fi
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  local scope="${3:-}"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "${scope:+$scope: }unexpected pattern in $file: $pattern"
  fi
}

extract_section() {
  local file="$1"
  local heading="$2"
  awk -v heading="$heading" '
    $0 == heading { in_section=1; print; next }
    in_section && /^```/ { in_code = !in_code; print; next }
    in_section && !in_code && /^## / && $0 != heading { exit }
    in_section { print }
  ' "$file"
}

assert_section_present() {
  local file="$1"
  local heading="$2"
  local pattern="$3"
  local scope="$4"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/product-context-signal.XXXXXX")"
  extract_section "$file" "$heading" > "$tmp"
  assert_present "$pattern" "$tmp" "$scope"
  rm -f "$tmp"
}

assert_section_absent() {
  local file="$1"
  local heading="$2"
  local pattern="$3"
  local scope="$4"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/product-context-signal.XXXXXX")"
  extract_section "$file" "$heading" > "$tmp"
  assert_absent "$pattern" "$tmp" "$scope"
  rm -f "$tmp"
}

assert_any_present() {
  local file="$1"
  local scope="$2"
  shift 2
  local pattern
  local hit=1
  for pattern in "$@"; do
    if rg -n "$pattern" "$file" >/dev/null 2>&1; then
      hit=0
      break
    fi
  done
  if [ "$hit" -ne 0 ]; then
    fail "${scope:+$scope: }missing any of patterns in $file: $*"
  fi
}

assert_flow_graph_before_table() {
  local file="$1"
  local scope="$2"
  local tmp
  local graph_line
  local table_line

  tmp="$(mktemp "${TMPDIR:-/tmp}/product-context-flow.XXXXXX")"
  extract_section "$file" "## 流程" > "$tmp"
  graph_line=$(awk '/digraph product_flow/ { print NR; exit }' "$tmp")
  table_line=$(awk '/^\| 步骤 \| 名称 \| 交互模式 \| 关键要求 \|$/ { print NR; exit }' "$tmp")

  if [ -z "$graph_line" ] || [ -z "$table_line" ] || [ "$graph_line" -ge "$table_line" ]; then
    fail "${scope:+$scope: }digraph product_flow must appear before the step table"
  fi

  rm -f "$tmp"
}

assert_audit_round_count() {
  local file="$1"
  local expected="$2"
  local actual

  if [ ! -f "$file" ]; then
    fail "missing audit loop record: $file"
    return
  fi
  actual=$(rg -n '^\| R[0-9]{2} \|' "$file" | wc -l | tr -d ' ')
  if [ "$actual" -lt "$expected" ]; then
    fail "expected at least $expected audit rounds in $file, got $actual"
  fi
}

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DIRECTOR_THINKING="$ROOT/shared/skills/product-director/references/product-thinking-contract.md"
MANAGER_REVIEW="$ROOT/shared/skills/product-manager/references/review-orchestration-contract.md"
PRD_REVIEWER="$ROOT/shared/skills/product-manager/references/prd-reviewer-prompt.md"
ARCHITECT_REVIEWER="$ROOT/shared/skills/product-manager/references/architect-reviewer-prompt.md"
TESTER_REVIEWER="$ROOT/shared/skills/product-manager/references/tester-reviewer-prompt.md"
AUDIT_LOOP_RECORD="$ROOT/docs/product-context-signal-cleanup-20260416/context-signal-audit-10-rounds.md"
DESIGN_DOC="$ROOT/docs/product-context-signal-cleanup-20260416/design.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
DESIGN_TEMPLATE="$ROOT/shared/skills/design/references/templates/design-template.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"

test -f "$DIRECTOR_SKILL" || fail "missing director skill: $DIRECTOR_SKILL"
test -f "$MANAGER_SKILL" || fail "missing manager skill: $MANAGER_SKILL"
test -f "$DIRECTOR_THINKING" || fail "missing director thinking contract: $DIRECTOR_THINKING"
test -f "$MANAGER_REVIEW" || fail "missing manager review contract: $MANAGER_REVIEW"
test -f "$PRD_REVIEWER" || fail "missing PRD reviewer prompt: $PRD_REVIEWER"
test -f "$ARCHITECT_REVIEWER" || fail "missing architect reviewer prompt: $ARCHITECT_REVIEWER"
test -f "$TESTER_REVIEWER" || fail "missing tester reviewer prompt: $TESTER_REVIEWER"
test -f "$DESIGN_DOC" || fail "missing design doc: $DESIGN_DOC"
test -f "$DESIGN_SKILL" || fail "missing design skill: $DESIGN_SKILL"
test -f "$DESIGN_TEMPLATE" || fail "missing design template: $DESIGN_TEMPLATE"
test -f "$TECH_LEAD_SKILL" || fail "missing tech-lead skill: $TECH_LEAD_SKILL"

assert_section_absent "$DIRECTOR_SKILL" "## 能力契约" 'SKILL\.md 只保留|真源' "director capability contract noise"
assert_section_absent "$DIRECTOR_SKILL" "## 产出" 'SKILL\.md 只保留|真源' "director output contract noise"
assert_section_absent "$MANAGER_SKILL" "## 评审编排" 'SKILL\.md 只保留|真源' "manager review contract noise"
assert_section_absent "$MANAGER_SKILL" "## 产出" 'SKILL\.md 只保留|真源' "manager output contract noise"
assert_absent 'split playbook|第 [12] 段' "$DIRECTOR_SKILL" "director runtime narrative noise"
assert_absent 'split playbook|第 [12] 段' "$MANAGER_SKILL" "manager runtime narrative noise"
assert_absent '至少 10 轮|10 轮审计|审计结果进入任务证据|T7|T8' "$DESIGN_DOC" "design doc process noise"
assert_absent '上游问题|上游阻断|上游审查|上游 review|上游.*review|review.*上游' "$MANAGER_SKILL" "manager review owner boundary"
assert_present '当前 Manager 阶段的 handoff 校验、M-S8 评审、M-S9 交付确认任一阻断未关闭' "$MANAGER_SKILL" "manager review owner boundary"
assert_present 'M-S8 评审由 `/product-manager` 发起并收敛' "$MANAGER_SKILL" "manager review owner boundary"
assert_absent 'product-manager-review\.md（上游三方评审结果）|读取 `product-manager-review\.md`|review\.md（上游三方评审结果）|读取 `review\.md`|上游架构红旗|上游测试红旗|上游红旗承接|上游审查承接' "$DESIGN_SKILL" "design downstream review-detail boundary"
assert_present '只消费 canonical `brief\.json / phase-prd\.json / UNIT-\*\.json` 与明确写入 `待设计决策` 的承接项；不读取产品评审过程明细或 legacy 投影视图。' "$DESIGN_SKILL" "design downstream review-detail boundary"
assert_absent '^## 上游审查承接$|product-manager-review\.md 的 `审查结论`|review\.md 的 `审查结论`|无上游审查|^\| AR-001 \||^\| TR-001 \|' "$DESIGN_TEMPLATE" "design template downstream review-detail boundary"
assert_present '^## 产品交付承接$' "$DESIGN_TEMPLATE" "design template downstream review-detail boundary"
assert_absent 'product-manager-review\.md（上游三方评审结果）|review\.md（上游三方评审结果）|参考其三视角审查结论|避免重复审查' "$TECH_LEAD_SKILL" "tech-lead downstream review-detail boundary"
assert_present '只消费已冻结的 canonical 需求、设计、测试用例和待计划约束；不读取产品评审过程明细，也不依赖前序评审过程来缩减本阶段审查。' "$TECH_LEAD_SKILL" "tech-lead downstream review-detail boundary"

assert_absent '^## 适用范围$' "$DIRECTOR_THINKING" "director thinking contract"
assert_absent '本契约定义' "$DIRECTOR_THINKING" "director thinking contract"
assert_absent '^## 适用范围$' "$MANAGER_REVIEW" "manager review contract"
assert_absent '本契约定义' "$MANAGER_REVIEW" "manager review contract"
assert_present '^## product-manager-review\.md 产物契约$' "$MANAGER_REVIEW" "manager review artifact definition"
assert_present 'product-manager-review\.md 是 Manager 阶段的评审闭环证据文件' "$MANAGER_REVIEW" "manager review artifact definition"
assert_absent '^维护 `product-manager-review\.md` 时|^维护 `review\.md` 时' "$MANAGER_REVIEW" "manager review artifact definition"

assert_section_present "$DIRECTOR_SKILL" "## 流程" 'digraph product_flow|references/flow-contract\.md' "director flow contract"
assert_section_present "$MANAGER_SKILL" "## 流程" 'digraph product_flow|references/flow-contract\.md' "manager flow contract"
assert_flow_graph_before_table "$DIRECTOR_SKILL" "director flow contract"
assert_flow_graph_before_table "$MANAGER_SKILL" "manager flow contract"

assert_section_present "$DIRECTOR_SKILL" "## 流程" 'Context Scan Agent' "director D-S1 agents"
assert_section_present "$DIRECTOR_SKILL" "## 流程" 'Problem Hypothesis Agent' "director D-S1 agents"
assert_section_present "$DIRECTOR_SKILL" "## 流程" 'final 结论|final conclusion|Final Conclusion' "director D-S1 final-conclusion guard"

assert_section_present "$PRD_REVIEWER" '### 输出格式' '^## Findings$' "PRD reviewer prompt"
assert_section_present "$PRD_REVIEWER" '### 输出格式' '承接目标' "PRD reviewer prompt"
assert_section_present "$PRD_REVIEWER" '### 输出格式' '^## Verdict Rules$' "PRD reviewer prompt"
assert_absent '沿用标准' "$PRD_REVIEWER" "PRD reviewer prompt"

assert_section_present "$ARCHITECT_REVIEWER" '### 输出格式' '^## Findings$' "architect reviewer prompt"
assert_section_present "$ARCHITECT_REVIEWER" '### 输出格式' '承接目标' "architect reviewer prompt"
assert_section_present "$ARCHITECT_REVIEWER" '### 输出格式' '^## Verdict Rules$' "architect reviewer prompt"
assert_absent '沿用标准' "$ARCHITECT_REVIEWER" "architect reviewer prompt"

assert_section_present "$TESTER_REVIEWER" '### 输出格式' '^## Findings$' "tester reviewer prompt"
assert_section_present "$TESTER_REVIEWER" '### 输出格式' '承接目标' "tester reviewer prompt"
assert_section_present "$TESTER_REVIEWER" '### 输出格式' '^## Verdict Rules$' "tester reviewer prompt"
assert_absent '沿用标准' "$TESTER_REVIEWER" "tester reviewer prompt"

assert_present '召集 Agent Team' "$MANAGER_REVIEW" "review orchestration"
assert_present '3 视角×max10轮' "$MANAGER_REVIEW" "review orchestration"
assert_present 'CONFIRMATION' "$MANAGER_REVIEW" "review orchestration"
assert_present '只重提 FAIL 视角' "$MANAGER_REVIEW" "review orchestration"
assert_present 'WARN 项在 canonical `review_conclusion / issue_ledger` 中显式承接；legacy lane 同步到 `product-manager-review\.md` 时也必须显式承接。' "$MANAGER_REVIEW" "review orchestration"

assert_audit_round_count "$AUDIT_LOOP_RECORD" 10

if [ "$failures" -ne 0 ]; then
  printf '[FAIL] product context signal quality contract: %s failed check(s)\n' "$failures" >&2
  exit 1
fi

echo "[PASS] product context signal quality contract"
