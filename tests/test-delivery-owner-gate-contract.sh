#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

GATE_STAGES="$ROOT/shared/skills/delivery-owner/scripts/delivery-gate-stages.sh"
PM_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
PM_EVALS="$ROOT/shared/skills/delivery-owner/evals/evals.json"
DELIVERY_GATE_DOC="$ROOT/shared/skills/delivery-owner/references/delivery-gate-dispatch.md"
SIGNOFF_CONTRACT="$ROOT/shared/skills/delivery-owner/references/signoff-contract.md"
DISPATCH_GUIDE="$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
RUNTIME_ADAPTER="$ROOT/shared/skills/delivery-owner/references/runtime-adapter-contract.md"
SCRIPT_MANIFEST="$ROOT/shared/skills/delivery-owner/scripts/manifest.json"
CR_TEMPLATE="$ROOT/shared/skills/delivery-owner/references/templates/code-review-report-template.md"
DEV_TEMPLATE="$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
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
OLD_PHASE_LABEL="Phase ""3"
OLD_REVIEW_ESCALATION="delivery_gate_escalation_review_stages"
OLD_QA_ESCALATION="delivery_gate_escalation_qa_stages"

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
source "$GATE_STAGES"

assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages 轻量)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages 标准)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages 完整)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages 轻量)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages 标准)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages 完整)"

for stage in REVIEW_A REVIEW_B REVIEW_C QA_A QA_B QA_C QA_D; do
  delivery_gate_is_gate_stage "$stage" || fail "$stage should be a fixed full gate stage"
  delivery_gate_is_non_waivable_stage "$stage" || fail "$stage should be non-waivable in fixed full gate"
done

if declare -F "$OLD_REVIEW_ESCALATION" >/dev/null; then
  fail "delivery gate stages must not expose review escalation helpers"
fi
if declare -F "$OLD_QA_ESCALATION" >/dev/null; then
  fail "delivery gate stages must not expose QA escalation helpers"
fi

