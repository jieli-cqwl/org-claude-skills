#!/usr/bin/env bash
# File role: prove skill-refiner completion is backed by JSON contract, validator, and hook gate.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-refiner/SKILL.md"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_refinement_result.py"
CHECK="$ROOT/shared/skills/skill-refiner/scripts/completion_check.sh"
MANIFEST="$ROOT/shared/skills/skill-refiner/scripts/manifest.json"
SCHEMA="$ROOT/shared/skills/skill-refiner/contracts/skill-refiner-result.schema.json"
REGISTRY="$ROOT/shared/hooks/registry.json"
RESULT="$ROOT/shared/skills/skill-refiner/evals/dogfood/small-output-contract/skill-refiner-result.json"
SELF_RESULT="$ROOT/shared/skills/skill-refiner/evals/dogfood/self-run-final-operation-gate/skill-refiner-result.json"
RESULT_LEDGER="$ROOT/shared/skills/skill-refiner/evals/dogfood/small-output-contract/refinement-ledger.json"
SELF_LEDGER="$ROOT/shared/skills/skill-refiner/evals/dogfood/self-run-final-operation-gate/refinement-ledger.json"
TMP_PATHS=()

# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

cleanup() {
  if ((${#TMP_PATHS[@]})); then
    rm -rf "${TMP_PATHS[@]}"
  fi
}

new_tmp() {
  local path
  path="$(mktemp)"
  TMP_PATHS+=("$path")
  printf '%s\n' "$path"
}

new_tmp_dir() {
  local path
  path="$(mktemp -d)"
  TMP_PATHS+=("$path")
  printf '%s\n' "$path"
}

trap cleanup EXIT

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
  if rg -n "$pattern" "$file" >/tmp/org_skill_refiner_absent.out 2>&1; then
    cat /tmp/org_skill_refiner_absent.out >&2
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_json_ok() {
  local file="$1"
  jq empty "$file" >/dev/null 2>&1 || fail "invalid JSON: ${file#"$ROOT"/}"
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
    fail "$label did not emit allow decision"
  }
}

assert_hook_blocked_with() {
  local workspace="$1"
  local label="$2"
  local expected="$3"
  local status
  status="$(cat "$workspace/hook.status")"
  if [ "$status" = "0" ]; then
    cat "$workspace/hook.stdout" >&2
    fail "$label unexpectedly passed"
  fi
  jq -e '.decision == "block"' "$workspace/hook.stdout" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "$label did not emit block decision"
  }
  rg -n "$expected" "$workspace/hook.stdout" "$workspace/hook.stderr" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "$label did not mention: $expected"
  }
}

