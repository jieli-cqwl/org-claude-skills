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

assert_manager_review_owner_boundary() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
requirements = {
    "handoff_gate": ["handoff", "阻断"],
    "review_step": ["M-S8", "评审"],
    "delivery_confirmation": ["M-S9", "交付确认"],
}
missing = [name for name, terms in requirements.items() if not all(term in text for term in terms)]
if missing:
    raise SystemExit(f"{path}: missing manager review owner boundary: {', '.join(missing)}")
PY
}

assert_manager_warn_carryover_contract() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
requirements = {
    "warn": ["WARN"],
    "review_conclusion": ["review_conclusion"],
    "issue_ledger": ["issue_ledger"],
}
missing = [name for name, terms in requirements.items() if not all(term in text for term in terms)]
if missing:
    raise SystemExit(f"{path}: missing manager WARN carryover contract: {', '.join(missing)}")
PY
}

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DIRECTOR_PROBLEM_GUIDE="$ROOT/shared/skills/product-director/references/problem-clarification.md"
DIRECTOR_SUCCESS_GUIDE="$ROOT/shared/skills/product-director/references/success-investment-boundary.md"
DIRECTOR_BUSINESS_GUIDE="$ROOT/shared/skills/product-director/references/business-semantics.md"
DIRECTOR_SCOPE_GUIDE="$ROOT/shared/skills/product-director/references/scope-constraints.md"
DIRECTOR_RISKS_GUIDE="$ROOT/shared/skills/product-director/references/risks-unknowns.md"
DIRECTOR_PHASE_GUIDE="$ROOT/shared/skills/product-director/references/phase-planning.md"
DIRECTOR_FINAL_GUIDE="$ROOT/shared/skills/product-director/references/final-artifacts.md"
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
test -f "$DIRECTOR_PROBLEM_GUIDE" || fail "missing director problem guide: $DIRECTOR_PROBLEM_GUIDE"
test -f "$DIRECTOR_SUCCESS_GUIDE" || fail "missing director success/investment-boundary guide: $DIRECTOR_SUCCESS_GUIDE"
test -f "$DIRECTOR_BUSINESS_GUIDE" || fail "missing director business semantics guide: $DIRECTOR_BUSINESS_GUIDE"
test -f "$DIRECTOR_SCOPE_GUIDE" || fail "missing director scope/constraints guide: $DIRECTOR_SCOPE_GUIDE"
test -f "$DIRECTOR_RISKS_GUIDE" || fail "missing director risks/unknowns guide: $DIRECTOR_RISKS_GUIDE"
test -f "$DIRECTOR_PHASE_GUIDE" || fail "missing director phase guide: $DIRECTOR_PHASE_GUIDE"
test -f "$DIRECTOR_FINAL_GUIDE" || fail "missing director final-artifacts guide: $DIRECTOR_FINAL_GUIDE"
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
assert_absent '至少 10 轮|10 轮审计|审计结果进入任务证据|T7|T8' "$DESIGN_DOC" "design doc process noise"
assert_absent '上游问题|上游阻断|上游审查|上游 review|上游.*review|review.*上游' "$MANAGER_SKILL" "manager review owner boundary"
assert_manager_review_owner_boundary "$MANAGER_SKILL" "manager review owner boundary"
assert_present 'M-S8 评审由 `/product-manager` 发起并收敛' "$MANAGER_SKILL" "manager review owner boundary"
assert_section_present "$MANAGER_SKILL" "### M-S8 三方评审与 AI 可执行性复核" 'reviewed_bundle_digest' "manager review owner boundary"
assert_present '三视角 reviewer.*同一份.*reviewed_bundle_digest|reviewed_bundle_digest.*每个 reviewer verdict' "$MANAGER_REVIEW" "manager review digest boundary"
assert_present '只消费 `brief\.json / phase-prd\.json / UNIT-\*\.json` 与明确写入 `待设计决策` 的承接项；不读取产品评审过程明细或派生视图。' "$DESIGN_SKILL" "design downstream review-detail boundary"
assert_present '你消费已确认的产品、架构和测试输入，设计可交付实施路径' "$TECH_LEAD_SKILL" "tech-lead downstream review-detail boundary"

