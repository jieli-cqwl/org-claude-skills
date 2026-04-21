#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"

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
  STATE_ROOT="$TMP_HOME/.org-skills-state"
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
  env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" "$@"
}

assert_control_plane_runtime_files() {
  local target_dir="$1"
  local label="$2"

  [ -f "$target_dir/tools/community/validate_product_closure.py" ] || fail "$label missing validate_product_closure.py"
  [ -f "$target_dir/tools/community/validate_readiness_contract.py" ] || fail "$label missing validate_readiness_contract.py"
  [ -f "$target_dir/tools/community/validate_standard_chain_readiness.py" ] || fail "$label missing validate_standard_chain_readiness.py"
  [ -f "$target_dir/tools/community/authority_proof.py" ] || fail "$label missing authority_proof.py"
  [ -f "$target_dir/tools/community/manage_artifact_registry.py" ] || fail "$label missing manage_artifact_registry.py"
  [ -f "$target_dir/tools/community/normalize_canonical_artifact.py" ] || fail "$label missing normalize_canonical_artifact.py"
  [ -f "$target_dir/tools/community/runtime_yaml.py" ] || fail "$label missing runtime_yaml.py"
  [ -f "$target_dir/tools/community/simple_json_schema.py" ] || fail "$label missing simple_json_schema.py"
  [ -f "$target_dir/tools/community/validate_canonical_schema.py" ] || fail "$label missing validate_canonical_schema.py"
  [ -f "$target_dir/tools/community/write_user_decision.py" ] || fail "$label missing write_user_decision.py"
  [ -f "$target_dir/contracts/product-artifacts.yaml" ] || fail "$label missing product-artifacts.yaml"
  [ -f "$target_dir/contracts/canonical/registry-bundle.yaml" ] || fail "$label missing canonical registry bundle"
  [ -f "$target_dir/shared/runtime/standard-chain-catalog.json" ] || fail "$label missing standard-chain catalog"
}

run_installed_completion_check() {
  local script="$1"
  local workspace="$2"
  local transcript_path="$3"
  local tool_name="$4"
  local file_path="$5"
  local payload

  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "install-runtime-gate" \
    --arg tp "$transcript_path" \
    --arg tn "$tool_name" \
    --arg fp "$file_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:$tn, tool_input:{file_path:$fp}}')"

  env HOME="$TMP_HOME" bash "$script" <<<"$payload"
}

assert_installed_control_plane_gates() {
  local target_dir="$1"
  local label="$2"
  local workspace="$TMP_HOME/workspace-$label"
  local transcript="$workspace/transcript.log"

  mkdir -p "$workspace/docs"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$workspace/docs/sample-feature"

  printf '%s\n' "docs/sample-feature/brief.json" > "$transcript"
  run_installed_completion_check \
    "$target_dir/skills/product-manager/scripts/completion_check.sh" \
    "$workspace" \
    "$transcript" \
    "Write" \
    "docs/sample-feature/brief.json" >/tmp/org_install_"${label}"_pm.out 2>&1 \
    || fail "$label installed product-manager gate should accept valid canonical fixture"

  printf '%s\n' "docs/sample-feature/phase-1/user-decision.json" > "$transcript"
  run_installed_completion_check \
    "$target_dir/skills/delivery-owner/scripts/completion_check.sh" \
    "$workspace" \
    "$transcript" \
    "Write" \
    "docs/sample-feature/phase-1/user-decision.json" >/tmp/org_install_"${label}"_do.out 2>&1 \
    || fail "$label installed delivery-owner gate should accept valid canonical fixture"
}

# 1) 缺少 openspec CLI 也应允许安装
new_home
set +e
run_without_openspec env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --check quick >/tmp/org_install_missing_openspec.out 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "install should succeed when openspec CLI is missing"
if grep -q "未检测到 openspec CLI" /tmp/org_install_missing_openspec.out; then
  fail "install output should not require openspec CLI"
fi
pass "无 openspec CLI 依赖"
cleanup_home

# 2) dry-run 不落盘元数据
new_home
run_install --target all --dry-run --force >/tmp/org_install_dryrun.out 2>&1 || fail "dry-run should succeed"
[ ! -f "$STATE_ROOT/claude/installed-version" ] || fail "dry-run created claude version metadata"
[ ! -f "$STATE_ROOT/codex/installed-version" ] || fail "dry-run created codex version metadata"
pass "dry-run 无副作用"
cleanup_home

