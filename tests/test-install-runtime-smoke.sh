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
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-smoke-install)" --target all --check quick

install_test_assert_file_exists "$home_dir/.claude/CLAUDE.md" "claude runtime should include CLAUDE.md"
install_test_assert_file_exists "$home_dir/.codex/AGENTS.md" "codex runtime should include AGENTS.md"

for runtime in "$home_dir/.claude" "$home_dir/.codex"; do
  for skill in "${official_skills[@]}"; do
    install_test_assert_file_exists "$runtime/skills/$skill/SKILL.md" "runtime should include official Superpowers skill $skill"
    cmp -s "$ROOT/community/superpowers/skills/$skill/SKILL.md" "$runtime/skills/$skill/SKILL.md" || install_test_fail "runtime Superpowers skill should match source: $runtime $skill"
    install_test_assert_path_absent "$runtime/skills/$skill/agents/openai.yaml" "Superpowers adapter should not exist for $skill"
  done
  install_test_assert_path_absent "$runtime/skills/verify-change" "retired Superpowers verify-change should not install"
  install_test_assert_path_absent "$runtime/skills/archive" "retired Superpowers archive should not install"
  install_test_assert_path_absent "$runtime/skills/parallel-subagent-development" "retired Superpowers parallel-subagent-development should not install"
done

install_test_assert_file_exists "$home_dir/.claude/skills/code-review-fix/SKILL.md" "claude runtime should include code-review-fix"
install_test_assert_file_exists "$home_dir/.claude/skills/doc-review-fix/SKILL.md" "claude runtime should include doc-review-fix"
install_test_assert_file_exists "$home_dir/.claude/skills/skill-creator/SKILL.md" "claude runtime should include skill-creator"
install_test_assert_file_exists "$home_dir/.codex/skills/skill-creator/agents/openai.yaml" "codex skill-creator adapter should exist"
install_test_assert_file_exists "$home_dir/.codex/skills/webapp-testing/agents/openai.yaml" "codex webapp-testing adapter should exist"
install_test_assert_path_absent "$home_dir/.codex/skills/product-director/agents/openai.yaml" "codex product-director should be manual-only"
install_test_assert_path_absent "$home_dir/.codex/skills/code-review-fix" "codex should not install claude-only code-review-fix"
install_test_assert_file_exists "$home_dir/.codex/hooks.json" "codex hooks.json should exist"
install_test_assert_file_contains "$home_dir/.codex/config.toml" "codex_hooks = true" "codex install should enable codex hooks"
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
install_test_assert_path_absent "$home_dir/.codex/skills/brainstorming/SKILL.md" "codex managed skill should be removed after uninstall"
install_test_assert_file_contains "$home_dir/.codex/config.toml" 'model = "gpt-5"' "codex config should preserve model after uninstall"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "codex_hooks = true" "codex config should restore codex_hooks baseline after uninstall"
install_test_assert_path_absent "$state_root/claude" "claude state dir should be removed after uninstall"
install_test_assert_path_absent "$state_root/codex" "codex state dir should be removed after uninstall"

install_test_case_pass "runtime-smoke: install and uninstall preserve runtime shape"

printf '\nInstall runtime smoke tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
