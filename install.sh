#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
SHARED_SOURCE="$REPO_ROOT/shared"
CLAUDE_SOURCE="$REPO_ROOT/claude"
CODEX_SOURCE="$REPO_ROOT/codex"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
ORG_STATE_ROOT="${ORG_STATE_ROOT:-$HOME/.org-skills-state}"

TARGET="all"
DRY_RUN=0
CHECK_LEVEL="quick"
FORCE=0
MERGE_HOOKS=0
DO_UNINSTALL=0
ROLLBACK_ACTIVE=0
ROLLBACK_CREATED_FILE=""
ROLLBACK_BACKUP_FILE=""
ROLLBACK_NAME=""
ROLLBACK_TEMP_BACKUP_ROOT=""

usage() {
  cat <<'USAGE'
Usage:
  install.sh [--target claude|codex|all] [--dry-run] [--check quick|full] [--force] [--merge-hooks] [--uninstall]

Options:
  --target       安装目标，默认 all
  --dry-run      仅输出计划，不写入文件
  --check        quick|full，默认 quick
  --force        覆盖非 org 管理冲突文件
  --merge-hooks  将 claude/settings/hooks-fragment.json 合并到 ~/.claude/settings.json
  --uninstall    按 manifest 执行卸载
  -h, --help     显示帮助
USAGE
}

log() {
  printf '[install] %s\n' "$*"
}

warn() {
  printf '[install][WARN] %s\n' "$*" >&2
}

fail() {
  printf '[install][ERROR] %s\n' "$*" >&2
  exit 1
}

target_state_dir() {
  local name="$1"
  printf '%s/%s\n' "$ORG_STATE_ROOT" "$name"
}

cleanup_legacy_runtime_state() {
  local target_dir="$1"

  rm -f \
    "$target_dir/.org-installed-version" \
    "$target_dir/.org-installed-manifest" \
    "$target_dir/.org-backup-manifest" \
    "$target_dir/.org-pruned-manifest"
  rm -rf "$target_dir/.org-backups"
}

on_err_rollback() {
  if [ "$ROLLBACK_ACTIVE" -eq 1 ]; then
    warn "$ROLLBACK_NAME 安装失败，正在回滚"
    rollback_from_tmp "$ROLLBACK_CREATED_FILE" "$ROLLBACK_BACKUP_FILE"
    if [ -n "$ROLLBACK_TEMP_BACKUP_ROOT" ] && [ -d "$ROLLBACK_TEMP_BACKUP_ROOT" ]; then
      rm -rf "$ROLLBACK_TEMP_BACKUP_ROOT"
    fi
  fi
}

trim() {
  awk '{$1=$1;print}'
}

write_atomic() {
  local target="$1"
  local src="$2"
  local tmp="${target}.tmp"
  mkdir -p "$(dirname "$target")"
  cp "$src" "$tmp"
  mv "$tmp" "$target"
}

assert_prerequisites() {
  command -v git >/dev/null 2>&1 || fail "git 不可用"
  [ -d "$SHARED_SOURCE" ] || fail "缺少目录: $SHARED_SOURCE"
  [ -f "$SHARED_SOURCE/assistant.md" ] || fail "缺少文件: $SHARED_SOURCE/assistant.md"
  [ -d "$SHARED_SOURCE/skills" ] || fail "缺少目录: $SHARED_SOURCE/skills"
  [ -d "$SHARED_SOURCE/reference" ] || fail "缺少目录: $SHARED_SOURCE/reference"
  [ -d "$SHARED_SOURCE/rules" ] || fail "缺少目录: $SHARED_SOURCE/rules"
  [ -d "$SHARED_SOURCE/agents" ] || fail "缺少目录: $SHARED_SOURCE/agents"
  [ -d "$CLAUDE_SOURCE" ] || fail "缺少目录: $CLAUDE_SOURCE"
  [ -d "$CODEX_SOURCE" ] || fail "缺少目录: $CODEX_SOURCE"
  [ -f "$REPO_ROOT/tools/validate-contracts.sh" ] || fail "缺少校验脚本: tools/validate-contracts.sh"
}