# 3) 冲突阻断（不加 --force）
new_home
mkdir -p "$TMP_HOME/.claude/skills/product-director"
printf 'local-only\n' > "$TMP_HOME/.claude/skills/product-director/SKILL.md"
set +e
run_install --target claude --check quick >/tmp/org_install_conflict.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "conflict install should fail without --force"
grep -q "检测到冲突" /tmp/org_install_conflict.out || fail "conflict message missing"
grep -q "local-only" "$TMP_HOME/.claude/skills/product-director/SKILL.md" || fail "existing file changed on conflict"
pass "冲突阻断生效"
cleanup_home

# 4) 幂等安装（同版本二次执行跳过）
new_home
run_install --target all --force --check quick >/tmp/org_install_first.out 2>&1 || fail "first install failed"
assert_control_plane_runtime_files "$TMP_HOME/.claude" "claude runtime"
assert_control_plane_runtime_files "$TMP_HOME/.codex" "codex runtime"
assert_installed_control_plane_gates "$TMP_HOME/.codex" "codex"
mkdir -p "$TMP_HOME/tools/community" "$TMP_HOME/contracts/canonical"
assert_installed_control_plane_gates "$TMP_HOME/.codex" "codex-shadow"
rm -f "$TMP_HOME/.claude/tools/community/authority_proof.py"
run_install --target claude --check quick >/tmp/org_install_runtime_dependency_repair.out 2>&1 || fail "same-version install should repair missing readiness dependency"
[ -f "$TMP_HOME/.claude/tools/community/authority_proof.py" ] || fail "same-version install should restore missing authority_proof.py"
ver1="$(cat "$STATE_ROOT/claude/installed-version")"
run_install --target all --check quick >/tmp/org_install_second.out 2>&1 || fail "second install failed"
ver2="$(cat "$STATE_ROOT/claude/installed-version")"
[ "$ver1" = "$ver2" ] || fail "version changed unexpectedly on idempotent install"
grep -q "已是最新版本" /tmp/org_install_second.out || fail "idempotent skip message missing"
pass "幂等安装生效"
cleanup_home

# 5) 同版本安装发现拆分后的 product skill 缺失时必须重装
new_home
run_install --target all --force --check quick >/tmp/org_install_product_split_first.out 2>&1 || fail "first product split install failed"
rm -f "$TMP_HOME/.claude/skills/product-director/SKILL.md"
rm -f "$TMP_HOME/.codex/skills/product-manager/SKILL.md"
run_install --target all --check quick >/tmp/org_install_product_split_second.out 2>&1 || fail "same-version install should repair missing product split skills"
[ -f "$TMP_HOME/.claude/skills/product-director/SKILL.md" ] || fail "same-version install should restore missing Claude product-director skill"
[ -f "$TMP_HOME/.codex/skills/product-manager/SKILL.md" ] || fail "same-version install should restore missing Codex product-manager skill"
grep -q "运行面不完整" /tmp/org_install_product_split_second.out || fail "same-version product split repair should not silently skip"
pass "同版本安装会修复 product split skill 缺失"
cleanup_home

# 5) 卸载安全：缺失 backup-manifest 时拒绝执行
new_home
run_install --target claude --force --check quick >/tmp/org_install_for_uninstall.out 2>&1 || fail "claude install failed"
rm -f "$STATE_ROOT/claude/backup-manifest"
set +e
run_install --uninstall --target claude >/tmp/org_uninstall_missing_backup.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "uninstall should fail when backup manifest missing"
grep -q "缺少 backup-manifest" /tmp/org_uninstall_missing_backup.out || fail "missing backup manifest message not found"
[ -f "$TMP_HOME/.claude/skills/product-director/SKILL.md" ] || fail "managed files should remain when uninstall refused"
pass "卸载安全保护生效"
cleanup_home

# 6) 安装失败自动回滚
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
[ ! -f "$STATE_ROOT/claude/installed-version" ] || fail "rollback failed: version metadata exists"
pass "安装失败回滚生效"
cleanup_home

