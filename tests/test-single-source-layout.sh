#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -d "$ROOT/shared/skills" || fail "missing shared/skills single-source directory"
test -d "$ROOT/shared/reference" || fail "missing shared/reference single-source directory"
test -d "$ROOT/shared/protocols" || fail "missing shared/protocols single-source directory"
test -f "$ROOT/shared/protocols/phase-selection-protocol.md" || fail "missing shared/protocols/phase-selection-protocol.md"
test -f "$ROOT/shared/protocols/review-fix-loop-protocol.md" || fail "missing shared/protocols/review-fix-loop-protocol.md"
test -f "$ROOT/shared/protocols/review-iteration-protocol.md" || fail "missing shared/protocols/review-iteration-protocol.md"
test ! -f "$ROOT/shared/reference/phase-selection-protocol.md" || fail "phase-selection-protocol should not remain in shared/reference"
test ! -f "$ROOT/shared/reference/review-fix-loop-protocol.md" || fail "review-fix-loop-protocol should not remain in shared/reference"
test ! -f "$ROOT/shared/reference/review-iteration-protocol.md" || fail "review-iteration-protocol should not remain in shared/reference"
test -d "$ROOT/shared/rules" || fail "missing shared/rules single-source directory"
test -d "$ROOT/shared/agents" || fail "missing shared/agents single-source directory"
test -f "$ROOT/shared/assistant.md" || fail "missing shared/assistant.md"
test -d "$ROOT/community" || fail "missing community directory"
test -f "$ROOT/community/SOURCES.yaml" || fail "missing community/SOURCES.yaml"
test ! -d "$ROOT/shared/skills/mcp-builder" || fail "shared/skills/mcp-builder should be retired after Anthropic vendoring"
test -d "$ROOT/community/superpowers/skills" || fail "missing community/superpowers/skills directory"
test -f "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md" || fail "missing community using-superpowers skill source"
grep -Fq 'disable-model-invocation: true' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md" || fail "using-superpowers should declare disable-model-invocation in source"
test -f "$ROOT/community/superpowers/skills/verify-change/SKILL.md" || fail "missing verify-change skill source"
test -f "$ROOT/community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py" || fail "missing verify-change embedded consistency checker"
test -f "$ROOT/community/superpowers/skills/archive/SKILL.md" || fail "missing archive skill source"
test -d "$ROOT/community/anthropic/skills" || fail "missing community/anthropic/skills directory"
test -d "$ROOT/community/anthropic/codex/skills" || fail "missing community/anthropic/codex/skills directory"
test -f "$ROOT/community/anthropic/skills/docx/SKILL.md" || fail "missing Anthropic official skill source: docx"
test -f "$ROOT/community/anthropic/skills/skill-creator/SKILL.md" || fail "missing Anthropic official skill source: skill-creator"
test -f "$ROOT/community/anthropic/skills/mcp-builder/SKILL.md" || fail "missing Anthropic official skill source: mcp-builder"
test -f "$ROOT/community/anthropic/codex/skills/docx/agents/openai.yaml" || fail "missing Anthropic Codex adapter: docx"
test -f "$ROOT/community/anthropic/codex/skills/skill-creator/agents/openai.yaml" || fail "missing Anthropic Codex adapter: skill-creator"
test -f "$ROOT/community/anthropic/codex/skills/mcp-builder/agents/openai.yaml" || fail "missing Anthropic Codex adapter: mcp-builder"
[ "$(find "$ROOT/community/anthropic/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "17" ] || fail "community/anthropic/skills should vendor exactly 17 official skills"
[ "$(find "$ROOT/community/anthropic/codex/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "17" ] || fail "community/anthropic/codex/skills should provide exactly 17 Codex adapters"
test ! -d "$ROOT/community/openspec" || fail "community/openspec should be retired"
test ! -d "$ROOT/community/superpowers/skills/executing-plans" || fail "executing-plans should be retired"
test ! -d "$ROOT/third_party/community" || fail "third_party/community should be retired"
test ! -d "$ROOT/community-adapters" || fail "community-adapters should be retired"
test ! -f "$ROOT/tools/dev/generate_opsx_adapters.py" || fail "generate_opsx_adapters.py should be retired"

test ! -d "$ROOT/codex/skills" || fail "codex/skills should not remain as a maintained source tree"
test ! -d "$ROOT/claude/reference" || fail "claude/reference should not remain as a maintained source tree"
test ! -d "$ROOT/claude/rules" || fail "claude/rules should not remain as a maintained source tree"
find "$ROOT/codex/agents" -maxdepth 1 -type f -name '*.md' | grep -q . && fail "codex/agents/*.md should be sourced from shared/agents instead of duplicated"
test ! -f "$ROOT/claude/hooks/lib/common.sh" || fail "claude/hooks/lib/common.sh should be sourced from shared/hooks/lib/common.sh"

if [ -d "$ROOT/claude/skills" ]; then
  extra_skill="$(find "$ROOT/claude/skills" -mindepth 1 -maxdepth 1 ! -name 'codex-doc-review' ! -name 'review-fix-loop' -print -quit)"
  [ -z "$extra_skill" ] || fail "claude/skills contains unexpected maintained source: $extra_skill"
  test -f "$ROOT/claude/skills/codex-doc-review/SKILL.md" || fail "missing claude-only skill source: codex-doc-review"
  test -f "$ROOT/claude/skills/review-fix-loop/SKILL.md" || fail "missing claude-only skill source: review-fix-loop"
fi

if [ -d "$ROOT/claude/agents" ]; then
  extra_agent="$(find "$ROOT/claude/agents" -mindepth 1 -maxdepth 1 ! -name 'codex-doc-reviewer.md' -print -quit)"
  [ -z "$extra_agent" ] || fail "claude/agents contains unexpected maintained source: $extra_agent"
  test -f "$ROOT/claude/agents/codex-doc-reviewer.md" || fail "missing claude-only agent source: codex-doc-reviewer.md"
fi

if rg -n '\$HOME/\.claude|~/.claude' "$ROOT/shared/skills" "$ROOT/shared/reference" "$ROOT/shared/protocols" "$ROOT/shared/agents" "$ROOT/claude/skills" "$ROOT/claude/agents" >/tmp/org_single_source_rg.out 2>&1; then
  cat /tmp/org_single_source_rg.out >&2
  fail "source tree should not hardcode ~/.claude runtime paths"
fi

if rg -n 'reference/(phase-selection-protocol|review-fix-loop-protocol|review-iteration-protocol)\.md' \
  "$ROOT/shared/skills" \
  "$ROOT/shared/reference" \
  "$ROOT/shared/protocols" \
  "$ROOT/shared/rules" \
  "$ROOT/shared/assistant.md" >/tmp/org_single_source_protocol_refs.out 2>&1; then
  cat /tmp/org_single_source_protocol_refs.out >&2
  fail "source tree should reference protocols/*.md instead of reference/*.md for workflow protocols"
fi

for skill in product design test-design tech-lead project-manager developer review verify qa fix worktree commit ux; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  test -f "$skill_file" || fail "missing skill source for manual-only check: $skill_file"
  grep -Fq 'disable-model-invocation: true' "$skill_file" || fail "manual-only skill should declare disable-model-invocation in source: $skill"
done

python3 "$ROOT/tools/community/source_lock_check.py" >/dev/null || fail "community source lock check failed"

echo "[PASS] single-source layout"
