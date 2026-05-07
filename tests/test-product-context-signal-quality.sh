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
DIRECTOR_SUCCESS_GUIDE="$ROOT/shared/skills/product-director/references/success-appetite.md"
MANAGER_REVIEW="$ROOT/shared/skills/product-manager/references/review-orchestration.md"
PRD_REVIEWER="$ROOT/shared/skills/product-manager/references/prd-reviewer-prompt.md"
ARCHITECT_REVIEWER="$ROOT/shared/skills/product-manager/references/architect-reviewer-prompt.md"
TESTER_REVIEWER="$ROOT/shared/skills/product-manager/references/tester-reviewer-prompt.md"
AUDIT_LOOP_RECORD="$ROOT/tests/fixtures/product-context-signal-cleanup-20260416/context-signal-audit-10-rounds.md"
DESIGN_DOC="$ROOT/tests/fixtures/product-context-signal-cleanup-20260416/design.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
DESIGN_TEMPLATE="$ROOT/shared/skills/design/projections/design-template.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"

test -f "$DIRECTOR_SKILL" || fail "missing director skill: $DIRECTOR_SKILL"
test -f "$MANAGER_SKILL" || fail "missing manager skill: $MANAGER_SKILL"
test -f "$DIRECTOR_SUCCESS_GUIDE" || fail "missing director success/appetite guide: $DIRECTOR_SUCCESS_GUIDE"
test -f "$MANAGER_REVIEW" || fail "missing manager review orchestration: $MANAGER_REVIEW"
test -f "$PRD_REVIEWER" || fail "missing PRD reviewer prompt: $PRD_REVIEWER"
test -f "$ARCHITECT_REVIEWER" || fail "missing architect reviewer prompt: $ARCHITECT_REVIEWER"
test -f "$TESTER_REVIEWER" || fail "missing tester reviewer prompt: $TESTER_REVIEWER"
test -f "$DESIGN_DOC" || fail "missing design doc: $DESIGN_DOC"
test -f "$DESIGN_SKILL" || fail "missing design skill: $DESIGN_SKILL"
test -f "$DESIGN_TEMPLATE" || fail "missing design template: $DESIGN_TEMPLATE"
test -f "$TECH_LEAD_SKILL" || fail "missing tech-lead skill: $TECH_LEAD_SKILL"

assert_section_absent "$DIRECTOR_SKILL" "## 能力契约" 'SKILL\.md 只保留|真源' "director capability contract noise"
assert_section_absent "$DIRECTOR_SKILL" "## 输出" 'SKILL\.md 只保留|真源' "director output noise"
assert_section_absent "$MANAGER_SKILL" "## 评审编排" 'SKILL\.md 只保留|真源' "manager review noise"
assert_section_absent "$MANAGER_SKILL" "## 输出" 'SKILL\.md 只保留|真源' "manager output noise"
assert_absent 'split playbook|第 [12] 段|standard-chain|canonical|资源路由：Trigger:|引用契约：Trigger:|按需读取|需要时|若需要|落盘|当前 eval|当前验证命令|等价证据引用|可委派|尽量' "$DIRECTOR_SKILL" "director runtime narrative noise"
assert_absent 'split playbook|第 [12] 段|standard-chain|canonical|资源路由：Trigger:|引用契约：Trigger:|按需读取|需要时|若需要|落盘|当前 eval|当前验证命令|等价证据引用|可委派|尽量' "$MANAGER_SKILL" "manager runtime narrative noise"
assert_absent '至少 10 轮|10 轮审计|审计结果进入任务证据|T7|T8' "$DESIGN_DOC" "design doc process noise"
assert_absent '上游问题|上游阻断|上游审查|上游 review|上游.*review|review.*上游' "$MANAGER_SKILL" "manager review owner boundary"
assert_present '当前 Manager 阶段的 handoff 校验、M-S8 评审、M-S9 交付确认任一阻断未关闭' "$MANAGER_SKILL" "manager review owner boundary"
assert_present 'M-S8 评审由 `/product-manager` 发起并收敛' "$MANAGER_SKILL" "manager review owner boundary"
assert_absent 'product-manager-review\.md（上游三方评审结果）|读取 `product-manager-review\.md`|review\.md（上游三方评审结果）|读取 `review\.md`|上游架构红旗|上游测试红旗|上游红旗承接|上游审查承接' "$DESIGN_SKILL" "design downstream review-detail boundary"
assert_present '只消费 `brief\.json / phase-prd\.json / UNIT-\*\.json` 与明确写入 `待设计决策` 的承接项；不读取产品评审过程明细或派生视图。' "$DESIGN_SKILL" "design downstream review-detail boundary"
assert_absent '^## 上游审查承接$|product-manager-review\.md 的 `审查结论`|review\.md 的 `审查结论`|无上游审查|^\| AR-001 \||^\| TR-001 \|' "$DESIGN_TEMPLATE" "design template downstream review-detail boundary"
assert_present '^## 产品交付承接$' "$DESIGN_TEMPLATE" "design template downstream review-detail boundary"
assert_absent 'product-manager-review\.md（上游三方评审结果）|review\.md（上游三方评审结果）|参考其三视角审查结论|避免重复审查' "$TECH_LEAD_SKILL" "tech-lead downstream review-detail boundary"
assert_present '只消费已冻结的需求、设计、测试用例和待计划约束；不读取产品评审过程明细，也不依赖前序评审过程来缩减本阶段审查。' "$TECH_LEAD_SKILL" "tech-lead downstream review-detail boundary"

