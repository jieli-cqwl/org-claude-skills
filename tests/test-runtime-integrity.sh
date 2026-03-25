#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

check_global_refs() {
  local runtime_dir="$1"
  local source_file ref

  while IFS= read -r source_file; do
    [ -f "$source_file" ] || continue
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      [ -f "$runtime_dir/$ref" ] || fail "$source_file 引用了缺失全局文档: $ref"
    done < <(grep -ohE "reference/[^\"'\` )(]+\\.md" "$source_file" | sort -u)
  done < <(find "$runtime_dir/rules" "$runtime_dir/reference" "$runtime_dir/skills" -type f \( -name '*.md' -o -name 'SKILL.md' \) | sort)
}

check_skill_refs() {
  local runtime_dir="$1"
  local skill_dir skill_file ref

  for skill_dir in "$runtime_dir"/skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_file="$skill_dir/SKILL.md"
    [ -f "$skill_file" ] || continue

    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      [ -f "$skill_dir/$ref" ] || fail "$skill_file 引用了缺失局部文档: $ref"
    done < <(grep -ohE "references/[^\"'\` )(]+\\.md" "$skill_file" | sort -u)
  done
}

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
TOML

cmp -s "$ROOT/claude/CLAUDE.md" "$ROOT/codex/AGENTS.md" || fail "claude/CLAUDE.md and codex/AGENTS.md should stay in sync"

HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_runtime_integrity_install.out 2>&1 || {
  cat /tmp/org_runtime_integrity_install.out >&2
  fail "install failed"
}

test -f "$TMP_HOME/.claude/CLAUDE.md" || fail "missing ~/.claude/CLAUDE.md"
test -f "$TMP_HOME/.codex/AGENTS.md" || fail "missing ~/.codex/AGENTS.md"
test -f "$STATE_ROOT/claude/installed-version" || fail "missing claude state version"
test -f "$STATE_ROOT/codex/installed-version" || fail "missing codex state version"

find "$TMP_HOME/.claude" -maxdepth 1 \( -name '.org-*' -o -name '.org-backups' \) | grep -q . && fail "runtime ~/.claude should not retain .org metadata"
find "$TMP_HOME/.codex" -maxdepth 1 \( -name '.org-*' -o -name '.org-backups' \) | grep -q . && fail "runtime ~/.codex should not retain .org metadata"

check_global_refs "$TMP_HOME/.claude"
check_global_refs "$TMP_HOME/.codex"
check_skill_refs "$TMP_HOME/.claude"
check_skill_refs "$TMP_HOME/.codex"

echo "[PASS] runtime integrity"
