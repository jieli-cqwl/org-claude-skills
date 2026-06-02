#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

GROUP="all"

usage() {
  cat <<'USAGE'
Usage: bash tests/test-install-safety.sh [--group all|backup-and-conflict|external-codex|external-claude|rollback|codex-hooks|state-cleanup|preserve-backup]
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --group)
      [ "$#" -ge 2 ] || install_test_fail "--group 缺少参数"
      GROUP="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      install_test_fail "未知参数: $1"
      ;;
  esac
done

case "$GROUP" in
  all|backup-and-conflict|external-codex|external-claude|rollback|codex-hooks|state-cleanup|preserve-backup) ;;
  *) install_test_fail "未知 install-safety group: $GROUP" ;;
esac

should_run_group() {
  [ "$GROUP" = "all" ] || [ "$GROUP" = "$1" ]
}

install_test_init

if should_run_group backup-and-conflict; then
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

install_test_case_start "safety: codex legacy skill conflict reports usable error without force"
home_dir="$(install_test_new_home safety-codex-legacy-skill-conflict)"
mkdir -p "$home_dir/.codex/skills/local-legacy"
printf 'local legacy skill\n' > "$home_dir/.codex/skills/local-legacy/SKILL.md"
log_file="$(install_test_log_path safety-codex-legacy-skill-conflict)"
set +e
install_test_run_install_fake_openspec_allow_failure "$home_dir" "$log_file" --target codex --check quick
rc=$?
set -e
install_test_assert_failure "$rc" "codex install should fail on unmanaged legacy skill without --force"
install_test_assert_file_contains "$log_file" "codex 检测到旧路径 ~/.codex/skills/local-legacy；请人工确认后使用 --force 归档" "legacy codex conflict should show actionable message"
install_test_assert_file_not_contains "$log_file" "unbound variable" "legacy codex conflict should not crash under nounset"
install_test_assert_file_contains "$home_dir/.codex/skills/local-legacy/SKILL.md" "local legacy skill" "legacy skill should remain unchanged when install is refused"
install_test_case_pass "safety: codex legacy skill conflict reports usable error without force"
fi

if should_run_group external-codex; then
  install_test_case_start "safety: codex external runtime skill survives reinstall"
home_dir="$(install_test_new_home safety-codex-external-runtime-skill)"
state_root="$(install_test_state_root "$home_dir")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-codex-external-runtime-skill-1)" --target codex --force --check quick
mkdir -p "$home_dir/.agents/skills/cc/references" "$state_root/external-runtime-skills"
cat > "$home_dir/.agents/skills/cc/SKILL.md" <<'MD'
---
name: cc
description: External QFT command panel.
---
# CC
MD
printf 'external routes\n' > "$home_dir/.agents/skills/cc/references/cc-routes.md"
cat > "$state_root/external-runtime-skills/codex.txt" <<'TXT'
# qft-cc-core maintained outside org-claude-skills
cc
TXT
printf '%s\n' \
  "$home_dir/.agents/skills/cc/SKILL.md" \
  "$home_dir/.agents/skills/cc/references/cc-routes.md" >> "$state_root/codex/installed-manifest"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-codex-external-runtime-skill-2)" --target codex --force --check quick
install_test_assert_file_contains "$home_dir/.agents/skills/cc/SKILL.md" "External QFT command panel" "external codex skill should not be pruned as stale managed file"
install_test_assert_file_contains "$home_dir/.agents/skills/cc/references/cc-routes.md" "external routes" "external codex skill child file should not be pruned"
install_test_assert_file_not_contains "$state_root/codex/pruned-manifest" "$home_dir/.agents/skills/cc/SKILL.md" "external codex skill should not be recorded as pruned"
install_test_run_install "$home_dir" "$(install_test_log_path safety-codex-external-runtime-skill-uninstall)" --target codex --uninstall
install_test_assert_file_contains "$home_dir/.agents/skills/cc/SKILL.md" "External QFT command panel" "external codex skill should survive org uninstall"
install_test_assert_file_contains "$home_dir/.agents/skills/cc/references/cc-routes.md" "external routes" "external codex skill child file should survive org uninstall"
install_test_case_pass "safety: codex external runtime skill survives reinstall"
fi

if should_run_group external-claude; then
  install_test_case_start "safety: claude external runtime skill survives reinstall"
home_dir="$(install_test_new_home safety-claude-external-runtime-skill)"
state_root="$(install_test_state_root "$home_dir")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-claude-external-runtime-skill-1)" --target claude --force --check quick
mkdir -p "$home_dir/.claude/skills/cc/references" "$state_root/external-runtime-skills"
cat > "$home_dir/.claude/skills/cc/SKILL.md" <<'MD'
---
name: cc
description: External QFT command panel.
---
# CC
MD
printf 'external routes\n' > "$home_dir/.claude/skills/cc/references/cc-routes.md"
cat > "$state_root/external-runtime-skills/claude.txt" <<'TXT'
# qft-cc-core maintained outside org-claude-skills
cc
TXT
printf '%s\n' \
  "$home_dir/.claude/skills/cc/SKILL.md" \
  "$home_dir/.claude/skills/cc/references/cc-routes.md" >> "$state_root/claude/installed-manifest"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-claude-external-runtime-skill-2)" --target claude --force --check quick
