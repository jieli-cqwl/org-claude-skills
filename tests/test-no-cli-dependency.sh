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
model = "gpt-5"
TOML

run_without_openspec env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_no_cli_install.out 2>&1 || {
  cat /tmp/org_no_cli_install.out >&2
  fail "install should succeed without openspec CLI"
}

if rg -n 'openspec CLI|@fission-ai/openspec|opsx:' "$ROOT/community/superpowers/skills/verify-change" "$ROOT/community/superpowers/skills/archive" "$ROOT/install.sh" >/tmp/org_no_cli_refs.out 2>&1; then
  cat /tmp/org_no_cli_refs.out >&2
  fail "small-chain runtime should not retain openspec CLI dependency references"
fi

echo "[PASS] no CLI dependency"
