#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

GATE_STAGES="$ROOT/shared/skills/delivery-owner/scripts/delivery-gate-stages.sh"
INPUT_READINESS_SCRIPT="$ROOT/shared/skills/delivery-owner/scripts/input_readiness_check.sh"
COMMIT_PREFLIGHT_SCRIPT="$ROOT/shared/skills/delivery-owner/scripts/commit_preflight_check.sh"
COMMIT_PREFLIGHT_VALIDATOR="$ROOT/tools/community/validate_delivery_owner_commit_preflight.py"
PM_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
DELIVERY_GATE_DOC="$ROOT/shared/skills/delivery-owner/references/delivery-gate-dispatch.md"
SIGNOFF_CONTRACT="$ROOT/shared/skills/delivery-owner/references/signoff-contract.md"
DISPATCH_GUIDE="$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
RUNTIME_ADAPTER="$ROOT/shared/skills/delivery-owner/references/runtime-adapter-contract.md"
SCRIPT_MANIFEST="$ROOT/shared/skills/delivery-owner/scripts/manifest.json"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
CR_TEMPLATE="$ROOT/shared/skills/delivery-owner/projections/code-review-report-template.md"
DEV_TEMPLATE="$ROOT/shared/skills/delivery-owner/projections/dev-report-template.md"
QA_SKILL="$ROOT/shared/skills/qa/SKILL.md"
QA_RELEASE_METHOD="$ROOT/shared/skills/qa/references/release-decision-methodology.md"
QA_TEMPLATE="$ROOT/shared/skills/qa/projections/qa-report-template.md"
PLAN_TEMPLATE="$ROOT/shared/skills/tech-lead/projections/plan-template.md"
ACCEPTANCE_TEMPLATE="$ROOT/shared/skills/delivery-owner/projections/acceptance-summary-template.md"
WAIVERS_TEMPLATE="$ROOT/shared/skills/delivery-owner/projections/waivers-template.md"
KICKOFF_CHECKLIST="$ROOT/shared/skills/delivery-owner/references/kickoff-checklist.md"
ARTIFACT_REGISTRY_TEMPLATE="$ROOT/shared/skills/delivery-owner/templates/artifact-registry.template.json"
DELIVERY_STATE_SCHEMA="$ROOT/shared/skills/delivery-owner/contracts/delivery-state.schema.json"
DELIVERY_STATE_TEMPLATE="$ROOT/shared/skills/delivery-owner/templates/delivery-state.template.json"
CHECK_SCRIPT="$ROOT/shared/skills/delivery-owner/scripts/completion_check.sh"
COMMIT_SKILL="$ROOT/shared/skills/commit/SKILL.md"
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
OLD_RUNTIME_HEADING='^## Runtime '"Authority"'$'

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

assert_completion_gate_contract() {
  python3 - "$SCRIPT_MANIFEST" "$HOOK_REGISTRY" <<'PY' || fail "delivery-owner manifest and registry must mirror completion gate contract"
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
scripts = [
    item
    for item in manifest.get("scripts", [])
    if item.get("id") == "completion-check"
]
if len(scripts) != 1:
    raise SystemExit("delivery-owner manifest must have exactly one completion-check script")
script = scripts[0]
entries = [
    item
    for item in registry.get("skill_completion_gates", [])
    if item.get("skill") == "delivery-owner"
]
if len(entries) != 1:
    raise SystemExit("delivery-owner registry must have exactly one entry")
entry = entries[0]
required = {"owner", "allowed_args", "output_root", "failure_state"}
missing_script = sorted(required - set(script))
missing_entry = sorted(required - set(entry))
if missing_script:
    raise SystemExit(f"delivery-owner manifest missing keys: {missing_script}")
if missing_entry:
    raise SystemExit(f"delivery-owner registry missing keys: {missing_entry}")
if entry.get("handler_rel") != f"skills/delivery-owner/{script['path']}":
    raise SystemExit("delivery-owner registry and manifest handler drift")
if entry.get("timeout_sec") != script.get("timeout_seconds"):
    raise SystemExit("delivery-owner registry and manifest timeout drift")
for field in required:
    if entry.get(field) != script.get(field):
        raise SystemExit(f"delivery-owner registry and manifest {field} drift")
for arg in ("--help", "-h"):
    if arg not in script.get("allowed_args", []):
        raise SystemExit(f"delivery-owner completion-check manifest missing help arg: {arg}")
PY
}

