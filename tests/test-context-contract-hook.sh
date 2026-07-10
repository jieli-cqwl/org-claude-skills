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
PROJECT="$TMP_DIR/project"
TRANSCRIPT="$TMP_DIR/transcript.jsonl"
mkdir -p "$PROJECT"
printf '{}\n' >"$TRANSCRIPT"
git -C "$PROJECT" init -q
git -C "$PROJECT" config user.email tests@example.invalid
git -C "$PROJECT" config user.name 'Context Hook Tests'
printf 'initial\n' >"$PROJECT/tracked.txt"
git -C "$PROJECT" add tracked.txt
git -C "$PROJECT" commit -qm initial
PROJECT_CANONICAL="$(cd "$PROJECT" && pwd -P)"

prompt_payload="$(jq -nc \
  --arg sid 'shell-session' \
  --arg tid 'turn-1' \
  --arg prompt 'token=secret-token-123 implement lifecycle' \
  --arg cwd "$PROJECT" \
  --arg transcript "$TRANSCRIPT" \
  '{session_id: $sid, turn_id: $tid, hook_event_name: "UserPromptSubmit", user_prompt: $prompt, cwd: $cwd, transcript_path: $transcript, permission_mode: "default", last_assistant_message: "previous"}')"
printf '%s' "$prompt_payload" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event UserPromptSubmit >"$TMP_DIR/context-prompt.out" \
  || fail "schema-2 prompt lifecycle should succeed"
jq -e '
  .hookSpecificOutput.hookEventName == "UserPromptSubmit"
  and (.hookSpecificOutput.additionalContext | contains("status: INCOMPLETE"))
  and (.hookSpecificOutput.additionalContext | contains("base_revision: 0"))
  and (.hookSpecificOutput.additionalContext | contains("session_id: shell-session"))
  and (.hookSpecificOutput.additionalContext | contains("turn_id: turn-1"))
  and (.hookSpecificOutput.additionalContext | contains("state-update --payload"))
  and (.hookSpecificOutput.additionalContext | contains("status: READY") | not)
' "$TMP_DIR/context-prompt.out" >/dev/null 2>&1 \
  || fail "prompt context should expose bounded non-ready update contract"

PENDING="$CONTEXT_STATE/shell-session/pending-turn.json"
[ -f "$PENDING" ] || fail "SessionStore should own one pending-turn generation"
jq -e --arg cwd "$PROJECT_CANONICAL" --arg transcript "$TRANSCRIPT" '
  .schema_version == "2.0"
  and .session_id == "shell-session"
  and .turn_id == "turn-1"
  and .cwd == $cwd
  and .transcript_path == $transcript
  and .base_revision == 0
  and (.prompt_sha256 | type == "string" and length == 64)
  and (.prompt_preview | contains("[REDACTED]"))
  and (.created_at | type == "string" and length > 0)
  and (.updated_at | type == "string" and length > 0)
' "$PENDING" >/dev/null 2>&1 || fail "pending turn should preserve bounded exact lifecycle identity"
assert_absent 'secret-token-123' "$PENDING"

stop_payload="$(jq -nc \
  --arg sid 'shell-session' \
  --arg tid 'turn-1' \
  --arg cwd "$PROJECT" \
  --arg transcript "$TRANSCRIPT" \
  '{session_id: $sid, turn_id: $tid, hook_event_name: "Stop", cwd: $cwd, transcript_path: $transcript, permission_mode: "default", last_assistant_message: "done"}')"
printf '%s' "$stop_payload" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event Stop >"$TMP_DIR/context-stop-before.out"
jq -e '
  .decision == "block"
  and .reason == "Context snapshot is not READY for this turn. Run the exact state-update command from the latest continuity context before finishing."
' "$TMP_DIR/context-stop-before.out" >/dev/null 2>&1 \
  || fail "Stop should block before a matching full update"

state_update_payload="$(jq -nc \
  --arg sid 'shell-session' \
  --arg tid 'turn-1' \
  '{
    session_id: $sid,
    turn_id: $tid,
    base_revision: 0,
    task: {
      task_status: "active",
      active_goal: "Enforce turn-bound context snapshots",
      scope_boundary: "Task 3 lifecycle only",
      non_goals: [],
      latest_user_correction: "",
      current_phase: "implementation",
      current_plan: ["implement", "verify"],
      completed_items: [{item: "tests written", evidence_refs: ["tests/test-context-contract-hook.sh"]}],
      pending_items: ["run gates"],
      blockers: [],
      next_action: "run lifecycle verification"
    }
  }')"
ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" state-update --payload "$state_update_payload" \
  >"$TMP_DIR/context-update.out" || fail "complete state-update should commit through CAS"
jq -e '
  .status == "READY"
  and .snapshot.schema_version == "2.0"
  and .snapshot.session_id == "shell-session"
  and .snapshot.turn_id == "turn-1"
  and .snapshot.revision == 1
  and .snapshot.base_revision == 0
