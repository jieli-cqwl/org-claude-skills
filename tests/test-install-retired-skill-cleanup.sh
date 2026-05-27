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

mkdir -p \
  "$TMP_HOME/.claude/skills/skill-auditor/scripts" \
  "$TMP_HOME/.codex/skills/skill-auditor/scripts" \
  "$TMP_HOME/.agents/skills/skill-auditor/scripts" \
  "$TMP_HOME/.claude/skills/skill-refiner/scripts" \
  "$TMP_HOME/.codex/skills/skill-refiner/scripts" \
  "$TMP_HOME/.agents/skills/skill-refiner/scripts" \
  "$TMP_HOME/.claude/skills/ai-cli-updater/scripts" \
  "$TMP_HOME/.codex/skills/ai-cli-updater/scripts" \
  "$TMP_HOME/.agents/skills/ai-cli-updater/scripts" \
  "$TMP_HOME/.claude/skills/test-design/evals" \
  "$TMP_HOME/.agents/skills/test-design/evals" \
  "$STATE_ROOT/claude" \
  "$STATE_ROOT/codex"
touch \
  "$TMP_HOME/.claude/skills/skill-auditor/SKILL.md" \
  "$TMP_HOME/.codex/skills/skill-auditor/SKILL.md" \
  "$TMP_HOME/.agents/skills/skill-auditor/SKILL.md" \
  "$TMP_HOME/.claude/skills/skill-refiner/SKILL.md" \
  "$TMP_HOME/.codex/skills/skill-refiner/SKILL.md" \
  "$TMP_HOME/.agents/skills/skill-refiner/SKILL.md" \
  "$TMP_HOME/.claude/skills/ai-cli-updater/SKILL.md" \
  "$TMP_HOME/.codex/skills/ai-cli-updater/SKILL.md" \
  "$TMP_HOME/.agents/skills/ai-cli-updater/SKILL.md"
printf '{"artifact_type":"stale-internal-eval"}\n' \
  > "$TMP_HOME/.claude/skills/test-design/evals/stale-internal.json"
printf '{"artifact_type":"stale-internal-eval"}\n' \
  > "$TMP_HOME/.agents/skills/test-design/evals/stale-internal.json"

printf '%s\n' \
  "$TMP_HOME/.claude/skills/skill-refiner/SKILL.md" \
  > "$STATE_ROOT/claude/installed-manifest"
printf '%s\n' \
  "$TMP_HOME/.agents/skills/skill-refiner/SKILL.md" \
  > "$STATE_ROOT/codex/installed-manifest"
: > "$STATE_ROOT/claude/backup-manifest"
: > "$STATE_ROOT/codex/backup-manifest"

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
cat > "$TMP_HOME/.codex/config.toml" <<'EOF_CONF'
model = "gpt-5"
EOF_CONF

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 ORG_SKIP_CODEX_HOOK_TRUST_AUDIT=1 bash "$ROOT/install.sh" --target all --check quick

test ! -e "$TMP_HOME/.claude/skills/skill-auditor" || fail "claude retired skill-auditor should be cleaned"
test ! -e "$TMP_HOME/.codex/skills/skill-auditor" || fail "codex retired skill-auditor should be cleaned"
test ! -e "$TMP_HOME/.agents/skills/skill-auditor" || fail "codex runtime retired skill-auditor should be cleaned"
test ! -e "$TMP_HOME/.claude/skills/skill-refiner" || fail "claude retired skill-refiner should be cleaned"
test ! -e "$TMP_HOME/.codex/skills/skill-refiner" || fail "codex retired skill-refiner should be cleaned"
test ! -e "$TMP_HOME/.agents/skills/skill-refiner" || fail "codex runtime retired skill-refiner should be cleaned"
test ! -e "$TMP_HOME/.claude/skills/ai-cli-updater" || fail "claude retired ai-cli-updater should be cleaned"
test ! -e "$TMP_HOME/.codex/skills/ai-cli-updater" || fail "codex retired ai-cli-updater should be cleaned"
test ! -e "$TMP_HOME/.agents/skills/ai-cli-updater" || fail "codex runtime retired ai-cli-updater should be cleaned"
test ! -e "$TMP_HOME/.claude/skills/test-design/evals" || fail "claude stale internal evals should be cleaned"
test ! -e "$TMP_HOME/.agents/skills/test-design/evals" || fail "codex runtime stale internal evals should be cleaned"
! grep -Fq '/skills/skill-refiner/' "$STATE_ROOT/claude/installed-manifest" \
  || fail "claude installed manifest should not retain retired skill-refiner"
! grep -Fq '/skills/skill-refiner/' "$STATE_ROOT/codex/installed-manifest" \
  || fail "codex installed manifest should not retain retired skill-refiner"
find "$STATE_ROOT/claude/unexpected-artifacts" -path '*/skills/skill-auditor/SKILL.md' -print -quit | grep -q . \
  || fail "claude retired skill-auditor should be archived"
find "$STATE_ROOT/codex/unexpected-artifacts" -path '*/skills/skill-auditor/SKILL.md' -print -quit | grep -q . \
  || fail "codex retired skill-auditor should be archived"
find "$STATE_ROOT/claude/unexpected-artifacts" -path '*/skills/skill-refiner/SKILL.md' -print -quit | grep -q . \
  || fail "claude retired skill-refiner should be archived"
find "$STATE_ROOT/codex/unexpected-artifacts" -path '*/skills/skill-refiner/SKILL.md' -print -quit | grep -q . \
  || fail "codex retired skill-refiner should be archived"
find "$STATE_ROOT/claude/unexpected-artifacts" -path '*/skills/ai-cli-updater/SKILL.md' -print -quit | grep -q . \
  || fail "claude retired ai-cli-updater should be archived"
find "$STATE_ROOT/codex/unexpected-artifacts" -path '*/skills/ai-cli-updater/SKILL.md' -print -quit | grep -q . \
  || fail "codex retired ai-cli-updater should be archived"

echo "[PASS] install retired skill cleanup"
