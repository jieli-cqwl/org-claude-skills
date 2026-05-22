#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

install_test_init

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

install_test_case_start "runtime-smoke: install and uninstall preserve runtime shape"
home_dir="$(install_test_new_home runtime-smoke)"
state_root="$(install_test_state_root "$home_dir")"
codex_skills_dir="$home_dir/.agents/skills"
mkdir -p "$home_dir/.codex/skills/.system/skill-creator"
printf 'legacy codex system skill-creator\n' > "$home_dir/.codex/skills/.system/skill-creator/SKILL.md"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-smoke-install)" --target all --check quick

install_test_assert_file_exists "$home_dir/.claude/CLAUDE.md" "claude runtime should include CLAUDE.md"
install_test_assert_file_exists "$home_dir/.codex/AGENTS.md" "codex runtime should include AGENTS.md"
install_test_assert_file_exists "$codex_skills_dir/product-manager/SKILL.md" "codex user skills should install to official ~/.agents/skills"
install_test_assert_path_absent "$home_dir/.codex/skills/product-manager/SKILL.md" "codex managed skills should not remain in legacy ~/.codex/skills"

for runtime in "$home_dir/.claude/skills" "$codex_skills_dir"; do
  for skill in "${official_skills[@]}"; do
    install_test_assert_file_exists "$runtime/$skill/SKILL.md" "runtime should include official Superpowers skill $skill"
    cmp -s "$ROOT/community/superpowers/skills/$skill/SKILL.md" "$runtime/$skill/SKILL.md" || install_test_fail "runtime Superpowers skill should match source: $runtime $skill"
    install_test_assert_path_absent "$runtime/$skill/agents/openai.yaml" "Superpowers adapter should not exist for $skill"
  done
  install_test_assert_path_absent "$runtime/verify-change" "retired Superpowers verify-change should not install"
  install_test_assert_path_absent "$runtime/archive" "retired Superpowers archive should not install"
  install_test_assert_path_absent "$runtime/parallel-subagent-development" "retired Superpowers parallel-subagent-development should not install"
done

if find "$home_dir/.claude/skills" "$home_dir/.agents/skills" \
  \( -path '*/evals/*/SKILL.md' -o -path '*/fixtures/*/SKILL.md' -o -path '*/examples/*/SKILL.md' -o -path '*/selves/*/SKILL.md' -o -path '*/*-workspace/*' \) \
  -print -quit | grep -q .; then
  install_test_fail "runtime should not expose internal eval/example/self/workspace files"
fi