' "$TMP_DIR/context-update.out" >/dev/null 2>&1 \
  || fail "state-update should return the exact ready snapshot identity"

printf '%s' "$stop_payload" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event Stop >"$TMP_DIR/context-stop-after.out"
jq -e 'length == 0' "$TMP_DIR/context-stop-after.out" >/dev/null 2>&1 \
  || fail "Stop should allow only after the current turn is ready"

jq -cn \
  '{type: "response_item", payload: {role: "user", content: [{type: "input_text", text: "transcript fallback turn"}], internal_chat_message_metadata_passthrough: {turn_id: "turn-3"}}}' \
  >"$TRANSCRIPT"
turn_three_stop="$(printf '%s' "$stop_payload" | jq -c '.turn_id = "turn-3"')"
printf '%s' "$turn_three_stop" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event Stop >"$TMP_DIR/context-transcript-fallback.out"
jq -e '
  .decision == "block"
  and (.reason | contains("state_update_command:"))
' "$TMP_DIR/context-transcript-fallback.out" >/dev/null 2>&1 \
  || fail "Stop should expose an update command after transcript pending recovery"
jq -e --arg tid "turn-3" '
  .turn_id == $tid
  and .base_revision == 1
' "$CONTEXT_STATE/shell-session/pending-turn.json" >/dev/null 2>&1 \
  || fail "transcript fallback should bind the current pending turn"
turn_three_update="$(printf '%s' "$state_update_payload" | jq -c '.turn_id = "turn-3" | .base_revision = 1')"
ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" state-update --payload "$turn_three_update" >/dev/null \
  || fail "transcript fallback turn should accept a complete state update"
printf '%s' "$turn_three_stop" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event Stop >"$TMP_DIR/context-transcript-fallback-ready.out"
jq -e 'length == 0' "$TMP_DIR/context-transcript-fallback-ready.out" >/dev/null 2>&1 \
  || fail "transcript fallback turn should become ready only after state update"

turn_two_payload="$(printf '%s' "$prompt_payload" | jq -c '.turn_id = "turn-2" | .user_prompt = "same prompt, new turn"')"
printf '%s' "$turn_two_payload" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event UserPromptSubmit >/dev/null
legacy_update="$(jq -nc \
  --arg sid 'shell-session' \
  --arg tid 'turn-2' \
  --arg cwd "$PROJECT" \
  --arg transcript "$TRANSCRIPT" \
  '{session_id: $sid, turn_id: $tid, hook_event_name: "StateUpdate", state: {active_goal: "schema-1 partial"}, cwd: $cwd, transcript_path: $transcript, permission_mode: "default", last_assistant_message: "legacy"}')"
printf '%s' "$legacy_update" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event StateUpdate >"$TMP_DIR/context-legacy.out"
jq -e 'length == 0' "$TMP_DIR/context-legacy.out" >/dev/null 2>&1 \
  || fail "legacy StateUpdate event should be ignored"
turn_two_stop="$(printf '%s' "$stop_payload" | jq -c '.turn_id = "turn-2"')"
printf '%s' "$turn_two_stop" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event Stop >"$TMP_DIR/context-legacy-stop.out"
jq -e '.decision == "block"' "$TMP_DIR/context-legacy-stop.out" >/dev/null 2>&1 \
  || fail "schema-1 partial StateUpdate evidence must never manufacture READY"

recover_output="$(ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" recover --session-id shell-session --turn-id turn-2)" \
  || fail "bounded recover should return lifecycle evidence"
printf '%s' "$recover_output" | jq -e '
  .status == "STALE"
  and .can_promote == false
  and .evidence.transcript_ref_present == true
' >/dev/null 2>&1 || fail "recover should report evidence without promoting state"
[ "$(printf '%s' "$recover_output" | wc -c | tr -d ' ')" -le 4096 ] \
  || fail "recover output should remain bounded"

if printf '%s %s' "$prompt_payload" "$prompt_payload" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event UserPromptSubmit >/dev/null 2>"$TMP_DIR/context-extra-json.err"; then
  fail "hook stdin should reject trailing JSON objects"
fi
assert_absent 'Traceback' "$TMP_DIR/context-extra-json.err"

missing_transcript="$(printf '%s' "$prompt_payload" | jq -c 'del(.transcript_path)')"
if printf '%s' "$missing_transcript" | \
  ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR="$CONTEXT_STATE" \
  python3 "$CONTEXT_CONTINUITY" --event UserPromptSubmit >/dev/null 2>"$TMP_DIR/context-missing-transcript.err"; then
  fail "UserPromptSubmit should fail closed without transcript_path"
fi
assert_absent 'Traceback' "$TMP_DIR/context-missing-transcript.err"

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
