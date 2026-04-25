#!/usr/bin/env bash
# shellcheck disable=SC2016
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
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/org_skill_gate_absent.out 2>&1; then
    cat /tmp/org_skill_gate_absent.out >&2
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_json_ok() {
  local file="$1"
  jq empty "$file" >/dev/null 2>&1 || fail "invalid JSON: ${file#"$ROOT"/}"
}

run_hook() {
  local script="$1"
  local workspace="$2"
  local session_id="$3"
  local transcript_entries="$4"
  local tool_name="${5:-}"
  local file_path="${6:-}"
  local transcript_path="$workspace/transcript.log"
  local payload status

  printf '%b' "$transcript_entries" > "$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "$session_id" \
    --arg tp "$transcript_path" \
    --arg tn "$tool_name" \
    --arg fp "$file_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}
      + (if $tn == "" then {} else {tool_name:$tn} end)
      + (if $fp == "" then {} else {tool_input:{file_path:$fp}} end)')"

  if (cd "$workspace" && bash "$script" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$workspace/hook.status"
}

assert_hook_passed() {
  local workspace="$1"
  local label="$2"
  local status
  status="$(cat "$workspace/hook.status")"
  if [ "$status" != "0" ]; then
    cat "$workspace/hook.stderr" >&2
    fail "$label failed with exit $status"
  fi
  jq -e '.decision == "allow"' "$workspace/hook.stdout" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "$label did not emit allow decision"
  }
}

prepare_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$workspace/docs/sample-feature"
}

prepare_git_trace_workspace() {
  local workspace="$1"
  local object_dir

  object_dir="$(git -C "$ROOT" rev-parse --git-path objects)"
  (cd "$workspace" && git init -q)
  mkdir -p "$workspace/.git/objects/info"
  printf '%s\n' "$object_dir" > "$workspace/.git/objects/info/alternates"
}

prepare_director_workspace() {
  local workspace="$1"
  prepare_workspace "$workspace"
  mv "$workspace/docs/sample-feature" "$workspace/docs/director-feature"

  jq '
    del(.acceptance_criteria, .design_decisions, .non_functional_requirements, .review_conclusion, .issue_ledger, .delivery_confirmation)
    | .authoritative_fields = ["$.root_problem", "$.user_profile", "$.business_goals", "$.appetite", "$.scope_boundaries", "$.non_goals", "$.feasibility_constraints", "$.risks_and_unknowns", "$.decision_rationale", "$.delivery_plan", "$.director_confirmation"]
  ' "$workspace/docs/director-feature/brief.json" > "$workspace/docs/director-feature/brief.tmp.json"
  mv "$workspace/docs/director-feature/brief.tmp.json" "$workspace/docs/director-feature/brief.json"

  jq '
    .unit_index = []
    | del(.review_conclusion, .issue_ledger, .business_flows, .user_paths, .rule_mappings, .design_decision_candidates)
    | .authoritative_fields = ["$.phase_goal", "$.entry_conditions", "$.exit_conditions", "$.director_confirmation"]
  ' "$workspace/docs/director-feature/phase-1/phase-prd.json" > "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json"
  mv "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json" "$workspace/docs/director-feature/phase-1/phase-prd.json"
}

prepare_director_pm_polluted_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"

  jq '
    .business_flows = ["PM-owned business flow should not appear in Director output"]
    | .user_paths = ["PM-owned user path should not appear in Director output"]
    | .rule_mappings = ["PM-owned rule mapping should not appear in Director output"]
    | .design_decision_candidates = []
  ' "$workspace/docs/director-feature/phase-1/phase-prd.json" > "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json"
  mv "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json" "$workspace/docs/director-feature/phase-1/phase-prd.json"
}

prepare_director_template_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs/director-template-feature/phase-1"
  cp "$ROOT/contracts/canonical/templates/planning/director/brief.template.json" \
    "$workspace/docs/director-template-feature/brief.json"
  cp "$ROOT/contracts/canonical/templates/planning/director/phase-prd.template.json" \
    "$workspace/docs/director-template-feature/phase-1/phase-prd.json"
}

prepare_manager_unit_placeholder_workspace() {
  local workspace="$1"
  prepare_workspace "$workspace"

  jq '
    .integration_context.business_modules[0] = "tbd"
    | .acceptance_criteria[0].example_input = "todo"
    | .verification_plan[0].business_operation = "n/a"
  ' "$workspace/docs/sample-feature/phase-1/units/UNIT-1.json" > "$workspace/docs/sample-feature/phase-1/units/UNIT-1.tmp.json"
  mv "$workspace/docs/sample-feature/phase-1/units/UNIT-1.tmp.json" "$workspace/docs/sample-feature/phase-1/units/UNIT-1.json"
}