assert_absent '本契约定义' "$DIRECTOR_SUCCESS_GUIDE" "director success/appetite guide"
assert_absent '本契约定义' "$MANAGER_REVIEW" "manager review orchestration"
assert_present 'Manager 阶段评审闭环只写入 `brief\.json\.review_conclusion / issue_ledger`' "$MANAGER_REVIEW" "manager review artifact definition"

assert_absent '节点顺序：' "$DIRECTOR_SKILL" "director flow sequence noise"
assert_section_present "$DIRECTOR_SKILL" "## 流程" '"Explore demand context" -> "Ask one clarifying question"' "director flow sequence"
assert_section_present "$DIRECTOR_SKILL" "## 流程" '"User approves baseline\?" -> "Present baseline sections" \[label="revise"\]' "director flow sequence"
assert_section_present "$DIRECTOR_SKILL" "## 流程" 'Self-review and gates' "director flow diagram"
assert_section_present "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '风险与未知项' "director flow route"
assert_absent '节点顺序：' "$MANAGER_SKILL" "manager flow sequence noise"
assert_section_present "$MANAGER_SKILL" "## 流程" '"M-S5\.5 Verification Plan" -> "M-S6 结构化待设计决策"' "manager flow sequence"
assert_section_present "$MANAGER_SKILL" "## 流程" 'M-S5\.5 Verification Plan' "manager flow diagram"
assert_section_present "$MANAGER_SKILL" "## 流程细节" 'M-S5\.5 Verification Plan' "manager flow details"
assert_section_present "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '静默信息收集' "director flow route"
assert_section_present "$MANAGER_SKILL" "## 流程细节" 'M-S0 内容完整性检查' "manager flow details"
assert_absent 'digraph product_flow|references/flow-contract\.md' "$DIRECTOR_SKILL" "director flow narrative noise"
assert_absent 'digraph product_flow|references/flow-contract\.md' "$MANAGER_SKILL" "manager flow narrative noise"
assert_section_present "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '项目现状、已有文档、contracts、历史需求' "director silent-scan inputs"
assert_section_present "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '候选线索、来源和冲突点' "director silent-scan outputs"
assert_section_present "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '读取 `references/problem-clarification\.md`，剥离方案名、技术词、对标诉求和抽象评价' "director natural process"
assert_section_present "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '读取 `references/final-artifacts\.md`，只有明确收到 `产品总监确认`' "director finalization route"
assert_section_present "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '每个业务判断阶段只读取当前步骤 reference；每轮只推进一个最会改变 Director 基线的事实' "director focused co-creation"
assert_section_absent "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '\| Step \| Read \| Advance when \| Stop when \|' "director process table noise"
assert_section_absent "$DIRECTOR_SKILL" "## The Process（按步骤读取）" '下游理解' "director process downstream-audience noise"
assert_absent 'references/conversation-guide\.md' "$DIRECTOR_SKILL" "director removed conversation guide"
python3 - "$DIRECTOR_SKILL" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
for forbidden in [
    r"^## 触发边界$",
    r"^## Handoff Contract",
]:
    if re.search(forbidden, text, re.M):
        raise SystemExit(f"unexpected Director section: {forbidden}")
