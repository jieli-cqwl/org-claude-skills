#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Fq "$pattern" "$file" || {
    cat "$file" >&2
    fail "expected pattern missing: $pattern"
  }
}

assert_path_absent() {
  local path="$1"
  [ ! -e "$path" ] || fail "expected path absent: $path"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Fq "$pattern" "$file"; then
    cat "$file" >&2
    fail "unexpected pattern present: $pattern"
  fi
}

WRAPPER="$ROOT/shared/hooks/managed/context_contract_validator.py"
[ -f "$WRAPPER" ] || fail "missing context contract hook wrapper"
PROMPT_TRACKER="$ROOT/shared/hooks/managed/codex_user_prompt_submit.py"
[ -f "$PROMPT_TRACKER" ] || fail "missing codex user prompt tracker"
STOP_DISPATCH="$ROOT/shared/hooks/managed/codex_stop_dispatch.py"
[ -f "$STOP_DISPATCH" ] || fail "missing codex stop dispatch hook"
CONTEXT_CONTINUITY="$ROOT/shared/hooks/managed/codex_context_continuity.py"
[ -f "$CONTEXT_CONTINUITY" ] || fail "missing codex context continuity hook"

mkdir -p "$TMP_DIR/no-contract"
python3 "$WRAPPER" <<JSON >"$TMP_DIR/no-contract.out"
{"cwd":"$TMP_DIR/no-contract","stop_hook_active":false}
JSON
assert_present "{}" "$TMP_DIR/no-contract.out"

mkdir -p "$TMP_DIR/invalid/contracts"
cat >"$TMP_DIR/invalid/contracts/active-doc-scope.yaml" <<'EOF'
version: 1
EOF

python3 "$WRAPPER" <<JSON >"$TMP_DIR/invalid-posttool.out"
{"cwd":"$TMP_DIR/invalid","hook_event_name":"PostToolUse","tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch"}}
JSON
assert_present '"decision": "block"' "$TMP_DIR/invalid-posttool.out"
assert_present '"hookEventName": "PostToolUse"' "$TMP_DIR/invalid-posttool.out"
assert_present 'scope_registry_schema_invalid' "$TMP_DIR/invalid-posttool.out"

python3 "$WRAPPER" <<JSON >"$TMP_DIR/invalid-stop.out"
{"cwd":"$TMP_DIR/invalid","hook_event_name":"Stop","stop_hook_active":false}
JSON
assert_present '"decision": "block"' "$TMP_DIR/invalid-stop.out"
assert_present 'scope_registry_schema_invalid' "$TMP_DIR/invalid-stop.out"

printf '{}' | python3 "$STOP_DISPATCH" >"$TMP_DIR/stop-dispatch-missing-session.out"
assert_present '"decision": "block"' "$TMP_DIR/stop-dispatch-missing-session.out"
assert_present 'session_id' "$TMP_DIR/stop-dispatch-missing-session.out"

ACTIVE_STATE="$TMP_DIR/active-skills"
ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" python3 "$PROMPT_TRACKER" <<'JSON'
{"session_id":"dollar-session","prompt":"$developer implement task"}
JSON
assert_present '"skill": "developer"' "$ACTIVE_STATE/dollar-session.json"

ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" python3 "$PROMPT_TRACKER" <<'JSON'
{"session_id":"slash-session","prompt":"/review inspect this change"}
JSON
assert_present '"skill": "review"' "$ACTIVE_STATE/slash-session.json"

ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" python3 "$PROMPT_TRACKER" <<'JSON'
{"session_id":"director-brainstorm-session","prompt":"/product-director 我想先脑暴一个权限矩阵配置中心"}
JSON
assert_path_absent "$ACTIVE_STATE/director-brainstorm-session.json"

ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" python3 "$PROMPT_TRACKER" <<'JSON'
{"session_id":"delivery-owner-session","prompt":"/delivery-owner 执行冻结任务批次"}
JSON
assert_present '"skill": "delivery-owner"' "$ACTIVE_STATE/delivery-owner-session.json"

CONTEXT_STATE="$TMP_DIR/context-continuity"
mkdir -p "$TMP_DIR/project"
latest_correction='不对，这里核心不是迁移，而是 LLM 上下文窗口治理'
user_prompt_payload="$(jq -nc \
  --arg sid "continuity-session" \
  --arg prompt "$latest_correction" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "UserPromptSubmit", prompt: $prompt, cwd: $cwd}')"
