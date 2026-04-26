#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/do_source_anchor_absent.out 2>&1; then
    cat /tmp/do_source_anchor_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_present 'key_fields: \[active_plan_version_ref, active_tasks_version_ref, current_stage, status, control_action, summary_text, tasks\]' "$ROOT/contracts/standard-chain.yaml"
assert_present 'key_fields: \[current_stage, release_recommendation, goal_closure, sign_off_status, business_risk_acceptance_status, decision_basis_refs\]' "$ROOT/contracts/standard-chain.yaml"
assert_present '^## 计划版本$' "$ROOT/shared/skills/tech-lead/projections/plan-template.md"
assert_present 'plan_version: v1' "$ROOT/shared/skills/tech-lead/projections/plan-template.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
assert_present 'enforce-canonical-only' "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"

for file in \
  "$ROOT/shared/skills/product-director/references/templates/brief-template.md" \
  "$ROOT/shared/skills/product-director/references/templates/phase-prd-template.md" \
  "$ROOT/shared/skills/design/projections/design-template.md" \
  "$ROOT/shared/skills/test-design/references/templates/test-cases-template.md"; do
  assert_present '^## 引用锚点合同$' "$file"
done

assert_present '^## 冻结说明$' "$ROOT/docs/archive/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present '^## 冻结说明$' "$ROOT/docs/archive/delivery-owner-role-20260411/quality-rubric.md"
assert_present '^## 冻结说明$' "$ROOT/docs/archive/delivery-owner-role-20260411/replay-scenarios.md"
assert_present 'goal_source_ref' "$ROOT/docs/archive/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present 'execution_basis_ref' "$ROOT/docs/archive/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present '^## 派发合同$' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '^## Evidence In$' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '^## Evidence Out$' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '^## Control Decision$' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '^## Replan Boundary$' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '^## Parallel Boundary$' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '^## 派发 prompt 质量要点$' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present 'replan_request' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present 'batch_freeze_reason' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present 'unlock_resolution' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present 'plan_version_value' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present 'dispatch_mode:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'plan_version_ref:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'plan_version_value:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'plan_version_ref:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'plan_version_value:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present '^## 最新状态摘要$' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'last_observed_at:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'current_plan_version_ref:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'current_plan_version_value:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'sign_off_status:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'business_risk_acceptance_status:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'risk_acceptance_basis:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present '\| 目标 \| goal_source_ref \| execution_basis_ref \| evidence_ref \| result \| remaining_gap \|' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'plan_version_ref:' "$ROOT/shared/skills/qa/references/templates/qa-report-template.md"
assert_present 'plan_version_value:' "$ROOT/shared/skills/qa/references/templates/qa-report-template.md"
assert_absent 'rebaseline' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'replan_request' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"

echo "[PASS] delivery-owner source anchor contract"