compute_repo_fingerprint() {
  python3 - "$REPO_ROOT" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
targets = ["VERSION", "install.sh", "uninstall.sh", "shared", "claude", "codex", "contracts", "tools", "tests", ".github"]

paths = []
for t in targets:
    p = os.path.join(root, t)
    if os.path.isfile(p):
        paths.append(p)
    elif os.path.isdir(p):
        for dirpath, dirnames, filenames in os.walk(p):
            dirnames[:] = sorted([d for d in dirnames if d != ".git"])
            for fn in sorted(filenames):
                paths.append(os.path.join(dirpath, fn))

h = hashlib.sha1()
for p in sorted(paths):
    rel = os.path.relpath(p, root)
    h.update(rel.encode("utf-8"))
    h.update(b"\0")
    if os.path.islink(p):
        target = os.readlink(p)
        h.update(b"LINK->")
        h.update(target.encode("utf-8"))
        continue
    if not os.path.isfile(p):
        continue
    with open(p, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)

print(h.hexdigest()[:8])
PY
}

merge_hooks_fragment() {
  local settings="$CLAUDE_DIR/settings.json"
  local fragment="$CLAUDE_SOURCE/settings/hooks-fragment.json"

  [ -f "$fragment" ] || {
    warn "未找到 hooks fragment: $fragment"
    return 0
  }

  if [ ! -f "$settings" ]; then
    warn "未找到 settings.json，跳过 hooks 合并: $settings"
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    warn "未安装 jq，跳过 hooks 合并"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] 将合并 hooks fragment -> $settings"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  jq -s '
    def merge_event($base; $add):
      reduce ($add // [])[] as $item ($base // [];
        if any(.[]; . == $item) then . else . + [$item] end
      );

    . as [$settings, $fragment]
    | $settings
    | .hooks = (.hooks // {})
    | .hooks.PreToolUse = merge_event(.hooks.PreToolUse; $fragment.hooks.PreToolUse)
    | .hooks.PostToolUse = merge_event(.hooks.PostToolUse; $fragment.hooks.PostToolUse)
    | .hooks.PostCompact = merge_event(.hooks.PostCompact; $fragment.hooks.PostCompact)
    | .hooks.TaskCompleted = merge_event(.hooks.TaskCompleted; $fragment.hooks.TaskCompleted)
  ' "$settings" "$fragment" > "$tmp"

  mv "$tmp" "$settings"
  log "已合并 hooks fragment -> $settings"
}

check_hooks_registration() {
  local settings="$CLAUDE_DIR/settings.json"
  local missing=0
  local cmd

  [ -f "$settings" ] || {
    warn "未找到 settings.json，无法检查 hooks 注册"
    return 0
  }

  for cmd in \
    "bash \$HOME/.claude/hooks/block_dangerous.sh" \
    "bash \$HOME/.claude/hooks/code_quality_check.sh" \
    "bash \$HOME/.claude/hooks/auto_format.sh" \
    "bash \$HOME/.claude/hooks/post_compact.sh" \
    "bash \$HOME/.claude/hooks/task_verify.sh"
  do
    if ! grep -Fq "$cmd" "$settings"; then
      warn "settings.json 缺少 hooks 注册: $cmd"
      missing=$((missing + 1))
    fi
  done

  if [ "$missing" -eq 0 ]; then
    log "hooks 注册检查通过"
  else
    warn "hooks 注册检查发现 $missing 项缺失（未阻断安装）"
  fi

  return 0
}

collect_stage_files() {
  local staging="$1"
  find "$staging" -type f | sed "s|^$staging/||" | sort
}

copy_tree_contents() {
  local src="$1"
  local dst="$2"

  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  cp -R "$src"/. "$dst"/
}

