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

WRAPPER="$ROOT/shared/hooks/managed/context_contract_validator.py"
[ -f "$WRAPPER" ] || fail "missing context contract hook wrapper"
PROMPT_TRACKER="$ROOT/shared/hooks/managed/codex_user_prompt_submit.py"
[ -f "$PROMPT_TRACKER" ] || fail "missing codex user prompt tracker"
STOP_DISPATCH="$ROOT/shared/hooks/managed/codex_stop_dispatch.py"
[ -f "$STOP_DISPATCH" ] || fail "missing codex stop dispatch hook"

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

mkdir -p "$ACTIVE_STATE"
cat >"$ACTIVE_STATE/unknown-session.json" <<'JSON'
{"session_id":"unknown-session","skill":"retired-skill","prompt":"$retired-skill"}
JSON
ORG_CODEX_ACTIVE_SKILLS_STATE_DIR="$ACTIVE_STATE" python3 "$STOP_DISPATCH" <<'JSON' >"$TMP_DIR/stop-dispatch-unknown.out"
{"session_id":"unknown-session","hook_event_name":"Stop","cwd":"/tmp"}
JSON
assert_present '{}' "$TMP_DIR/stop-dispatch-unknown.out"
assert_path_absent "$ACTIVE_STATE/unknown-session.json"

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
