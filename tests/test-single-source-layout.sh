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
test -d "$ROOT/shared/runtime" || fail "missing shared/runtime single-source directory"
test -f "$ROOT/shared/runtime/runtime-catalog.json" || fail "missing shared/runtime/runtime-catalog.json"
test -f "$ROOT/shared/protocols/phase-selection-protocol.md" || fail "missing shared/protocols/phase-selection-protocol.md"
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
test -f "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md" || fail "missing verification-before-completion skill source"
test -f "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md" || fail "missing finishing-a-development-branch skill source"
test -f "$ROOT/community/superpowers/skills/archive/SKILL.md" || fail "missing archive skill source"
test -d "$ROOT/community/anthropic/skills" || fail "missing community/anthropic/skills directory"
test -d "$ROOT/community/anthropic/codex/skills" || fail "missing community/anthropic/codex/skills directory"
test -d "$ROOT/community/nextlevelbuilder/skills" || fail "missing community/nextlevelbuilder/skills directory"
test -d "$ROOT/community/nextlevelbuilder/codex/skills" || fail "missing community/nextlevelbuilder/codex/skills directory"
for skill in ai-cli-updater h5 skill-harness refactor research; do
  test -f "$ROOT/shared/skills/$skill/SKILL.md" || fail "missing shared skill source: $skill"
done
test ! -d "$ROOT/shared/skills/skill-auditor" || fail "shared/skills/skill-auditor should be archived after skill-harness migration"
for skill in algorithmic-art brand-guidelines canvas-design doc-coauthoring docx internal-comms mcp-builder pdf pptx slack-gif-creator theme-factory web-artifacts-builder xlsx; do
  test -f "$ROOT/community/anthropic/skills/$skill/SKILL.md" || fail "missing Anthropic skill source: $skill"
done
test -f "$ROOT/community/anthropic/skills/skill-creator/SKILL.md" || fail "missing Anthropic official skill source: skill-creator"
test -f "$ROOT/community/anthropic/skills/webapp-testing/SKILL.md" || fail "missing Anthropic skill source: webapp-testing"
test -f "$ROOT/community/anthropic/codex/skills/docx/agents/openai.yaml" || fail "missing Anthropic Codex adapter: docx"
test -f "$ROOT/community/anthropic/codex/skills/skill-creator/agents/openai.yaml" || fail "missing Anthropic Codex adapter: skill-creator"
test -f "$ROOT/community/anthropic/codex/skills/mcp-builder/agents/openai.yaml" || fail "missing Anthropic Codex adapter: mcp-builder"
[ "$(find "$ROOT/community/anthropic/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "17" ] || fail "community/anthropic/skills should vendor exactly 17 official skills"
[ "$(find "$ROOT/community/anthropic/codex/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "17" ] || fail "community/anthropic/codex/skills should provide exactly 17 Codex adapters"
test -d "$ROOT/community/vercel/skills" || fail "missing community/vercel/skills directory"
test -d "$ROOT/community/vercel/codex/skills" || fail "missing community/vercel/codex/skills directory"
test -f "$ROOT/community/vercel/skills/find-skills/SKILL.md" || fail "missing Vercel skill source: find-skills"
test -f "$ROOT/community/vercel/skills/agent-browser/SKILL.md" || fail "missing Vercel skill source: agent-browser"
test -f "$ROOT/community/vercel/codex/skills/find-skills/agents/openai.yaml" || fail "missing Vercel Codex adapter: find-skills"
test -f "$ROOT/community/vercel/codex/skills/agent-browser/agents/openai.yaml" || fail "missing Vercel Codex adapter: agent-browser"
test -f "$ROOT/community/alchaincyf/skills/darwin-skill/SKILL.md" || fail "missing Alchaincyf skill source: darwin-skill"
test -f "$ROOT/community/nextlevelbuilder/skills/ui-ux-pro-max/SKILL.md" || fail "missing NextLevelBuilder skill source: ui-ux-pro-max"
test -f "$ROOT/community/nextlevelbuilder/skills/ui-ux-pro-max/scripts/search.py" || fail "missing NextLevelBuilder ui-ux-pro-max search script"
test -f "$ROOT/community/nextlevelbuilder/codex/skills/ui-ux-pro-max/agents/openai.yaml" || fail "missing NextLevelBuilder Codex adapter: ui-ux-pro-max"
[ "$(find "$ROOT/community/vercel/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "2" ] || fail "community/vercel/skills should vendor exactly 2 selected skills"
[ "$(find "$ROOT/community/vercel/codex/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "2" ] || fail "community/vercel/codex/skills should provide exactly 2 Codex adapters"
[ "$(find "$ROOT/community/nextlevelbuilder/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "1" ] || fail "community/nextlevelbuilder/skills should vendor exactly 1 selected skill"
[ "$(find "$ROOT/community/nextlevelbuilder/codex/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "1" ] || fail "community/nextlevelbuilder/codex/skills should provide exactly 1 Codex adapter"
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
  extra_skill="$(find "$ROOT/claude/skills" -mindepth 1 -maxdepth 1 ! -name 'code-review-fix' ! -name 'doc-review-fix' -print -quit)"
  [ -z "$extra_skill" ] || fail "claude/skills contains unexpected maintained source: $extra_skill"
  test -f "$ROOT/claude/skills/code-review-fix/SKILL.md" || fail "missing claude-only skill source: code-review-fix"
  test -f "$ROOT/claude/skills/doc-review-fix/SKILL.md" || fail "missing claude-only skill source: doc-review-fix"
fi

if [ -d "$ROOT/claude/agents" ]; then
  extra_agent="$(find "$ROOT/claude/agents" -mindepth 1 -maxdepth 1 -print -quit)"
  [ -z "$extra_agent" ] || fail "claude/agents contains unexpected maintained source: $extra_agent"
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

if ! python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = [
    root / "shared" / "skills",
    root / "shared" / "protocols",
    root / "shared" / "agents",
    root / "shared" / "reference",
    root / "shared" / "assistant.md",
    root / "shared" / "rules",
]
pattern = re.compile(r'\b(?:reference|protocols|rules)/[^"\'` )(]+\.md')
allowed_prefixes = ("{{RUNTIME_HOME}}/", ".claude/", ".codex/", "./", "../")
violations = []

for base in paths:
    iter_paths = [base] if base.is_file() else base.rglob("*.md")
    for path in iter_paths:
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            for match in pattern.finditer(line):
                prefix = line[:match.start()]
                if prefix.endswith(allowed_prefixes):
                    continue
                violations.append(f"{path}:{lineno}:{line.strip()}")
                break

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY
then
  fail "shared docs should use runtime-safe prefixes for global reference/protocol/rules links"
fi

for skill in product-director product-manager design test-design tech-lead delivery-owner developer review verify qa fix worktree commit ux feishu-docs hv-analysis; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  test -f "$skill_file" || fail "missing skill source for manual-only check: $skill_file"
  grep -Fq 'disable-model-invocation: true' "$skill_file" || fail "manual-only skill should declare disable-model-invocation in source: $skill"
done

python3 "$ROOT/tools/community/source_lock_check.py" >/dev/null || fail "community source lock check failed"

echo "[PASS] single-source layout"
