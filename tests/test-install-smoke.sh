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

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --check quick

test -f "$TMP_HOME/.claude/CLAUDE.md"
test -f "$TMP_HOME/.claude/skills/brainstorming/SKILL.md"
test -f "$TMP_HOME/.claude/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.claude/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.claude/skills/archive/SKILL.md"
test -f "$TMP_HOME/.claude/skills/code-review-fix/SKILL.md"
test -f "$TMP_HOME/.claude/skills/doc-review-fix/SKILL.md"
test -f "$TMP_HOME/.claude/skills/docx/SKILL.md"
test -f "$TMP_HOME/.claude/skills/skill-creator/SKILL.md"
test -f "$TMP_HOME/.claude/skills/skill-harness/SKILL.md"
test -f "$TMP_HOME/.claude/skills/feishu-docs/SKILL.md"
test ! -e "$TMP_HOME/.claude/skills/skill-auditor"
test ! -e "$TMP_HOME/.claude/skills/new-skills"
test -f "$TMP_HOME/.claude/skills/mcp-builder/SKILL.md"
if ! grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/skill-harness/SKILL.md"; then
  echo "[FAIL] ~/.claude/skills/skill-harness/SKILL.md should be manual-only"
  exit 1
fi
if grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/webapp-testing/SKILL.md"; then
  echo "[FAIL] ~/.claude/skills/webapp-testing/SKILL.md should remain auto-visible"
  exit 1
fi
test -f "$TMP_HOME/.claude/skills/find-skills/SKILL.md"
test -f "$TMP_HOME/.claude/skills/agent-browser/SKILL.md"
test -f "$TMP_HOME/.claude/skills/darwin-skill/SKILL.md"
test -f "$TMP_HOME/.claude/skills/ui-ux-pro-max/SKILL.md"
test -f "$TMP_HOME/.claude/skills/ui-ux-pro-max/scripts/search.py"
grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/ui-ux-pro-max/SKILL.md"
test -f "$TMP_HOME/.claude/hooks/block_dangerous.sh"
test -x "$TMP_HOME/.claude/hooks/block_dangerous.sh"
test -x "$TMP_HOME/.claude/hooks/managed/block_dangerous.sh"
test -f "$TMP_HOME/.claude/protocols/phase-selection-protocol.md"
test ! -f "$TMP_HOME/.claude/reference/phase-selection-protocol.md"
test -f "$TMP_HOME/.claude/agents/code-reviewer.md"
test -f "$TMP_HOME/.claude/agents/generic-code-reviewer.md"
test -f "$TMP_HOME/.codex/AGENTS.md"
test -f "$TMP_HOME/.codex/skills/brainstorming/agents/openai.yaml"
test ! -f "$TMP_HOME/.codex/skills/product-director/agents/openai.yaml"
test ! -f "$TMP_HOME/.codex/skills/product-manager/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.codex/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.codex/skills/archive/SKILL.md"
test -f "$TMP_HOME/.codex/agents/code-reviewer.md"
test -f "$TMP_HOME/.codex/agents/generic-code-reviewer.md"
test -f "$TMP_HOME/.codex/agents/generic-code-reviewer.toml"
test ! -e "$TMP_HOME/.codex/skills/code-review-fix"
test ! -e "$TMP_HOME/.codex/skills/doc-review-fix"
test ! -e "$TMP_HOME/.codex/skills/review-fix-loop"
test ! -f "$TMP_HOME/.codex/skills/docx/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/skill-creator/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/skill-harness/SKILL.md"
test ! -f "$TMP_HOME/.codex/skills/skill-harness/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/feishu-docs/SKILL.md"
test ! -f "$TMP_HOME/.codex/skills/feishu-docs/agents/openai.yaml"
test ! -e "$TMP_HOME/.codex/skills/skill-auditor"
test ! -e "$TMP_HOME/.codex/skills/new-skills"
test ! -f "$TMP_HOME/.codex/skills/mcp-builder/agents/openai.yaml"
if ! grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.codex/skills/skill-harness/SKILL.md"; then
  echo "[FAIL] ~/.codex/skills/skill-harness/SKILL.md should be manual-only"
  exit 1
fi
test -f "$TMP_HOME/.codex/skills/find-skills/SKILL.md"
test -f "$TMP_HOME/.codex/skills/agent-browser/SKILL.md"
test -f "$TMP_HOME/.codex/skills/darwin-skill/SKILL.md"
test -f "$TMP_HOME/.codex/skills/ui-ux-pro-max/SKILL.md"
test -f "$TMP_HOME/.codex/skills/ui-ux-pro-max/scripts/search.py"
grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.codex/skills/ui-ux-pro-max/SKILL.md"
test -f "$TMP_HOME/.codex/skills/find-skills/agents/openai.yaml"
test ! -f "$TMP_HOME/.codex/skills/agent-browser/agents/openai.yaml"
test ! -f "$TMP_HOME/.codex/skills/darwin-skill/agents/openai.yaml"
test ! -f "$TMP_HOME/.codex/skills/ui-ux-pro-max/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/webapp-testing/agents/openai.yaml"
if grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.codex/skills/webapp-testing/SKILL.md"; then
  echo "[FAIL] ~/.codex/skills/webapp-testing/SKILL.md should remain auto-visible"
  exit 1
