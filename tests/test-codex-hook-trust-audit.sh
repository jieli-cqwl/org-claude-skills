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
  --expected-command "python3 /tmp/codex/hooks/managed/codex_stop_dispatch.py" \
  || fail "ready trusted/managed hooks should pass"
grep -Fq 'ready=2 not_ready=0 extra_not_ready=0' "$TMP_DIR/audit.out" || fail "ready audit should report all audited hooks ready"

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

echo "[PASS] codex hook trust audit"
