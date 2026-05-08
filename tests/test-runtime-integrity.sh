#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
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

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_runtime_integrity_install.out 2>&1 || {
  cat /tmp/org_runtime_integrity_install.out >&2
  fail "install failed"
}

python3 "$ROOT/tools/community/source_lock_check.py" >/dev/null || fail "source lock invalid"
python3 "$ROOT/tools/community/check_superpowers_upstream_fidelity.py" >/dev/null || fail "Superpowers fidelity invalid"
python3 "$ROOT/tools/community/render_canonical.py" >/dev/null || fail "canonical assets missing"

for runtime in "$TMP_HOME/.claude" "$TMP_HOME/.codex"; do
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
test -f "$TMP_HOME/.codex/skills/product-director/SKILL.md" || fail "missing Codex first-party product-director"
test ! -f "$TMP_HOME/.codex/skills/product-director/agents/openai.yaml" || fail "product-director should be codex manual-only"
test -f "$TMP_HOME/.codex/skills/skill-creator/agents/openai.yaml" || fail "skill-creator Anthropic adapter should remain"
test -f "$TMP_HOME/.codex/skills/find-skills/agents/openai.yaml" || fail "find-skills Vercel adapter should remain"
test -f "$TMP_HOME/.codex/skills/webapp-testing/agents/openai.yaml" || fail "webapp-testing Anthropic adapter should remain"
test ! -f "$TMP_HOME/.codex/skills/agent-browser/agents/openai.yaml" || fail "agent-browser should remain manual-only"

test -f "$TMP_HOME/.claude/hooks/registry.json" || fail "missing Claude hook registry"
test -f "$TMP_HOME/.codex/hooks/registry.json" || fail "missing Codex hook registry"
test ! -f "$TMP_HOME/.codex/hooks/managed/implementation_router.py" || fail "implementation router hook should not install"
test ! -f "$TMP_HOME/.claude/hooks/managed/implementation_router.py" || fail "implementation router hook should not install"
if grep -Fq 'implementation-router' "$TMP_HOME/.codex/hooks/registry.json"; then
  fail "runtime hook registry should not contain implementation-router"
fi

grep -Fq 'codex_hooks = true' "$TMP_HOME/.codex/config.toml" || fail "codex install should enable codex hooks"
grep -Fq "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include managed dangerous hook"
grep -Fq "$TMP_HOME/.codex/hooks/managed/context_contract_validator.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include context validator"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include active-skill tracker"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks should include stop dispatcher"

test -f "$STATE_ROOT/claude/installed-version" || fail "missing claude state version"
test -f "$STATE_ROOT/codex/installed-version" || fail "missing codex state version"

echo "[PASS] runtime integrity"