# shellcheck source=/dev/null
source "$GATE_STAGES"

assert_completion_gate_contract
test -f "$INPUT_READINESS_SCRIPT" || fail "missing delivery-owner input readiness script"
bash -n "$INPUT_READINESS_SCRIPT" || fail "delivery-owner input readiness script must pass bash syntax check"
test -f "$COMMIT_PREFLIGHT_SCRIPT" || fail "missing delivery-owner commit preflight script"
bash -n "$COMMIT_PREFLIGHT_SCRIPT" || fail "delivery-owner commit preflight script must pass bash syntax check"
python3 -m py_compile "$COMMIT_PREFLIGHT_VALIDATOR" || fail "delivery-owner commit preflight validator must compile"

python3 - "$ROOT" <<'PY' || fail "PARTIAL signoff goal closure must require remaining_gap_text"
import json
import shutil
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/community"))
from validate_readiness_contract import assert_signoff_closure

source = root / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
with tempfile.TemporaryDirectory() as tmp:
    feature_dir = Path(tmp) / "sample-feature"
    shutil.copytree(source, feature_dir)
    signoff_path = feature_dir / "phase-1/signoff-package.json"
    signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
    for row in signoff["goal_closure"]:
        if row.get("result") == "PARTIAL":
            row.pop("remaining_gap_text", None)
            break
    signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    try:
        assert_signoff_closure(feature_dir, feature_dir / "phase-1")
    except ValueError as exc:
        if "remaining_gap_text" in str(exc):
            raise SystemExit(0)
        raise
    raise SystemExit("missing remaining_gap_text was accepted")
PY

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
assert_absent '> ultrathink' "$PM_SKILL" "delivery-owner skill"
assert_present '运行时你扮演交付控制面' "$PM_SKILL" "delivery-owner skill"
assert_present '## 输入识别' "$PM_SKILL" "delivery-owner skill"
assert_present 'Handoff Intake' "$PM_SKILL" "delivery-owner skill"
assert_present 'unit-definition' "$PM_SKILL" "delivery-owner skill"
assert_present 'unit-*/test-cases.json' "$PM_SKILL" "delivery-owner skill"
assert_present "bash shared/skills/delivery-owner/scripts/input_readiness_check.sh --phase-dir \"\$PHASE_DIR\"" "$PM_SKILL" "delivery-owner skill"
assert_absent 'plan.json / tasks.json / test-cases.json' "$PM_SKILL" "delivery-owner skill"
assert_absent "与 \`code-review-result.json.dimension_verdicts\` 同步" "$PM_SKILL" "delivery-owner skill"
assert_present 'Dispatch → Observe Evidence → Classify Drift → Update delivery-state.json → Control Decision → Next Action' "$PM_SKILL" "delivery-owner skill"
assert_present 'REQUEST_CHANGES' "$PM_SKILL" "delivery-owner skill"
assert_present 'Commit preflight' "$PM_SKILL" "delivery-owner skill"
assert_absent "$OLD_RUNTIME_HEADING" "$PM_SKILL" "delivery-owner skill"
assert_present 'references/dispatch-guide.md' "$PM_SKILL" "delivery-owner skill"
assert_present 'references/delivery-gate-dispatch.md' "$PM_SKILL" "delivery-owner skill"
assert_present 'REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D' "$PM_SKILL" "delivery-owner skill"
assert_present '/consistency-audit' "$PM_SKILL" "delivery-owner skill"
assert_present 'consistency-auditor 角色' "$PM_SKILL" "delivery-owner skill"
assert_present 'code-review-result.json' "$PM_SKILL" "delivery-owner skill"
assert_present 'qa-result.json' "$PM_SKILL" "delivery-owner skill"
assert_present '当前验证命令' "$PM_SKILL" "delivery-owner skill"
assert_absent 'completion_check.sh / delivery-gate-stages.sh|completion gate adapter' "$PM_SKILL" "delivery-owner skill"
assert_present '不得用 Mock 验收替代' "$PM_SKILL" "delivery-owner skill"
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

