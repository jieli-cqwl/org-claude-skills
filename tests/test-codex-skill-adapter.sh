#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
TMP_HOME="$(mktemp -d)"
STATE_ROOT="$TMP_HOME/.org-skills-state"
CODEX_SKILLS_DIR="$TMP_HOME/.agents/skills"
GENERATE_OPENAI_YAML="$ROOT/tools/install/generate-all-openai-yaml.sh"

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

# shellcheck disable=SC2016 # Assert the literal fallback expression in the maintenance script.
grep -Fq 'SRC_CODEX_SKILLS="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"' "$GENERATE_OPENAI_YAML" || fail "openai yaml maintenance script should default to official ~/.agents/skills"
! grep -Eq 'SRC_CODEX_SKILLS=.*\\.codex/skills' "$GENERATE_OPENAI_YAML" || fail "openai yaml maintenance script should not default to legacy ~/.codex/skills"

mkdir -p "$TMP_HOME/.codex"
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"
TOML

run_with_fake_openspec "$TMP_HOME" env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 ORG_SKIP_CODEX_HOOK_TRUST_AUDIT=1 bash "$ROOT/install.sh" --target codex --force --check quick >/tmp/org_codex_skill_adapter_install.out 2>&1 || {
  cat /tmp/org_codex_skill_adapter_install.out >&2
  fail "install failed"
}

for skill in "${official_skills[@]}"; do
  runtime_skill="$CODEX_SKILLS_DIR/$skill/SKILL.md"
  source_skill="$ROOT/community/superpowers/skills/$skill/SKILL.md"
  [ -f "$runtime_skill" ] || fail "Codex runtime missing official Superpowers skill: $skill"
  cmp -s "$source_skill" "$runtime_skill" || fail "Codex runtime Superpowers skill should match source byte-for-byte: $skill"
  [ ! -f "$CODEX_SKILLS_DIR/$skill/agents/openai.yaml" ] || fail "Superpowers Codex adapter should not exist: $skill"
  if grep -Eq '^(user-invocable|disable-model-invocation):' "$runtime_skill"; then
    fail "Superpowers runtime SKILL.md should not be frontmatter-mutated: $skill"
  fi
done

for retired in verify-change archive parallel-subagent-development; do
  [ ! -e "$CODEX_SKILLS_DIR/$retired" ] || fail "retired Superpowers local skill should not install into Codex: $retired"
done

[ ! -e "$TMP_HOME/.codex/skills/codex-doc-review" ] || fail "codex runtime should not keep claude-only skill in legacy ~/.codex/skills"
[ ! -e "$CODEX_SKILLS_DIR/codex-doc-review" ] || fail "codex runtime should not install claude-only skill codex-doc-review"
[ ! -e "$CODEX_SKILLS_DIR/review-fix-loop" ] || fail "codex runtime should not install claude-only skill review-fix-loop"
[ ! -e "$CODEX_SKILLS_DIR/code-review-fix" ] || fail "codex runtime should not install claude-only skill code-review-fix"
[ ! -e "$CODEX_SKILLS_DIR/doc-review-fix" ] || fail "codex runtime should not install claude-only skill doc-review-fix"
[ -f "$CODEX_SKILLS_DIR/feishu-docs/SKILL.md" ] || fail "feishu-docs should install as a codex skill"
[ ! -f "$CODEX_SKILLS_DIR/feishu-docs/agents/openai.yaml" ] || fail "feishu-docs should remain codex manual-only"
[ -f "$CODEX_SKILLS_DIR/deep-research/SKILL.md" ] || fail "deep-research should install as a codex skill"
[ ! -f "$CODEX_SKILLS_DIR/deep-research/agents/openai.yaml" ] || fail "deep-research should remain codex manual-only"
[ ! -f "$CODEX_SKILLS_DIR/product-director/agents/openai.yaml" ] || fail "product-director should remain codex manual-only"
[ ! -f "$CODEX_SKILLS_DIR/tech-lead/agents/openai.yaml" ] || fail "tech-lead should remain codex manual-only"
[ ! -f "$CODEX_SKILLS_DIR/commit/agents/openai.yaml" ] || fail "commit should remain codex manual-only"
[ -f "$CODEX_SKILLS_DIR/skill-creator/agents/openai.yaml" ] || fail "skill-creator Anthropic adapter should remain installed"
[ -f "$CODEX_SKILLS_DIR/webapp-testing/agents/openai.yaml" ] || fail "webapp-testing Anthropic adapter should remain installed"
[ -f "$TMP_HOME/.codex/hooks.json" ] || fail "codex runtime should render hooks.json"
grep -Fq 'hooks = true' "$TMP_HOME/.codex/config.toml" || fail "codex runtime should enable hooks feature"
! grep -Eq '^[[:space:]]*codex_hooks[[:space:]]*=' "$TMP_HOME/.codex/config.toml" || fail "codex runtime should not keep deprecated codex_hooks feature"
grep -Fq "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing managed dangerous bash hook"
grep -Fq "$TMP_HOME/.codex/hooks/managed/context_contract_validator.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing context validator hook"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing active skill tracker"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing stop dispatcher"

echo "[PASS] codex skill adapter"
