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

official_skills=(
  brainstorming
  dispatching-parallel-agents
  executing-plans
  finishing-a-development-branch
  receiving-code-review
  requesting-code-review
  subagent-driven-development
  systematic-debugging
  test-driven-development
  using-git-worktrees
  using-superpowers
  verification-before-completion
  writing-plans
  writing-skills
)

test -d "$ROOT/shared/skills" || fail "missing shared/skills single-source directory"
test -d "$ROOT/shared/reference" || fail "missing shared/reference single-source directory"
test -d "$ROOT/shared/protocols" || fail "missing shared/protocols single-source directory"
test -d "$ROOT/shared/runtime" || fail "missing shared/runtime single-source directory"
test -d "$ROOT/shared/rules" || fail "missing shared/rules single-source directory"
test -d "$ROOT/shared/agents" || fail "missing shared/agents single-source directory"
test -f "$ROOT/shared/assistant.md" || fail "missing shared/assistant.md"
test -f "$ROOT/community/SOURCES.yaml" || fail "missing community/SOURCES.yaml"

test -d "$ROOT/community/superpowers/skills" || fail "missing Superpowers skills mirror"
[ "$(find "$ROOT/community/superpowers" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | paste -sd, -)" = "skills" ] || fail "community/superpowers should contain only skills"
[ "$(find "$ROOT/community/superpowers/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "14" ] || fail "Superpowers mirror should contain exactly 14 official skills"
for skill in "${official_skills[@]}"; do
  test -f "$ROOT/community/superpowers/skills/$skill/SKILL.md" || fail "missing Superpowers skill source: $skill"
  test ! -f "$ROOT/community/superpowers/skills/$skill/agents/openai.yaml" || fail "Superpowers source must not contain Codex adapter: $skill"
  if grep -Eq '^(user-invocable|disable-model-invocation):' "$ROOT/community/superpowers/skills/$skill/SKILL.md"; then
    fail "Superpowers source must not contain runtime visibility frontmatter: $skill"
  fi
done

for retired in verify-change archive parallel-subagent-development; do
  test ! -e "$ROOT/community/superpowers/skills/$retired" || fail "retired local Superpowers skill should not remain: $retired"
done
test ! -d "$ROOT/community/superpowers/codex" || fail "Superpowers Codex adapter tree should not exist"
test ! -d "$ROOT/community/superpowers/agents" || fail "Superpowers agents tree should not exist"

test -d "$ROOT/community/anthropic/skills" || fail "missing community/anthropic/skills directory"
test -d "$ROOT/community/anthropic/codex/skills" || fail "missing community/anthropic/codex/skills directory"
test -d "$ROOT/community/vercel/skills" || fail "missing community/vercel/skills directory"
test -d "$ROOT/community/vercel/codex/skills" || fail "missing community/vercel/codex/skills directory"
test -d "$ROOT/community/alchaincyf/skills" || fail "missing community/alchaincyf/skills directory"
test -d "$ROOT/community/nextlevelbuilder/skills" || fail "missing community/nextlevelbuilder/skills directory"
test -d "$ROOT/community/persona/skills" || fail "missing community/persona/skills directory"
test -d "$ROOT/community/panniantong/skills" || fail "missing community/panniantong/skills directory"
test -d "$ROOT/community/panniantong/codex/skills" || fail "missing community/panniantong/codex/skills directory"
test -f "$ROOT/community/panniantong/skills/agent-reach/SKILL.md" || fail "missing Panniantong agent-reach source"
test -f "$ROOT/community/panniantong/codex/skills/agent-reach/agents/openai.yaml" || fail "missing Panniantong agent-reach Codex adapter"
test -d "$ROOT/community/skills-sh/skills" || fail "missing community/skills-sh/skills directory"
test -d "$ROOT/community/skills-sh/codex/skills" || fail "missing community/skills-sh/codex/skills directory"
for skill in baoyu-markdown-to-html bb-browser code-to-prd graphify humanizer-zh notebooklm prd self-improving-agent to-prd; do
  test -f "$ROOT/community/skills-sh/skills/$skill/SKILL.md" || fail "missing skills.sh skill source: $skill"
done
for skill in bb-browser humanizer-zh notebooklm; do
  test -f "$ROOT/community/skills-sh/codex/skills/$skill/agents/openai.yaml" || fail "missing skills.sh Codex adapter: $skill"
done
test ! -e "$ROOT/community/skills-sh/codex/skills/self-improving-agent/agents/openai.yaml" || fail "self-improving-agent should not expose a Codex adapter"
test ! -e "$ROOT/community/skills-sh/codex/skills/code-to-prd/agents/openai.yaml" || fail "code-to-prd should not expose a Codex adapter"
test ! -e "$ROOT/community/skills-sh/codex/skills/graphify/agents/openai.yaml" || fail "graphify should not expose a Codex adapter"

test ! -d "$ROOT/community/openspec" || fail "community/openspec should be retired"
test ! -d "$ROOT/third_party/community" || fail "third_party/community should be retired"
test ! -d "$ROOT/community-adapters" || fail "community-adapters should be retired"
test ! -f "$ROOT/tools/dev/generate_opsx_adapters.py" || fail "generate_opsx_adapters.py should be retired"

test ! -d "$ROOT/codex/skills" || fail "codex/skills should not remain as a maintained source tree"
test ! -d "$ROOT/claude/reference" || fail "claude/reference should not remain as a maintained source tree"
test ! -d "$ROOT/claude/rules" || fail "claude/rules should not remain as a maintained source tree"
test ! -f "$ROOT/claude/hooks/lib/common.sh" || fail "claude/hooks/lib/common.sh should be sourced from shared/hooks/lib/common.sh"

for skill in product-director product-manager design test-design tech-lead delivery-owner developer review verify qa fix worktree commit ux feishu-docs deep-research; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  test -f "$skill_file" || fail "missing skill source for manual-only check: $skill_file"
  grep -Fq 'disable-model-invocation: true' "$skill_file" || fail "manual-only skill should declare disable-model-invocation in source: $skill"
done

python3 "$ROOT/tools/community/source_lock_check.py" >/dev/null || fail "community source lock check failed"
python3 "$ROOT/tools/community/check_superpowers_upstream_fidelity.py" >/dev/null || fail "Superpowers fidelity check failed"

echo "[PASS] single-source layout"