printf '%s' "$user_prompt_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >"$TMP_DIR/context-user-prompt.out"
context_card="$CONTEXT_STATE/continuity-session.json"
[ -f "$context_card" ] || fail "context continuity should write task state card"
jq -e --arg correction "$latest_correction" '
  .schema_version == "1.0"
  and .session_id == "continuity-session"
  and (.last_user_prompt_hash | type == "string" and length == 64)
  and .last_user_prompt_preview == $correction
  and .active_goal == ""
  and .scope_boundary == ""
  and .non_goals == []
  and .latest_user_correction == ""
  and .current_phase == ""
  and .current_plan == []
  and .completed_items == []
  and .evidence_refs == []
  and .pending_items == []
  and .blockers == []
  and .next_action == ""
  and (.truth_policy | contains("禁止猜测"))
  and (.recovery_contract.required_questions | index("当前目标是什么？") != null)
  and (.recovery_contract.required_questions | index("最新用户纠偏是什么？") != null)
  and (.recovery_contract.required_questions | index("当前做到哪一步？") != null)
  and (.recovery_contract.required_questions | index("哪些已经完成且证据在哪？") != null)
  and (.recovery_contract.required_questions | index("哪些未完成或被阻塞？") != null)
  and (.recovery_contract.required_questions | index("下一步是什么？") != null)
' "$context_card" >/dev/null 2>&1 || fail "context continuity should persist a structured recovery contract without fake progress"

missing_session_payload='{"hook_event_name":"UserPromptSubmit","prompt":"no session"}'
if printf '%s' "$missing_session_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >/dev/null 2>"$TMP_DIR/context-missing-session.err"; then
  fail "missing session id should fail visibly"
fi
assert_present "missing session_id" "$TMP_DIR/context-missing-session.err"
assert_path_absent "$CONTEXT_STATE/unknown-session.json"

secret_prompt_payload="$(jq -nc \
  --arg sid "privacy-session" \
  --arg prompt "secret-token-123 should not be stored in full" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "UserPromptSubmit", prompt: $prompt, cwd: $cwd}')"
printf '%s' "$secret_prompt_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >/dev/null \
  || fail "privacy prompt should be recorded as redacted metadata"
assert_absent "secret-token-123" "$CONTEXT_STATE/privacy-session.json"
jq -e '
  (.last_user_prompt_hash | type == "string" and length == 64)
  and (.last_user_prompt_preview | contains("[REDACTED]"))
' "$CONTEXT_STATE/privacy-session.json" >/dev/null 2>&1 || fail "prompt preview should be short and redacted"

raw_secret_prompt='openai sk-proj-abcdefghijklmnopqrstuvwxyz123456 github ghp_abcdefghijklmnopqrstuvwxyz123456 bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature -----BEGIN PRIVATE KEY-----PRIVATEKEYMATERIALSHOULDNOTLEAK'
raw_secret_payload="$(jq -nc \
  --arg sid "raw-secret-session" \
  --arg prompt "$raw_secret_prompt" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "UserPromptSubmit", prompt: $prompt, cwd: $cwd}')"
printf '%s' "$raw_secret_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >/dev/null \
  || fail "raw secret prompt should be recorded as redacted metadata"
assert_absent "sk-proj-abcdefghijklmnopqrstuvwxyz123456" "$CONTEXT_STATE/raw-secret-session.json"
assert_absent "ghp_abcdefghijklmnopqrstuvwxyz123456" "$CONTEXT_STATE/raw-secret-session.json"
assert_absent "eyJhbGciOiJIUzI1NiJ9" "$CONTEXT_STATE/raw-secret-session.json"
assert_absent "BEGIN PRIVATE KEY" "$CONTEXT_STATE/raw-secret-session.json"
assert_absent "PRIVATEKEYMATERIALSHOULDNOTLEAK" "$CONTEXT_STATE/raw-secret-session.json"
jq -e '
  (.last_user_prompt_hash | type == "string" and length == 64)
  and (.last_user_prompt_preview | contains("[REDACTED]"))
' "$CONTEXT_STATE/raw-secret-session.json" >/dev/null 2>&1 || fail "raw secret prompt preview should be redacted"

PROBE_DIR="$TMP_DIR/context-payload-probe"
probe_payload="$(jq -nc \
  --arg sid "probe-session" \
  --arg prompt "secret-token-123 should not be stored in full" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "UserPromptSubmit", prompt: $prompt, cwd: $cwd, nested: {token: "secret-token-123"}}')"
