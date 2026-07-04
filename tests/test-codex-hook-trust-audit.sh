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

run_audit() {
  local json_file="$1"
  shift

  python3 "$ROOT/tools/community/audit_codex_hook_trust.py" --from-json "$json_file" "$@" >"$TMP_DIR/audit.out" 2>"$TMP_DIR/audit.err"
}

cat > "$TMP_DIR/ready.json" <<'JSON'
{
  "data": [
    {
      "cwd": "/repo",
      "hooks": [
        {
          "eventName": "preToolUse",
          "matcher": "Bash",
          "command": "bash /tmp/codex/hooks/managed/block_dangerous.sh",
          "enabled": true,
          "trustStatus": "trusted"
        },
        {
          "eventName": "stop",
          "matcher": null,
          "command": "python3 /tmp/codex/hooks/managed/codex_stop_dispatch.py",
          "enabled": true,
          "trustStatus": "managed"
        },
        {
          "eventName": "subagentStart",
          "matcher": null,
          "command": "python3 /tmp/codex/hooks/managed/codex_subagent_dispatch_guard.py",
          "enabled": true,
          "trustStatus": "trusted"
        },
        {
          "eventName": "stop",
          "matcher": null,
          "command": "python3 /tmp/disabled.py",
          "enabled": false,
          "trustStatus": "untrusted"
        }
      ],
      "warnings": [],
      "errors": []
    }
  ]
}
JSON

run_audit "$TMP_DIR/ready.json" \
  --require-ready \
  --require-all-enabled \
  --expected-command "bash /tmp/codex/hooks/managed/block_dangerous.sh" \
  --expected-command "python3 /tmp/codex/hooks/managed/codex_subagent_dispatch_guard.py" \
  --expected-command "python3 /tmp/codex/hooks/managed/codex_stop_dispatch.py" \
  || fail "ready trusted/managed hooks should pass"
grep -Fq 'ready=3 not_ready=0 extra_not_ready=0' "$TMP_DIR/audit.out" || fail "ready audit should report all audited hooks ready"

cat > "$TMP_DIR/untrusted.json" <<'JSON'
{
  "result": {
    "data": [
      {
        "cwd": "/repo",
        "hooks": [
          {
            "eventName": "postToolUse",
            "matcher": "Write|Edit",
            "command": "python3 /tmp/codex/hooks/managed/context_contract_validator.py",
            "enabled": true,
            "trustStatus": "untrusted"
          }
        ],
        "warnings": [],
        "errors": []
      }
    ]
  }
}
JSON

set +e
run_audit "$TMP_DIR/untrusted.json" --require-ready --require-all-enabled
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "untrusted enabled hook should return needs-review exit code"
grep -Fq '需要在 Codex 中 review/trust' "$TMP_DIR/audit.out" || fail "untrusted audit should print review guidance"

set +e
run_audit "$TMP_DIR/untrusted.json" \
  --require-ready \
  --expected-command "missing-other-command"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "missing expected command should fail before extra untrusted hooks block"
grep -Fq 'extra_not_ready=1' "$TMP_DIR/audit.out" || fail "non-audited untrusted hooks should be reported as extra"

cat > "$TMP_DIR/modified.json" <<'JSON'
{
  "data": [
    {
      "cwd": "/repo",
      "hooks": [
        {
          "eventName": "stop",
          "matcher": null,
          "command": "python3 /tmp/codex/hooks/managed/codex_stop_dispatch.py",
          "enabled": true,
          "trustStatus": "modified"
        }
      ],
      "warnings": [],
      "errors": []
    }
  ]
}
JSON

set +e
run_audit "$TMP_DIR/modified.json" --require-ready --require-all-enabled
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "modified enabled hook should require review"

set +e
run_audit "$TMP_DIR/ready.json" --expected-command "missing-command"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "missing expected command should fail audit"
grep -Fq '缺少预期 Codex hook command' "$TMP_DIR/audit.out" || fail "missing command audit should explain the failure"

mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/codex" <<'PY'
#!/usr/bin/env python3
import json
import os
import shutil
import sys


def respond(request_id, result):
    print(json.dumps({"jsonrpc": "2.0", "id": request_id, "result": result}), flush=True)


def hook(event_name, key, command, trust_status="trusted"):
    return {
        "eventName": event_name,
        "key": key,
        "command": command,
        "enabled": True,
        "trustStatus": trust_status,
    }


if sys.argv[1:4] != ["app-server", "--enable", "hooks"]:
    raise SystemExit("unexpected fake codex invocation")

codex_home = os.environ.get("CODEX_HOME", "/tmp/probe-codex")
python_launcher = shutil.which("python3") or "python3"
hooks = [
    hook("preToolUse", "pre_tool_use:0:0", f"bash {codex_home}/hooks/managed/block_dangerous.sh"),
    hook("postToolUse", "post_tool_use:0:0", f"{python_launcher} {codex_home}/hooks/managed/context_contract_validator.py"),
    hook("userPromptSubmit", "user_prompt_submit:0:0", f"{python_launcher} {codex_home}/hooks/managed/codex_user_prompt_submit.py"),
    hook("subagentStart", "subagent_start:0:0", f"{python_launcher} {codex_home}/hooks/managed/codex_subagent_dispatch_guard.py"),
    hook("stop", "stop:0:0", f"{python_launcher} {codex_home}/hooks/managed/codex_stop_dispatch.py", "managed"),
]
if os.environ.get("ORG_CODEX_CONTEXT_CONTINUITY_ENABLED") == "1":
    context_command = f"{python_launcher} {codex_home}/hooks/managed/codex_context_continuity.py"
    hooks.extend(
        [
            hook("userPromptSubmit", "user_prompt_submit:1:0", f"{context_command} --event UserPromptSubmit"),
            hook("stop", "stop:1:0", f"{context_command} --event Stop"),
            hook("preCompact", "pre_compact:0:0", f"{context_command} --event PreCompact"),
            hook("postCompact", "post_compact:0:0", f"{context_command} --event PostCompact"),
            hook("sessionStart", "session_start:1:0", f"{context_command} --event SessionStart --source compact"),
        ]
    )

for raw_line in sys.stdin:
    message = json.loads(raw_line)
    method = message.get("method")
    if method == "initialize":
        respond(message["id"], {})
    elif method == "hooks/list":
        respond(message["id"], {"data": [{"cwd": "/repo", "hooks": hooks, "warnings": [], "errors": []}]})
PY
chmod +x "$TMP_DIR/bin/codex"

PATH="$TMP_DIR/bin:$PATH" CODEX_HOME="/tmp/probe-codex" bash "$ROOT/tools/dev/probe-codex-hooks.sh" /repo >"$TMP_DIR/probe.out" 2>"$TMP_DIR/probe.err" \
  || fail "probe should accept the installer python launcher"
grep -Fq 'ready=5 not_ready=0 extra_not_ready=0' "$TMP_DIR/probe.out" || fail "probe should audit all managed Codex hooks as ready"
PATH="$TMP_DIR/bin:$PATH" CODEX_HOME="/tmp/probe-codex" ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 bash "$ROOT/tools/dev/probe-codex-hooks.sh" /repo >"$TMP_DIR/probe-context.out" 2>"$TMP_DIR/probe-context.err" \
  || fail "probe should include opt-in context continuity hooks when enabled"
grep -Fq 'ready=10 not_ready=0 extra_not_ready=0' "$TMP_DIR/probe-context.out" || fail "probe should audit opt-in context continuity hooks as ready"

echo "[PASS] codex hook trust audit"