assert_present 'Delivery Owner 是交付负责人' "$PM_SKILL" "delivery-owner skill"
assert_present '# /delivery-owner -- 交付负责人' "$PM_SKILL" "delivery-owner skill"
assert_present '运行时你扮演交付控制面' "$PM_SKILL" "delivery-owner skill"
OLD_RUNTIME_HEADING='## Runtime '"Authority"
assert_absent "$OLD_RUNTIME_HEADING" "$PM_SKILL" "delivery-owner skill"
assert_present 'references/dispatch-guide.md' "$PM_SKILL" "delivery-owner skill"
assert_present 'references/delivery-gate-dispatch.md' "$PM_SKILL" "delivery-owner skill"
assert_present 'REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D' "$PM_SKILL" "delivery-owner skill"
assert_present 'consistency-auditor' "$PM_SKILL" "delivery-owner skill"
assert_present 'code-review-result.json' "$PM_SKILL" "delivery-owner skill"
assert_present 'qa-result.json' "$PM_SKILL" "delivery-owner skill"
assert_present 'fresh proving command' "$PM_SKILL" "delivery-owner skill"
assert_present '不得用 Mock 验收替代' "$PM_SKILL" "delivery-owner skill"
assert_present '口头 Phase 确认不是 canonical baseline' "$PM_SKILL" "delivery-owner skill"
assert_present '缺基线阻断固定输出' "$PM_SKILL" "delivery-owner skill"
assert_present 'canonical 工件齐全且来自 active artifact-registry，不以缺工件阻断' "$PM_SKILL" "delivery-owner skill"
assert_present 'current_stage=TASK_EXECUTION' "$PM_SKILL" "delivery-owner skill"
assert_present '不得进入交付门禁或 commit' "$PM_SKILL" "delivery-owner skill"
assert_present '缺失 canonical 工件时不派发专家、不维护 delivery-state.json' "$PM_SKILL" "delivery-owner skill"
assert_present '不派发 developer、review 或 qa' "$PM_SKILL" "delivery-owner skill"
assert_present 'developer-report、verify-result 和 fresh proving evidence' "$PM_SKILL" "delivery-owner skill"
assert_present '恢复条件：工件齐备后才按批次/并行策略派发，并要求 developer-report、verify-result 和 fresh proving evidence。' "$PM_SKILL" "delivery-owner skill"
assert_present 'non-waivable REVIEW_A / REVIEW_B / REVIEW_C / QA_A' "$PM_SKILL" "delivery-owner skill"
assert_present '生成或消费 signoff-package.json' "$PM_SKILL" "delivery-owner skill"
assert_present '门禁结论：不跳过交付门禁 review / QA。' "$PM_SKILL" "delivery-owner skill"
assert_present 'signoff-package.json：生成或消费 signoff-package.json' "$PM_SKILL" "delivery-owner skill"
assert_present '提交/门禁请求固定输出' "$PM_SKILL" "delivery-owner skill"
assert_present 'signoff-package.json：生成或消费 signoff-package.json；若前置门禁失败未消费，写明“未消费”与原因' "$PM_SKILL" "delivery-owner skill"
assert_present '用户签收前不提交' "$PM_SKILL" "delivery-owner skill"
assert_present '本次不实际提交、不写文件' "$PM_SKILL" "delivery-owner skill"
assert_present '并行回收固定输出' "$PM_SKILL" "delivery-owner skill"
assert_present '将 T1/T2 标记为 VERIFIED/CLOSED，并将 T3 标记为 READY_TO_DISPATCH' "$PM_SKILL" "delivery-owner skill"
assert_present '共享文件冲突固定输出' "$PM_SKILL" "delivery-owner skill"
assert_present '识别 T1/T2 写同一文件且 shared_files 未声明' "$PM_SKILL" "delivery-owner skill"
assert_present '专家报告消费固定输出' "$PM_SKILL" "delivery-owner skill"
assert_present '逐项消费 verify-result.json 的 SPEC_OK / 2A_OK / 2B_OK / 2C_OK' "$PM_SKILL" "delivery-owner skill"
assert_present '缺任一报告或 proving 输出时不能关闭 Task' "$PM_SKILL" "delivery-owner skill"
assert_present 'fresh_proving_command / fresh_proving_output' "$PM_SKILL" "delivery-owner skill"
assert_absent '动态质量升档' "$PM_SKILL" "delivery-owner skill"
assert_absent '动态升档' "$PM_SKILL" "delivery-owner skill"
assert_absent "$OLD_PHASE_LABEL 审查分级" "$PM_SKILL" "delivery-owner skill"
assert_absent '旧分级矩阵' "$PM_SKILL" "delivery-owner skill"
assert_absent '你的职责：' "$PM_SKILL" "delivery-owner skill"
assert_absent '你不做：' "$PM_SKILL" "delivery-owner skill"
assert_absent "轻量：\`REVIEW_A + REVIEW_B + REVIEW_C + QA_A\`" "$PM_SKILL" "delivery-owner skill"
assert_absent "标准：\`REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_C\`" "$PM_SKILL" "delivery-owner skill"
if grep -E '^allowed-tools:.*(^|, )Edit(,|$)' "$PM_SKILL"; then
  fail "delivery-owner frontmatter must not allow Edit"
fi

python3 - <<'PY' "$PM_EVALS"
import json
import sys
from pathlib import Path

evals = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["evals"]
by_id = {item["id"]: item for item in evals}
required = {
    "parallel-reports-unlock-next-batch": [
        "消费 T1/T2 的 developer-report.json 与 verify-result.json",
        "确认 batch 1 全部回收后才解锁 T3",
        "将 T1/T2 标记为 VERIFIED/CLOSED，并将 T3 标记为 READY_TO_DISPATCH",
        "不进入交付门禁或 commit",
    ],
    "parallel-shared-file-conflict-blocks": [
        "识别 T1/T2 写同一文件且 shared_files 未声明",
        "控制动作必须是 BLOCK",
        "不派发 developer、review 或 qa",
        "说明修复路径是声明共享文件协议、拆分批次或重新计划",
    ],
    "expert-report-consumption-gates": [
        "逐项消费 developer-report.json 的 RED/GREEN 与 fresh proving output",
        "逐项消费 verify-result.json 的 SPEC_OK / 2A_OK / 2B_OK / 2C_OK",
        "缺任一报告或 proving 输出时不能关闭 Task",
        "报告齐全时才同步 delivery-state.json 并推进下一动作",
    ],
}
missing_ids = sorted(set(required) - set(by_id))
if missing_ids:
    raise AssertionError(f"missing delivery-owner eval ids: {missing_ids}")