assert_reference_contract "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## 派发合同' "$DISPATCH_GUIDE" "dispatch guide"
assert_absent 'Phase 2' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Evidence In' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Evidence Out' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## Control Decision' "$DISPATCH_GUIDE" "dispatch guide"
assert_present '## 控制循环' "$DISPATCH_GUIDE" "dispatch guide"
assert_present 'Classify Drift' "$DISPATCH_GUIDE" "dispatch guide"
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
assert_present '## Script Boundary' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_present 'input-readiness-check' "$SCRIPT_MANIFEST" "script manifest"
assert_present 'input_readiness_check.sh' "$SCRIPT_MANIFEST" "script manifest"
assert_present 'validate_delivery_owner_input_readiness.py' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_present 'validate_standard_chain_readiness.py' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_absent 'Legacy Markdown Compatibility' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_absent 'ORG_ENABLE_LEGACY_MARKDOWN_HOOKS' "$RUNTIME_ADAPTER" "runtime adapter contract"

assert_reference_contract "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_reference_contract "$SIGNOFF_CONTRACT" "signoff contract"
assert_present 'unit-definition' "$ARTIFACT_REGISTRY_TEMPLATE" "artifact-registry template"
assert_present 'units/UNIT-1.json' "$ARTIFACT_REGISTRY_TEMPLATE" "artifact-registry template"
assert_present 'artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal' "$ARTIFACT_REGISTRY_TEMPLATE" "artifact-registry template"
assert_present 'director_lock_digest' "$ARTIFACT_REGISTRY_TEMPLATE" "artifact-registry template"
assert_present '"kickoff"' "$DELIVERY_STATE_SCHEMA" "delivery-state schema"
assert_present '"kickoff"' "$DELIVERY_STATE_TEMPLATE" "delivery-state template"
assert_present 'unit-definition' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'unit-*/test-cases.json' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'unit-*/test-cases.json' "$DISPATCH_GUIDE" "dispatch guide"
assert_present 'unit-definition' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present 'unit-*/test-cases.json' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 固定完整门禁' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "| Code Review | \`REVIEW_A + REVIEW_B + REVIEW_C\` | \`code-review-result.json\` |" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "| QA | \`QA_A + QA_B + QA_C + QA_D\` | \`qa-result.json\` |" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## Handoff Boundary' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 修复循环与熔断' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 签收前一致性旁路扫描' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "固定完整门禁全部通过后、生成 \`signoff-package.json\` 前" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "\`delivery-owner\` 调度 \`/consistency-audit\` 一次" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "consistency-auditor\` 只作为 standard-chain role/producer 名称" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "\`decision_authority: advisory_only\`" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present "不得替代 \`REVIEW/QA\` 结论" "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 风险接受边界' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## 汇总代理边界' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present 'review / qa / fix' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present 'residual_risk / waiver' "$DELIVERY_GATE_DOC" "delivery gate dispatch"
assert_present '## Constraint Closure' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present "optional active \`fix-result.json\`" "$SIGNOFF_CONTRACT" "signoff contract"
assert_present 'completion_status=FIXED' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present '## Gate Closure' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present '## Goal Closure' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present 'remaining_gap_text' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present '## User Decision Branches' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present 'REQUEST_CHANGES' "$SIGNOFF_CONTRACT" "signoff contract"
assert_present 'RISK_NOT_ACCEPTED' "$SIGNOFF_CONTRACT" "signoff contract"
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
assert_absent '## 汇总代理状态' "$CR_TEMPLATE" "code-review template"
assert_absent 'Status Synthesis Agent|Evidence Synthesis Agent' "$CR_TEMPLATE" "code-review template"
assert_absent '<metadata>' "$CR_TEMPLATE" "code-review template"

