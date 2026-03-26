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

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"
TOML

run_with_fake_openspec "$TMP_HOME" env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_platform_noise_install.out 2>&1 || {
  cat /tmp/org_platform_noise_install.out >&2
  fail "install failed"
}

grep -Fxq '# CLAUDE.md' "$TMP_HOME/.claude/CLAUDE.md" || fail "claude entry doc title should be # CLAUDE.md"
grep -Fxq '# AGENTS.md' "$TMP_HOME/.codex/AGENTS.md" || fail "codex entry doc title should be # AGENTS.md"

if rg -n \
  -e '^# CLAUDE\.md$' \
  -e 'Claude Code Skill 创建与改进' \
  -e 'Claude 工作时需要查阅' \
  -e 'description 被注入 system prompt 后由 Claude 读取' \
  -e '过时文档隔离（Claude 不参考）' \
  "$TMP_HOME/.codex/AGENTS.md" \
  "$TMP_HOME/.codex/skills" \
  "$TMP_HOME/.codex/reference" \
  "$TMP_HOME/.codex/agents" >/tmp/org_platform_noise_rg.out 2>&1; then
  cat /tmp/org_platform_noise_rg.out >&2
  fail "codex runtime still contains claude-only noise"
fi

echo "[PASS] platform runtime noise"