printf '%s' "$probe_payload" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  ORG_CODEX_CONTEXT_CONTINUITY_PAYLOAD_PROBE_DIR="$PROBE_DIR" \
  python3 "$CONTEXT_CONTINUITY" >/dev/null
probe_file="$(find "$PROBE_DIR" -type f -name '*.json' -print -quit 2>/dev/null || true)"
[ -n "$probe_file" ] || fail "payload probe should write a redacted probe record"
jq -e '
  .session_id_present == true
  and .event == "UserPromptSubmit"
  and (.payload_keys | index("prompt") != null)
  and (. | tostring | contains("secret-token-123") | not)
' "$probe_file" >/dev/null 2>&1 || fail "payload probe should record redacted metadata only"

stop_payload="$(jq -nc \
  --arg sid "continuity-session" \
  --arg cwd "$TMP_DIR/project" \
  --arg transcript "$TMP_DIR/transcript.jsonl" \
  '{session_id: $sid, hook_event_name: "Stop", cwd: $cwd, transcript_path: $transcript}')"
printf '%s' "$stop_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >"$TMP_DIR/context-stop.out"
jq -e --arg transcript "$TMP_DIR/transcript.jsonl" '
  .last_stop.transcript_path == $transcript
  and .last_stop.cwd
' "$context_card" >/dev/null 2>&1 || fail "context continuity should checkpoint stop metadata"

unknown_state_payload="$(jq -nc \
  --arg sid "continuity-session" \
  '{session_id: $sid, hook_event_name: "StateUpdate", state: {active_goal: "目标", unsupported_field: "must fail"}}')"
if printf '%s' "$unknown_state_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >/dev/null 2>"$TMP_DIR/context-state-unknown.err"; then
  fail "unknown recovery state fields should fail visibly"
fi
assert_present "unsupported state field" "$TMP_DIR/context-state-unknown.err"

bad_type_state_payload="$(jq -nc \
  --arg sid "continuity-session" \
  '{session_id: $sid, hook_event_name: "StateUpdate", state: {current_plan: "not-a-list"}}')"
if printf '%s' "$bad_type_state_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >/dev/null 2>"$TMP_DIR/context-state-bad-type.err"; then
  fail "wrong recovery state field types should fail visibly"
fi
assert_present "state field current_plan must be a list" "$TMP_DIR/context-state-bad-type.err"

active_goal='确保 Codex 压缩上下文后仍能恢复目标、计划、证据和下一步'
scope_boundary='只治理 Codex hook 状态与安装，不替代 Codex memories'
current_phase='实现前验证'
next_action='补实现并跑 focused tests'
state_update_payload="$(jq -nc \
  --arg sid "continuity-session" \
  --arg goal "$active_goal" \
  --arg scope "$scope_boundary" \
  --arg correction "$latest_correction" \
  --arg phase "$current_phase" \
  --arg next "$next_action" \
  '{
    session_id: $sid,
    hook_event_name: "StateUpdate",
    source: "codex-agent",
    state: {
      active_goal: $goal,
      scope_boundary: $scope,
      latest_user_correction: $correction,
      current_phase: $phase,
      current_plan: ["补状态写入器", "持久 opt-in", "恢复注入增强"],
      completed_items: ["已确认 Codex PreCompact/PostCompact/SessionStart 事件面"],
      evidence_refs: ["tests/test-context-contract-hook.sh"],
      pending_items: ["实现状态写入器", "重新安装验证"],
      blockers: [],
      next_action: $next,
      git_head: "test-head",
      truth_policy: "恢复时优先读取 task_state_ref 和证据引用；证据不足必须报告 blocked，禁止猜测。"
    }
  }')"
printf '%s' "$state_update_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >"$TMP_DIR/context-state-update.out" \
  || fail "state update should write controlled recovery fields"
jq -e --arg goal "$active_goal" --arg scope "$scope_boundary" --arg phase "$current_phase" --arg next "$next_action" '
  .active_goal == $goal
  and .scope_boundary == $scope
  and .current_phase == $phase
  and .next_action == $next
  and (.current_plan | length == 3)
  and (.completed_items | length == 1)
  and (.evidence_refs | index("tests/test-context-contract-hook.sh") != null)
  and (.pending_items | length == 2)
  and .blockers == []
  and .git_head == "test-head"
  and (.state_updates[-1].source == "codex-agent")
  and (.state_updates[-1].updated_fields | index("active_goal") != null)
