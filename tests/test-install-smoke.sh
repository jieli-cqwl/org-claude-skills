#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
TMP_HOME="$(mktemp -d)"
STATE_ROOT="$TMP_HOME/.org-skills-state"

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

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --check quick

test -f "$TMP_HOME/.claude/CLAUDE.md"
test -f "$TMP_HOME/.claude/skills/brainstorming/SKILL.md"
test -f "$TMP_HOME/.claude/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.claude/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.claude/skills/archive/SKILL.md"
test -f "$TMP_HOME/.claude/skills/docx/SKILL.md"
test -f "$TMP_HOME/.claude/skills/skill-creator/SKILL.md"
test -f "$TMP_HOME/.claude/skills/mcp-builder/SKILL.md"
test -f "$TMP_HOME/.claude/hooks/block_dangerous.sh"
test -f "$TMP_HOME/.claude/protocols/phase-selection-protocol.md"
test ! -f "$TMP_HOME/.claude/reference/phase-selection-protocol.md"
test -f "$TMP_HOME/.codex/AGENTS.md"
test -f "$TMP_HOME/.codex/skills/brainstorming/agents/openai.yaml"
test ! -f "$TMP_HOME/.codex/skills/product/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.codex/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.codex/skills/archive/SKILL.md"
test -f "$TMP_HOME/.codex/skills/docx/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/skill-creator/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/mcp-builder/agents/openai.yaml"
test -f "$TMP_HOME/.codex/agents/developer.toml"
test -f "$TMP_HOME/.codex/protocols/phase-selection-protocol.md"
test ! -f "$TMP_HOME/.codex/reference/phase-selection-protocol.md"
test -f "$STATE_ROOT/claude/installed-version"
test -f "$STATE_ROOT/codex/installed-version"
test ! -e "$TMP_HOME/.claude/.org-installed-version"
test ! -e "$TMP_HOME/.claude/.org-backups"
test ! -e "$TMP_HOME/.codex/.org-installed-version"
test ! -e "$TMP_HOME/.codex/.org-backups"

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

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --uninstall

if [ -f "$TMP_HOME/.claude/skills/brainstorming/SKILL.md" ]; then
  echo "[FAIL] ~/.claude/skills/brainstorming/SKILL.md should be removed after uninstall"
  exit 1
fi
if [ -f "$TMP_HOME/.codex/AGENTS.md" ]; then
  echo "[FAIL] ~/.codex/AGENTS.md should be removed after uninstall"
  exit 1
fi
if [ -f "$TMP_HOME/.codex/skills/verify-change/SKILL.md" ]; then
  echo "[FAIL] ~/.codex/skills/verify-change/SKILL.md should be removed after uninstall"
  exit 1
fi

after_uninstall_hash="$(shasum "$TMP_HOME/.codex/config.toml" | awk '{print $1}')"
if [ "$before_hash" != "$after_uninstall_hash" ]; then
  echo "[FAIL] protected file ~/.codex/config.toml changed after uninstall"
  exit 1
fi

if [ -d "$STATE_ROOT/claude" ] || [ -d "$STATE_ROOT/codex" ]; then
  echo "[FAIL] state directories should be removed after uninstall"
  exit 1
fi

echo "[PASS] install/uninstall smoke"
