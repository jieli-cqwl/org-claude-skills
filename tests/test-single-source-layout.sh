#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -d "$ROOT/shared/skills" || fail "missing shared/skills single-source directory"
test -d "$ROOT/shared/reference" || fail "missing shared/reference single-source directory"
test -d "$ROOT/shared/rules" || fail "missing shared/rules single-source directory"
test -d "$ROOT/shared/agents" || fail "missing shared/agents single-source directory"
test -f "$ROOT/shared/assistant.md" || fail "missing shared/assistant.md"

test ! -d "$ROOT/codex/skills" || fail "codex/skills should not remain as a maintained source tree"
test ! -d "$ROOT/claude/reference" || fail "claude/reference should not remain as a maintained source tree"
test ! -d "$ROOT/claude/rules" || fail "claude/rules should not remain as a maintained source tree"
find "$ROOT/codex/agents" -maxdepth 1 -type f -name '*.md' | grep -q . && fail "codex/agents/*.md should be sourced from shared/agents instead of duplicated"
test ! -f "$ROOT/claude/hooks/lib/common.sh" || fail "claude/hooks/lib/common.sh should be sourced from shared/hooks/lib/common.sh"

if [ -d "$ROOT/claude/skills" ]; then
  extra_skill="$(find "$ROOT/claude/skills" -mindepth 1 -maxdepth 1 ! -name 'codex-doc-review' -print -quit)"
  [ -z "$extra_skill" ] || fail "claude/skills contains unexpected maintained source: $extra_skill"
  test -f "$ROOT/claude/skills/codex-doc-review/SKILL.md" || fail "missing claude-only skill source: codex-doc-review"
fi

if [ -d "$ROOT/claude/agents" ]; then
  extra_agent="$(find "$ROOT/claude/agents" -mindepth 1 -maxdepth 1 ! -name 'codex-doc-reviewer.md' -print -quit)"
  [ -z "$extra_agent" ] || fail "claude/agents contains unexpected maintained source: $extra_agent"
  test -f "$ROOT/claude/agents/codex-doc-reviewer.md" || fail "missing claude-only agent source: codex-doc-reviewer.md"
fi

if rg -n '\$HOME/\.claude|~/.claude' "$ROOT/shared/skills" "$ROOT/shared/reference" "$ROOT/shared/agents" "$ROOT/claude/skills" "$ROOT/claude/agents" >/tmp/org_single_source_rg.out 2>&1; then
  cat /tmp/org_single_source_rg.out >&2
  fail "source tree should not hardcode ~/.claude runtime paths"
fi

echo "[PASS] single-source layout"
