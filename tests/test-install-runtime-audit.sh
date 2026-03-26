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

run_install() {
  run_with_fake_openspec "$TMP_HOME" env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" "$@"
}

run_install --target all --force --check quick >/tmp/org_install_runtime_audit_first.out 2>&1 || {
  cat /tmp/org_install_runtime_audit_first.out >&2
  fail "initial install failed"
}

printf 'platform default rules\n' > "$TMP_HOME/.codex/rules/default.rules"
default_rules_hash="$(shasum "$TMP_HOME/.codex/rules/default.rules" | awk '{print $1}')"
ln -s "$TMP_HOME/.claude/reference/代码质量.md" "$TMP_HOME/.codex/rules/代码质量.md"
[ -L "$TMP_HOME/.codex/rules/代码质量.md" ] || fail "failed to seed legacy residue symlink"

before_version="$(cat "$STATE_ROOT/codex/installed-version")"
run_install --target codex --check quick >/tmp/org_install_runtime_audit_second.out 2>&1 || {
  cat /tmp/org_install_runtime_audit_second.out >&2
  fail "audit install failed"
}
after_version="$(cat "$STATE_ROOT/codex/installed-version")"

[ "$before_version" = "$after_version" ] || fail "audit should not change installed version"
[ ! -e "$TMP_HOME/.codex/rules/代码质量.md" ] || fail "legacy residue should be removed"
[ -f "$TMP_HOME/.codex/rules/default.rules" ] || fail "default.rules should be preserved"
[ "$default_rules_hash" = "$(shasum "$TMP_HOME/.codex/rules/default.rules" | awk '{print $1}')" ] || fail "default.rules content should remain unchanged"

archive_path="$(find "$STATE_ROOT/codex/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/代码质量.md' | head -1)"
[ -n "$archive_path" ] || fail "legacy residue should be archived"

echo "[PASS] install runtime audit"