render_runtime_placeholders() {
  local tree="$1"
  local runtime_home="$2"
  local file

  while IFS= read -r -d '' file; do
    ORG_RENDER_RUNTIME_HOME="$runtime_home" perl -0pi -e '
      s/\{\{RUNTIME_HOME\}\}/$ENV{ORG_RENDER_RUNTIME_HOME}/g;
    ' "$file"
  done < <(find "$tree" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' -o -name '*.toml' -o -name '*.yaml' \) -print0)
}

build_staging_claude() {
  local staging="$1"
  mkdir -p "$staging"/{skills,rules,reference,hooks,agents}

  cp "$SHARED_SOURCE/assistant.md" "$staging/CLAUDE.md"
  copy_tree_contents "$SHARED_SOURCE/skills" "$staging/skills"
  copy_tree_contents "$SHARED_SOURCE/rules" "$staging/rules"
  copy_tree_contents "$SHARED_SOURCE/reference" "$staging/reference"
  copy_tree_contents "$SHARED_SOURCE/agents" "$staging/agents"
  copy_tree_contents "$SHARED_SOURCE/hooks" "$staging/hooks"
  copy_tree_contents "$CLAUDE_SOURCE/hooks" "$staging/hooks"
  find "$staging/skills" -mindepth 2 -maxdepth 2 -type d -name agents -exec rm -rf {} +
  render_runtime_placeholders "$staging" "\$HOME/.claude"
}

build_staging_codex() {
  local staging="$1"
  mkdir -p "$staging"/{skills,rules,reference,agents,hooks}

  cp "$SHARED_SOURCE/assistant.md" "$staging/AGENTS.md"
  copy_tree_contents "$SHARED_SOURCE/skills" "$staging/skills"
  copy_tree_contents "$SHARED_SOURCE/rules" "$staging/rules"
  copy_tree_contents "$SHARED_SOURCE/reference" "$staging/reference"
  copy_tree_contents "$SHARED_SOURCE/agents" "$staging/agents"
  copy_tree_contents "$SHARED_SOURCE/hooks" "$staging/hooks"

  local f
  for f in "$CODEX_SOURCE"/agents/*.toml; do
    [ -f "$f" ] || continue
    sed "s|{{HOME}}|$HOME|g" "$f" > "$staging/agents/$(basename "$f")"
  done

  render_runtime_placeholders "$staging" "\$HOME/.codex"
}

legacy_runtime_state_exists() {
  local target_dir="$1"

  [ -f "$target_dir/.org-installed-version" ] \
    || [ -f "$target_dir/.org-installed-manifest" ] \
    || [ -f "$target_dir/.org-backup-manifest" ] \
    || [ -f "$target_dir/.org-pruned-manifest" ] \
    || [ -d "$target_dir/.org-backups" ]
}

archive_legacy_runtime_state() {
  local target_dir="$1"
  local state_dir="$2"
  local archive_root
  archive_root="$state_dir/legacy-runtime-orphans/$(date +%Y%m%d%H%M%S)-$$"

  mkdir -p "$archive_root"

  local legacy_path moved=0
  for legacy_path in \
    "$target_dir/.org-installed-version" \
    "$target_dir/.org-installed-manifest" \
    "$target_dir/.org-backup-manifest" \
    "$target_dir/.org-pruned-manifest" \
    "$target_dir/.org-backups"
  do
    if [ -e "$legacy_path" ] || [ -L "$legacy_path" ]; then
      mv "$legacy_path" "$archive_root/$(basename "$legacy_path")"
      moved=1
    fi
  done

  if [ "$moved" -eq 0 ]; then
    rmdir "$archive_root" 2>/dev/null || true
  else
    warn "检测到旧运行目录元数据残留，已归档到 $archive_root"
  fi
}

migrate_legacy_runtime_state() {
  local name="$1"
  local target_dir="$2"
  local state_dir="$3"

  legacy_runtime_state_exists "$target_dir" || return 0

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] $name 将把运行目录中的旧 .org-* 元数据迁移到 $state_dir"
    return 0
  fi

  local state_version="$state_dir/installed-version"
  local state_manifest="$state_dir/installed-manifest"
  local state_backup="$state_dir/backup-manifest"
  local state_pruned="$state_dir/pruned-manifest"
  local state_backups_dir="$state_dir/backups"

  if [ -f "$state_version" ] || [ -f "$state_manifest" ] || [ -f "$state_backup" ] || [ -f "$state_pruned" ] || [ -d "$state_backups_dir" ]; then
    archive_legacy_runtime_state "$target_dir" "$state_dir"
    return 0
  fi

  mkdir -p "$state_dir"

  if [ -f "$target_dir/.org-installed-version" ]; then
    mv "$target_dir/.org-installed-version" "$state_version"
  fi

  if [ -f "$target_dir/.org-installed-manifest" ]; then
    mv "$target_dir/.org-installed-manifest" "$state_manifest"
  fi

  if [ -f "$target_dir/.org-pruned-manifest" ]; then
    mv "$target_dir/.org-pruned-manifest" "$state_pruned"
  fi

  if [ -d "$target_dir/.org-backups" ]; then
    mkdir -p "$state_dir"
    mv "$target_dir/.org-backups" "$state_backups_dir"
  fi

  if [ -f "$target_dir/.org-backup-manifest" ]; then
    local tmp
    tmp=$(mktemp)
    sed "s|$target_dir/.org-backups|$state_backups_dir|g" "$target_dir/.org-backup-manifest" > "$tmp"
    mv "$tmp" "$state_backup"
    rm -f "$target_dir/.org-backup-manifest"
  fi

  cleanup_legacy_runtime_state "$target_dir"
  log "$name 已将旧运行目录元数据迁移到 $state_dir"
}

precheck_metadata_health() {
  local state_dir="$1"
  local version_file="$state_dir/installed-version"
  local manifest_file="$state_dir/installed-manifest"
  local backup_file="$state_dir/backup-manifest"
  local pruned_file="$state_dir/pruned-manifest"

  if [ -f "$version_file" ] && { [ ! -f "$manifest_file" ] || [ ! -f "$backup_file" ]; }; then
    warn "$state_dir 元数据不完整，将执行修复安装"
  fi

  if [ -f "$manifest_file" ] && [ ! -f "$backup_file" ]; then
    warn "$state_dir 缺少 backup-manifest，将执行修复安装"
  fi

  if [ -f "$version_file" ] && [ -f "$manifest_file" ] && [ ! -f "$pruned_file" ]; then
    warn "$state_dir 缺少 pruned-manifest，将自动补齐空文件"
  fi
}

is_in_manifest() {
  local manifest_file="$1"
  local path="$2"

  [ -f "$manifest_file" ] || return 1
  grep -Fxq "$path" "$manifest_file"
}

lookup_backup_path() {
  local backup_manifest="$1"
  local path="$2"

  [ -f "$backup_manifest" ] || return 1
  awk -F '\t' -v key="$path" '$1==key {print $2; exit}' "$backup_manifest"
}

reuse_existing_backup_mapping() {
  local backup_manifest="$1"
  local path="$2"
  local backup_tmp="$3"
  local backup

  backup="$(lookup_backup_path "$backup_manifest" "$path" || true)"
  if [ -n "$backup" ] && [ -f "$backup" ]; then
    printf '%s\t%s\n' "$path" "$backup" >> "$backup_tmp"
    return 0
  fi

  return 1
}

check_conflicts() {
  local target_dir="$1"
  local staging="$2"
  local prev_manifest="$3"
  local conflicts_file="$4"

  : > "$conflicts_file"

  local rel dst
  while IFS= read -r rel; do
    dst="$target_dir/$rel"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if is_in_manifest "$prev_manifest" "$dst"; then
        continue
      fi
      printf '%s\n' "$dst" >> "$conflicts_file"
    fi
  done < <(collect_stage_files "$staging")
}

backup_existing_path() {
  local target_dir="$1"
  local dst="$2"
  local backup_root="$3"
  local backup_tmp="$4"

  local rel backup_path
  rel="${dst#"$target_dir"/}"
  backup_path="$backup_root/$rel"
  mkdir -p "$(dirname "$backup_path")"
  cp -a "$dst" "$backup_path"
  printf '%s\t%s\n' "$dst" "$backup_path" >> "$backup_tmp"
}

normalize_parent_symlinks() {
  local target_dir="$1"
  local dst="$2"
  local backup_root="$3"
  local backup_tmp="$4"

  local rel_dir
  rel_dir="$(dirname "${dst#"$target_dir"/}")"
  [ "$rel_dir" = "." ] && return 0

  local current segment
  current="$target_dir"

  local IFS='/'
  for segment in $rel_dir; do
    current="$current/$segment"
    if [ -L "$current" ]; then
      # 兼容历史安装中的目录软链接，改为真实目录，避免写穿到外部路径。
      backup_existing_path "$target_dir" "$current" "$backup_root" "$backup_tmp"
      rm -f "$current"
    fi
  done
}

remove_stale_managed_files() {
  local target_dir="$1"
  local prev_manifest="$2"
  local prev_backup_manifest="$3"
  local staged_abs_file="$4"
  local backup_root="$5"
  local backup_tmp="$6"
  local pruned_tmp="$7"

  [ -f "$prev_manifest" ] || return 0

  local dst
  while IFS= read -r dst; do
    [ -n "$dst" ] || continue
    case "$dst" in
      "$target_dir"/*) ;;
      *) continue ;;
    esac

    if grep -Fxq "$dst" "$staged_abs_file"; then
      continue
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if ! reuse_existing_backup_mapping "$prev_backup_manifest" "$dst" "$backup_tmp"; then
        backup_existing_path "$target_dir" "$dst" "$backup_root" "$backup_tmp"
      fi
      rm -f "$dst"
      remove_if_empty "$(dirname "$dst")" "$target_dir"
      printf '%s\n' "$dst" >> "$pruned_tmp"
    fi
  done < "$prev_manifest"
}

rollback_from_tmp() {
  local created_file="$1"
  local backup_map_file="$2"

  if [ -f "$created_file" ]; then
    while IFS= read -r created; do
      [ -n "$created" ] || continue
      rm -f "$created"
    done < "$created_file"
  fi

  if [ -f "$backup_map_file" ]; then
    while IFS=$'\t' read -r dst backup; do
      [ -n "$dst" ] || continue
      [ -f "$backup" ] || continue
      mkdir -p "$(dirname "$dst")"
      cp -a "$backup" "$dst"
    done < "$backup_map_file"
  fi
}

persist_metadata() {
  local state_dir="$1"
  local manifest_tmp="$2"
  local backup_manifest_tmp="$3"
  local pruned_manifest_tmp="$4"
  local version_tag="$5"

  local manifest="$state_dir/installed-manifest"
  local backup_manifest="$state_dir/backup-manifest"
  local pruned_manifest="$state_dir/pruned-manifest"
  local version_file="$state_dir/installed-version"

  local sorted_manifest sorted_backup sorted_pruned version_tmp
  sorted_manifest=$(mktemp)
  sorted_backup=$(mktemp)
  sorted_pruned=$(mktemp)
  version_tmp=$(mktemp)

  mkdir -p "$state_dir"
  sort -u "$manifest_tmp" > "$sorted_manifest"
  sort -u "$backup_manifest_tmp" > "$sorted_backup"
  sort -u "$pruned_manifest_tmp" > "$sorted_pruned"
  printf '%s\n' "$version_tag" > "$version_tmp"

  write_atomic "$manifest" "$sorted_manifest"
  write_atomic "$backup_manifest" "$sorted_backup"
  write_atomic "$pruned_manifest" "$sorted_pruned"
  write_atomic "$version_file" "$version_tmp"

  rm -f "$sorted_manifest" "$sorted_backup" "$sorted_pruned" "$version_tmp"
}

install_to_target() {
  local name="$1"
  local target_dir="$2"
  local build_fn="$3"
  local version_tag="$4"
  local state_dir
  state_dir="$(target_state_dir "$name")"

  mkdir -p "$target_dir"
  migrate_legacy_runtime_state "$name" "$target_dir" "$state_dir"
  precheck_metadata_health "$state_dir"

  local version_file="$state_dir/installed-version"
  local manifest_file="$state_dir/installed-manifest"
  local backup_manifest_file="$state_dir/backup-manifest"

  if [ "$FORCE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] \
    && [ -f "$version_file" ] && [ -f "$manifest_file" ] && [ -f "$backup_manifest_file" ]; then
    local installed
    installed="$(trim < "$version_file")"
    if [ "$installed" = "$version_tag" ]; then
      log "$name 已是最新版本 ($installed)，跳过安装"
      return 0
    fi
  fi

  local staging
  staging=$(mktemp -d)
  "$build_fn" "$staging"

  local conflicts
  conflicts=$(mktemp)
  check_conflicts "$target_dir" "$staging" "$manifest_file" "$conflicts"

  if [ -s "$conflicts" ] && [ "$FORCE" -eq 0 ]; then
    warn "$name 检测到非 org 管理冲突文件（请先确认）:"
    sed 's/^/  - /' "$conflicts" >&2
    rm -rf "$staging"
    rm -f "$conflicts"
    fail "检测到冲突，使用 --force 可跳过确认"
  fi

  local staged_rel staged_abs stale_candidates
  staged_rel=$(mktemp)
  staged_abs=$(mktemp)
  stale_candidates=$(mktemp)
  : > "$stale_candidates"
  collect_stage_files "$staging" > "$staged_rel"

  local rel dst
  while IFS= read -r rel; do
    printf '%s/%s\n' "$target_dir" "$rel" >> "$staged_abs"
  done < "$staged_rel"

  if [ -f "$manifest_file" ]; then
    while IFS= read -r dst; do
      [ -n "$dst" ] || continue
      case "$dst" in
        "$target_dir"/*) ;;
        *) continue ;;
      esac
      if grep -Fxq "$dst" "$staged_abs"; then
        continue
      fi
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        printf '%s\n' "$dst" >> "$stale_candidates"
      fi
    done < "$manifest_file"
  fi

  local total_files stale_count
  total_files=$(wc -l < "$staged_rel" | tr -d ' ')
  stale_count=$(wc -l < "$stale_candidates" | tr -d ' ')

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] $name 计划写入 $total_files 个文件到 $target_dir"
    if [ "$stale_count" -gt 0 ]; then
      log "[dry-run] $name 将清理 $stale_count 个旧版本遗留受管文件"
    fi
    if [ -s "$conflicts" ]; then
      warn "[dry-run] $name 将覆盖冲突文件："
      sed 's/^/  - /' "$conflicts" >&2
    fi
    rm -rf "$staging"
    rm -f "$conflicts" "$staged_rel" "$staged_abs" "$stale_candidates"
    return 0
  fi

  local backup_root
  backup_root="$state_dir/backups/$(date +%Y%m%d%H%M%S)-$$"
  mkdir -p "$backup_root"

  local created_tmp backup_tmp manifest_tmp pruned_tmp
  created_tmp=$(mktemp)
  backup_tmp=$(mktemp)
  manifest_tmp=$(mktemp)
  pruned_tmp=$(mktemp)
  : > "$created_tmp"
  : > "$backup_tmp"
  : > "$manifest_tmp"
  : > "$pruned_tmp"

  ROLLBACK_ACTIVE=1
  ROLLBACK_CREATED_FILE="$created_tmp"
  ROLLBACK_BACKUP_FILE="$backup_tmp"
  ROLLBACK_NAME="$name"
  ROLLBACK_TEMP_BACKUP_ROOT="$backup_root"
  trap on_err_rollback ERR

  remove_stale_managed_files "$target_dir" "$manifest_file" "$backup_manifest_file" "$staged_abs" "$backup_root" "$backup_tmp" "$pruned_tmp"

  local src
  while IFS= read -r rel; do
    src="$staging/$rel"
    dst="$target_dir/$rel"
    local carried_backup=0

    if is_in_manifest "$manifest_file" "$dst" && reuse_existing_backup_mapping "$backup_manifest_file" "$dst" "$backup_tmp"; then
      carried_backup=1
    fi

    normalize_parent_symlinks "$target_dir" "$dst" "$backup_root" "$backup_tmp"
    mkdir -p "$(dirname "$dst")"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if [ "$carried_backup" -eq 0 ]; then
        backup_existing_path "$target_dir" "$dst" "$backup_root" "$backup_tmp"
      fi
      if [ -L "$dst" ]; then
        # 覆盖软链接时先移除链接本身，确保目标落盘为真实文件。
        rm -f "$dst"
      fi
    else
      printf '%s\n' "$dst" >> "$created_tmp"
    fi

    cp -a "$src" "$dst"
    printf '%s\n' "$dst" >> "$manifest_tmp"
  done < "$staged_rel"

  persist_metadata "$state_dir" "$manifest_tmp" "$backup_tmp" "$pruned_tmp" "$version_tag"
  cleanup_legacy_runtime_state "$target_dir"

  ROLLBACK_ACTIVE=0
  ROLLBACK_CREATED_FILE=""
  ROLLBACK_BACKUP_FILE=""
  ROLLBACK_NAME=""
  ROLLBACK_TEMP_BACKUP_ROOT=""
  trap - ERR

  local pruned_count
  pruned_count=$(wc -l < "$pruned_tmp" | tr -d ' ')

  rm -rf "$staging"
  rm -f "$conflicts" "$created_tmp" "$backup_tmp" "$manifest_tmp" "$pruned_tmp" "$staged_rel" "$staged_abs" "$stale_candidates"

  log "$name 安装完成，写入 $total_files 个文件，清理 $pruned_count 个旧版本遗留受管文件"
}

remove_if_empty() {
  local dir="$1"
  local stop_dir="$2"

  while [ "$dir" != "/" ] && [ "$dir" != "$stop_dir" ]; do
    if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null || true)" ]; then
      rmdir "$dir" 2>/dev/null || true
      dir="$(dirname "$dir")"
    else
      break
    fi
  done
}

uninstall_target() {
  local name="$1"
  local target_dir="$2"
  local state_dir
  state_dir="$(target_state_dir "$name")"

  migrate_legacy_runtime_state "$name" "$target_dir" "$state_dir"

  local manifest="$state_dir/installed-manifest"
  local backup_manifest="$state_dir/backup-manifest"
  local pruned_manifest="$state_dir/pruned-manifest"
  local version_file="$state_dir/installed-version"

  if [ ! -f "$manifest" ] && [ ! -f "$version_file" ]; then
    log "$name 未检测到安装元数据，跳过卸载"
    return 0
  fi

  [ -f "$manifest" ] || fail "$name 缺少 manifest，无法安全卸载"
  [ -f "$backup_manifest" ] || fail "$name 缺少 backup-manifest，请先执行 install.sh --force 修复元数据"

  while IFS=$'\t' read -r dst backup; do
    [ -n "$dst" ] || continue
    [ -n "$backup" ] || continue
    [ -f "$backup" ] || fail "$name 备份文件缺失，拒绝卸载以避免数据丢失: $backup"
  done < "$backup_manifest"

  if [ "$DRY_RUN" -eq 1 ]; then
    local count pruned_count
    count=$(wc -l < "$manifest" | tr -d ' ')
    if [ -f "$pruned_manifest" ]; then
      pruned_count=$(wc -l < "$pruned_manifest" | tr -d ' ')
    else
      pruned_count=0
    fi
    log "[dry-run] $name 计划卸载 $count 个管理文件，恢复 $pruned_count 个历史裁剪文件"
    return 0
  fi

  while IFS= read -r dst; do
    [ -n "$dst" ] || continue
    local backup
    backup=$(awk -F '\t' -v key="$dst" '$1==key {print $2; exit}' "$backup_manifest")
    if [ -n "$backup" ] && [ -f "$backup" ]; then
      mkdir -p "$(dirname "$dst")"
      cp -a "$backup" "$dst"
    else
      rm -f "$dst"
    fi
    remove_if_empty "$(dirname "$dst")" "$target_dir"
  done < "$manifest"

  if [ -f "$pruned_manifest" ]; then
    while IFS= read -r dst; do
      [ -n "$dst" ] || continue
      local backup
      backup=$(awk -F '\t' -v key="$dst" '$1==key {print $2; exit}' "$backup_manifest")
      if [ -n "$backup" ] && [ -f "$backup" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -a "$backup" "$dst"
      fi
    done < "$pruned_manifest"
  fi

  rm -f "$manifest" "$backup_manifest" "$pruned_manifest" "$version_file"
  rm -rf "$state_dir/backups"
  rmdir "$state_dir" 2>/dev/null || true
  rmdir "$ORG_STATE_ROOT" 2>/dev/null || true
  cleanup_legacy_runtime_state "$target_dir"
  log "$name 卸载完成"
}

quick_check() {
  local target="$1"

  if [ "$target" = "claude" ] || [ "$target" = "all" ]; then
    [ -f "$CLAUDE_DIR/skills/product/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/product/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/hooks/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.claude/hooks/block_dangerous.sh 不存在"
    [ -f "$CLAUDE_DIR/CLAUDE.md" ] || fail "Quick Check 失败: ~/.claude/CLAUDE.md 不存在"
    [ ! -e "$CLAUDE_DIR/.org-installed-version" ] || fail "Quick Check 失败: ~/.claude 不应残留 .org-installed-version"
    [ ! -e "$CLAUDE_DIR/.org-backups" ] || fail "Quick Check 失败: ~/.claude 不应残留 .org-backups"
    [ -f "$(target_state_dir claude)/installed-version" ] || fail "Quick Check 失败: ~/.org-skills-state/claude/installed-version 不存在"
    check_hooks_registration
  fi

  if [ "$target" = "codex" ] || [ "$target" = "all" ]; then
    [ -f "$CODEX_DIR/AGENTS.md" ] || fail "Quick Check 失败: ~/.codex/AGENTS.md 不存在"
    [ -f "$CODEX_DIR/skills/product/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.codex/skills/product/agents/openai.yaml 不存在"
    [ ! -L "$CODEX_DIR/skills/product/SKILL.md" ] || fail "Quick Check 失败: ~/.codex/skills/product/SKILL.md 不应为软链接"
    [ -f "$CODEX_DIR/agents/developer.toml" ] || fail "Quick Check 失败: ~/.codex/agents/developer.toml 不存在"
    [ -f "$CODEX_DIR/hooks/lib/common.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/lib/common.sh 不存在"
    [ ! -e "$CODEX_DIR/.org-installed-version" ] || fail "Quick Check 失败: ~/.codex 不应残留 .org-installed-version"
    [ ! -e "$CODEX_DIR/.org-backups" ] || fail "Quick Check 失败: ~/.codex 不应残留 .org-backups"
    [ -f "$(target_state_dir codex)/installed-version" ] || fail "Quick Check 失败: ~/.org-skills-state/codex/installed-version 不存在"
  fi

  log "Quick Check 通过"
}

run_checks() {
  local target="$1"

  quick_check "$target"

  if [ "$CHECK_LEVEL" = "full" ]; then
    log "执行 full 检查：tests/run-all.sh"
    bash "$REPO_ROOT/tests/run-all.sh"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target)
        [ "$#" -ge 2 ] || fail "--target 缺少参数"
        TARGET="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --check)
        [ "$#" -ge 2 ] || fail "--check 缺少参数"
        CHECK_LEVEL="$2"
        shift 2
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --merge-hooks)
        MERGE_HOOKS=1
        shift
        ;;
      --uninstall)
        DO_UNINSTALL=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "未知参数: $1"
        ;;
    esac
  done

  case "$TARGET" in
    claude|codex|all) ;;
    *) fail "--target 仅支持 claude|codex|all" ;;
  esac

  case "$CHECK_LEVEL" in
    quick|full) ;;
    *) fail "--check 仅支持 quick|full" ;;
  esac
}

main() {
  parse_args "$@"
  assert_prerequisites

  if [ "$DO_UNINSTALL" -eq 1 ]; then
    if [ "$TARGET" = "claude" ] || [ "$TARGET" = "all" ]; then
      uninstall_target "claude" "$CLAUDE_DIR"
    fi
    if [ "$TARGET" = "codex" ] || [ "$TARGET" = "all" ]; then
      uninstall_target "codex" "$CODEX_DIR"
    fi
    exit 0
  fi

  if [ "${ORG_SKIP_CONTRACT_VALIDATION:-0}" = "1" ]; then
    warn "已跳过契约校验（ORG_SKIP_CONTRACT_VALIDATION=1）"
  else
    log "执行契约校验"
    bash "$REPO_ROOT/tools/validate-contracts.sh"
  fi

  local version_base git_hash version_tag dirty fingerprint
  version_base="$(trim < "$REPO_ROOT/VERSION")"
  if git -C "$REPO_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
    git_hash="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
    dirty=""
    if ! git -C "$REPO_ROOT" diff --quiet --ignore-submodules -- \
      || ! git -C "$REPO_ROOT" diff --cached --quiet --ignore-submodules --; then
      dirty="-dirty"
    fi
    git_hash="${git_hash}${dirty}"
  else
    fingerprint="$(compute_repo_fingerprint)"
    git_hash="nogit-${fingerprint}"
  fi
  version_tag="${version_base}-${git_hash}"

  if [ "$TARGET" = "claude" ] || [ "$TARGET" = "all" ]; then
    install_to_target "claude" "$CLAUDE_DIR" build_staging_claude "$version_tag"
    if [ "$MERGE_HOOKS" -eq 1 ]; then
      merge_hooks_fragment
    fi
  fi

  if [ "$TARGET" = "codex" ] || [ "$TARGET" = "all" ]; then
    install_to_target "codex" "$CODEX_DIR" build_staging_codex "$version_tag"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run 模式，跳过安装后检查"
  else
    run_checks "$TARGET"
  fi
  log "安装流程完成：target=$TARGET, version=$version_tag"
}

main "$@"
