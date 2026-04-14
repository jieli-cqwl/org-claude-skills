#!/usr/bin/env bash
set -euo pipefail

BASE_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-hooks-probe.XXXXXX")"
PROBE_REPO="$TMP_ROOT/repo"
RUNTIME_CODEX_HOME="$TMP_ROOT/codex-home"
HOOKS_FILE="$RUNTIME_CODEX_HOME/hooks.json"
LOG_FILE="$TMP_ROOT/events.log"
JSON_OUT="$TMP_ROOT/codex.out"
JSON_ERR="$TMP_ROOT/codex.err"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$RUNTIME_CODEX_HOME" "$PROBE_REPO"
git -C "$PROBE_REPO" init -q

copy_runtime_context() {
  local rel="$1"
  local src="$BASE_CODEX_HOME/$rel"
  local dst="$RUNTIME_CODEX_HOME/$rel"

  if [ -d "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
  elif [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
}

copy_runtime_context "auth.json"
copy_runtime_context "config.toml"
copy_runtime_context "AGENTS.md"
copy_runtime_context "agents"

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
    printf '%s\n' "$prompt" | CODEX_HOME="$RUNTIME_CODEX_HOME" timeout 60 codex --enable codex_hooks exec --json -c model_reasoning_effort="medium" -
    rc=$?
    set -e
    printf '\n[rc=%s]\n' "$rc"
  } >> "$JSON_OUT" 2>> "$JSON_ERR"
}

run_probe "bash-flow" "Use the Bash tool exactly once to run \`printf ok >/tmp/codex-hooks-probe-bash.txt\`, then reply with just OK."

printf 'probe_root=%s\n' "$TMP_ROOT"
printf 'codex_home=%s\n' "$BASE_CODEX_HOME"
printf 'codex_runtime_home=%s\n' "$RUNTIME_CODEX_HOME"
printf 'codex_bin=%s\n' "$(command -v codex 2>/dev/null || echo unknown)"
printf 'codex_bin_real=%s\n' "$(python3 - <<'PY'
import os, shutil
path = shutil.which("codex")
print(os.path.realpath(path) if path else "unknown")
PY
)"
printf 'codex_agents_md=%s\n' "$BASE_CODEX_HOME/AGENTS.md"
printf 'codex_input_mode=stdin\n'
printf 'codex_hooks_flag=enabled\n'

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