for eval_id, expectations in required.items():
    actual = set(by_id[eval_id].get("expectations", []))
    missing = [item for item in expectations if item not in actual]
    if missing:
        raise AssertionError(f"{eval_id} missing expectations: {missing}")
PY

python3 - <<'PY' "$ROOT/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/unit-1/tasks"
import json
import sys
from pathlib import Path

tasks_dir = Path(sys.argv[1])
for task_id in ("T1", "T2"):
    developer_report = json.loads((tasks_dir / task_id / "developer-report.json").read_text(encoding="utf-8"))
    verify_result = json.loads((tasks_dir / task_id / "verify-result.json").read_text(encoding="utf-8"))
    phases = {item["phase"]: item["result"] for item in developer_report["tdd_evidence_index"]}
    if phases.get("RED") != "FAIL_EXPECTED" or phases.get("GREEN") != "PASS":
        raise AssertionError(f"{task_id} missing RED/GREEN developer evidence")
    if "fresh_proving_command" not in developer_report or "fresh_proving_output" not in developer_report:
        raise AssertionError(f"{task_id} missing fresh proving evidence")
    verdicts = verify_result["phase_verdicts"]
    expected = {
        "spec_review": "SPEC_OK",
        "phase2a": "2A_OK",
        "phase2b": "2B_OK",
        "phase2c": "2C_OK",
    }
    for key, status in expected.items():
        if verdicts.get(key, {}).get("status") != status:
            raise AssertionError(f"{task_id} missing {status}")
PY

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

assert_present '## Canonical Artifact Boundary' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_present 'validate_standard_chain_readiness.py' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_absent 'Legacy Markdown Compatibility' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_absent 'ORG_ENABLE_LEGACY_MARKDOWN_HOOKS' "$RUNTIME_ADAPTER" "runtime adapter contract"

assert_reference_contract "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_reference_contract "$SIGNOFF_CONTRACT" "signoff contract"
assert_present '## 固定完整门禁' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "| Code Review | \`REVIEW_A + REVIEW_B + REVIEW_C\` | \`code-review-result.json\` |" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "| QA | \`QA_A + QA_B + QA_C + QA_D\` | \`qa-result.json\` |" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## Handoff Boundary' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 修复循环与熔断' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 签收前一致性旁路扫描' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "固定完整门禁全部通过后、生成 \`signoff-package.json\` 前" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "\`delivery-owner\` 调度 \`consistency-auditor\` 一次" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "\`decision_authority: advisory_only\`" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "不得替代 \`REVIEW/QA\` 结论" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 风险接受边界' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 汇总代理边界' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present 'review / qa / fix' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present 'residual_risk / waiver' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## Constraint Closure' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present '## Gate Closure' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present '## Goal Closure' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present '## Projection Boundary' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present 'Fixed full delivery gates are non-optional' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present 'Fixed full gate stages cannot be waived as a whole' "$SIGNOFF_CONTRACT" "signoff contract"
assert_absent '## 动态升档规则' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_absent '按分级裁剪执行' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_absent '| 轻量 |' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_absent '| 标准 |' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_absent '| 完整 |' "$DELIVERY_GATE_DOC" "delivery gate dispatch"

assert_present "强门禁固定跟踪 \`REVIEW_A / REVIEW_B / REVIEW_C\`" "$CR_TEMPLATE" "code-review template"
assert_present 'REVIEW_A（安全性）' "$CR_TEMPLATE" "code-review template"
assert_present 'REVIEW_B（质量）' "$CR_TEMPLATE" "code-review template"
assert_present 'REVIEW_C（运行质量）' "$CR_TEMPLATE" "code-review template"
assert_absent '审查分级' "$CR_TEMPLATE" "code-review template"
assert_absent '"grade"' "$CR_TEMPLATE" "code-review template"
assert_present '## 汇总代理状态' "$CR_TEMPLATE" "code-review template"
assert_absent '<metadata>' "$CR_TEMPLATE" "code-review template"

assert_present "强门禁固定跟踪 \`QA_A / QA_B / QA_C / QA_D\`" "$QA_TEMPLATE" "qa template"
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
assert_present 'residual_risk:edge-case-copy' "$WAIVERS_TEMPLATE" "waivers template"
assert_absent '| PMW-001 | QA_D |' "$WAIVERS_TEMPLATE" "waivers template"

