#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
HOOKS_FILE="$CODEX_HOME/hooks.json"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-hooks-probe.XXXXXX")"
PROBE_REPO="$TMP_ROOT/repo"
LOG_FILE="$TMP_ROOT/events.log"
JSON_OUT="$TMP_ROOT/codex.out"
JSON_ERR="$TMP_ROOT/codex.err"
BACKUP_FILE="$TMP_ROOT/hooks.json.backup"

cleanup() {
  if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$HOOKS_FILE"
  else
    rm -f "$HOOKS_FILE"
  fi
}
trap cleanup EXIT

mkdir -p "$CODEX_HOME" "$PROBE_REPO"
git -C "$PROBE_REPO" init -q

cat > "$TMP_ROOT/probe.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
label="$1"
log_file="$2"
input="$(cat || true)"
{
  printf '=== %s ===\n' "$label"
  printf '%s\n' "$input"
} >> "$log_file"
SH
chmod +x "$TMP_ROOT/probe.sh"

if [ -f "$HOOKS_FILE" ]; then
  cp "$HOOKS_FILE" "$BACKUP_FILE"
fi

cat > "$HOOKS_FILE" <<JSON
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $TMP_ROOT/probe.sh SessionStart $LOG_FILE"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash $TMP_ROOT/probe.sh PreToolUse $LOG_FILE"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash $TMP_ROOT/probe.sh PostToolUse $LOG_FILE"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $TMP_ROOT/probe.sh TaskCompleted $LOG_FILE"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $TMP_ROOT/probe.sh Stop $LOG_FILE"
          }
        ]
      }
    ]
  }
}
JSON

run_probe() {
  local name="$1"
  local prompt="$2"
  local rc

  {
    printf -- '--- %s ---\n' "$name"
    cd "$PROBE_REPO"
    set +e
    codex exec --json "$prompt"
    rc=$?
    set -e
    printf '\n[rc=%s]\n' "$rc"
  } >> "$JSON_OUT" 2>> "$JSON_ERR"
}

run_probe "bash-flow" "Use the Bash tool exactly once to run \`printf ok >/tmp/codex-hooks-probe-bash.txt\`, then reply with just OK."
run_probe "write-flow" "Use the Write tool exactly once to create a file named \`hook-write.txt\` in the current directory containing exactly \`ok\`, then reply with just OK. Do not use Bash."

printf 'probe_root=%s\n' "$TMP_ROOT"
printf 'codex_home=%s\n' "$CODEX_HOME"
printf 'codex_version=%s\n' "$(codex --version 2>/dev/null || echo unknown)"

printf '\n[events]\n'
if [ -f "$LOG_FILE" ]; then
  cat "$LOG_FILE"
else
  printf 'no hook events captured\n'
fi

printf '\n[codex.err]\n'
if [ -f "$JSON_ERR" ]; then
  sed -n '1,120p' "$JSON_ERR"
fi

printf '\n[codex.out]\n'
if [ -f "$JSON_OUT" ]; then
  sed -n '1,220p' "$JSON_OUT"
fi
