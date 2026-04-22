#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

install_test_init

install_test_case_start "core: install succeeds without openspec CLI"
home_dir="$(install_test_new_home core-no-openspec)"
state_root="$(install_test_state_root "$home_dir")"
log_file="$(install_test_log_path core-no-openspec)"
set +e
INSTALL_TEST_CURRENT_LOG="$log_file"
run_without_openspec env HOME="$home_dir" ORG_STATE_ROOT="$state_root" ORG_SKIP_CONTRACT_VALIDATION=1 \
  bash "$ROOT/install.sh" --target all --check quick >"$log_file" 2>&1
rc=$?
set -e
install_test_assert_success "$rc" "install should succeed when openspec CLI is missing"
if grep -q "未检测到 openspec CLI" "$log_file"; then
  install_test_fail "install output should not require openspec CLI"
fi
install_test_case_pass "core: install succeeds without openspec CLI"

install_test_case_start "core: dry-run has no metadata side effects"
home_dir="$(install_test_new_home core-dry-run)"
state_root="$(install_test_state_root "$home_dir")"
log_file="$(install_test_log_path core-dry-run)"
install_test_run_install "$home_dir" "$log_file" --target all --dry-run --force
install_test_assert_path_absent "$state_root/claude/installed-version" "dry-run should not create claude version metadata"
install_test_assert_path_absent "$state_root/codex/installed-version" "dry-run should not create codex version metadata"
install_test_case_pass "core: dry-run has no metadata side effects"

install_test_case_start "core: conflict blocks install without force"
home_dir="$(install_test_new_home core-conflict)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p "$home_dir/.claude/skills/product-director"
printf 'local-only\n' > "$home_dir/.claude/skills/product-director/SKILL.md"
log_file="$(install_test_log_path core-conflict)"
set +e
install_test_run_install_allow_failure "$home_dir" "$log_file" --target claude --check quick
rc=$?
set -e
install_test_assert_failure "$rc" "conflict install should fail without --force"
install_test_assert_file_contains "$log_file" "检测到冲突" "conflict message"
install_test_assert_file_contains "$home_dir/.claude/skills/product-director/SKILL.md" "local-only" "existing conflict file should stay unchanged"
install_test_case_pass "core: conflict blocks install without force"

install_test_case_start "core: create baseline for installed-runtime repair cases"
install_test_create_baseline_home core-baseline >/dev/null
baseline_home="$INSTALL_TEST_BASELINE_HOME"
install_test_assert_control_plane_runtime_files "$baseline_home/.claude" "claude baseline runtime"
install_test_assert_control_plane_runtime_files "$baseline_home/.codex" "codex baseline runtime"
install_test_case_pass "core: create baseline for installed-runtime repair cases"

install_test_case_start "core: same-version install is idempotent and repairs dependencies"
home_dir="$(install_test_clone_baseline_home core-idempotent)"
state_root="$(install_test_state_root "$home_dir")"
install_test_assert_installed_control_plane_gates "$home_dir" "$home_dir/.codex" "codex"
mkdir -p "$home_dir/tools/community" "$home_dir/contracts/canonical"
install_test_assert_installed_control_plane_gates "$home_dir" "$home_dir/.codex" "codex-shadow"
rm -f "$home_dir/.claude/tools/community/authority_proof.py"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-idempotent-repair)" --target claude --check quick
install_test_assert_file_exists "$home_dir/.claude/tools/community/authority_proof.py" "same-version install should restore missing authority_proof.py"
ver1="$(cat "$state_root/claude/installed-version")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-idempotent-second)" --target all --check quick
ver2="$(cat "$state_root/claude/installed-version")"
[ "$ver1" = "$ver2" ] || install_test_fail "version changed unexpectedly on idempotent install"
install_test_assert_file_contains "$(install_test_log_path core-idempotent-second)" "已是最新版本" "idempotent skip message"
install_test_case_pass "core: same-version install is idempotent and repairs dependencies"

install_test_case_start "core: same-version install repairs missing product split skills"
home_dir="$(install_test_clone_baseline_home core-product-split)"
rm -f "$home_dir/.claude/skills/product-director/SKILL.md"
rm -f "$home_dir/.codex/skills/product-manager/SKILL.md"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-product-split-second)" --target all --check quick
install_test_assert_file_exists "$home_dir/.claude/skills/product-director/SKILL.md" "same-version install should restore missing Claude product-director skill"
install_test_assert_file_exists "$home_dir/.codex/skills/product-manager/SKILL.md" "same-version install should restore missing Codex product-manager skill"
install_test_assert_file_contains "$(install_test_log_path core-product-split-second)" "运行面不完整" "same-version product split repair should not silently skip"
install_test_case_pass "core: same-version install repairs missing product split skills"

install_test_case_start "core: same-version codex reinstall preserves local developer edits"
home_dir="$(install_test_clone_baseline_home core-codex-local-edit)"
printf '\n## 本地补充\n- 这段内容用于验证同版本重装不会覆盖本地修改\n' >> "$home_dir/.codex/skills/developer/SKILL.md"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-codex-local-edit-second)" --target codex --check quick
install_test_assert_file_contains "$home_dir/.codex/skills/developer/SKILL.md" "## 本地补充" "codex reinstall should preserve local developer SKILL.md edits when version matches"
install_test_assert_file_contains "$(install_test_log_path core-codex-local-edit-second)" "已是最新版本" "same-version codex reinstall should skip when runtime contains local edits"
install_test_case_pass "core: same-version codex reinstall preserves local developer edits"

printf '\nInstall core tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