# 7) Claude hooks 默认合并，即使安装前没有 settings.json
new_home
rm -f "$TMP_HOME/.claude/settings.json"
run_install --target claude --force --check quick >/tmp/org_install_merge_hooks.out 2>&1 || fail "claude install should create and merge settings.json by default"
[ -f "$TMP_HOME/.claude/settings.json" ] || fail "claude install should create settings.json when it is missing"
grep -Fq "bash \$HOME/.claude/hooks/block_dangerous.sh" "$TMP_HOME/.claude/settings.json" || fail "hook block_dangerous not merged"
grep -Fq "bash \$HOME/.claude/hooks/code_quality_check.sh" "$TMP_HOME/.claude/settings.json" || fail "hook code_quality_check not merged"
grep -Fq "bash \$HOME/.claude/hooks/auto_format.sh" "$TMP_HOME/.claude/settings.json" || fail "hook auto_format not merged"
grep -Fq "bash \$HOME/.claude/hooks/post_compact.sh" "$TMP_HOME/.claude/settings.json" || fail "hook post_compact not merged"
grep -Fq "bash \$HOME/.claude/hooks/task_verify.sh" "$TMP_HOME/.claude/settings.json" || fail "hook task_verify not merged"
[ -x "$TMP_HOME/.claude/hooks/block_dangerous.sh" ] || fail "claude dangerous hook wrapper should be executable"
[ -x "$TMP_HOME/.claude/hooks/managed/block_dangerous.sh" ] || fail "claude managed dangerous hook should be executable"
printf '{}' | bash "$TMP_HOME/.claude/hooks/block_dangerous.sh" >/dev/null 2>&1 || fail "claude dangerous hook wrapper should run without permission errors"
post_compact_payload="$(printf '{}' | bash "$TMP_HOME/.claude/hooks/post_compact.sh")" || fail "claude post_compact hook should emit JSON payload"
printf '%s' "$post_compact_payload" | jq -e '.hookSpecificOutput.hookEventName == "PostCompact"' >/dev/null 2>&1 || fail "claude post_compact hook should keep PostCompact event name"
printf '%s' "$post_compact_payload" | grep -Fq 'mode / stage / status / scope_ref / state_ref / next_ref / blocker / decision_needed' || fail "claude post_compact hook should restore state anchors"
printf '%s' "$post_compact_payload" | grep -Fq '如果 goal / owner / lane / phase 已变化，先回源纠偏，不继续执行' || fail "claude post_compact hook should require freshness check before continuing"
printf '%s' "$post_compact_payload" | grep -Fq 'blocked / waiting_on / unblock_condition / decision_needed' || fail "claude post_compact hook should describe blocked fallback"
printf '%s' "$post_compact_payload" | grep -Fq '探索型任务额外允许保留最多 3 条理由胶囊' || fail "claude post_compact hook should describe rationale capsule branch for exploration"
run_install --uninstall --target claude >/tmp/org_uninstall_merge_hooks.out 2>&1 || fail "claude uninstall after auto settings creation failed"
[ ! -f "$TMP_HOME/.claude/settings.json" ] || fail "claude uninstall should remove settings.json that was created only for managed hooks"
pass "Claude hooks 默认合并并可恢复 baseline"
cleanup_home

# 8) codex .toml 占位符替换
new_home
run_install --target codex --force --check quick >/tmp/org_install_codex_only.out 2>&1 || fail "codex-only install failed"
if grep -Fq '{{HOME}}' "$TMP_HOME/.codex/agents/developer.toml"; then
  fail "codex toml placeholder not replaced"
fi
grep -Fq "$TMP_HOME/.codex" "$TMP_HOME/.codex/agents/developer.toml" || fail "codex toml missing concrete HOME path"
grep -Fq 'codex_hooks = true' "$TMP_HOME/.codex/config.toml" || fail "codex install should enable codex_hooks feature"
[ -x "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" ] || fail "codex managed dangerous hook should be executable"
printf '{}' | bash "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" >/dev/null 2>&1 || fail "codex managed dangerous hook should run without permission errors"
pass "codex toml 占位符替换生效"
cleanup_home

