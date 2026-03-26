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

test ! -d "$ROOT/claude/skills" || fail "claude/skills should not remain as a maintained source tree"
test ! -d "$ROOT/codex/skills" || fail "codex/skills should not remain as a maintained source tree"
test ! -d "$ROOT/claude/reference" || fail "claude/reference should not remain as a maintained source tree"
test ! -d "$ROOT/claude/rules" || fail "claude/rules should not remain as a maintained source tree"
test ! -d "$ROOT/claude/agents" || fail "claude/agents should not remain as a maintained source tree"
find "$ROOT/codex/agents" -maxdepth 1 -type f -name '*.md' | grep -q . && fail "codex/agents/*.md should be sourced from shared/agents instead of duplicated"
test ! -f "$ROOT/claude/hooks/lib/common.sh" || fail "claude/hooks/lib/common.sh should be sourced from shared/hooks/lib/common.sh"

if rg -n '\$HOME/\.claude|~/.claude' "$ROOT/shared/skills" "$ROOT/shared/reference" "$ROOT/shared/agents" >/tmp/org_single_source_rg.out 2>&1; then
  cat /tmp/org_single_source_rg.out >&2
  fail "shared source should not hardcode ~/.claude runtime paths"
fi

echo "[PASS] single-source layout"