fi
test -f "$TMP_HOME/.codex/agents/developer.toml"
test -f "$TMP_HOME/.codex/protocols/phase-selection-protocol.md"
test ! -f "$TMP_HOME/.codex/reference/phase-selection-protocol.md"
test -f "$TMP_HOME/.codex/hooks.json"
test -x "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh"
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
grep -Fq '你是 code-reviewer。' "$TMP_HOME/.claude/agents/code-reviewer.md"
if grep -Fq 'Use this agent when a major project step has been completed' "$TMP_HOME/.claude/agents/code-reviewer.md"; then
  echo "[FAIL] ~/.claude/agents/code-reviewer.md should keep shared runtime contract, not superpowers generic reviewer"
  exit 1
fi
grep -Fq 'Use this agent when a major project step has been completed' "$TMP_HOME/.claude/agents/generic-code-reviewer.md"
grep -Fq 'name: generic-code-reviewer' "$TMP_HOME/.claude/agents/generic-code-reviewer.md"
if grep -Fq 'scope（可选）' "$TMP_HOME/.claude/agents/generic-code-reviewer.md"; then
  echo "[FAIL] ~/.claude/agents/generic-code-reviewer.md should keep generic reviewer contract, not shared gated reviewer"
  exit 1
fi
if grep -Fq '你是 code-reviewer。' "$TMP_HOME/.claude/agents/generic-code-reviewer.md"; then
  echo "[FAIL] ~/.claude/agents/generic-code-reviewer.md should stay aligned with superpowers generic reviewer content"
  exit 1
fi
grep -Fq '你是 code-reviewer。' "$TMP_HOME/.codex/agents/code-reviewer.md"
if grep -Fq 'Use this agent when a major project step has been completed' "$TMP_HOME/.codex/agents/code-reviewer.md"; then
  echo "[FAIL] ~/.codex/agents/code-reviewer.md should keep shared runtime contract, not superpowers generic reviewer"
  exit 1
fi
grep -Fq 'Use this agent when a major project step has been completed' "$TMP_HOME/.codex/agents/generic-code-reviewer.md"
grep -Fq 'name: generic-code-reviewer' "$TMP_HOME/.codex/agents/generic-code-reviewer.md"
if grep -Fq 'scope（可选）' "$TMP_HOME/.codex/agents/generic-code-reviewer.md"; then
  echo "[FAIL] ~/.codex/agents/generic-code-reviewer.md should keep generic reviewer contract, not shared gated reviewer"
  exit 1
fi
if grep -Fq '你是 code-reviewer。' "$TMP_HOME/.codex/agents/generic-code-reviewer.md"; then
  echo "[FAIL] ~/.codex/agents/generic-code-reviewer.md should stay aligned with superpowers generic reviewer content"
  exit 1
fi
grep -Fq "$TMP_HOME/.codex/agents/generic-code-reviewer.md" "$TMP_HOME/.codex/agents/generic-code-reviewer.toml"
grep -Fq "bash \$HOME/.claude/hooks/block_dangerous.sh" "$TMP_HOME/.claude/settings.json"
grep -Fq "bash \$HOME/.claude/hooks/code_quality_check.sh" "$TMP_HOME/.claude/settings.json"
grep -Fq "bash \$HOME/.claude/hooks/auto_format.sh" "$TMP_HOME/.claude/settings.json"
grep -Fq "bash \$HOME/.claude/hooks/post_compact.sh" "$TMP_HOME/.claude/settings.json"
grep -Fq "bash \$HOME/.claude/hooks/task_verify.sh" "$TMP_HOME/.claude/settings.json"
grep -Fq 'model = "gpt-5"' "$TMP_HOME/.codex/config.toml"
grep -Fq 'codex_hooks = true' "$TMP_HOME/.codex/config.toml"
grep -Fq "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" "$TMP_HOME/.codex/hooks.json"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" "$TMP_HOME/.codex/hooks.json"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" "$TMP_HOME/.codex/hooks.json"
printf '{}' | bash "$TMP_HOME/.claude/hooks/block_dangerous.sh"
printf '{}' | bash "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh"

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
grep -Fq 'model = "gpt-5"' "$TMP_HOME/.codex/config.toml"
if grep -Fq 'codex_hooks = true' "$TMP_HOME/.codex/config.toml"; then
  echo "[FAIL] ~/.codex/config.toml should restore the pre-install codex_hooks baseline after uninstall"
  exit 1
fi
if [ -f "$TMP_HOME/.codex/hooks.json" ]; then
  echo "[FAIL] ~/.codex/hooks.json should be removed when no user hooks existed before install"
  exit 1
fi
claude_hook_literal="bash \$HOME/.claude/hooks/"
if grep -Fq "$claude_hook_literal" "$TMP_HOME/.claude/settings.json"; then
  echo "[FAIL] ~/.claude/settings.json should restore the pre-install hook baseline after uninstall"
  exit 1
fi

if [ -d "$STATE_ROOT/claude" ] || [ -d "$STATE_ROOT/codex" ]; then
  echo "[FAIL] state directories should be removed after uninstall"
  exit 1
fi

echo "[PASS] install/uninstall smoke"