install_test_assert_file_exists "$home_dir/.claude/skills/code-review-fix/SKILL.md" "claude runtime should include code-review-fix"
install_test_assert_file_exists "$home_dir/.claude/skills/doc-review-fix/SKILL.md" "claude runtime should include doc-review-fix"
install_test_assert_file_exists "$home_dir/.claude/skills/skill-creator/SKILL.md" "claude runtime should include skill-creator"
install_test_assert_path_absent "$codex_skills_dir/skill-creator" "codex user runtime should not install Anthropic skill-creator because Codex provides a bundled system skill"
install_test_assert_file_contains "$home_dir/.codex/skills/.system/skill-creator/SKILL.md" "legacy codex system skill-creator" "installer should not manage Codex bundled system skills"
install_test_assert_file_exists "$codex_skills_dir/webapp-testing/agents/openai.yaml" "codex webapp-testing adapter should exist"
install_test_assert_file_exists "$home_dir/.claude/skills/agent-reach/SKILL.md" "claude runtime should include agent-reach"
install_test_assert_file_exists "$codex_skills_dir/agent-reach/SKILL.md" "codex runtime should include agent-reach"
install_test_assert_file_exists "$codex_skills_dir/agent-reach/agents/openai.yaml" "codex agent-reach adapter should exist"
install_test_assert_file_exists "$codex_skills_dir/agent-browser/SKILL.md" "codex runtime should include agent-browser"
install_test_assert_file_not_contains "$codex_skills_dir/agent-browser/agents/openai.yaml" "allow_implicit_invocation: false" "codex agent-browser should remain auto"
install_test_assert_file_exists "$codex_skills_dir/ui-ux-pro-max/SKILL.md" "codex runtime should include ui-ux-pro-max"
install_test_assert_file_contains "$codex_skills_dir/ui-ux-pro-max/agents/openai.yaml" "allow_implicit_invocation: false" "codex ui-ux-pro-max should disable implicit invocation"
install_test_assert_file_exists "$codex_skills_dir/to-prd/SKILL.md" "codex runtime should include to-prd"
install_test_assert_file_contains "$codex_skills_dir/to-prd/agents/openai.yaml" "allow_implicit_invocation: false" "codex to-prd should disable implicit invocation"
install_test_assert_file_exists "$codex_skills_dir/prd/SKILL.md" "codex runtime should include prd"
install_test_assert_file_contains "$codex_skills_dir/prd/agents/openai.yaml" "allow_implicit_invocation: false" "codex prd should disable implicit invocation"
install_test_assert_file_exists "$codex_skills_dir/baoyu-markdown-to-html/SKILL.md" "codex runtime should include baoyu-markdown-to-html"
install_test_assert_file_contains "$codex_skills_dir/baoyu-markdown-to-html/agents/openai.yaml" "allow_implicit_invocation: false" "codex baoyu-markdown-to-html should disable implicit invocation"
install_test_assert_file_exists "$codex_skills_dir/code-to-prd/SKILL.md" "codex runtime should include code-to-prd"
install_test_assert_file_contains "$codex_skills_dir/code-to-prd/agents/openai.yaml" "allow_implicit_invocation: false" "codex code-to-prd should disable implicit invocation"
install_test_assert_file_exists "$codex_skills_dir/graphify/SKILL.md" "codex runtime should include graphify"
install_test_assert_file_contains "$codex_skills_dir/graphify/agents/openai.yaml" "allow_implicit_invocation: false" "codex graphify should disable implicit invocation"
install_test_assert_file_exists "$home_dir/.claude/skills/planning-with-files/SKILL.md" "claude runtime should include planning-with-files"
install_test_assert_file_contains "$home_dir/.claude/skills/planning-with-files/SKILL.md" "disable-model-invocation: true" "claude planning-with-files should be manual-only"
install_test_assert_file_not_contains "$home_dir/.claude/skills/planning-with-files/SKILL.md" "hooks:" "claude planning-with-files should not keep upstream auto hooks"
install_test_assert_file_exists "$codex_skills_dir/planning-with-files/SKILL.md" "codex runtime should include planning-with-files"
install_test_assert_file_not_contains "$codex_skills_dir/planning-with-files/SKILL.md" "hooks:" "codex planning-with-files should not keep upstream auto hooks"
install_test_assert_file_contains "$codex_skills_dir/planning-with-files/agents/openai.yaml" "allow_implicit_invocation: false" "codex planning-with-files should disable implicit invocation"
install_test_assert_file_exists "$codex_skills_dir/cli-updater/SKILL.md" "codex runtime should include cli-updater"
install_test_assert_file_contains "$codex_skills_dir/cli-updater/agents/openai.yaml" "allow_implicit_invocation: false" "codex cli-updater should disable implicit invocation"
install_test_assert_path_absent "$codex_skills_dir/ai-cli-updater" "codex runtime should not include retired ai-cli-updater"
install_test_assert_file_contains "$codex_skills_dir/cli-updater/SKILL.md" "name: cli-updater" "cli-updater skill metadata should use new name"
install_test_assert_file_contains "$codex_skills_dir/cli-updater/SKILL.md" '$cli-updater' "cli-updater should reference its new slash command"
install_test_assert_file_not_contains "$codex_skills_dir/cli-updater/SKILL.md" '$ai-cli-updater' "cli-updater should not reference retired slash command"
install_test_assert_file_contains "$codex_skills_dir/product-director/agents/openai.yaml" "allow_implicit_invocation: false" "codex product-director should disable implicit invocation"
install_test_assert_file_contains "$codex_skills_dir/tech-lead/agents/openai.yaml" "allow_implicit_invocation: false" "codex tech-lead should disable implicit invocation"
install_test_assert_file_contains "$codex_skills_dir/commit/agents/openai.yaml" "allow_implicit_invocation: false" "codex commit should disable implicit invocation"
install_test_assert_file_contains "$codex_skills_dir/github-repo-radar/agents/openai.yaml" "allow_implicit_invocation: false" "codex github-repo-radar should disable implicit invocation"
install_test_assert_file_contains "$codex_skills_dir/refactor/agents/openai.yaml" "allow_implicit_invocation: false" "codex refactor should disable implicit invocation"
install_test_assert_file_contains "$codex_skills_dir/security/agents/openai.yaml" "allow_implicit_invocation: false" "codex security should disable implicit invocation"
install_test_assert_path_absent "$codex_skills_dir/code-review-fix" "codex should not install claude-only code-review-fix"
install_test_assert_file_exists "$home_dir/.codex/hooks.json" "codex hooks.json should exist"
install_test_assert_file_contains "$home_dir/.codex/config.toml" "hooks = true" "codex install should enable hooks feature"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "codex_hooks" "codex install should not keep deprecated codex_hooks feature"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/context_contract_validator.py" "codex hooks should include context validator"
install_test_assert_path_absent "$home_dir/.codex/hooks/managed/implementation_router.py" "codex implementation router hook should not install"

install_test_assert_control_plane_runtime_files "$home_dir/.claude" "claude runtime"
install_test_assert_control_plane_runtime_files "$home_dir/.codex" "codex runtime"

install_test_assert_file_exists "$state_root/claude/installed-version" "claude external state should record installed version"
install_test_assert_file_exists "$state_root/codex/installed-version" "codex external state should record installed version"
install_test_assert_path_absent "$home_dir/.claude/.org-installed-version" "claude legacy runtime version metadata should be absent"
install_test_assert_path_absent "$home_dir/.codex/.org-installed-version" "codex legacy runtime version metadata should be absent"

install_test_run_install "$home_dir" "$(install_test_log_path runtime-smoke-uninstall)" --target all --uninstall

install_test_assert_path_absent "$home_dir/.claude/skills/brainstorming/SKILL.md" "claude managed skill should be removed after uninstall"
install_test_assert_path_absent "$home_dir/.codex/AGENTS.md" "codex AGENTS.md should be removed after uninstall"
install_test_assert_path_absent "$codex_skills_dir/brainstorming/SKILL.md" "codex managed skill should be removed after uninstall"
install_test_assert_file_contains "$home_dir/.codex/config.toml" 'model = "gpt-5"' "codex config should preserve model after uninstall"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "hooks = true" "codex config should restore hooks baseline after uninstall"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "codex_hooks" "codex config should not restore deprecated codex_hooks after uninstall"
install_test_assert_path_absent "$state_root/claude" "claude state dir should be removed after uninstall"
install_test_assert_path_absent "$state_root/codex" "codex state dir should be removed after uninstall"

install_test_case_pass "runtime-smoke: install and uninstall preserve runtime shape"

printf '\nInstall runtime smoke tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
