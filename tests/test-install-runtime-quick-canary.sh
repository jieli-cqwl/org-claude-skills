#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

install_test_init

install_test_case_start "runtime-quick-canary: codex install exposes managed runtime entry"
home_dir="$(install_test_new_home runtime-quick-canary)"
codex_skills_dir="$home_dir/.agents/skills"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-quick-canary-install)" --target codex --check quick

install_test_assert_file_exists "$home_dir/.codex/AGENTS.md" "codex runtime should include AGENTS.md"
install_test_assert_file_contains "$home_dir/.codex/AGENTS.md" "硬约束来源" "codex entry should identify rules as the hard constraint source"
install_test_assert_file_exists "$home_dir/.codex/rules/铁律.md" "codex runtime should include rules"
install_test_assert_file_exists "$home_dir/.codex/reference/测试规范.md" "codex runtime should include reference docs"
install_test_assert_file_exists "$codex_skills_dir/product-manager/SKILL.md" "codex runtime should install managed user skills"
install_test_assert_file_exists "$home_dir/.codex/hooks.json" "codex runtime should include hooks.json"
install_test_case_pass "runtime-quick-canary: codex install exposes managed runtime entry"

printf '\nInstall runtime quick canary passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
