#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

install_test_init

install_test_case_start "migration: retired product symlink skill is cleaned"
home_dir="$(install_test_new_home migration-product-symlink)"
mkdir -p "$home_dir/.claude/skills/product/references" "$home_dir/.claude/skills/product/scripts"
mkdir -p "$home_dir/.codex/skills/product"
printf 'legacy product skill\n' > "$home_dir/.claude/skills/product/SKILL.md"
printf 'legacy ref\n' > "$home_dir/.claude/skills/product/references/legacy.md"
printf '#!/usr/bin/env bash\n' > "$home_dir/.claude/skills/product/scripts/legacy.sh"
ln -s "$home_dir/.claude/skills/product/SKILL.md" "$home_dir/.codex/skills/product/SKILL.md"
ln -s "$home_dir/.claude/skills/product/references" "$home_dir/.codex/skills/product/references"
ln -s "$home_dir/.claude/skills/product/scripts" "$home_dir/.codex/skills/product/scripts"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path migration-product-symlink-install)" --target codex --force --check quick
install_test_assert_path_absent "$home_dir/.codex/skills/product" "retired product skill should be removed after migration"
install_test_case_pass "migration: retired product symlink skill is cleaned"

install_test_case_start "migration: stale managed file is pruned and restored on uninstall"
home_dir="$(install_test_new_home migration-pruned-manifest)"
state_root="$(install_test_state_root "$home_dir")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path migration-pruned-first)" --target codex --force --check quick
stale_path="$home_dir/.codex/skills/product-director/obsolete-noise.md"
printf 'obsolete managed artifact\n' > "$stale_path"
printf '%s\n' "$stale_path" >> "$state_root/codex/installed-manifest"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path migration-pruned-second)" --target codex --force --check quick
install_test_assert_path_absent "$stale_path" "stale managed file should be pruned during install"
grep -Fxq "$stale_path" "$state_root/codex/pruned-manifest" || install_test_fail "pruned manifest missing stale path"
install_test_run_install "$home_dir" "$(install_test_log_path migration-pruned-uninstall)" --uninstall --target codex
install_test_assert_file_exists "$stale_path" "pruned stale file should be restorable on uninstall"
install_test_case_pass "migration: stale managed file is pruned and restored on uninstall"

install_test_case_start "migration: runtime metadata moves from runtime dir to state dir"
home_dir="$(install_test_new_home migration-legacy-state)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p "$home_dir/.claude/.org-backups/legacy/hooks"
printf '1.0.0-legacy\n' > "$home_dir/.claude/.org-installed-version"
printf '%s\n' "$home_dir/.claude/hooks/block_dangerous.sh" > "$home_dir/.claude/.org-installed-manifest"
printf '%s\t%s\n' \
  "$home_dir/.claude/hooks/block_dangerous.sh" \
  "$home_dir/.claude/.org-backups/legacy/hooks/block_dangerous.sh" > "$home_dir/.claude/.org-backup-manifest"
: > "$home_dir/.claude/.org-pruned-manifest"
printf 'legacy backup\n' > "$home_dir/.claude/.org-backups/legacy/hooks/block_dangerous.sh"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path migration-legacy-state-install)" --target claude --force --check quick
install_test_assert_path_absent "$home_dir/.claude/.org-installed-version" "legacy version metadata should be removed from runtime dir"
install_test_assert_path_absent "$home_dir/.claude/.org-backups" "legacy backup dir should be removed from runtime dir"
install_test_assert_file_exists "$state_root/claude/installed-version" "state dir should contain installed-version after migration"
install_test_assert_file_contains "$state_root/claude/backup-manifest" "$state_root/claude/backups" "backup manifest should point to external state backups"
install_test_case_pass "migration: runtime metadata moves from runtime dir to state dir"

install_test_case_start "migration: legacy .claude git repo is retired"
home_dir="$(install_test_new_home migration-retire-dot-claude)"
state_root="$(install_test_state_root "$home_dir")"
repo_dir="$home_dir/legacy-claude"
mkdir -p "$repo_dir/skills/product-director" "$repo_dir/tests" "$repo_dir/docs"
printf 'legacy settings\n' > "$repo_dir/settings.json"
printf 'legacy tracked skill\n' > "$repo_dir/skills/product-director/SKILL.md"
printf 'legacy test asset\n' > "$repo_dir/tests/obsolete.sh"
printf 'legacy note\n' > "$repo_dir/docs/note.md"
printf 'legacy finder noise\n' > "$repo_dir/docs/.DS_Store"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.name "Test User"
git -C "$repo_dir" config user.email "test@example.com"
git -C "$repo_dir" add .
git -C "$repo_dir" commit -qm "init"
git -C "$repo_dir" remote add origin https://github.com/example/dot-claude.git
ORG_STATE_ROOT="$state_root" bash "$ROOT/tools/migration/retire-dot-claude.sh" --claude-dir "$repo_dir" --shared-repo "$ROOT" >"$(install_test_log_path migration-retire-dot-claude)" 2>&1 \
  || install_test_fail "retire-dot-claude should succeed"
install_test_assert_path_absent "$repo_dir/.git" ".git should be removed after retirement"
install_test_assert_file_exists "$repo_dir/settings.json" "local runtime settings should be kept in runtime dir"
install_test_assert_file_exists "$repo_dir/skills/product-director/SKILL.md" "shared managed skill should be kept in runtime dir"
install_test_assert_path_absent "$repo_dir/tests/obsolete.sh" "repo-only test file should be archived out of runtime dir"
install_test_assert_path_absent "$repo_dir/docs/note.md" "repo-only docs should be archived out of runtime dir"
archive_dir="$(find "$state_root/archive" -maxdepth 1 -type d -name 'dot-claude-retirement-*' | head -1)"
[ -n "$archive_dir" ] || install_test_fail "retirement archive dir missing"
install_test_assert_file_exists "$archive_dir/dot-claude-git.tar.gz" "git archive should exist"
install_test_assert_file_exists "$archive_dir/runtime-files/tests/obsolete.sh" "archived test file should exist"
install_test_assert_file_exists "$archive_dir/runtime-files/docs/note.md" "archived docs file should exist"
install_test_assert_file_exists "$archive_dir/runtime-files/docs/.DS_Store" "untracked repo-only noise should be archived"
install_test_case_pass "migration: legacy .claude git repo is retired"

printf '\nInstall migration tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