assert_present 'current_tasks_version_ref:' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_present 'current_tasks_version_value:' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_present 'compensation_control' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_present 'user_confirmation_ref' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_present '## 汇总代理状态' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent 'delivery-status-summary.md' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent 'evidence-summary.md' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_B (E2E 旅程) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_C (回归验证) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_D (探索性测试) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"

assert_present '## 汇总代理状态' "$DEV_TEMPLATE" "dev report template"
assert_absent 'Commit:' "$DEV_TEMPLATE" "dev report template"
assert_absent 'Task-Commit' "$DEV_TEMPLATE" "dev report template"
assert_absent 'delivery-status-summary.md' "$DEV_TEMPLATE" "dev report template"
assert_absent 'evidence-summary.md' "$DEV_TEMPLATE" "dev report template"
assert_absent 'delivery-status-summary.md' "$CR_TEMPLATE" "code-review template"
assert_absent 'evidence-summary.md' "$CR_TEMPLATE" "code-review template"
for template in "$DEV_TEMPLATE" "$CR_TEMPLATE" "$ACCEPTANCE_TEMPLATE" "$WAIVERS_TEMPLATE"; do
  assert_absent 'HOOK-CONTRACT' "$template" "delivery-owner template"
  assert_absent '## 汇总代理引用' "$template" "delivery-owner template"
  if [ "$template" != "$WAIVERS_TEMPLATE" ]; then
    assert_present '字段引用位' "$template" "delivery-owner template"
    assert_present '证据锚点引用位' "$template" "delivery-owner template"
  fi
  assert_absent '触发条件' "$template" "delivery-owner template"
  assert_absent '重入规则' "$template" "delivery-owner template"
done

assert_present 'compensation_control' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'expires_at' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'user_confirmation_ref' "$KICKOFF_CHECKLIST" "kickoff checklist"

assert_absent "## $OLD_PHASE_LABEL 审查分级" "$PLAN_TEMPLATE" "plan template"
assert_absent '审查分级:' "$PLAN_TEMPLATE" "plan template"
assert_absent '轻量:' "$PLAN_TEMPLATE" "plan template"
assert_absent '标准:' "$PLAN_TEMPLATE" "plan template"
assert_absent '完整:' "$PLAN_TEMPLATE" "plan template"
assert_present 'REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D' "$PLAN_TEMPLATE" "plan template"

assert_present '"path": "scripts/delivery-gate-stages.sh"' "$SCRIPT_MANIFEST" "script manifest"
assert_present 'fixed full gate' "$SCRIPT_MANIFEST" "script manifest"
assert_absent 'unsupported grade' "$SCRIPT_MANIFEST" "script manifest"
assert_absent 'grade matrix' "$SCRIPT_MANIFEST" "script manifest"

assert_present 'validate_standard_chain_readiness.py' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_present 'canonical closeout 工件路径未命中' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_absent 'ORG_ENABLE_LEGACY_MARKDOWN_HOOKS' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_absent 'legacy markdown' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_present 'delivery_gate_required_review_stages' "$GATE_STAGES" "delivery-owner gate stages"
assert_present 'delivery_gate_required_qa_stages' "$GATE_STAGES" "delivery-owner gate stages"
assert_absent 'plan_grade' "$CHECK_SCRIPT" "delivery-owner completion check"
assert_absent "$OLD_PHASE_LABEL 审查分级" "$CHECK_SCRIPT" "delivery-owner completion check"
assert_absent '审查分级' "$TECH_LEAD_CHECK" "tech-lead completion check"
assert_absent 'parse_plan_grade' "$QA_CHECK" "qa completion check"
assert_absent '缺少有效的审查分级' "$QA_CHECK" "qa completion check"

assert_present 'full-gate evidence chain' "$TASK_GRADER" "task constraint grader"
assert_absent '审查分级匹配' "$TASK_GRADER" "task constraint grader"
assert_absent '动态升档' "$ROLLOUT_GATE_TEST" "rollout gate test"
assert_absent 'quality escalation after risk increase' "$REPLAY_GATE_TEST" "replay contract test"

[ ! -d "$LEGACY_ROLE_DOC" ] || fail "stale delivery-owner role docs should be archived"
[ -d "$ARCHIVED_ROLE_DOC" ] || fail "archived delivery-owner role docs missing"

echo "[PASS] delivery-owner gate contract"