' "$context_card" >/dev/null 2>&1 || fail "state update should populate recovery fields and audit metadata"

precompact_payload="$(jq -nc \
  --arg sid "continuity-session" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "PreCompact", trigger: "auto", cwd: $cwd}')"
printf '%s' "$precompact_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" >"$TMP_DIR/context-precompact.out"
precompact_card="$CONTEXT_STATE/latest-precompact-continuity-session.json"
[ -f "$precompact_card" ] || fail "PreCompact should seal a latest checkpoint"
assert_present '"checkpoint_event": "PreCompact"' "$precompact_card"
assert_present "$latest_correction" "$precompact_card"
jq -e --arg checkpoint "$precompact_card" '.precompact.checkpoint_ref == $checkpoint' "$context_card" >/dev/null 2>&1 \
  || fail "task state card should reference latest precompact checkpoint"

compact_summary='full compact summary must remain metadata only'
postcompact_payload="$(jq -nc \
  --arg sid "continuity-session" \
  --arg cwd "$TMP_DIR/project" \
  --arg summary "$compact_summary" \
  '{session_id: $sid, hook_event_name: "PostCompact", trigger: "auto", cwd: $cwd, compact_summary: $summary}')"
postcompact_output="$(printf '%s' "$postcompact_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY")" \
  || fail "PostCompact continuity hook should record compact metadata"
printf '%s' "$postcompact_output" >"$TMP_DIR/context-postcompact.out"
[ -z "$postcompact_output" ] || fail "PostCompact continuity hook must not emit hook-specific additionalContext"
assert_absent "$compact_summary" "$TMP_DIR/context-postcompact.out"
assert_absent "$compact_summary" "$context_card"
compact_ref="$(jq -r '.postcompact.compact_summary_ref' "$context_card")"
[ -f "$compact_ref" ] || fail "PostCompact should persist compact metadata ref"
jq -e --arg summary "$compact_summary" '
  .session_id == "continuity-session"
  and .hook_event_name == "PostCompact"
  and .summary_length == ($summary | length)
  and (.summary_sha256 | type == "string" and length == 64)
  and (. | has("compact_summary") | not)
' "$compact_ref" >/dev/null 2>&1 || fail "PostCompact should store compact metadata without full summary by default"

sessionstart_payload="$(jq -nc \
  --arg sid "continuity-session" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "SessionStart", source: "compact", cwd: $cwd}')"
sessionstart_output="$(printf '%s' "$sessionstart_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY")" \
  || fail "SessionStart compact continuity hook should emit recovery context"
printf '%s' "$sessionstart_output" >"$TMP_DIR/context-sessionstart.out"
printf '%s' "$sessionstart_output" | jq -e '
  .hookSpecificOutput.hookEventName == "SessionStart"
  and (.hookSpecificOutput.additionalContext | contains("task_state_ref:"))
  and (.hookSpecificOutput.additionalContext | contains("precompact_checkpoint_ref:"))
  and (.hookSpecificOutput.additionalContext | contains("compact_summary_ref:"))
  and (.hookSpecificOutput.additionalContext | contains("recovery_missing_fields: none"))
  and (.hookSpecificOutput.additionalContext | contains("active_goal: 确保 Codex 压缩上下文后仍能恢复目标、计划、证据和下一步"))
  and (.hookSpecificOutput.additionalContext | contains("current_phase: 实现前验证"))
  and (.hookSpecificOutput.additionalContext | contains("next_action: 补实现并跑 focused tests"))
  and (.hookSpecificOutput.additionalContext | contains("blockers: none"))
  and (.hookSpecificOutput.additionalContext | contains("不要猜测"))
' >/dev/null 2>&1 || fail "SessionStart compact hook should point Codex at structured recovery refs"
assert_absent "$compact_summary" "$TMP_DIR/context-sessionstart.out"
jq -e --arg state "$context_card" --arg checkpoint "$precompact_card" --arg compact "$compact_ref" '
  .last_recovery_injection.hook_event_name == "SessionStart"
  and .last_recovery_injection.source == "compact"
  and .last_recovery_injection.task_state_ref == $state
  and .last_recovery_injection.precompact_checkpoint_ref == $checkpoint
  and .last_recovery_injection.compact_summary_ref == $compact
  and (.last_recovery_injection.additional_context_sha256 | type == "string" and length == 64)
