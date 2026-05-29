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
install_test_assert_file_exists "$home_dir/.codex/rules/交付验收底线.md" "codex runtime should include rules"
install_test_assert_file_exists "$home_dir/.codex/reference/测试规范.md" "codex runtime should include reference docs"
install_test_assert_file_exists "$codex_skills_dir/product-manager/SKILL.md" "codex runtime should install managed user skills"
install_test_assert_file_exists "$home_dir/.codex/hooks.json" "codex runtime should include hooks.json"
install_test_case_pass "runtime-quick-canary: codex install exposes managed runtime entry"

install_test_case_start "runtime-quick-canary: task verify ruff lint is scoped to changed files"
workspace="$INSTALL_TEST_TMP_ROOT/task-verify-scope-workspace"
mkdir -p "$workspace/vendor"
(
  cd "$workspace"
  git init -q
  printf '%s\n' 'print(f"upstream lint debt")' > vendor/upstream.py
  printf '%s\n' 'print("clean")' > changed.py
  git add .
  git -c user.name=test -c user.email=test@example.com commit -q -m init
  printf '%s\n' 'print("clean changed")' > changed.py
)
verify_log="$(install_test_log_path runtime-quick-canary-task-verify-scope)"
printf '{"cwd":"%s"}' "$workspace" | COMMENT_CHECK_MODE=warn bash "$ROOT/claude/hooks/task_verify.sh" >"$verify_log" 2>&1 || install_test_fail "task verify should ignore unchanged upstream lint debt"
install_test_assert_file_not_contains "$verify_log" "vendor/upstream.py" "task verify should not lint unchanged Python files"
install_test_case_pass "runtime-quick-canary: task verify ruff lint is scoped to changed files"

install_test_case_start "runtime-quick-canary: task verify warn details stay out of hook output"
workspace="$INSTALL_TEST_TMP_ROOT/task-verify-warn-report-workspace"
report_dir="$INSTALL_TEST_TMP_ROOT/task-verify-reports"
mkdir -p "$workspace" "$report_dir"
(
  cd "$workspace"
  git init -q
  git -c user.name=test -c user.email=test@example.com commit --allow-empty -q -m init
  printf '%s\n' 'def sample():' '    return 1' > target.py
)
verify_log="$(install_test_log_path runtime-quick-canary-task-verify-warn-report)"
printf '{"cwd":"%s"}' "$workspace" | CLAUDE_TASK_VERIFY_REPORT_DIR="$report_dir" COMMENT_CHECK_MODE=warn bash "$ROOT/claude/hooks/task_verify.sh" >"$verify_log" 2>&1 || install_test_fail "task verify warn mode should not block task completion"
install_test_assert_file_contains "$verify_log" "完整报告：" "task verify warn output should point to the full report"
install_test_assert_file_not_contains "$verify_log" "函数注释缺失" "task verify warn output should not inline detailed findings"
report_line=$(grep -F "完整报告：" "$verify_log" | tail -1)
report_path="${report_line##*完整报告：}"
[ -f "$report_path" ] || install_test_fail "task verify warn report should exist: $report_path"
install_test_assert_file_contains "$report_path" "函数注释缺失" "task verify warn report should keep detailed findings"
install_test_case_pass "runtime-quick-canary: task verify warn details stay out of hook output"

printf '\nInstall runtime quick canary passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