PY
assert_section_present "$DIRECTOR_SKILL" "## HARD-GATE" '在你向用户呈现 Director baseline 并收到明确 `产品总监确认` 之前，不要把它当成已确认基线。' "director confirmed-baseline guard"
assert_section_absent "$DIRECTOR_SKILL" "## HARD-GATE" '技术债|schema|hook|runtime|contract|product-director-ledger|brief\.json|phase-prd\.json' "director hard-gate stays light"
assert_section_absent "$DIRECTOR_SKILL" "## HARD-GATE" '下游不得直接修改' "director downstream-audience noise"
assert_section_absent "$DIRECTOR_SKILL" "## HARD-GATE" 'director_confirmation|locked_field_digest' "director runtime-lock noise"
assert_section_present "$DIRECTOR_SKILL" "## Role Boundary（角色边界）" '主动形成推荐判断并推进基线闭合；用户负责补充、确认或替换真实业务事实' "director co-creation owner boundary"
assert_section_present "$DIRECTOR_SKILL" "## Role Boundary（角色边界）" '确认前只形成候选判断' "director pending-baseline wording"
assert_section_absent "$DIRECTOR_SKILL" "## Role Boundary（角色边界）" '移交给设计、测试设计、技术负责人和交付角色' "director role-boundary downstream noise"
assert_section_absent "$DIRECTOR_SKILL" "## Role Boundary（角色边界）" '不得反向改写' "director downstream-audience noise"
assert_present 'schema、hook、runtime 或 contract 缺失属于环境阻塞' "$DIRECTOR_FINAL_GUIDE" "director finalization dependency guard"
assert_present '为什么当前 Phase 能直接支撑成功标准' "$DIRECTOR_PHASE_GUIDE" "director phase recommendation reason"
assert_present '问题澄清检查点必须包含事实状态表' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_present '对外每轮只呈现本轮依赖事实和一个待验证事实' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_absent '问题澄清输出必须包含事实状态表' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_present '\| 受影响角色 \|' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_present '\| 触发场景 \|' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_present '\| 当前处理方式 \|' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_present '\| 现实代价 \|' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_present '\| 直接原因 \|' "$DIRECTOR_PROBLEM_GUIDE" "director problem clarification fact table"
assert_present '对象边界' "$DIRECTOR_BUSINESS_GUIDE" "director business semantics boundary"
assert_present '影响范围或 Phase 的业务判定条件' "$DIRECTOR_BUSINESS_GUIDE" "director business semantics boundary"
assert_absent '触发业务动作' "$DIRECTOR_BUSINESS_GUIDE" "director business semantics boundary"
assert_absent '下游理解' "$DIRECTOR_BUSINESS_GUIDE" "director business semantics boundary"
assert_present '本期明确排除的边界。' "$DIRECTOR_SCOPE_GUIDE" "director scope boundary"
assert_present '记录备注.*不写入结果 payload' "$DIRECTOR_RISKS_GUIDE" "director risk result-payload boundary"
assert_absent '下游执行风险' "$DIRECTOR_RISKS_GUIDE" "director risk final-json boundary"
assert_absent 'digest|locked_field|director_confirmation' "$DIRECTOR_FINAL_GUIDE" "director runtime-lock finalization noise"
assert_present 'product-director-ledger\.json' "$DIRECTOR_FINAL_GUIDE" "director ledger artifact boundary"
assert_present '只按模板写结果 payload' "$DIRECTOR_FINAL_GUIDE" "director result-payload boundary"

assert_section_present "$PRD_REVIEWER" '### 输出格式' '^## 发现输出$' "PRD reviewer prompt"
assert_section_present "$PRD_REVIEWER" '### 输出格式' '承接目标' "PRD reviewer prompt"
assert_section_present "$PRD_REVIEWER" '### 输出格式' '^## 判定规则$' "PRD reviewer prompt"
assert_absent '沿用标准' "$PRD_REVIEWER" "PRD reviewer prompt"

assert_section_present "$ARCHITECT_REVIEWER" '### 输出格式' '^## 发现输出$' "architect reviewer prompt"
assert_section_present "$ARCHITECT_REVIEWER" '### 输出格式' '承接目标' "architect reviewer prompt"
assert_section_present "$ARCHITECT_REVIEWER" '### 输出格式' '^## 判定规则$' "architect reviewer prompt"
assert_absent '沿用标准' "$ARCHITECT_REVIEWER" "architect reviewer prompt"

assert_section_present "$TESTER_REVIEWER" '### 输出格式' '^## 发现输出$' "tester reviewer prompt"
assert_section_present "$TESTER_REVIEWER" '### 输出格式' '承接目标' "tester reviewer prompt"
assert_section_present "$TESTER_REVIEWER" '### 输出格式' '^## 判定规则$' "tester reviewer prompt"
assert_absent '沿用标准' "$TESTER_REVIEWER" "tester reviewer prompt"

assert_present '召集 agent teams' "$MANAGER_REVIEW" "review orchestration"
assert_present '3 视角×max10轮' "$MANAGER_REVIEW" "review orchestration"
assert_present 'CONFIRMATION' "$MANAGER_REVIEW" "review orchestration"
assert_present '只重提 FAIL 视角' "$MANAGER_REVIEW" "review orchestration"
assert_manager_warn_carryover_contract "$MANAGER_REVIEW" "review orchestration"

assert_audit_round_count "$AUDIT_LOOP_RECORD" 10

if [ "$failures" -ne 0 ]; then
  printf '[FAIL] product context signal quality contract: %s failed check(s)\n' "$failures" >&2
  exit 1
fi

echo "[PASS] product context signal quality contract"