# 9) codex 同版本重装不应覆盖 developer skill 本地修改
new_home
run_install --target codex --force --check quick >/tmp/org_install_codex_skill_refresh_first.out 2>&1 || fail "codex install for local edit preservation test failed"
printf '\n## 本地补充\n- 这段内容用于验证同版本重装不会覆盖本地修改\n' >> "$TMP_HOME/.codex/skills/developer/SKILL.md"
run_install --target codex --check quick >/tmp/org_install_codex_skill_refresh_second.out 2>&1 || fail "codex reinstall for local edit preservation test failed"
grep -Fq '## 本地补充' "$TMP_HOME/.codex/skills/developer/SKILL.md" || fail "codex reinstall should preserve local developer SKILL.md edits when version matches"
grep -q "已是最新版本" /tmp/org_install_codex_skill_refresh_second.out || fail "same-version codex reinstall should skip when runtime contains local edits"
pass "codex 同版本重装不覆盖 developer skill 本地修改"
cleanup_home

# 10) codex hooks.json 中残留的临时探针路径应被清理，但保留正常 hook
new_home
mkdir -p "$TMP_HOME/bin"
cat > "$TMP_HOME/bin/notify.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$TMP_HOME/bin/notify.sh"
cat > "$TMP_HOME/.codex/hooks.json" <<JSON
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $TMP_HOME/tmp/codex-hooks-probe.stale/probe.sh Stop $TMP_HOME/tmp/events.log"
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "$TMP_HOME/bin/notify.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$TMP_HOME/bin/notify.sh"
          }
        ]
      }
    ]
  }
}
JSON
run_install --target codex --force --check quick >/tmp/org_install_codex_hooks_cleanup.out 2>&1 || fail "codex install with stale hooks failed"
if grep -Fq 'codex-hooks-probe.stale' "$TMP_HOME/.codex/hooks.json"; then
  fail "stale codex probe hooks should be removed during install"
fi
grep -Fq "$TMP_HOME/bin/notify.sh" "$TMP_HOME/.codex/hooks.json" || fail "valid user hook should be preserved during install"
grep -Fq "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" "$TMP_HOME/.codex/hooks.json" || fail "managed dangerous hook should be installed"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" "$TMP_HOME/.codex/hooks.json" || fail "managed active-skill tracker should be installed"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" "$TMP_HOME/.codex/hooks.json" || fail "managed stop dispatcher should be installed"
grep -Fq '"PostToolUse": []' "$TMP_HOME/.codex/hooks.json" || fail "unsupported Claude-standard PostToolUse should render as an empty array"
grep -Fq '"PostCompact": []' "$TMP_HOME/.codex/hooks.json" || fail "unsupported Claude-standard PostCompact should render as an empty array"
grep -Fq '"TaskCompleted": []' "$TMP_HOME/.codex/hooks.json" || fail "unsupported Claude-standard TaskCompleted should render as an empty array"
if grep -Fq '"SessionStart"' "$TMP_HOME/.codex/hooks.json"; then
  fail "non-standard SessionStart should be removed during codex install"
fi
pass "codex hooks.json 失效临时探针清理生效"
cleanup_home

# 11) codex 卸载应移除 managed hooks，但保留用户 hooks
new_home
mkdir -p "$TMP_HOME/bin"
cat > "$TMP_HOME/bin/notify.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$TMP_HOME/bin/notify.sh"
cat > "$TMP_HOME/.codex/hooks.json" <<JSON
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$TMP_HOME/bin/notify.sh"
          }
        ]
      }
    ]
  }
}
JSON
run_install --target codex --force --check quick >/tmp/org_install_codex_uninstall_hooks.out 2>&1 || fail "codex install for uninstall hook preservation test failed"
run_install --uninstall --target codex >/tmp/org_uninstall_codex_uninstall_hooks.out 2>&1 || fail "codex uninstall for hook preservation test failed"
[ -f "$TMP_HOME/.codex/hooks.json" ] || fail "user hooks.json should remain after uninstall"
grep -Fq "$TMP_HOME/bin/notify.sh" "$TMP_HOME/.codex/hooks.json" || fail "user hook should remain after uninstall"
if grep -Fq "$TMP_HOME/.codex/hooks/managed/" "$TMP_HOME/.codex/hooks.json"; then
  fail "managed codex hooks should be removed during uninstall"
fi
if grep -Fq 'codex_hooks = true' "$TMP_HOME/.codex/config.toml"; then
  fail "codex_hooks feature should restore pre-install baseline during uninstall"
fi
pass "codex 卸载保留用户 hooks 并恢复 config baseline"
cleanup_home

