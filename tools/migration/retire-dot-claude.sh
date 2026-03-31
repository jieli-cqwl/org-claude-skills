#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
SHARED_REPO="$REPO_ROOT"
STATE_ROOT="${ORG_STATE_ROOT:-$HOME/.org-skills-state}"
ARCHIVE_REMOTE=0

usage() {
  cat <<'USAGE'
Usage:
  retire-dot-claude.sh [--claude-dir PATH] [--shared-repo PATH] [--state-root PATH] [--archive-remote]

Options:
  --claude-dir       旧 .claude 运行目录，默认 ~/.claude
  --shared-repo      org-claude-skills 仓库根目录，默认当前仓库
  --state-root       统一状态/归档目录，默认 ~/.org-skills-state
  --archive-remote   同时通过 gh 将 origin 对应远端仓库设为 archived
  -h, --help         显示帮助
USAGE
}

log() {
  printf '[retire-dot-claude] %s\n' "$*"
}

fail() {
  printf '[retire-dot-claude][ERROR] %s\n' "$*" >&2
  exit 1
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

is_local_runtime_only() {
  local rel="$1"

  case "$rel" in
    settings.json|settings.local.json|statusline-command.sh|bin/jdtls-wrapper.sh)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_shared_runtime_managed() {
  local rel="$1"
  local name rest file

  case "$rel" in
    CLAUDE.md)
      [ -f "$SHARED_REPO/shared/assistant.md" ]
      ;;
    hooks/*)
      [ -f "$SHARED_REPO/shared/$rel" ] || [ -f "$SHARED_REPO/claude/$rel" ]
      ;;
    skills/lib/*)
      [ -f "$SHARED_REPO/shared/$rel" ]
      ;;
    skills/*/*)
      name="${rel#skills/}"
      name="${name%%/*}"
      rest="${rel#skills/"$name"/}"
      [ -f "$SHARED_REPO/shared/skills/$name/$rest" ]
      ;;
    rules/*)
      file="${rel#rules/}"
      [ -f "$SHARED_REPO/shared/rules/$file" ]
      ;;
    reference/*)
      file="${rel#reference/}"
      [ -f "$SHARED_REPO/shared/reference/$file" ] || [ -f "$SHARED_REPO/shared/protocols/$file" ]
      ;;
    agents/*)
      file="${rel#agents/}"
      [ -f "$SHARED_REPO/shared/agents/$file" ]
      ;;
    *)
      return 1
      ;;
  esac
}

archive_runtime_extra() {
  local rel="$1"
  local archive_runtime_root="$2"
  local src="$CLAUDE_DIR/$rel"
  local dst="$archive_runtime_root/$rel"

  [ -e "$src" ] || [ -L "$src" ] || return 0

  mkdir -p "$(dirname "$dst")"
  mv "$src" "$dst"
  remove_if_empty "$(dirname "$src")" "$CLAUDE_DIR"
}

archive_repo_only_path() {
  local rel="$1"
  local archive_runtime_root="$2"
  local src="$CLAUDE_DIR/$rel"
  local dst="$archive_runtime_root/$rel"

  [ -e "$src" ] || [ -L "$src" ] || return 0

  if [ -d "$src" ] && [ ! -L "$src" ]; then
    mkdir -p "$dst"
    find "$src" -mindepth 1 -maxdepth 1 -exec mv {} "$dst"/ \;
    rmdir "$src" 2>/dev/null || true
  else
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
  fi
  remove_if_empty "$(dirname "$src")" "$CLAUDE_DIR"
}

parse_origin_slug() {
  local url="$1"

  case "$url" in
    git@github.com:*.git)
      printf '%s\n' "${url#git@github.com:}" | sed 's/\.git$//'
      ;;
    https://github.com/*.git)
      printf '%s\n' "${url#https://github.com/}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${url#https://github.com/}"
      ;;
    *)
      return 1
      ;;
  esac
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --claude-dir)
        [ "$#" -ge 2 ] || fail "--claude-dir 缺少参数"
        CLAUDE_DIR="$2"
        shift 2
        ;;
      --shared-repo)
        [ "$#" -ge 2 ] || fail "--shared-repo 缺少参数"
        SHARED_REPO="$2"
        shift 2
        ;;
      --state-root)
        [ "$#" -ge 2 ] || fail "--state-root 缺少参数"
        STATE_ROOT="$2"
        shift 2
        ;;
      --archive-remote)
        ARCHIVE_REMOTE=1
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
}

main() {
  parse_args "$@"

  [ -d "$CLAUDE_DIR" ] || fail "目录不存在: $CLAUDE_DIR"
  [ -d "$SHARED_REPO" ] || fail "共享仓库不存在: $SHARED_REPO"
  [ -d "$CLAUDE_DIR/.git" ] || fail "$CLAUDE_DIR 不是 git 仓库，无法执行退役"

  local stamp archive_root archive_runtime_root runtime_manifest snapshot_file git_archive
  local origin_url_snapshot=""
  stamp="$(date +%Y%m%d%H%M%S)"
  archive_root="$STATE_ROOT/archive/dot-claude-retirement-$stamp"
  archive_runtime_root="$archive_root/runtime-files"
  runtime_manifest="$archive_root/runtime-archived-manifest.txt"
  snapshot_file="$archive_root/repo-snapshot.txt"
  git_archive="$archive_root/dot-claude-git.tar.gz"

  mkdir -p "$archive_runtime_root"
  origin_url_snapshot="$(git -C "$CLAUDE_DIR" remote get-url origin 2>/dev/null || true)"

  {
    printf 'timestamp=%s\n' "$stamp"
    printf 'claude_dir=%s\n' "$CLAUDE_DIR"
    printf 'shared_repo=%s\n' "$SHARED_REPO"
    printf 'branch=%s\n' "$(git -C "$CLAUDE_DIR" branch --show-current || true)"
    printf 'head=%s\n' "$(git -C "$CLAUDE_DIR" rev-parse HEAD || true)"
    printf 'origin=%s\n' "$origin_url_snapshot"
    printf '%s\n' 'status<<EOF'
    git -C "$CLAUDE_DIR" status --short || true
    printf '%s\n' 'EOF'
  } > "$snapshot_file"

  local rel archived_count=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if is_shared_runtime_managed "$rel" || is_local_runtime_only "$rel"; then
      continue
    fi
    archive_runtime_extra "$rel" "$archive_runtime_root"
    printf '%s\n' "$rel" >> "$runtime_manifest"
    archived_count=$((archived_count + 1))
  done < <(git -C "$CLAUDE_DIR" ls-files | sort)

  local repo_only_root
  for repo_only_root in .gitignore contracts docs output-styles tests tools; do
    if [ -e "$CLAUDE_DIR/$repo_only_root" ] || [ -L "$CLAUDE_DIR/$repo_only_root" ]; then
      archive_repo_only_path "$repo_only_root" "$archive_runtime_root"
    fi
  done

  tar -czf "$git_archive" -C "$CLAUDE_DIR" .git
  rm -rf "$CLAUDE_DIR/.git"

  if [ "$ARCHIVE_REMOTE" -eq 1 ]; then
    command -v gh >/dev/null 2>&1 || fail "--archive-remote 需要 gh 命令"
    local slug
    [ -n "$origin_url_snapshot" ] || fail "缺少 origin，无法归档远端仓库"
    slug="$(parse_origin_slug "$origin_url_snapshot")" || fail "无法识别 GitHub origin: $origin_url_snapshot"
    gh repo archive "$slug" --yes
    log "已归档远端仓库: $slug"
  fi

  log "已归档 $archived_count 个旧 tracked 文件到 $archive_runtime_root"
  log "已归档 .git 到 $git_archive"
}

main "$@"