assert_absent '^## 适用范围$' "$DIRECTOR_SUCCESS_GUIDE" "director success/appetite guide"
assert_absent '本契约定义' "$DIRECTOR_SUCCESS_GUIDE" "director success/appetite guide"
assert_absent '^## 适用范围$' "$MANAGER_REVIEW" "manager review orchestration"
assert_absent '本契约定义' "$MANAGER_REVIEW" "manager review orchestration"
assert_present '^## Canonical Review Fields$' "$MANAGER_REVIEW" "manager review artifact definition"
assert_present 'Manager 阶段评审闭环只写入 `brief\.json\.review_conclusion / issue_ledger`' "$MANAGER_REVIEW" "manager review artifact definition"
assert_absent 'product-manager-review\.md|^维护 `review\.md` 时' "$MANAGER_REVIEW" "manager review artifact definition"

assert_absent '^## 流程总览$' "$DIRECTOR_SKILL" "director flow overview merged"
assert_absent '节点顺序：' "$DIRECTOR_SKILL" "director flow sequence noise"
assert_section_present "$DIRECTOR_SKILL" "## 流程图" '"D-S5\.5 风险与未知项" -> "Pause D-S5\.5 关键风险未闭合" -> "D-S6 Phase 规划"' "director flow sequence"
assert_section_present "$DIRECTOR_SKILL" "## 流程图" 'D-S5\.5 风险与未知项' "director flow diagram"
assert_section_present "$DIRECTOR_SKILL" "## 流程细节" 'D-S5\.5 风险与未知项' "director flow details"
assert_absent '^## 流程总览$' "$MANAGER_SKILL" "manager flow overview merged"
assert_absent '节点顺序：' "$MANAGER_SKILL" "manager flow sequence noise"
assert_section_present "$MANAGER_SKILL" "## 流程图" '"M-S5\.5 Verification Plan" -> "M-S6 结构化待设计决策"' "manager flow sequence"
assert_section_present "$MANAGER_SKILL" "## 流程图" 'M-S5\.5 Verification Plan' "manager flow diagram"
assert_section_present "$MANAGER_SKILL" "## 流程细节" 'M-S5\.5 Verification Plan' "manager flow details"
assert_absent 'digraph product_flow|references/flow-contract\.md' "$DIRECTOR_SKILL" "director flow narrative noise"
assert_absent 'digraph product_flow|references/flow-contract\.md' "$MANAGER_SKILL" "manager flow narrative noise"
assert_section_present "$DIRECTOR_SKILL" "## 流程细节" '使用 sub Agent 扫描项目现状' "director D-S1 agents"
assert_section_present "$DIRECTOR_SKILL" "## 流程细节" '候选根问题与候选关键假设' "director D-S1 agents"
assert_section_present "$DIRECTOR_SKILL" "## 流程细节" 'final 结论|final conclusion|Final Conclusion' "director D-S1 final-conclusion guard"

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

assert_present '召集 TeamCreate 协作团队' "$MANAGER_REVIEW" "review orchestration"
assert_present '3 视角×max10轮' "$MANAGER_REVIEW" "review orchestration"
assert_present 'CONFIRMATION' "$MANAGER_REVIEW" "review orchestration"
assert_present '只重提 FAIL 视角' "$MANAGER_REVIEW" "review orchestration"
assert_present 'WARN 项在 `review_conclusion / issue_ledger` 中显式承接。' "$MANAGER_REVIEW" "review orchestration"

assert_audit_round_count "$AUDIT_LOOP_RECORD" 10

if [ "$failures" -ne 0 ]; then
  printf '[FAIL] product context signal quality contract: %s failed check(s)\n' "$failures" >&2
  exit 1
fi

echo "[PASS] product context signal quality contract"