# 11) codex 卸载应恢复安装前的非标准事件 hooks 基线
new_home
mkdir -p "$TMP_HOME/bin"
cat > "$TMP_HOME/bin/session_notify.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$TMP_HOME/bin/session_notify.sh"
cat > "$TMP_HOME/.codex/hooks.json" <<JSON
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$TMP_HOME/bin/session_notify.sh"
          }
        ]
      }
    ]
  }
}
JSON
run_install --target codex --force --check quick >/tmp/org_install_codex_restore_nonstandard.out 2>&1 || fail "codex install for non-standard hook restore test failed"
run_install --uninstall --target codex >/tmp/org_uninstall_codex_restore_nonstandard.out 2>&1 || fail "codex uninstall for non-standard hook restore test failed"
[ -f "$TMP_HOME/.codex/hooks.json" ] || fail "non-standard hooks.json baseline should be restored after uninstall"
grep -Fq '"SessionStart"' "$TMP_HOME/.codex/hooks.json" || fail "non-standard SessionStart hook should be restored after uninstall"
grep -Fq "$TMP_HOME/bin/session_notify.sh" "$TMP_HOME/.codex/hooks.json" || fail "non-standard SessionStart command should be restored after uninstall"
if grep -Fq "$TMP_HOME/.codex/hooks/managed/" "$TMP_HOME/.codex/hooks.json"; then
  fail "managed codex hooks should not remain after restoring non-standard baseline"
fi
pass "codex 卸载恢复非标准 hooks 基线"
cleanup_home

# 12) 兼容历史软链接技能（安装后应迁移为真实文件/目录）
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
[ ! -e "$TMP_HOME/.codex/skills/product" ] || fail "retired product skill should be removed after migration"
pass "退役 product 软链接技能清理生效"
cleanup_home

# 13) 旧版本遗留受管文件清理（安装去噪，卸载可恢复）
new_home
run_install --target codex --force --check quick >/tmp/org_install_prune_first.out 2>&1 || fail "first codex install for prune test failed"
stale_path="$TMP_HOME/.codex/skills/product-director/obsolete-noise.md"
printf 'obsolete managed artifact\n' > "$stale_path"
printf '%s\n' "$stale_path" >> "$STATE_ROOT/codex/installed-manifest"
run_install --target codex --force --check quick >/tmp/org_install_prune_second.out 2>&1 || fail "second codex install for prune test failed"
[ ! -f "$stale_path" ] || fail "stale managed file should be pruned during install"
grep -Fxq "$stale_path" "$STATE_ROOT/codex/pruned-manifest" || fail "pruned manifest missing stale path"
run_install --uninstall --target codex >/tmp/org_uninstall_prune_restore.out 2>&1 || fail "codex uninstall after prune test failed"
[ -f "$stale_path" ] || fail "pruned stale file should be restorable on uninstall"
pass "旧版本遗留受管文件清理与恢复生效"
cleanup_home

# 14) 运行目录元数据迁移到状态目录
new_home
mkdir -p "$TMP_HOME/.claude/.org-backups/legacy/hooks"
printf '1.0.0-legacy\n' > "$TMP_HOME/.claude/.org-installed-version"
printf '%s\n' "$TMP_HOME/.claude/hooks/block_dangerous.sh" > "$TMP_HOME/.claude/.org-installed-manifest"
printf '%s\t%s\n' \
  "$TMP_HOME/.claude/hooks/block_dangerous.sh" \
  "$TMP_HOME/.claude/.org-backups/legacy/hooks/block_dangerous.sh" > "$TMP_HOME/.claude/.org-backup-manifest"
: > "$TMP_HOME/.claude/.org-pruned-manifest"
printf 'legacy backup\n' > "$TMP_HOME/.claude/.org-backups/legacy/hooks/block_dangerous.sh"
run_install --target claude --force --check quick >/tmp/org_install_migrate_legacy_state.out 2>&1 || fail "legacy state migration install failed"
[ ! -e "$TMP_HOME/.claude/.org-installed-version" ] || fail "legacy version metadata should be removed from runtime dir"
[ ! -d "$TMP_HOME/.claude/.org-backups" ] || fail "legacy backup dir should be removed from runtime dir"
[ -f "$STATE_ROOT/claude/installed-version" ] || fail "state dir missing installed-version after migration"
grep -Fq "$STATE_ROOT/claude/backups" "$STATE_ROOT/claude/backup-manifest" || fail "backup manifest should point to external state backups"
pass "运行目录旧元数据迁移生效"
cleanup_home