assert_present "强门禁固定跟踪 \`QA_A / QA_B / QA_C / QA_D\`" "$QA_TEMPLATE" "qa template"
assert_present '### QA_A UNIT 执行汇总' "$QA_TEMPLATE" "qa template"
assert_present '## 验证-B: E2E 用户旅程' "$QA_TEMPLATE" "qa template"
assert_present '## 验证-C: 回归验证' "$QA_TEMPLATE" "qa template"
assert_present '## 验证-D: 探索性测试' "$QA_TEMPLATE" "qa template"
assert_present 'release_recommendation: {ALLOW, CONDITIONAL_ALLOW, BLOCK, DEFER}' "$QA_TEMPLATE" "qa template"
assert_present '"release_recommendation":"{ALLOW, CONDITIONAL_ALLOW, BLOCK, DEFER}"' "$QA_TEMPLATE" "qa template"
assert_present 'release_recommendation | 显示含义' "$QA_RELEASE_METHOD" "qa release methodology"
assert_present 'ALLOW' "$QA_RELEASE_METHOD" "qa release methodology"
assert_present 'CONDITIONAL_ALLOW' "$QA_RELEASE_METHOD" "qa release methodology"
assert_present 'BLOCK' "$QA_RELEASE_METHOD" "qa release methodology"
assert_present 'DEFER' "$QA_RELEASE_METHOD" "qa release methodology"
assert_present 'shared/skills/qa/contracts/qa-result.schema.json' "$QA_SKILL" "qa skill"
assert_present 'shared/skills/qa/templates/qa-result.template.json' "$QA_SKILL" "qa skill"
assert_present 'active_plan_version_ref' "$QA_SKILL" "qa skill"
assert_present 'stage_results' "$QA_SKILL" "qa skill"
assert_present '"qa":{"QA_A"' "$QA_TEMPLATE" "qa template"
assert_present '"QA_B"' "$QA_TEMPLATE" "qa template"
assert_present '"QA_C"' "$QA_TEMPLATE" "qa template"
assert_present '"QA_D"' "$QA_TEMPLATE" "qa template"
assert_absent 'release_recommendation: \{放行, 条件放行, 阻塞\}' "$QA_TEMPLATE" "qa template"
assert_absent '"release_recommendation":"\{放行, 条件放行, 阻塞\}"' "$QA_TEMPLATE" "qa template"
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
assert_absent '## 汇总代理状态' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent 'Status Synthesis Agent|Evidence Synthesis Agent' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent 'delivery-status-summary.md' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent 'evidence-summary.md' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_B (E2E 旅程) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_C (回归验证) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"
assert_absent '| QA_D (探索性测试) | {OK, ISSUE, N/A}' "$ACCEPTANCE_TEMPLATE" "acceptance summary template"

assert_absent '## 汇总代理状态' "$DEV_TEMPLATE" "dev report template"
assert_absent 'Status Synthesis Agent|Evidence Synthesis Agent' "$DEV_TEMPLATE" "dev report template"
assert_absent 'Commit:' "$DEV_TEMPLATE" "dev report template"
assert_absent 'Task-Commit' "$DEV_TEMPLATE" "dev report template"
assert_absent 'delivery-status-summary.md' "$DEV_TEMPLATE" "dev report template"
assert_absent 'evidence-summary.md' "$DEV_TEMPLATE" "dev report template"
assert_absent 'delivery-status-summary.md' "$CR_TEMPLATE" "code-review template"
assert_absent 'evidence-summary.md' "$CR_TEMPLATE" "code-review template"
for template in "$DEV_TEMPLATE" "$CR_TEMPLATE" "$ACCEPTANCE_TEMPLATE" "$WAIVERS_TEMPLATE"; do
  assert_absent 'HOOK-CONTRACT' "$template" "delivery-owner template"
  assert_absent '## 汇总代理引用' "$template" "delivery-owner template"
  assert_absent '字段引用位|证据锚点引用位' "$template" "delivery-owner template"
  assert_absent '触发条件' "$template" "delivery-owner template"
  assert_absent '重入规则' "$template" "delivery-owner template"
done

assert_present 'compensation_control' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'expires_at' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_present 'user_confirmation_ref' "$KICKOFF_CHECKLIST" "kickoff checklist"
assert_absent 'signoff-package.json.kickoff_status' "$KICKOFF_CHECKLIST" "kickoff checklist"

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
assert_present 'commit_preflight_check.sh' "$PM_SKILL" "delivery-owner skill"
assert_present 'commit-preflight.json' "$PM_SKILL" "delivery-owner skill"
assert_present 'commit-preflight-check' "$SCRIPT_MANIFEST" "script manifest"
assert_present 'commit_preflight_check.sh' "$SCRIPT_MANIFEST" "script manifest"
assert_present 'validate_delivery_owner_commit_preflight.py' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_present 'DELIVERY_OWNER_COMMIT_PREFLIGHT_FAILED' "$RUNTIME_ADAPTER" "runtime adapter contract"
assert_present 'commit-preflight.json' "$COMMIT_SKILL" "commit skill"
assert_present 'decision=allow' "$COMMIT_SKILL" "commit skill"
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