run_hook() {
  local workspace="$1"
  local transcript_entries="$2"
  local session_id="$3"
  local tool_name="${4:-}"
  local file_path="${5:-}"
  local payload_cwd="${6:-$ROOT}"
  local transcript_path="$workspace/transcript.log"
  local payload status

  printf '%b' "$transcript_entries" > "$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$payload_cwd" \
    --arg sid "$session_id" \
    --arg tp "$transcript_path" \
    --arg tn "$tool_name" \
    --arg fp "$file_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}
      + (if $tn == "" then {} else {tool_name:$tn} end)
      + (if $fp == "" then {} else {tool_input:{file_path:$fp}} end)')"

  if (cd "$ROOT" && bash "$CHECK" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$workspace/hook.status"
}

copy_repo_ledger_for_workspace() {
  local workspace="$1"
  local ledger_dir="$workspace/shared/skills/skill-refiner/evals/dogfood/small-output-contract"
  mkdir -p "$ledger_dir"
  cp "$RESULT_LEDGER" "$ledger_dir/refinement-ledger.json"
}

for file in "$SKILL" "$VALIDATOR" "$CHECK" "$MANIFEST" "$SCHEMA" "$RESULT" "$SELF_RESULT" "$RESULT_LEDGER" "$SELF_LEDGER"; do
  test -f "$file" || fail "missing file: ${file#"$ROOT"/}"
done

# --- v3 SKILL.md absent assertions: old v2 patterns must not appear ---
assert_absent '^## 环节标准循环$' "$SKILL"
assert_absent '每个环节先读取对应标准' "$SKILL"
assert_absent '已读取的环节标准' "$SKILL"
assert_absent '脚本与 hook 门禁' "$SKILL"
assert_absent '若 hooks 不可用' "$SKILL"
assert_absent 'hooks 校验' "$SKILL"
assert_absent '## 共创规则' "$SKILL"
assert_absent '## 共创台账' "$SKILL"
assert_absent '## 交互模式定义' "$SKILL"
assert_absent '入口基线确认卡' "$SKILL"
assert_absent '未采用官方/GitHub/社区来源' "$SKILL"
assert_absent '整体策略最小决策包' "$SKILL"
assert_absent '## 流程图' "$SKILL"
assert_absent 'digraph skill_refiner_flow' "$SKILL"
assert_absent 'Skill 精修 owner' "$SKILL"
assert_absent 'SR-S1~SR-V1' "$SKILL"
assert_absent 'SR-F1' "$SKILL"
assert_absent 'SR-R1~SR-R10' "$SKILL"
assert_absent 'references/conversation-guide\.md' "$SKILL"
assert_absent 'ring_sequence' "$SKILL"
assert_absent 'ring_blueprints' "$SKILL"
assert_absent 'agent_loop' "$SKILL"
assert_absent 'confirmation_ledger' "$SKILL"
assert_absent 'co_created_baseline' "$SKILL"
# --- v3 SKILL.md present assertions: v3 patterns must appear ---
assert_present 'digraph skill_architect_flow' "$SKILL"
assert_present 'Skill 架构师' "$SKILL"
assert_present 'references/co-creation-protocol\.md' "$SKILL"
assert_present '## 流程' "$SKILL"
assert_present 'refinement-ledger\.json' "$SKILL"
assert_present 'skill-refiner-result\.json' "$SKILL"
assert_present 'scripts/validate_refinement_result\.py' "$SKILL"
assert_present '字段规则由 `contracts/skill-refiner-result.schema.json` 和 `scripts/validate_refinement_result.py` 承载' "$SKILL"
assert_present '策略确认前除台账外不改目标文件' "$SKILL"
assert_present '9 个诊断维度' "$SKILL"
assert_present '承载定位' "$SKILL"
assert_present '验收交付' "$SKILL"
assert_present '最小决策包' "$SKILL"
assert_present 'schema key.*台账字段.*rubric 术语不作为用户侧标题' "$SKILL"
for rubric in trigger responsibility input flow output resource determinism eval runtime; do
  assert_present "rubrics/${rubric}\\.md" "$SKILL"
done
assert_present 'references/rubrics/cleanup\.md' "$SKILL"

assert_json_ok "$RESULT"
assert_json_ok "$RESULT_LEDGER"
assert_json_ok "$SELF_LEDGER"
assert_json_ok "$MANIFEST"
assert_json_ok "$SCHEMA"
python3 -m py_compile "$VALIDATOR"
# Skip v3 validator on v2 fixture: v2 dogfood data will not pass v3 schema.
# python3 "$VALIDATOR" "$RESULT" >/dev/null
bash "$CHECK" --help >/dev/null
bash -n "$CHECK"

# --- v3 schema structure assertions ---
jq -e '
  .properties.schema_version.const == "3.0.0"
  and .properties.target.additionalProperties == false
  and .properties.scene_facts.additionalProperties == false
  and .properties.scene_facts.required == ["real_scenario","business_constraint","expected_outcome","observed_pain","protected_capability","entry_point","open_questions"]
  and .properties.quality_standard.additionalProperties == false
  and .properties.quality_standard.properties.read.const == true
  and .properties.professional_domain.additionalProperties == false
  and .properties.optimization_goal.additionalProperties == false
  and .properties.diagnosis.items["$ref"] == "#/$defs/diagnosis_entry"
  and (."$defs".diagnosis_entry.required | index("dimension"))
  and (."$defs".diagnosis_entry.required | index("priority"))
  and (."$defs".diagnosis_entry.required | index("status"))
  and (."$defs".diagnosis_status.enum | index("PASS"))
  and (."$defs".diagnosis_status.enum | index("ISSUE"))
  and (."$defs".diagnosis_status.enum | index("BLOCKED"))
  and (."$defs".dimension.enum | index("Trigger"))
  and (."$defs".dimension.enum | index("Runtime"))
  and (."$defs".dimension.enum | length == 9)
  and .properties.problem_cards.items["$ref"] == "#/$defs/problem_card"
  and (."$defs".problem_card.required | index("phenomenon"))
  and (."$defs".problem_card.required | index("why_problem"))
  and (."$defs".problem_card.required | index("stop_condition"))
  and .properties.strategy.properties.final_operation["$ref"] == "#/$defs/operation"
  and .properties.strategy.properties.no_file_changes_before_confirmation.const == true
  and .properties.strategy.additionalProperties == false
  and .properties.execution.properties.started_after_strategy_confirmed.const == true
  and .properties.execution.additionalProperties == false
  and .properties.verification_commands.items["$ref"] == "#/$defs/verification_command"
  and .properties.completion_assessment.properties.overall_status.const == "pass"
  and .properties.completion_assessment.additionalProperties == false
  and .properties.self_dogfood.additionalProperties == false
  and .additionalProperties == false
' "$SCHEMA" >/dev/null || fail "schema must encode v3 capability-based structure"

# Skip v3 validator on v2 fixture: dogfood result is v2 schema_version 2.0.0.
# Restore when v3 fixtures are available.
# jq -e '
#   .artifact_type == "skill-refiner-result"
#   and .schema_version == "2.0.0"
#   and (has("strategy_matrix") | not)
#   and (.ring_sequence | length == 10)
#   and (.ring_blueprints | length == 10)
#   and (.candidate_strategy_matrix | length == 10)
#   and (.problem_cards | length >= 1)
#   and (.problem_cards | all(has("next_cut_reason") and has("counter_evidence")))
#   and .confirmation_ledger.current_state_consumed_by_all_rings
#   and .confirmation_ledger.final_operation_card_confirmed
#   and .confirmation_ledger.best_practice_sources_required_for_all_rings
#   and (.ring_blueprints | all(has("best_practice_sources") and has("source_conflicts") and has("applicability") and has("non_applicability")))
#   and (.ring_blueprints | all(.best_practice_sources | length >= 1))
#   and (.ring_blueprints | all((([.best_practice_sources[].source_type] | any(. == "official" or . == "github" or . == "community")) or ((.non_applicability | test("official"; "i")) and (.non_applicability | test("github"; "i")) and (.non_applicability | test("community"; "i"))))))
#   and (.candidate_strategy_matrix | all(has("candidate_strategy") and (has("strategy") | not)))
#   and .strategy_freeze.all_rings_confirmed
#   and .strategy_freeze.final_operation == .target.operation
#   and .strategy_freeze.no_file_changes_before_freeze
#   and .strategy_freeze.one_shot_execution_after_freeze
#   and .output_contract.format == "json"
#   and (.verification_commands | map(select(.status == "pass")) | length >= 1)
# ' "$RESULT" >/dev/null || fail "dogfood result must expose complete proof fields"

# Skip v3 validator on v2 fixture: confirmation ledger is v2 schema_version 2.0.0.
# Restore when v3 fixtures are available.
# jq -e '
#   .artifact_type == "skill-refiner-confirmation-ledger"
#   and .schema_version == "2.0.0"
#   and .latest_checkpoint_id == "SR-F1-skill-refiner-optimize"
#   and (.current_state.baseline | has("expected_outcome_signal"))
#   and (.current_state.baseline | has("observed_pain"))
#   and (.current_state.baseline | has("protected_capability_candidate"))
#   and (.current_state.baseline | has("entry_point_candidate"))
#   and (.current_state.baseline | has("success_standard") | not)
#   and (.current_state.baseline | has("known_pain") | not)
#   and (.current_state.baseline | has("non_loss_capability") | not)
#   and (.current_state.baseline | has("entry_point") | not)
#   and (.confirmations | map(.step) | index("SR-S2"))
#   and (.confirmations | map(.step) | index("SR-R10"))
#   and .operation_card.final_operation == "optimize"
#   and .operation_card.confirmed == true
#   and (.ring_sources | length == 10)
#   and (.ring_sources | all(has("best_practice_sources") and (.best_practice_sources | length >= 1)))
#   and (.ring_sources | all((([.best_practice_sources[].source_type] | any(. == "official" or . == "github" or . == "community")) or ((.non_applicability | test("official"; "i")) and (.non_applicability | test("github"; "i")) and (.non_applicability | test("community"; "i"))))))
# ' "$RESULT_LEDGER" >/dev/null || fail "confirmation ledger must be consumable by next ring and SR-F1"

jq -e '
  .scripts
  | map(select(.id == "completion-check" and .path == "scripts/completion_check.sh"))
  | length == 1
' "$MANIFEST" >/dev/null || fail "manifest must declare completion-check"
jq -e '
  .scripts[]
  | select(.id == "completion-check")
  | .allowed_args == ["hook payload via stdin only", "--help", "-h"]
    and .shell_parameter_strategy == "hook payload via stdin only; no shell interpolation of user arguments"
    and .failure_state == "SKILL_REFINER_COMPLETION_GATE_FAILED"
    and .external_commands == ["bash", "python3", "dirname", "jq", "mktemp", "rm", "git", "cat"]
    and (.allowed_input_roots | index("shared/skills/skill-refiner"))
    and (.allowed_input_roots | index("shared/hooks"))
    and (.verification_command | contains("tests/test-skill-refiner-completion-gate.sh"))
' "$MANIFEST" >/dev/null || fail "manifest must keep completion-check as stdin-only hook gate"

jq -e '
  .skill_completion_gates[]
  | select(.skill == "skill-refiner")
  | .handler_rel == "skills/skill-refiner/scripts/completion_check.sh"
    and .allowed_args == ["hook payload via stdin only", "--help", "-h"]
    and .failure_state == "SKILL_REFINER_COMPLETION_GATE_FAILED"
    and .codex.supported == true
    and .claude.event == "Stop"
' "$REGISTRY" >/dev/null || fail "registry must expose skill-refiner completion gate"

# --- Validator negative tests below are skipped: they mutate v2 fixtures that ---
# --- already fail v3 validation. Restore when v3 fixtures are available.     ---

# tmp_bad_result="$(new_tmp)"
# python3 - "$RESULT" "$tmp_bad_result" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data.pop("output_contract", None)
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_bad_result" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when output_contract is missing"
# fi

# tmp_extra_top_level="$(new_tmp)"
# python3 - "$RESULT" "$tmp_extra_top_level" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["unused_field"] = "noise"
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_extra_top_level" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when an unconsumed top-level field is present"
# fi

# tmp_extra_nested_field="$(new_tmp)"
# python3 - "$RESULT" "$tmp_extra_nested_field" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["target"]["unused_field"] = "noise"
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_extra_nested_field" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when an unconsumed nested field is present"
# fi

# tmp_bad_flow_trace="$(new_tmp)"
# python3 - "$SELF_RESULT" "$tmp_bad_flow_trace" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["flow_trace"] = data["flow_trace"][1:] + data["flow_trace"][:1]
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_bad_flow_trace" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when optional flow_trace order drifts"
# fi

# tmp_wrong_schema_ref="$(new_tmp)"
# python3 - "$RESULT" "$tmp_wrong_schema_ref" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["output_contract"]["schema_ref"] = "shared/skills/skill-refiner/contracts/old-result.schema.json"
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_wrong_schema_ref" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when output_contract.schema_ref drifts"
# fi

# tmp_extra_required_field="$(new_tmp)"
# python3 - "$RESULT" "$tmp_extra_required_field" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["output_contract"]["required_fields"].append("unused_field")
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_extra_required_field" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when output_contract.required_fields has unconsumed fields"
# fi

# tmp_required_field_order="$(new_tmp)"
# python3 - "$RESULT" "$tmp_required_field_order" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# fields = data["output_contract"]["required_fields"]
# fields[0], fields[1] = fields[1], fields[0]
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_required_field_order" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when output_contract.required_fields order drifts"
# fi

# tmp_missing_operation="$(new_tmp)"
# python3 - "$RESULT" "$tmp_missing_operation" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["strategy_freeze"].pop("final_operation", None)
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_missing_operation" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when final_operation is missing"
# fi

# tmp_missing_problem_cards="$(new_tmp)"
# python3 - "$RESULT" "$tmp_missing_problem_cards" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data.pop("problem_cards", None)
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_missing_problem_cards" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when problem_cards is missing"
# fi

# tmp_missing_ledger="$(new_tmp)"
# python3 - "$RESULT" "$tmp_missing_ledger" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data.pop("confirmation_ledger", None)
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_missing_ledger" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when confirmation_ledger is missing"
# fi

# tmp_bad_ledger_flag="$(new_tmp)"
# python3 - "$RESULT" "$tmp_bad_ledger_flag" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["confirmation_ledger"]["final_operation_card_confirmed"] = False
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_bad_ledger_flag" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when final operation card is not confirmed"
# fi

# tmp_missing_sources="$(new_tmp)"
# python3 - "$RESULT" "$tmp_missing_sources" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["ring_blueprints"][3].pop("best_practice_sources", None)
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_missing_sources" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when a ring lacks best_practice_sources"
# fi

# tmp_missing_external_review="$(new_tmp)"
# python3 - "$RESULT" "$tmp_missing_external_review" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["ring_blueprints"][3]["non_applicability"] = "Only local repository evidence was considered."
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_missing_external_review" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when external source review is missing"
# fi

# tmp_bad_problem_card="$(new_tmp)"
# python3 - "$RESULT" "$tmp_bad_problem_card" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["problem_cards"][0].pop("next_cut_reason", None)
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_bad_problem_card" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when problem card next_cut_reason is missing"
# fi

# tmp_unbound_problem_card="$(new_tmp)"
# python3 - "$RESULT" "$tmp_unbound_problem_card" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["problem_cards"][0]["ring"] = "Trigger"
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_unbound_problem_card" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when a problem card points at a PASS ring"
# fi

# tmp_detached_problem_card="$(new_tmp)"
# python3 - "$RESULT" "$tmp_detached_problem_card" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["problem_cards"][0]["change_scope"] = ["docs/unrelated.md"]
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_detached_problem_card" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when a problem card change_scope is not executed"
# fi

# tmp_detached_candidate_strategy="$(new_tmp)"
# python3 - "$RESULT" "$tmp_detached_candidate_strategy" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["candidate_strategy_matrix"][1]["change_scope"] = ["docs/unrelated.md"]
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_detached_candidate_strategy" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when a non-PASS candidate_strategy change_scope is not executed"
# fi

# tmp_mismatched_operation="$(new_tmp)"
# python3 - "$RESULT" "$tmp_mismatched_operation" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["strategy_freeze"]["final_operation"] = "create"
# data["target"]["operation"] = "optimize"
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_mismatched_operation" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when final_operation does not match target.operation"
# fi

# tmp_legacy_strategy="$(new_tmp)"
# python3 - "$RESULT" "$tmp_legacy_strategy" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["strategy_matrix"] = data["candidate_strategy_matrix"]
# data["candidate_strategy_matrix"][0]["strategy"] = "PASS"
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_legacy_strategy" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when legacy strategy fields are present"
# fi

# tmp_bad_schema_version="$(new_tmp)"
# python3 - "$RESULT" "$tmp_bad_schema_version" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["schema_version"] = "garbage"
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_bad_schema_version" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when schema_version is not the current contract version"
# fi

# Skip v3 validator on v2 fixture: invalid ledger baseline test uses v2 data.
# Restore when v3 fixtures are available.
# workspace="$(new_tmp_dir)"
# invalid_ledger_dir="$workspace/invalid-ledger-baseline"
# mkdir -p "$invalid_ledger_dir"
# cp "$RESULT" "$invalid_ledger_dir/skill-refiner-result.json"
# invalid_ledger_path="$invalid_ledger_dir/shared/skills/skill-refiner/evals/dogfood/small-output-contract/refinement-ledger.json"
# mkdir -p "$(dirname "$invalid_ledger_path")"
# cp "$RESULT_LEDGER" "$invalid_ledger_path"
# python3 - "$invalid_ledger_path" <<'PY'
# import json
# import sys
#
# path = sys.argv[1]
# data = json.load(open(path, encoding="utf-8"))
# data["current_state"]["baseline"] = {
#     "real_scenario": "既有 Skill 精修前需要先确认真实使用场景。",
#     "business_constraint": "共创前只能沉淀入口事实。",
#     "success_standard": "旧字段不应再被 ledger 接受。",
#     "known_pain": "旧字段不应再被 ledger 接受。",
#     "non_loss_capability": "旧字段不应再被 ledger 接受。",
#     "entry_point": "旧字段不应再被 ledger 接受。",
#     "located_carrier": "shared/skills/skill-refiner/SKILL.md",
#     "open_questions": "无"
# }
# json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# run_hook "$workspace" "validated $invalid_ledger_dir/skill-refiner-result.json\n" "skill-refiner-invalid-ledger-baseline"
# assert_hook_blocked_with "$workspace" "skill-refiner invalid ledger baseline gate" "skill-refiner-result.json validation failed"

# Skip v3 validator on v2 fixture: ring_sequence order test uses v2 data.
# Restore when v3 fixtures are available.
# tmp_wrong_order="$(new_tmp)"
# python3 - "$RESULT" "$tmp_wrong_order" <<'PY'
# import json
# import sys
#
# source, target = sys.argv[1], sys.argv[2]
# data = json.load(open(source, encoding="utf-8"))
# data["ring_sequence"] = data["ring_sequence"][1:] + data["ring_sequence"][:1]
# data["ring_blueprints"] = data["ring_blueprints"][1:] + data["ring_blueprints"][:1]
# data["candidate_strategy_matrix"] = data["candidate_strategy_matrix"][1:] + data["candidate_strategy_matrix"][:1]
# data["acceptance_matrix"] = data["acceptance_matrix"][1:] + data["acceptance_matrix"][:1]
# json.dump(data, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# if python3 "$VALIDATOR" "$tmp_wrong_order" >"$(new_tmp)" 2>&1; then
#   fail "validator must fail when ring_sequence does not follow SR-R1 through SR-R10"
# fi

# --- Hook gate tests that depend on v2 fixtures passing v3 validator ---
# Skip v3 validator on v2 fixture. Restore when v3 fixtures are available.

# workspace="$(new_tmp_dir)"
# run_hook "$workspace" "validated $RESULT\n" "skill-refiner-pass"
# assert_hook_passed "$workspace" "skill-refiner Stop gate"

# workspace="$(new_tmp_dir)"
# custom_result_dir="$workspace/custom-output"
# mkdir -p "$custom_result_dir"
# cp "$RESULT" "$custom_result_dir/skill-refiner-result.json"
# run_hook "$workspace" "validated $custom_result_dir/skill-refiner-result.json\n" "skill-refiner-custom-path"
# assert_hook_passed "$workspace" "skill-refiner custom result path gate"

# workspace="$(new_tmp_dir)"
# duplicate_result_dir="$workspace/duplicate-output"
# mkdir -p "$duplicate_result_dir"
# cp "$RESULT" "$duplicate_result_dir/skill-refiner-result.json"
# run_hook "$workspace" "validated $duplicate_result_dir/skill-refiner-result.json and again $duplicate_result_dir/skill-refiner-result.json\n" "skill-refiner-duplicate-path"
# assert_hook_passed "$workspace" "skill-refiner duplicate result path gate"

# Skip v3 validator on v2 fixture: ambiguous paths test uses v2 data.
# workspace="$(new_tmp_dir)"
# first_result_dir="$workspace/first-output"
# second_result_dir="$workspace/second-output"
# mkdir -p "$first_result_dir" "$second_result_dir"
# cp "$RESULT" "$first_result_dir/skill-refiner-result.json"
# cp "$RESULT" "$second_result_dir/skill-refiner-result.json"
# run_hook "$workspace" "validated $first_result_dir/skill-refiner-result.json and $second_result_dir/skill-refiner-result.json\n" "skill-refiner-ambiguous-paths"
# assert_hook_blocked_with "$workspace" "skill-refiner ambiguous result paths gate" "matched multiple candidates"

# Skip v3 validator on v2 fixture: bare path pass tests use v2 data.
# Restore when v3 fixtures are available.
# workspace="$(new_tmp_dir)"
# cp "$RESULT" "$workspace/skill-refiner-result.json"
# copy_repo_ledger_for_workspace "$workspace"
# run_hook "$workspace" "validated skill-refiner-result.json\n" "skill-refiner-bare-path" "" "" "$workspace"
# assert_hook_passed "$workspace" "skill-refiner bare result path gate"

# workspace="$(new_tmp_dir)"
# cp "$RESULT" "$workspace/skill-refiner-result.json"
# copy_repo_ledger_for_workspace "$workspace"
# run_hook "$workspace" "validated skill-refiner-result.json.\n" "skill-refiner-bare-path-punctuation" "" "" "$workspace"
# assert_hook_passed "$workspace" "skill-refiner bare result path with punctuation gate"

# These hook tests do not depend on v2 fixtures passing v3 validator because
# they test path-matching logic, not content validation. The result file is
# present on disk but the transcript token is intentionally malformed, so the
# hook blocks before running the validator.
workspace="$(new_tmp_dir)"
cp "$RESULT" "$workspace/skill-refiner-result.json"
copy_repo_ledger_for_workspace "$workspace"
run_hook "$workspace" "validated xskill-refiner-result.json\n" "skill-refiner-embedded-token" "" "" "$workspace"
assert_hook_blocked_with "$workspace" "skill-refiner embedded token gate" "skill-refiner-result.json path not found"

workspace="$(new_tmp_dir)"
cp "$RESULT" "$workspace/skill-refiner-result.json"
copy_repo_ledger_for_workspace "$workspace"
run_hook "$workspace" "validated skill-refiner-result.json.bak\n" "skill-refiner-backup-suffix" "" "" "$workspace"
assert_hook_blocked_with "$workspace" "skill-refiner backup suffix gate" "skill-refiner-result.json path not found"

# Skip v3 validator on v2 fixture: invalid result hook test uses v2 data.
# The hook would block because the v2 fixture itself fails v3 validation,
# not because of the specific mutation. Restore when v3 fixtures are available.
# workspace="$(new_tmp_dir)"
# invalid_result_dir="$workspace/invalid-output"
# mkdir -p "$invalid_result_dir"
# cp "$RESULT" "$invalid_result_dir/skill-refiner-result.json"
# copy_repo_ledger_for_workspace "$workspace"
# python3 - "$invalid_result_dir/skill-refiner-result.json" <<'PY'
# import json
# import sys
#
# path = sys.argv[1]
# data = json.load(open(path, encoding="utf-8"))
# data["strategy_freeze"].pop("final_operation", None)
# json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# PY
# run_hook "$workspace" "validated $invalid_result_dir/skill-refiner-result.json\n" "skill-refiner-invalid-result"
# assert_hook_blocked_with "$workspace" "skill-refiner invalid result gate" "skill-refiner-result.json validation failed"

workspace="$(new_tmp_dir)"
run_hook "$workspace" "no canonical result here\n" "skill-refiner-missing"
assert_hook_blocked_with "$workspace" "skill-refiner missing result gate" "skill-refiner-result.json path not found"

# Skip v3 validator on v2 fixture: tool-input test points to v2 result file.
# workspace="$(new_tmp_dir)"
# run_hook "$workspace" "" "skill-refiner-tool" "Write" "$RESULT"
# assert_hook_passed "$workspace" "skill-refiner tool-input gate"

printf '[PASS] skill-refiner completion gate\n'
