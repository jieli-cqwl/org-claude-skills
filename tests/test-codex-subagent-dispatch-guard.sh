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

assert_json_object_empty() {
  local file="$1"
  jq -e 'type == "object" and length == 0' "$file" >/dev/null 2>&1 || {
    cat "$file" >&2
    fail "expected allow payload: {}"
  }
}

assert_json_block() {
  local file="$1"
  local code="$2"
  jq -e --arg code "$code" '
    .decision == "block"
    and .failure_code == $code
    and (.reason | type == "string" and length > 0)
  ' "$file" >/dev/null 2>&1 || {
    cat "$file" >&2
    fail "expected block payload with failure_code=$code"
  }
}

write_active_skill() {
  local session_id="$1"
  local skill="$2"

  mkdir -p "$ACTIVE_STATE"
  jq -n --arg sid "$session_id" --arg skill "$skill" \
    '{session_id: $sid, skill: $skill, prompt: ("/" + $skill)}' \
    >"$ACTIVE_STATE/$session_id.json"
}

write_dispatch_auth() {
  local session_id="$1"
  local role="$2"
  local expires_at="$3"

  mkdir -p "$AUTH_STATE"
  jq -n \
    --arg sid "$session_id" \
    --arg role "$role" \
    --arg task "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1" \
    --arg expires "$expires_at" \
    '{
      schema_version: 1,
      session_id: $sid,
      role: $role,
      task_ref: $task,
      authorized_by: "delivery-owner",
      created_at: "2026-07-03T00:00:00+00:00",
      expires_at: $expires
    }' >"$AUTH_STATE/$session_id.json"
}

run_guard() {
  local payload="$1"
  local output="$2"

  printf '%s' "$payload" | \
    ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" \
    ORG_CODEX_DISPATCH_AUTH_STATE_DIR="$AUTH_STATE" \
    python3 "$GUARD" >"$output"
}

GUARD="$ROOT/shared/hooks/managed/codex_subagent_dispatch_guard.py"
[ -f "$GUARD" ] || fail "missing codex subagent dispatch guard"

ACTIVE_STATE="$TMP_DIR/active-skills"
AUTH_STATE="$TMP_DIR/dispatch-auth"

run_guard '{"session_id":"free-session","agent_name":"researcher"}' "$TMP_DIR/free.out"
assert_json_object_empty "$TMP_DIR/free.out"

run_guard '{"agent_name":"developer"}' "$TMP_DIR/missing-session.out"
assert_json_block "$TMP_DIR/missing-session.out" "MISSING_SESSION"

run_guard '{"session_id":"missing-active","agent_name":"developer"}' "$TMP_DIR/missing-active.out"
assert_json_block "$TMP_DIR/missing-active.out" "MISSING_DELIVERY_OWNER"

write_active_skill "wrong-skill" "review"
write_dispatch_auth "wrong-skill" "developer" "2999-01-01T00:00:00+00:00"
run_guard '{"session_id":"wrong-skill","agent_name":"developer"}' "$TMP_DIR/wrong-skill.out"
assert_json_block "$TMP_DIR/wrong-skill.out" "MISSING_DELIVERY_OWNER"

write_active_skill "role-mismatch" "delivery-owner"
write_dispatch_auth "role-mismatch" "qa" "2999-01-01T00:00:00+00:00"
run_guard '{"session_id":"role-mismatch","subagent":{"name":"developer"}}' "$TMP_DIR/role-mismatch.out"
assert_json_block "$TMP_DIR/role-mismatch.out" "ROLE_MISMATCH"

write_active_skill "expired-auth" "delivery-owner"
write_dispatch_auth "expired-auth" "developer" "2000-01-01T00:00:00+00:00"
run_guard '{"session_id":"expired-auth","tool_input":{"agent":"developer"}}' "$TMP_DIR/expired-auth.out"
assert_json_block "$TMP_DIR/expired-auth.out" "AUTH_EXPIRED"

write_active_skill "ok-session" "delivery-owner"
write_dispatch_auth "ok-session" "developer" "2999-01-01T00:00:00+00:00"
run_guard '{"session_id":"ok-session","agent_name":"developer"}' "$TMP_DIR/ok-session.out"
assert_json_object_empty "$TMP_DIR/ok-session.out"
[ ! -e "$AUTH_STATE/ok-session.json" ] || fail "dispatch authorization should be consumed after successful protected agent start"

echo "[PASS] codex subagent dispatch guard"