assert_standard_chain_control_contract() {
  assert_present 'phase_delivery_owner: delivery-owner' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'sidecar_dispatch' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'consistency-auditor' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'decision_authority: advisory_only' "$ROOT/contracts/standard-chain.yaml"
  assert_absent 'gate_escalation' "$ROOT/contracts/standard-chain.yaml"

  assert_present '# /delivery-owner -- 交付负责人' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present '运行时你扮演交付控制面' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present 'artifact-registry.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present 'consistency-audit-result.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present '^## Evidence Freshness$' "$ROOT/shared/skills/delivery-owner/references/signoff-contract.md"

  assert_present 'planning owner' "$ROOT/shared/skills/tech-lead/SKILL.md"
  assert_present 'Task 实现 owner' "$ROOT/shared/skills/developer/SKILL.md"
  assert_present '独立质量判断 owner' "$ROOT/shared/skills/qa/SKILL.md"
  assert_present 'canonical `brief.json.review_conclusion / issue_ledger`' "$ROOT/shared/skills/product-manager/references/review-orchestration-contract.md"
  assert_absent 'product-manager-review\.md' "$ROOT/shared/skills/product-manager/references/review-orchestration-contract.md"
}

assert_canonical_runtime_artifacts() {
  local file
  for file in \
    "$ROOT/contracts/canonical/templates/planning/director/brief.template.json" \
    "$ROOT/contracts/canonical/templates/planning/director/phase-prd.template.json" \
    "$ROOT/contracts/canonical/schemas/runtime/developer-report.schema.json" \
    "$ROOT/contracts/canonical/schemas/runtime/verify-result.schema.json" \
    "$ROOT/contracts/canonical/schemas/runtime/code-review-result.schema.json" \
    "$ROOT/contracts/canonical/schemas/runtime/qa-result.schema.json" \
    "$ROOT/contracts/canonical/schemas/runtime/consistency-audit-result.schema.json" \
    "$ROOT/contracts/canonical/schemas/runtime/fix-result.schema.json" \
    "$ROOT/contracts/canonical/templates/runtime/developer-report.template.json" \
    "$ROOT/contracts/canonical/templates/runtime/verify-result.template.json" \
    "$ROOT/contracts/canonical/templates/runtime/code-review-result.template.json" \
    "$ROOT/contracts/canonical/templates/runtime/qa-result.template.json" \
    "$ROOT/contracts/canonical/templates/runtime/consistency-audit-result.template.json" \
    "$ROOT/contracts/canonical/templates/runtime/fix-result.template.json"; do
    assert_json_ok "$file"
  done

  assert_present 'consistency-audit-result' "$ROOT/shared/runtime/standard-chain-catalog.json"
  assert_present 'active_plan_version_ref' "$ROOT/contracts/canonical/schemas/runtime/developer-report.schema.json"
  assert_present 'active_tasks_version_ref' "$ROOT/contracts/canonical/schemas/runtime/qa-result.schema.json"
  assert_present 'backward_compatibility' "$ROOT/contracts/canonical/schemas/runtime/code-review-result.schema.json"
  assert_present 'backward_compatibility' "$ROOT/contracts/canonical/templates/runtime/code-review-result.template.json"
  assert_present 'references/output-contract\.md#Director-Output Contract v1' "$ROOT/shared/skills/product-director/SKILL.md"
  assert_present 'contracts/canonical/templates/planning/director/brief.template.json' "$ROOT/shared/skills/product-director/references/output-contract.md"
  assert_present 'contracts/canonical/templates/planning/director/phase-prd.template.json' "$ROOT/shared/skills/product-director/references/output-contract.md"
  assert_absent '历史 product-artifact 兼容校验' "$ROOT/shared/skills/product-director/SKILL.md"
}

