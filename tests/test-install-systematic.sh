#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
SKIP=0

log() {
  printf '[systematic] %s\n' "$*"
}

pass() {
  PASS=$((PASS + 1))
  printf '[PASS] %s\n' "$*"
}

skip() {
  SKIP=$((SKIP + 1))
  printf '[SKIP] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

new_home() {
  TMP_HOME="$(mktemp -d)"
  mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
  cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
  cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
TOML
}

cleanup_home() {
  if [ -n "${TMP_HOME:-}" ] && [ -d "$TMP_HOME" ]; then
    chmod -R u+w "$TMP_HOME" 2>/dev/null || true
    rm -rf "$TMP_HOME"
  fi
  TMP_HOME=""
}

run_install() {
  HOME="$TMP_HOME" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" "$@"
}

# 1) dry-run 不落盘元数据
new_home
run_install --target all --dry-run --force >/tmp/org_install_dryrun.out 2>&1 || fail "dry-run should succeed"
[ ! -f "$TMP_HOME/.claude/.org-installed-version" ] || fail "dry-run created claude version metadata"
[ ! -f "$TMP_HOME/.codex/.org-installed-version" ] || fail "dry-run created codex version metadata"
pass "dry-run 无副作用"
cleanup_home

# 2) 冲突阻断（不加 --force）
new_home
mkdir -p "$TMP_HOME/.claude/skills/product"
printf 'local-only\n' > "$TMP_HOME/.claude/skills/product/SKILL.md"
set +e
run_install --target claude --check quick >/tmp/org_install_conflict.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "conflict install should fail without --force"
grep -q "检测到冲突" /tmp/org_install_conflict.out || fail "conflict message missing"
grep -q "local-only" "$TMP_HOME/.claude/skills/product/SKILL.md" || fail "existing file changed on conflict"
pass "冲突阻断生效"
cleanup_home

# 3) 幂等安装（同版本二次执行跳过）
new_home
run_install --target all --force --check quick >/tmp/org_install_first.out 2>&1 || fail "first install failed"
ver1="$(cat "$TMP_HOME/.claude/.org-installed-version")"
run_install --target all --check quick >/tmp/org_install_second.out 2>&1 || fail "second install failed"
ver2="$(cat "$TMP_HOME/.claude/.org-installed-version")"
[ "$ver1" = "$ver2" ] || fail "version changed unexpectedly on idempotent install"
grep -q "已是最新版本" /tmp/org_install_second.out || fail "idempotent skip message missing"
pass "幂等安装生效"
cleanup_home

# 4) 卸载安全：缺失 backup-manifest 时拒绝执行
new_home
run_install --target claude --force --check quick >/tmp/org_install_for_uninstall.out 2>&1 || fail "claude install failed"
rm -f "$TMP_HOME/.claude/.org-backup-manifest"
set +e
run_install --uninstall --target claude >/tmp/org_uninstall_missing_backup.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "uninstall should fail when backup manifest missing"
grep -q "缺少 backup-manifest" /tmp/org_uninstall_missing_backup.out || fail "missing backup manifest message not found"
[ -f "$TMP_HOME/.claude/skills/product/SKILL.md" ] || fail "managed files should remain when uninstall refused"
pass "卸载安全保护生效"
cleanup_home

# 5) 安装失败自动回滚
new_home
mkdir -p "$TMP_HOME/.claude/reference"
chmod 500 "$TMP_HOME/.claude/reference"
set +e
run_install --target claude --force --check quick >/tmp/org_install_rollback.out 2>&1
rc=$?
set -e
chmod 700 "$TMP_HOME/.claude/reference" || true
[ "$rc" -ne 0 ] || fail "install should fail when reference dir is read-only"
# agents 通常在 reference 前写入，失败后应被回滚删除
[ ! -f "$TMP_HOME/.claude/agents/code-reviewer.md" ] || fail "rollback failed: agent file still exists"
[ ! -f "$TMP_HOME/.claude/.org-installed-version" ] || fail "rollback failed: version metadata exists"
pass "安装失败回滚生效"
cleanup_home

# 6) merge-hooks 合并（可选，依赖 jq）
new_home
if command -v jq >/dev/null 2>&1; then
  run_install --target claude --force --merge-hooks --check quick >/tmp/org_install_merge_hooks.out 2>&1 || fail "install with --merge-hooks failed"
  grep -Fq "bash \$HOME/.claude/hooks/block_dangerous.sh" "$TMP_HOME/.claude/settings.json" || fail "hook block_dangerous not merged"
  grep -Fq "bash \$HOME/.claude/hooks/code_quality_check.sh" "$TMP_HOME/.claude/settings.json" || fail "hook code_quality_check not merged"
  grep -Fq "bash \$HOME/.claude/hooks/auto_format.sh" "$TMP_HOME/.claude/settings.json" || fail "hook auto_format not merged"
  grep -Fq "bash \$HOME/.claude/hooks/post_compact.sh" "$TMP_HOME/.claude/settings.json" || fail "hook post_compact not merged"
  grep -Fq "bash \$HOME/.claude/hooks/task_verify.sh" "$TMP_HOME/.claude/settings.json" || fail "hook task_verify not merged"
  pass "--merge-hooks 合并生效"
else
  skip "系统缺少 jq，跳过 --merge-hooks 测试"
fi
cleanup_home

# 7) codex .toml 占位符替换
new_home
run_install --target codex --force --check quick >/tmp/org_install_codex_only.out 2>&1 || fail "codex-only install failed"
if grep -Fq '{{HOME}}' "$TMP_HOME/.codex/agents/developer.toml"; then
  fail "codex toml placeholder not replaced"
fi
grep -Fq "$TMP_HOME/.codex" "$TMP_HOME/.codex/agents/developer.toml" || fail "codex toml missing concrete HOME path"
pass "codex toml 占位符替换生效"
cleanup_home

# 8) 兼容历史软链接技能（安装后应迁移为真实文件/目录）
new_home
mkdir -p "$TMP_HOME/.claude/skills/product/references" "$TMP_HOME/.claude/skills/product/scripts"
mkdir -p "$TMP_HOME/.codex/skills/product"
printf 'legacy product skill\n' > "$TMP_HOME/.claude/skills/product/SKILL.md"
printf 'legacy ref\n' > "$TMP_HOME/.claude/skills/product/references/legacy.md"
printf '#!/usr/bin/env bash\n' > "$TMP_HOME/.claude/skills/product/scripts/legacy.sh"
ln -s "$TMP_HOME/.claude/skills/product/SKILL.md" "$TMP_HOME/.codex/skills/product/SKILL.md"
ln -s "$TMP_HOME/.claude/skills/product/references" "$TMP_HOME/.codex/skills/product/references"
ln -s "$TMP_HOME/.claude/skills/product/scripts" "$TMP_HOME/.codex/skills/product/scripts"
run_install --target codex --force --check quick >/tmp/org_install_legacy_symlink.out 2>&1 || fail "legacy symlink migration install failed"
[ ! -L "$TMP_HOME/.codex/skills/product/SKILL.md" ] || fail "legacy SKILL.md symlink should be replaced"
[ ! -L "$TMP_HOME/.codex/skills/product/references" ] || fail "legacy references symlink should be replaced"
[ ! -L "$TMP_HOME/.codex/skills/product/scripts" ] || fail "legacy scripts symlink should be replaced"
[ -f "$TMP_HOME/.codex/skills/product/SKILL.md" ] || fail "product SKILL.md missing after migration"
pass "历史软链接技能迁移生效"
cleanup_home

# 9) 旧版本遗留受管文件清理（安装去噪，卸载可恢复）
new_home
run_install --target codex --force --check quick >/tmp/org_install_prune_first.out 2>&1 || fail "first codex install for prune test failed"
stale_path="$TMP_HOME/.codex/skills/product/obsolete-noise.md"
printf 'obsolete managed artifact\n' > "$stale_path"
printf '%s\n' "$stale_path" >> "$TMP_HOME/.codex/.org-installed-manifest"
run_install --target codex --force --check quick >/tmp/org_install_prune_second.out 2>&1 || fail "second codex install for prune test failed"
[ ! -f "$stale_path" ] || fail "stale managed file should be pruned during install"
grep -Fxq "$stale_path" "$TMP_HOME/.codex/.org-pruned-manifest" || fail "pruned manifest missing stale path"
run_install --uninstall --target codex >/tmp/org_uninstall_prune_restore.out 2>&1 || fail "codex uninstall after prune test failed"
[ -f "$stale_path" ] || fail "pruned stale file should be restorable on uninstall"
pass "旧版本遗留受管文件清理与恢复生效"
cleanup_home

printf '\nSystematic tests passed: %d, skipped: %d\n' "$PASS" "$SKIP"