install_test_assert_file_contains "$home_dir/.claude/skills/cc/SKILL.md" "External QFT command panel" "external claude skill should not be pruned as stale managed file"
install_test_assert_file_contains "$home_dir/.claude/skills/cc/references/cc-routes.md" "external routes" "external claude skill child file should not be pruned"
install_test_assert_file_not_contains "$state_root/claude/pruned-manifest" "$home_dir/.claude/skills/cc/SKILL.md" "external claude skill should not be recorded as pruned"
install_test_run_install "$home_dir" "$(install_test_log_path safety-claude-external-runtime-skill-uninstall)" --target claude --uninstall
install_test_assert_file_contains "$home_dir/.claude/skills/cc/SKILL.md" "External QFT command panel" "external claude skill should survive org uninstall"
install_test_assert_file_contains "$home_dir/.claude/skills/cc/references/cc-routes.md" "external routes" "external claude skill child file should survive org uninstall"
install_test_case_pass "safety: claude external runtime skill survives reinstall"
fi

if should_run_group rollback; then
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

install_test_case_start "safety: install failure rolls back runtime audit skill cleanup"
home_dir="$(install_test_new_home safety-rollback-runtime-audit-cleanup)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p \
  "$home_dir/.agents/skills/zz-runtime-probe-before-fail" \
  "$home_dir/.codex/skills/zz-runtime-probe-legacy" \
  "$home_dir/.codex/reference"
printf 'probe skill should survive failed install\n' > "$home_dir/.agents/skills/zz-runtime-probe-before-fail/SKILL.md"
printf 'legacy probe skill should survive failed install\n' > "$home_dir/.codex/skills/zz-runtime-probe-legacy/SKILL.md"
chmod 500 "$home_dir/.codex/reference"
set +e
install_test_run_install_allow_failure "$home_dir" "$(install_test_log_path safety-rollback-runtime-audit-cleanup-install)" --target codex --force --check quick
rc=$?
set -e
chmod 700 "$home_dir/.codex/reference" || true
install_test_assert_failure "$rc" "install should fail after runtime audit cleanup has found stale skill roots"
install_test_assert_file_contains "$home_dir/.agents/skills/zz-runtime-probe-before-fail/SKILL.md" "probe skill should survive failed install" "rollback should restore active runtime probe skill cleanup"
install_test_assert_file_contains "$home_dir/.codex/skills/zz-runtime-probe-legacy/SKILL.md" "legacy probe skill should survive failed install" "rollback should restore codex legacy skill cleanup"
install_test_assert_path_absent "$state_root/codex/installed-version" "rollback should not leave codex version metadata after audit cleanup failure"
install_test_case_pass "safety: install failure rolls back runtime audit skill cleanup"

install_test_case_start "safety: install failure restores normalized directory symlink"
home_dir="$(install_test_new_home safety-rollback-symlink)"
state_root="$(install_test_state_root "$home_dir")"
external_reference="$home_dir/external-reference"
mkdir -p "$external_reference" "$home_dir/.claude/skills"
rm -rf "$home_dir/.claude/reference"
ln -s "$external_reference" "$home_dir/.claude/reference"
chmod 500 "$home_dir/.claude/skills"
set +e
install_test_run_install_allow_failure "$home_dir" "$(install_test_log_path safety-rollback-symlink-install)" --target claude --force --check quick
rc=$?
set -e
chmod 700 "$home_dir/.claude/skills" || true
install_test_assert_failure "$rc" "install should fail after normalizing reference symlink"
[ -L "$home_dir/.claude/reference" ] || install_test_fail "rollback should restore reference directory symlink"
[ "$(readlink "$home_dir/.claude/reference")" = "$external_reference" ] || install_test_fail "rollback should restore original reference symlink target"
install_test_assert_path_absent "$state_root/claude/installed-version" "rollback should not leave version metadata after symlink normalization failure"
install_test_case_pass "safety: install failure restores normalized directory symlink"

install_test_case_start "safety: uninstall restores normalized directory symlink"
home_dir="$(install_test_new_home safety-uninstall-symlink)"
external_reference="$home_dir/external-reference"
mkdir -p "$external_reference" "$home_dir/.claude"
rm -rf "$home_dir/.claude/reference"
ln -s "$external_reference" "$home_dir/.claude/reference"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-uninstall-symlink-install)" --target claude --force --check quick
install_test_run_install "$home_dir" "$(install_test_log_path safety-uninstall-symlink-uninstall)" --target claude --uninstall
[ -L "$home_dir/.claude/reference" ] || install_test_fail "uninstall should restore reference directory symlink"
[ "$(readlink "$home_dir/.claude/reference")" = "$external_reference" ] || install_test_fail "uninstall should restore original reference symlink target"
install_test_case_pass "safety: uninstall restores normalized directory symlink"
fi

if should_run_group codex-hooks; then
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
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "hooks = true" "hooks feature should restore pre-install baseline during uninstall"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "codex_hooks" "deprecated codex_hooks feature should not remain during uninstall"
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
fi

if should_run_group state-cleanup; then
  install_test_case_start "safety: uninstall removes external state dirs"
home_dir="$(install_test_new_home safety-state-cleanup)"
state_root="$(install_test_state_root "$home_dir")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path safety-state-cleanup-install)" --target all --force --check quick
install_test_run_install "$home_dir" "$(install_test_log_path safety-state-cleanup-uninstall)" --target all --uninstall
install_test_assert_path_absent "$state_root/claude" "claude state dir should be removed after uninstall"
install_test_assert_path_absent "$state_root/codex" "codex state dir should be removed after uninstall"
install_test_case_pass "safety: uninstall removes external state dirs"
fi

if should_run_group preserve-backup; then
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
fi

printf '\nInstall safety tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