assert_canonical_only_scripts() {
  local script
  for script in \
    "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$ROOT/shared/skills/product-manager/scripts/completion_check.sh" \
    "$ROOT/shared/skills/design/scripts/completion_check.sh" \
    "$ROOT/shared/skills/test-design/scripts/completion_check.sh" \
    "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh" \
    "$ROOT/shared/skills/developer/scripts/completion_check.sh" \
    "$ROOT/shared/skills/review/scripts/completion_check.sh" \
    "$ROOT/shared/skills/qa/scripts/completion_check.sh"; do
    bash -n "$script"
    assert_present 'canonical' "$script"
    assert_absent 'ORG_ENABLE_LEGACY_MARKDOWN_HOOKS|legacy markdown|brief\.md|prd\.md|design\.md|plan\.md|test-cases\.md|developer-report-Task|qa-report\.md|code-review-report\.md|product-manager-review\.md' "$script"
    assert_absent 'first_matching_hook_path|grep -oE .*head -1|head -1 \|\| true' "$script"
  done
}

assert_canonical_hooks_pass() {
  SKILL_OUTPUT_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skill-output-canonical.XXXXXX")"
  trap 'rm -rf "$SKILL_OUTPUT_TMP_ROOT"' EXIT

  prepare_director_workspace "$SKILL_OUTPUT_TMP_ROOT/director"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director" "director-canonical" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/director" "product-director canonical gate"

  prepare_director_template_workspace "$SKILL_OUTPUT_TMP_ROOT/director-template"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-template" "director-template-canonical" \
    "docs/director-template-feature/brief.json\ndocs/director-template-feature/phase-1/phase-prd.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/director-template" "product-director advertised template gate"

  prepare_director_pm_polluted_workspace "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted" "director-pm-polluted" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted/hook.stdout" >&2
    fail "product-director gate should reject PM-owned phase-prd fields"
  fi
  assert_present 'contains Manager-owned closure, business semantics, design decisions, or non-empty unit_index' "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted/hook.stderr"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/manager"
  run_hook "$ROOT/shared/skills/product-manager/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/manager" "manager-canonical" \
    "docs/sample-feature/brief.json\ndocs/sample-feature/phase-1/phase-prd.json\ndocs/sample-feature/phase-1/units/UNIT-1.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/manager" "product-manager canonical gate"

  prepare_manager_unit_placeholder_workspace "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder"
  run_hook "$ROOT/shared/skills/product-manager/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder" "manager-unit-placeholder" \
    "docs/sample-feature/brief.json\ndocs/sample-feature/phase-1/phase-prd.json\ndocs/sample-feature/phase-1/units/UNIT-1.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder/hook.stdout" >&2
    fail "product-manager gate should reject UNIT placeholder semantic fields"
  fi
  assert_present 'UNIT.json PM-owned semantic fields are not closed' "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder/hook.stderr"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/design"
  run_hook "$ROOT/shared/skills/design/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/design" "design-canonical" \
    "docs/sample-feature/phase-1/design.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/design" "design canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/test-design"
  run_hook "$ROOT/shared/skills/test-design/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/test-design" "test-design-canonical" \
    "docs/sample-feature/phase-1/unit-1/test-cases.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/test-design" "test-design canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/tech-lead"
  run_hook "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/tech-lead" "tech-lead-canonical" \
    "docs/sample-feature/phase-1/plan.json\n" \
    "Write" "docs/sample-feature/phase-1/plan.json"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/tech-lead" "tech-lead canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/developer"
  prepare_git_trace_workspace "$SKILL_OUTPUT_TMP_ROOT/developer"
  run_hook "$ROOT/shared/skills/developer/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/developer" "developer-canonical" \
    "docs/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/developer" "developer canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/review"
  run_hook "$ROOT/shared/skills/review/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/review" "review-canonical" \
    "docs/sample-feature/phase-1/code-review-result.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/review" "review canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/qa"
  run_hook "$ROOT/shared/skills/qa/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/qa" "qa-canonical" \
    "docs/sample-feature/phase-1/qa-result.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/qa" "qa canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous"
  cp -R "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/docs/sample-feature" "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/docs/other-feature"
  run_hook "$ROOT/shared/skills/qa/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous" "qa-ambiguous-canonical" \
    "docs/sample-feature/phase-1/qa-result.json\ndocs/other-feature/phase-1/qa-result.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.stdout" >&2
    fail "qa canonical gate should block ambiguous Stop candidates"
  fi
  rg -n 'qa-result.json matched multiple candidates' "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.stderr" >/dev/null 2>&1 || {
    cat "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.stderr" >&2
    fail "qa canonical gate did not explain ambiguous candidates"
  }
}

assert_standard_chain_control_contract
assert_canonical_runtime_artifacts
assert_canonical_only_scripts
assert_canonical_hooks_pass

printf '[PASS] skill output and gate contract\n'
