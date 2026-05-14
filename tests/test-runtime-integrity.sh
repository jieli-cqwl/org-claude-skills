#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
TMP_HOME="$(mktemp -d)"
STATE_ROOT="$TMP_HOME/.org-skills-state"
CODEX_SKILLS_DIR="$TMP_HOME/.agents/skills"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

manual_policy() {
  local skill="$1"
  test -f "$CODEX_SKILLS_DIR/$skill/agents/openai.yaml" \
    && grep -Fq 'allow_implicit_invocation: false' "$CODEX_SKILLS_DIR/$skill/agents/openai.yaml"
}

auto_policy() {
  local skill="$1"
  test -f "$CODEX_SKILLS_DIR/$skill/agents/openai.yaml" \
    && ! grep -Fq 'allow_implicit_invocation: false' "$CODEX_SKILLS_DIR/$skill/agents/openai.yaml"
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

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
printf '{"hooks":{}}\n' > "$TMP_HOME/.claude/settings.json"
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
TOML

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 ORG_SKIP_CODEX_HOOK_TRUST_AUDIT=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_runtime_integrity_install.out 2>&1 || {
  cat /tmp/org_runtime_integrity_install.out >&2
  fail "install failed"
}

python3 "$ROOT/tools/community/source_lock_check.py" >/dev/null || fail "source lock invalid"
python3 "$ROOT/tools/community/check_superpowers_upstream_fidelity.py" >/dev/null || fail "Superpowers fidelity invalid"
python3 "$ROOT/tools/community/render_canonical.py" >/dev/null || fail "canonical assets missing"

for runtime in "$TMP_HOME/.claude" "$TMP_HOME/.agents"; do
  for skill in "${official_skills[@]}"; do
    runtime_skill="$runtime/skills/$skill/SKILL.md"
    source_skill="$ROOT/community/superpowers/skills/$skill/SKILL.md"
    test -f "$runtime_skill" || fail "missing official Superpowers skill in runtime: $runtime $skill"
    cmp -s "$source_skill" "$runtime_skill" || fail "runtime Superpowers skill differs from source: $runtime $skill"
    test ! -f "$runtime/skills/$skill/agents/openai.yaml" || fail "Superpowers adapter should not exist in runtime: $runtime $skill"
    if grep -Eq '^(user-invocable|disable-model-invocation):' "$runtime_skill"; then
      fail "Superpowers runtime frontmatter should remain official: $runtime $skill"
    fi
  done
  for retired in verify-change archive parallel-subagent-development; do
    test ! -e "$runtime/skills/$retired" || fail "retired Superpowers skill should not exist in runtime: $runtime $retired"
  done
done

test -f "$TMP_HOME/.claude/CLAUDE.md" || fail "missing ~/.claude/CLAUDE.md"
test -f "$TMP_HOME/.codex/AGENTS.md" || fail "missing ~/.codex/AGENTS.md"
test -f "$TMP_HOME/.claude/skills/product-director/SKILL.md" || fail "missing Claude first-party product-director"
test -f "$CODEX_SKILLS_DIR/product-director/SKILL.md" || fail "missing Codex first-party product-director"
test ! -e "$TMP_HOME/.codex/skills/product-director" || fail "Codex first-party skills should not remain in legacy ~/.codex/skills"
manual_policy product-director || fail "product-director should disable Codex implicit invocation"
manual_policy tech-lead || fail "tech-lead should disable Codex implicit invocation"
manual_policy commit || fail "commit should disable Codex implicit invocation"
test -f "$CODEX_SKILLS_DIR/skill-creator/SKILL.md" || fail "skill-creator Anthropic source should install"
test ! -e "$CODEX_SKILLS_DIR/skill-creator/agents/openai.yaml" || fail "skill-creator Anthropic adapter should not exist"
test -f "$CODEX_SKILLS_DIR/find-skills/agents/openai.yaml" || fail "find-skills Vercel adapter should remain"
test -f "$CODEX_SKILLS_DIR/webapp-testing/agents/openai.yaml" || fail "webapp-testing Anthropic adapter should remain"
auto_policy agent-browser || fail "agent-browser should remain auto"
auto_policy ui-ux-pro-max || fail "ui-ux-pro-max should remain auto"
manual_policy github-repo-radar || fail "github-repo-radar should disable Codex implicit invocation"
manual_policy refactor || fail "refactor should disable Codex implicit invocation"
manual_policy security || fail "security should disable Codex implicit invocation"

test -f "$TMP_HOME/.claude/hooks/registry.json" || fail "missing Claude hook registry"
test -f "$TMP_HOME/.codex/hooks/registry.json" || fail "missing Codex hook registry"
test ! -f "$TMP_HOME/.codex/hooks/managed/implementation_router.py" || fail "implementation router hook should not install"
test ! -f "$TMP_HOME/.claude/hooks/managed/implementation_router.py" || fail "implementation router hook should not install"
if grep -Fq 'implementation-router' "$TMP_HOME/.codex/hooks/registry.json"; then
  fail "runtime hook registry should not contain implementation-router"
fi

grep -Fq 'hooks = true' "$TMP_HOME/.codex/config.toml" || fail "codex install should enable hooks feature"
! grep -Eq '^[[:space:]]*codex_hooks[[:space:]]*=' "$TMP_HOME/.codex/config.toml" || fail "codex install should not keep deprecated codex_hooks feature"
grep -Fq "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include managed dangerous hook"
grep -Fq "$TMP_HOME/.codex/hooks/managed/context_contract_validator.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include context validator"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include active-skill tracker"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include stop dispatcher"

test -f "$STATE_ROOT/claude/installed-version" || fail "missing claude state version"
test -f "$STATE_ROOT/codex/installed-version" || fail "missing codex state version"

echo "[PASS] runtime integrity"