' "$context_card" >/dev/null 2>&1 || fail "SessionStart compact hook should persist recovery injection evidence"
sessionstart_no_source_payload="$(jq -nc \
  --arg sid "continuity-session" \
  --arg cwd "$TMP_DIR/project" \
  '{session_id: $sid, hook_event_name: "SessionStart", cwd: $cwd}')"
sessionstart_arg_output="$(printf '%s' "$sessionstart_no_source_payload" | ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" python3 "$CONTEXT_CONTINUITY" --event SessionStart --source compact)" \
  || fail "SessionStart compact source arg should emit recovery context"
printf '%s' "$sessionstart_arg_output" | jq -e '.hookSpecificOutput.additionalContext | contains("task_state_ref:")' >/dev/null 2>&1 \
  || fail "SessionStart source arg should drive compact recovery"

mkdir -p "$ACTIVE_STATE"
cat >"$ACTIVE_STATE/unknown-session.json" <<'JSON'
{"session_id":"unknown-session","skill":"retired-skill","prompt":"$retired-skill"}
JSON
ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" python3 "$STOP_DISPATCH" <<'JSON' >"$TMP_DIR/stop-dispatch-unknown.out"
{"session_id":"unknown-session","hook_event_name":"Stop","cwd":"/tmp"}
JSON
assert_present '{}' "$TMP_DIR/stop-dispatch-unknown.out"
assert_path_absent "$ACTIVE_STATE/unknown-session.json"

NON_STOP_RUNTIME="$TMP_DIR/non-stop-runtime"
mkdir -p "$NON_STOP_RUNTIME/hooks/managed"
cp "$STOP_DISPATCH" "$NON_STOP_RUNTIME/hooks/managed/codex_stop_dispatch.py"
cat >"$NON_STOP_RUNTIME/hooks/registry.json" <<'JSON'
{
  "skill_completion_gates": [
    {
      "skill": "product-director",
      "handler_rel": "skills/product-director/scripts/completion_check.sh",
      "timeout_sec": 5,
      "codex": {"supported": true},
      "claude": {"supported": true, "event": "PostToolUse", "matcher": "Edit|Write"}
    }
  ]
}
JSON
cat >"$ACTIVE_STATE/director-stale-session.json" <<'JSON'
{"session_id":"director-stale-session","skill":"product-director","prompt":"/product-director brainstorm only"}
JSON
ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" \
  python3 "$NON_STOP_RUNTIME/hooks/managed/codex_stop_dispatch.py" <<'JSON' >"$TMP_DIR/stop-dispatch-non-stop.out"
{"session_id":"director-stale-session","hook_event_name":"Stop","cwd":"/tmp"}
JSON
assert_present '{}' "$TMP_DIR/stop-dispatch-non-stop.out"
assert_path_absent "$ACTIVE_STATE/director-stale-session.json"

ESCAPE_RUNTIME="$TMP_DIR/escape-runtime"
mkdir -p "$ESCAPE_RUNTIME/hooks/managed"
cp "$STOP_DISPATCH" "$ESCAPE_RUNTIME/hooks/managed/codex_stop_dispatch.py"
cat >"$ESCAPE_RUNTIME/hooks/registry.json" <<'JSON'
{
  "skill_completion_gates": [
    {
      "skill": "escape-skill",
      "handler_rel": "../outside-gate.sh",
      "timeout_sec": 5,
      "codex": {"supported": true}
    }
  ]
}
JSON
cat >"$TMP_DIR/outside-gate.sh" <<'EOF'
#!/usr/bin/env bash
printf '{"decision":"block","reason":"OUTSIDE_GATE_EXECUTED"}\n'
EOF
chmod +x "$TMP_DIR/outside-gate.sh"
cat >"$ACTIVE_STATE/escape-session.json" <<'JSON'
{"session_id":"escape-session","skill":"escape-skill","prompt":"$escape-skill"}
JSON
ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" \
  python3 "$ESCAPE_RUNTIME/hooks/managed/codex_stop_dispatch.py" <<'JSON' >"$TMP_DIR/stop-dispatch-escape.out"
{"session_id":"escape-session","hook_event_name":"Stop","cwd":"/tmp"}
JSON
assert_present '"decision": "block"' "$TMP_DIR/stop-dispatch-escape.out"
assert_present '配置无效' "$TMP_DIR/stop-dispatch-escape.out"
if grep -Fq 'OUTSIDE_GATE_EXECUTED' "$TMP_DIR/stop-dispatch-escape.out"; then
  fail "stop dispatcher must not execute completion gates outside runtime home"
fi

echo "[PASS] context contract hook"
