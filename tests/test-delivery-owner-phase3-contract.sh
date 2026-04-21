#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

MATRIX="$ROOT/shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh"
PM_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
PHASE3_DOC="$ROOT/shared/skills/delivery-owner/references/phase3-dispatch.md"
DISPATCH_GUIDE="$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
SCRIPT_MANIFEST="$ROOT/shared/skills/delivery-owner/scripts/manifest.json"
CR_TEMPLATE="$ROOT/shared/skills/delivery-owner/references/templates/code-review-report-template.md"
QA_TEMPLATE="$ROOT/shared/skills/qa/references/templates/qa-report-template.md"
PLAN_TEMPLATE="$ROOT/shared/skills/tech-lead/references/templates/plan-template.md"
ACCEPTANCE_TEMPLATE="$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
WAIVERS_TEMPLATE="$ROOT/shared/skills/delivery-owner/references/templates/waivers-template.md"
KICKOFF_CHECKLIST="$ROOT/shared/skills/delivery-owner/references/kickoff-checklist.md"
CHECK_SCRIPT="$ROOT/shared/skills/delivery-owner/scripts/completion_check.sh"
TECH_LEAD_CHECK="$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
QA_CHECK="$ROOT/shared/skills/qa/scripts/completion_check.sh"
ROLLOUT_GATE_TEST="$ROOT/tests/test-delivery-owner-rollout-gate.sh"
REPLAY_GATE_TEST="$ROOT/tests/test-delivery-owner-replay-contract.sh"
TASK_GRADER="$ROOT/tools/eval/graders/task-constraint-grader.md"
LEGACY_ROLE_DOC="$ROOT/docs/delivery-owner-role-20260411"
ARCHIVED_ROLE_DOC="$ROOT/docs/archive/delivery-owner-role-20260411"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_lines() {
  local expected="$1"
  shift
  local got
  got="$(printf '%s\n' "$@")"
  [ "$got" = "$expected" ] || fail "unexpected lines: expected [$expected], got [$got]"
}

assert_present() {
  local needle="$1"
  local file="$2"
  local label="$3"
  grep -Fq "$needle" "$file" || fail "$label missing [$needle]"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    fail "$label must not contain [$needle]"
  fi
}

assert_reference_contract() {
  local doc="$1"
  local label="$2"
  local field
  for field in Trigger: Read: Expect: Consume: Evidence: Sync:; do
    assert_present "$field" "$doc" "$label"
  done
}

# shellcheck source=/dev/null
source "$MATRIX"

assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(phase3_required_review_stages)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(phase3_required_review_stages 轻量)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(phase3_required_review_stages 标准)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(phase3_required_review_stages 完整)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(phase3_required_qa_stages)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(phase3_required_qa_stages 轻量)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(phase3_required_qa_stages 标准)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(phase3_required_qa_stages 完整)"

for stage in REVIEW_A REVIEW_B REVIEW_C QA_A QA_B QA_C QA_D; do
  phase3_is_gate_stage "$stage" || fail "$stage should be a fixed full gate stage"
  phase3_is_non_waivable_stage "$stage" || fail "$stage should be non-waivable in fixed full gate"
done

if declare -F phase3_escalation_review_stages >/dev/null; then
  assert_lines "" "$(phase3_escalation_review_stages INTERFACE_BREAK)"
fi
if declare -F phase3_escalation_qa_stages >/dev/null; then
  assert_lines "" "$(phase3_escalation_qa_stages INTERFACE_BREAK)"
fi