# 15) 卸载后状态目录清理
new_home
run_install --target all --force --check quick >/tmp/org_install_state_cleanup.out 2>&1 || fail "install for state cleanup test failed"
run_install --target all --uninstall >/tmp/org_uninstall_state_cleanup.out 2>&1 || fail "uninstall for state cleanup test failed"
[ ! -d "$STATE_ROOT/claude" ] || fail "claude state dir should be removed after uninstall"
[ ! -d "$STATE_ROOT/codex" ] || fail "codex state dir should be removed after uninstall"
pass "卸载后状态目录清理生效"
cleanup_home

# 16) 旧 .claude git 退役：归档 repo-only 文件并移除 .git
new_home
repo_dir="$TMP_HOME/legacy-claude"
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
ORG_STATE_ROOT="$STATE_ROOT" bash "$ROOT/tools/migration/retire-dot-claude.sh" --claude-dir "$repo_dir" --shared-repo "$ROOT" >/tmp/org_retire_dot_claude.out 2>&1 || fail "retire-dot-claude should succeed"
[ ! -d "$repo_dir/.git" ] || fail ".git should be removed after retirement"
[ -f "$repo_dir/settings.json" ] || fail "local runtime settings should be kept in runtime dir"
[ -f "$repo_dir/skills/product-director/SKILL.md" ] || fail "shared managed skill should be kept in runtime dir"
[ ! -f "$repo_dir/tests/obsolete.sh" ] || fail "repo-only test file should be archived out of runtime dir"
[ ! -f "$repo_dir/docs/note.md" ] || fail "repo-only docs should be archived out of runtime dir"
archive_dir="$(find "$STATE_ROOT/archive" -maxdepth 1 -type d -name 'dot-claude-retirement-*' | head -1)"
[ -n "$archive_dir" ] || fail "retirement archive dir missing"
[ -f "$archive_dir/dot-claude-git.tar.gz" ] || fail "git archive missing"
[ -f "$archive_dir/runtime-files/tests/obsolete.sh" ] || fail "archived test file missing"
[ -f "$archive_dir/runtime-files/docs/note.md" ] || fail "archived docs file missing"
[ -f "$archive_dir/runtime-files/docs/.DS_Store" ] || fail "untracked repo-only noise should also be archived"
pass "旧 .claude git 退役生效"
cleanup_home

# 17) 重复 --force 覆盖安装后，卸载仍恢复用户原始文件
new_home
mkdir -p "$TMP_HOME/.claude/hooks"
printf 'user original hook\n' > "$TMP_HOME/.claude/hooks/block_dangerous.sh"
run_install --target claude --force --check quick >/tmp/org_install_preserve_backup_1.out 2>&1 || fail "first install for preserve-backup test failed"
run_install --target claude --force --check quick >/tmp/org_install_preserve_backup_2.out 2>&1 || fail "second install for preserve-backup test failed"
run_install --target claude --uninstall >/tmp/org_uninstall_preserve_backup.out 2>&1 || fail "uninstall for preserve-backup test failed"
grep -Fxq 'user original hook' "$TMP_HOME/.claude/hooks/block_dangerous.sh" || fail "uninstall should restore the original user file after repeated force installs"
pass "重复覆盖安装仍保留原始恢复基线"
cleanup_home

# 18) codex 安装应清理退役 skill 残留
new_home
mkdir -p "$TMP_HOME/.codex/skills/project-agents-init/references"
printf 'legacy retired skill\n' > "$TMP_HOME/.codex/skills/project-agents-init/SKILL.md"
printf 'legacy retired ref\n' > "$TMP_HOME/.codex/skills/project-agents-init/references/legacy.md"
run_install --target codex --force --check quick >/tmp/org_install_retired_skill_cleanup.out 2>&1 || fail "codex install with retired skill residue failed"
[ ! -e "$TMP_HOME/.codex/skills/project-agents-init" ] || fail "retired skill project-agents-init should be removed during codex install"
pass "退役 skill 残留清理生效"
cleanup_home

printf '\nSystematic tests passed: %d, skipped: %d\n' "$PASS" "$SKIP"
