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

assert_present 'key_fields: \[active_plan_version_ref, active_tasks_version_ref, current_stage, status, control_action, summary_text, tasks, kickoff\]' "$ROOT/contracts/standard-chain.yaml"
assert_present 'key_fields: \[baseline_plan_version_ref, baseline_tasks_version_ref, active_plan_version_ref, active_tasks_version_ref, current_stage, release_recommendation, goal_closure, waiver_entries, sign_off_status, business_risk_acceptance_status, last_observed_at, runtime_snapshot, active_blocker, blocker_owner, takeover_note, decision_basis_refs\]' "$ROOT/contracts/standard-chain.yaml"
assert_present 'key_fields: \[baseline_plan_version_ref, baseline_tasks_version_ref, active_plan_version_ref, active_tasks_version_ref, current_stage, decision, decision_source, actor_id, sign_off_status, business_risk_acceptance_status, authority_proof_refs, decision_basis_refs, director_lock_digests, decision_payload_digest\]' "$ROOT/contracts/standard-chain.yaml"
assert_present '^## 计划版本$' "$ROOT/shared/skills/tech-lead/projections/plan-template.md"
assert_present 'plan_version: v1' "$ROOT/shared/skills/tech-lead/projections/plan-template.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
assert_present 'enforce-canonical-only' "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"

for file in \
  "$ROOT/shared/skills/test-design/projections/test-cases-template.md"; do
  assert_present '^## 引用锚点合同$' "$file"
done

assert_present '"authoritative_fields"' "$ROOT/shared/skills/product-director/templates/brief.template.json"
assert_present '"\$\.business_goals"' "$ROOT/shared/skills/product-director/templates/brief.template.json"
assert_present '"\$\.director_confirmation"' "$ROOT/shared/skills/product-director/templates/brief.template.json"
assert_present '"authoritative_fields"' "$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
assert_present '"\$\.phase_goal"' "$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
assert_present '"\$\.director_confirmation"' "$ROOT/shared/skills/product-director/templates/phase-prd.template.json"

assert_present '"verification_mapping"' "$ROOT/shared/skills/design/templates/design.template.json"
assert_present '"evidence_ref"' "$ROOT/shared/skills/design/templates/design.template.json"
assert_present '"verification_mapping"' "$ROOT/shared/skills/design/contracts/design.schema.json"
assert_present '"evidence_ref"' "$ROOT/shared/skills/design/contracts/design.schema.json"

assert_present '^## 冻结说明$' "$ROOT/docs/archive/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present '^## 冻结说明$' "$ROOT/docs/archive/delivery-owner-role-20260411/quality-rubric.md"
assert_present '^## 冻结说明$' "$ROOT/docs/archive/delivery-owner-role-20260411/replay-scenarios.md"
assert_present 'goal_source_ref' "$ROOT/docs/archive/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present 'execution_basis_ref' "$ROOT/docs/archive/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present 'Task Packet' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'task packet' "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_present 'expected_evidence' "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_present 'direct' "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_present 'role-owned' "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_present 'actionable' "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_present 'signoff_ready' "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_present 'baseline_plan_version_ref' "$ROOT/shared/skills/delivery-owner/templates/signoff-package.template.json"
assert_present 'goal_source_ref' "$ROOT/shared/skills/delivery-owner/templates/signoff-package.template.json"
[ ! -d "$ROOT/shared/skills/delivery-owner/projections" ] \
  || fail "active delivery-owner must not retain old human projection templates"
assert_present 'plan_version_ref:' "$ROOT/shared/skills/qa/projections/qa-report-template.md"
assert_present 'plan_version_value:' "$ROOT/shared/skills/qa/projections/qa-report-template.md"
assert_present 'rebaseline_needed' "$ROOT/shared/skills/delivery-owner/SKILL.md"

echo "[PASS] delivery-owner source anchor contract"