assert_present 'Delivery Owner 负责计划执行与全链路交付验收' "$PM_SKILL" "delivery-owner skill"
assert_present 'Runtime Authority' "$PM_SKILL" "delivery-owner skill"
assert_present 'references/dispatch-guide.md' "$PM_SKILL" "delivery-owner skill"
assert_present 'references/phase3-dispatch.md' "$PM_SKILL" "delivery-owner skill"
assert_present 'REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D' "$PM_SKILL" "delivery-owner skill"
assert_present 'code-review-result.json' "$PM_SKILL" "delivery-owner skill"
assert_present 'qa-result.json' "$PM_SKILL" "delivery-owner skill"
assert_present 'fresh proving command' "$PM_SKILL" "delivery-owner skill"
assert_present '不得用 Mock 验收替代' "$PM_SKILL" "delivery-owner skill"
assert_absent '动态质量升档' "$PM_SKILL" "delivery-owner skill"
assert_absent '动态升档' "$PM_SKILL" "delivery-owner skill"
assert_absent 'Phase 3 审查分级' "$PM_SKILL" "delivery-owner skill"
assert_absent 'plan grade matrix' "$PM_SKILL" "delivery-owner skill"
assert_absent '轻量：`REVIEW_A + REVIEW_B + REVIEW_C + QA_A`' "$PM_SKILL" "delivery-owner skill"
assert_absent '标准：`REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_C`' "$PM_SKILL" "delivery-owner skill"
if grep -E '^allowed-tools:.*(^|, )Edit(,|$)' "$PM_SKILL"; then
  fail "delivery-owner frontmatter must not allow Edit"
fi

assert_reference_contract "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## 派发合同' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Evidence In' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Evidence Out' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Control Decision' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Replan Boundary' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Parallel Boundary' "$DISPATCH_GUIDE" "dispatch guide"
assert_present 'Requirement' "$DISPATCH_GUIDE" "dispatch guide"
assert_present 'Goal' "$DISPATCH_GUIDE" "dispatch guide"
assert_present 'Acceptance Criteria' "$DISPATCH_GUIDE" "dispatch guide"
assert_present 'Scope' "$DISPATCH_GUIDE" "dispatch guide"
assert_absent 'Agent(subagent_type:' "$DISPATCH_GUIDE" "dispatch guide"
assert_absent 'Developer 执行：test-first 实现' "$DISPATCH_GUIDE" "dispatch guide"
assert_absent 'Verifier 执行' "$DISPATCH_GUIDE" "dispatch guide"
assert_absent 'Fixer 执行' "$DISPATCH_GUIDE" "dispatch guide"
assert_absent 'runtime_snapshot / active_blocker' "$DISPATCH_GUIDE" "dispatch guide"
assert_absent 'qa-report.md' "$DISPATCH_GUIDE" "dispatch guide"

assert_reference_contract "$PHASE3_DOC" "phase3 dispatch"
assert_present '## 固定完整门禁' "$PHASE3_DOC" "phase3 dispatch"
assert_present '| Code Review | `REVIEW_A + REVIEW_B + REVIEW_C` | `code-review-result.json` |' "$PHASE3_DOC" "phase3 dispatch"
assert_present '| QA | `QA_A + QA_B + QA_C + QA_D` | `qa-result.json` |' "$PHASE3_DOC" "phase3 dispatch"
assert_present '## Handoff Boundary' "$PHASE3_DOC" "phase3 dispatch"
assert_present '## 修复循环与熔断' "$PHASE3_DOC" "phase3 dispatch"
assert_present '## 风险接受边界' "$PHASE3_DOC" "phase3 dispatch"
assert_present '## 汇总代理边界' "$PHASE3_DOC" "phase3 dispatch"
assert_present 'review / qa / fix' "$PHASE3_DOC" "phase3 dispatch"
assert_present 'residual_risk / waiver' "$PHASE3_DOC" "phase3 dispatch"
assert_absent '## 动态升档规则' "$PHASE3_DOC" "phase3 dispatch"
assert_absent '按分级裁剪执行' "$PHASE3_DOC" "phase3 dispatch"
assert_absent '| 轻量 |' "$PHASE3_DOC" "phase3 dispatch"
assert_absent '| 标准 |' "$PHASE3_DOC" "phase3 dispatch"
assert_absent '| 完整 |' "$PHASE3_DOC" "phase3 dispatch"

assert_present '强门禁固定跟踪 `REVIEW_A / REVIEW_B / REVIEW_C`' "$CR_TEMPLATE" "code-review template"
assert_present '"review":{"REVIEW_A"' "$CR_TEMPLATE" "code-review template"
assert_present '"REVIEW_B"' "$CR_TEMPLATE" "code-review template"
assert_present '"REVIEW_C"' "$CR_TEMPLATE" "code-review template"
assert_absent '审查分级' "$CR_TEMPLATE" "code-review template"
assert_absent '"grade"' "$CR_TEMPLATE" "code-review template"

