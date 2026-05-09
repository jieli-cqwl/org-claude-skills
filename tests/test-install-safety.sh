#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

install_test_init

install_test_case_start "safety: uninstall refuses missing backup manifest"
home_dir="$(install_test_new_home safety-missing-backup)"
state_root="$(install_test_state_root "$home_dir")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-missing-backup-install)" --target claude --force --check quick
rm -f "$state_root/claude/backup-manifest"
set +e
install_test_run_install_allow_failure "$home_dir" "$(install_test_log_path safety-missing-backup-uninstall)" --uninstall --target claude
rc=$?
set -e
install_test_assert_failure "$rc" "uninstall should fail when backup manifest is missing"
install_test_assert_file_contains "$(install_test_log_path safety-missing-backup-uninstall)" "缺少 backup-manifest" "missing backup manifest message"
install_test_assert_file_exists "$home_dir/.claude/skills/product-director/SKILL.md" "managed files should remain when uninstall is refused"
install_test_case_pass "safety: uninstall refuses missing backup manifest"

install_test_case_start "safety: install failure rolls back managed files"
home_dir="$(install_test_new_home safety-rollback)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p "$home_dir/.claude/reference"
chmod 500 "$home_dir/.claude/reference"
set +e
install_test_run_install_allow_failure "$home_dir" "$(install_test_log_path safety-rollback-install)" --target claude --force --check quick
rc=$?
set -e
chmod 700 "$home_dir/.claude/reference" || true
install_test_assert_failure "$rc" "install should fail when reference dir is read-only"
install_test_assert_path_absent "$home_dir/.claude/agents/code-reviewer.md" "rollback should remove managed agent file"
install_test_assert_path_absent "$state_root/claude/installed-version" "rollback should not leave version metadata"
install_test_case_pass "safety: install failure rolls back managed files"

install_test_case_start "safety: codex uninstall preserves user hooks and restores config"
home_dir="$(install_test_new_home safety-codex-user-hooks)"
mkdir -p "$home_dir/bin"
mkdir -p "$home_dir/.codex/hooks/managed-old"
cat > "$home_dir/bin/notify.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$home_dir/bin/notify.sh"
cat > "$home_dir/.codex/hooks/managed-old/user_notify.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$home_dir/.codex/hooks/managed-old/user_notify.sh"
cat > "$home_dir/.codex/hooks.json" <<JSON
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$home_dir/bin/notify.sh"
          },
          {
            "type": "command",
            "command": "$home_dir/.codex/hooks/managed-old/user_notify.sh"
          }
        ]
      }
    ]
  }
}
JSON
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-codex-user-hooks-install)" --target codex --force --check quick
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed-old/user_notify.sh" "managed-looking user hook should remain after install"
install_test_run_install "$home_dir" "$(install_test_log_path safety-codex-user-hooks-uninstall)" --uninstall --target codex
install_test_assert_file_exists "$home_dir/.codex/hooks.json" "user hooks.json should remain after uninstall"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/bin/notify.sh" "user hook should remain after uninstall"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed-old/user_notify.sh" "user hook with managed-looking prefix should remain after uninstall"
install_test_assert_file_not_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/" "managed codex hooks should be removed during uninstall"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "codex_hooks = true" "codex_hooks feature should restore pre-install baseline during uninstall"
install_test_case_pass "safety: codex uninstall preserves user hooks and restores config"

install_test_case_start "safety: codex uninstall restores supported hook baseline"
home_dir="$(install_test_new_home safety-codex-supported-hooks)"
mkdir -p "$home_dir/bin"
cat > "$home_dir/bin/session_notify.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$home_dir/bin/session_notify.sh"
cat > "$home_dir/.codex/hooks.json" <<JSON
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$home_dir/bin/session_notify.sh"
          }
        ]
      }
    ]
  }
}
JSON
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-codex-supported-hooks-install)" --target codex --force --check quick
install_test_run_install "$home_dir" "$(install_test_log_path safety-codex-supported-hooks-uninstall)" --uninstall --target codex
install_test_assert_file_exists "$home_dir/.codex/hooks.json" "supported hooks.json baseline should be restored after uninstall"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"SessionStart"' "supported SessionStart hook should be restored after uninstall"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/bin/session_notify.sh" "supported SessionStart command should be restored after uninstall"
install_test_assert_file_not_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/" "managed codex hooks should not remain after restoring supported baseline"
install_test_case_pass "safety: codex uninstall restores supported hook baseline"

install_test_case_start "safety: uninstall removes external state dirs"
home_dir="$(install_test_new_home safety-state-cleanup)"
state_root="$(install_test_state_root "$home_dir")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-state-cleanup-install)" --target all --force --check quick
install_test_run_install "$home_dir" "$(install_test_log_path safety-state-cleanup-uninstall)" --target all --uninstall
install_test_assert_path_absent "$state_root/claude" "claude state dir should be removed after uninstall"
install_test_assert_path_absent "$state_root/codex" "codex state dir should be removed after uninstall"
install_test_case_pass "safety: uninstall removes external state dirs"

install_test_case_start "safety: repeated force install preserves original restore baseline"
home_dir="$(install_test_new_home safety-preserve-backup)"
mkdir -p "$home_dir/.claude/hooks"
printf 'user original hook\n' > "$home_dir/.claude/hooks/block_dangerous.sh"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-preserve-backup-1)" --target claude --force --check quick
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-preserve-backup-2)" --target claude --force --check quick
install_test_run_install "$home_dir" "$(install_test_log_path safety-preserve-backup-uninstall)" --target claude --uninstall
grep -Fxq 'user original hook' "$home_dir/.claude/hooks/block_dangerous.sh" \
  || install_test_fail "uninstall should restore the original user file after repeated force installs"
install_test_case_pass "safety: repeated force install preserves original restore baseline"

printf '\nInstall safety tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
