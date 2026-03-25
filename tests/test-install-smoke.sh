#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
cat > "$TMP_HOME/.codex/config.toml" <<'EOF_CONF'
model = "gpt-5"
EOF_CONF

before_hash="$(shasum "$TMP_HOME/.codex/config.toml" | awk '{print $1}')"

HOME="$TMP_HOME" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --check quick

test -f "$TMP_HOME/.claude/skills/product/SKILL.md"
test -f "$TMP_HOME/.claude/hooks/block_dangerous.sh"
test -f "$TMP_HOME/.codex/AGENTS.md"
test -f "$TMP_HOME/.codex/skills/product/agents/openai.yaml"
test -f "$TMP_HOME/.codex/agents/developer.toml"

grep -Fq "$TMP_HOME/.codex" "$TMP_HOME/.codex/agents/developer.toml"
if grep -Fq '{{HOME}}' "$TMP_HOME/.codex/agents/developer.toml"; then
  echo "[FAIL] developer.toml still contains {{HOME}} placeholder"
  exit 1
fi

after_hash="$(shasum "$TMP_HOME/.codex/config.toml" | awk '{print $1}')"
if [ "$before_hash" != "$after_hash" ]; then
  echo "[FAIL] protected file ~/.codex/config.toml was modified"
  exit 1
fi

HOME="$TMP_HOME" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --uninstall

if [ -f "$TMP_HOME/.claude/skills/product/SKILL.md" ]; then
  echo "[FAIL] ~/.claude/skills/product/SKILL.md should be removed after uninstall"
  exit 1
fi
if [ -f "$TMP_HOME/.codex/AGENTS.md" ]; then
  echo "[FAIL] ~/.codex/AGENTS.md should be removed after uninstall"
  exit 1
fi

after_uninstall_hash="$(shasum "$TMP_HOME/.codex/config.toml" | awk '{print $1}')"
if [ "$before_hash" != "$after_uninstall_hash" ]; then
  echo "[FAIL] protected file ~/.codex/config.toml changed after uninstall"
  exit 1
fi

echo "[PASS] install/uninstall smoke"