assert_present '强门禁固定跟踪 `QA_A / QA_B / QA_C / QA_D`' "$QA_TEMPLATE" "qa template"
assert_present '### QA_A UNIT 执行汇总' "$QA_TEMPLATE" "qa template"
assert_present '## 验证-B: E2E 用户旅程' "$QA_TEMPLATE" "qa template"
assert_present '## 验证-C: 回归验证' "$QA_TEMPLATE" "qa template"
assert_present '## 验证-D: 探索性测试' "$QA_TEMPLATE" "qa template"
assert_present '"qa":{"QA_A"' "$QA_TEMPLATE" "qa template"
assert_present '"QA_B"' "$QA_TEMPLATE" "qa template"
assert_present '"QA_C"' "$QA_TEMPLATE" "qa template"
assert_present '"QA_D"' "$QA_TEMPLATE" "qa template"
assert_absent '审查分级' "$QA_TEMPLATE" "qa template"
assert_absent '"grade"' "$QA_TEMPLATE" "qa template"
assert_absent '轻量/标准模式不执行' "$QA_TEMPLATE" "qa template"

for stage in REVIEW_A REVIEW_B REVIEW_C QA_A QA_B QA_C QA_D; do
  assert_present "$stage" "$WAIVERS_TEMPLATE" "waivers template"
done
assert_present '固定完整门禁阶段不得整体豁免' "$WAIVERS_TEMPLATE" "waivers template"
assert_present 'residual_risk:edge-case-copy' "$WAIVERS_TEMPLATE" "waivers template"
assert_absent '| PMW-001 | QA_D |' "$WAIVERS_TEMPLATE" "waivers template"

assert_present 'current_tasks_version_ref:' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_present 'current_tasks_version_value:' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_present 'compensation_control' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_present 'user_confirmation_ref' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_B (E2E 旅程) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_C (回归验证) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_D (探索性测试) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"

assert_present 'compensation_control' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'expires_at' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'user_confirmation_ref' "$KICKOFF_CHECKLIST" "kickoff checklist"

assert_absent '## Phase 3 审查分级' "$PLAN_TEMPLATE" "plan template"
assert_absent '审查分级:' "$PLAN_TEMPLATE" "plan template"
assert_absent '轻量:' "$PLAN_TEMPLATE" "plan template"
assert_absent '标准:' "$PLAN_TEMPLATE" "plan template"
assert_absent '完整:' "$PLAN_TEMPLATE" "plan template"
assert_present 'REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D' "$PLAN_TEMPLATE" "plan template"

assert_present '"path": "scripts/phase3-grade-matrix.sh"' "$SCRIPT_MANIFEST" "script manifest"
assert_present 'fixed full gate' "$SCRIPT_MANIFEST" "script manifest"
assert_absent 'unsupported grade' "$SCRIPT_MANIFEST" "script manifest"
assert_absent 'grade matrix' "$SCRIPT_MANIFEST" "script manifest"

assert_present 'phase3_required_review_stages' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_present 'phase3_required_qa_stages' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_absent 'plan_grade' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_absent 'Phase 3 审查分级' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_absent '审查分级' "$TECH_LEAD_CHECK" "tech-lead completion check"
assert_absent 'parse_plan_grade' "$QA_CHECK" "qa completion check"
assert_absent '缺少有效的审查分级' "$QA_CHECK" "qa completion check"

assert_present 'full-gate evidence chain' "$TASK_GRADER" "task constraint grader"
assert_absent '审查分级匹配' "$TASK_GRADER" "task constraint grader"
assert_absent '动态升档' "$ROLLOUT_GATE_TEST" "rollout gate test"
assert_absent 'quality escalation after risk increase' "$REPLAY_GATE_TEST" "replay contract test"

[ ! -d "$LEGACY_ROLE_DOC" ] || fail "stale delivery-owner role docs should be archived"
[ -d "$ARCHIVED_ROLE_DOC" ] || fail "archived delivery-owner role docs missing"

echo "[PASS] delivery-owner phase3 contract"
