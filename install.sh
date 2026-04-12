#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
SHARED_SOURCE="$REPO_ROOT/shared"
CLAUDE_SOURCE="$REPO_ROOT/claude"
CODEX_SOURCE="$REPO_ROOT/codex"
COMMUNITY_SOURCE="$REPO_ROOT/community"
HOOK_REGISTRY="$SHARED_SOURCE/hooks/registry.json"
HOOK_RENDERER="$REPO_ROOT/tools/community/render_hook_registry.py"
CODEX_RUNTIME_MANAGER="$REPO_ROOT/tools/community/manage_codex_runtime.py"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
ORG_STATE_ROOT="${ORG_STATE_ROOT:-$HOME/.org-skills-state}"

TARGET="all"
DRY_RUN=0
CHECK_LEVEL="quick"
FORCE=0
MERGE_HOOKS=1
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
  --merge-hooks  兼容旧参数；Claude hooks 现已默认合并到 ~/.claude/settings.json
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
  [ -d "$SHARED_SOURCE/protocols" ] || fail "缺少目录: $SHARED_SOURCE/protocols"
  [ -d "$SHARED_SOURCE/rules" ] || fail "缺少目录: $SHARED_SOURCE/rules"
  [ -d "$SHARED_SOURCE/agents" ] || fail "缺少目录: $SHARED_SOURCE/agents"
  [ -d "$CLAUDE_SOURCE" ] || fail "缺少目录: $CLAUDE_SOURCE"
  [ -d "$CODEX_SOURCE" ] || fail "缺少目录: $CODEX_SOURCE"
  [ -d "$COMMUNITY_SOURCE/superpowers/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/superpowers/skills"
  [ -d "$COMMUNITY_SOURCE/anthropic/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/anthropic/skills"
  [ -d "$COMMUNITY_SOURCE/anthropic/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/anthropic/codex/skills"
  [ -d "$COMMUNITY_SOURCE/vercel/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/vercel/skills"
  [ -d "$COMMUNITY_SOURCE/vercel/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/vercel/codex/skills"
  [ -f "$COMMUNITY_SOURCE/superpowers/agents/generic-code-reviewer.md" ] || fail "缺少文件: $COMMUNITY_SOURCE/superpowers/agents/generic-code-reviewer.md"
  [ -f "$COMMUNITY_SOURCE/SOURCES.yaml" ] || fail "缺少文件: $COMMUNITY_SOURCE/SOURCES.yaml"
  [ -f "$REPO_ROOT/tools/validate-contracts.sh" ] || fail "缺少校验脚本: tools/validate-contracts.sh"
  [ -f "$REPO_ROOT/tools/community/sync_vercel_skills_from_upstream.py" ] || fail "缺少 Vercel sync 脚本: tools/community/sync_vercel_skills_from_upstream.py"
  [ -f "$HOOK_REGISTRY" ] || fail "缺少 hook registry: $HOOK_REGISTRY"
  [ -f "$HOOK_RENDERER" ] || fail "缺少 hook renderer: $HOOK_RENDERER"
  [ -f "$CODEX_RUNTIME_MANAGER" ] || fail "缺少 Codex runtime manager: $CODEX_RUNTIME_MANAGER"
}

compute_repo_fingerprint() {
  python3 - "$REPO_ROOT" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
targets = ["VERSION", "install.sh", "uninstall.sh", "shared", "claude", "codex", "community", "openspec", "contracts", "tools", "tests", ".github"]

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

render_claude_hooks_fragment() {
  local output="$1"

  python3 "$HOOK_RENDERER" claude-settings-fragment \
    --registry "$HOOK_REGISTRY" \
    --runtime-home "\$HOME/.claude" > "$output"
}

claude_settings_baseline_file() {
  printf '%s/claude-settings-baseline.json\n' "$(target_state_dir claude)"
}

claude_settings_missing_marker() {
  printf '%s/claude-settings-baseline.missing\n' "$(target_state_dir claude)"
}

required_claude_hook_commands() {
  cat <<'EOF'
bash $HOME/.claude/hooks/block_dangerous.sh
bash $HOME/.claude/hooks/code_quality_check.sh
bash $HOME/.claude/hooks/auto_format.sh
bash $HOME/.claude/hooks/post_compact.sh
bash $HOME/.claude/hooks/task_verify.sh
EOF
}

claude_hooks_registered() {
  local settings="$1"
  local cmd

  [ -f "$settings" ] || return 1

  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    grep -Fq "$cmd" "$settings" || return 1
  done < <(required_claude_hook_commands)

  return 0
}

snapshot_claude_settings_baseline() {
  local settings="$CLAUDE_DIR/settings.json"
  local baseline_file missing_marker
  baseline_file="$(claude_settings_baseline_file)"
  missing_marker="$(claude_settings_missing_marker)"

  if [ -f "$baseline_file" ] || [ -f "$missing_marker" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$baseline_file")"

  if [ -f "$settings" ]; then
    cp -a "$settings" "$baseline_file"
  else
    : > "$missing_marker"
  fi
}

cleanup_claude_settings_managed_hooks() {
  local settings="$CLAUDE_DIR/settings.json"
  local fragment tmp

  [ -f "$settings" ] || return 0

  fragment=$(mktemp)
  tmp=$(mktemp)
  render_claude_hooks_fragment "$fragment"

  python3 - "$settings" "$fragment" "$tmp" <<'PY'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
fragment_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])

settings = json.loads(settings_path.read_text(encoding="utf-8"))
fragment = json.loads(fragment_path.read_text(encoding="utf-8"))

settings_hooks = settings.get("hooks", {})
fragment_hooks = fragment.get("hooks", {})

for event, fragment_items in fragment_hooks.items():
    existing_items = settings_hooks.get(event)
    if not isinstance(existing_items, list):
        continue
    managed = {json.dumps(item, sort_keys=True, ensure_ascii=False) for item in fragment_items}
    filtered = [
        item for item in existing_items
        if json.dumps(item, sort_keys=True, ensure_ascii=False) not in managed
    ]
    if filtered:
        settings_hooks[event] = filtered
    else:
        settings_hooks.pop(event, None)

if settings_hooks:
    settings["hooks"] = settings_hooks
else:
    settings.pop("hooks", None)

output_path.write_text(
    json.dumps(settings, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

  mv "$tmp" "$settings"
  rm -f "$fragment"
}

restore_claude_settings_baseline() {
  local settings="$CLAUDE_DIR/settings.json"
  local baseline_file missing_marker
  baseline_file="$(claude_settings_baseline_file)"
  missing_marker="$(claude_settings_missing_marker)"

  if [ -f "$baseline_file" ]; then
    mkdir -p "$(dirname "$settings")"
    cp -a "$baseline_file" "$settings"
    rm -f "$baseline_file" "$missing_marker"
    return 0
  fi

  if [ -f "$missing_marker" ]; then
    rm -f "$settings" "$missing_marker"
    return 0
  fi

  cleanup_claude_settings_managed_hooks
}

merge_hooks_fragment() {
  local settings="$CLAUDE_DIR/settings.json"

  local fragment tmp
  fragment=$(mktemp)
  render_claude_hooks_fragment "$fragment"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] 将合并 hooks fragment -> $settings"
    rm -f "$fragment"
    return 0
  fi

  snapshot_claude_settings_baseline
  [ -f "$settings" ] || printf '%s\n' '{"hooks":{}}' > "$settings"

  tmp=$(mktemp)
  python3 - "$settings" "$fragment" "$tmp" <<'PY'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
fragment_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])

settings = json.loads(settings_path.read_text(encoding="utf-8"))
fragment = json.loads(fragment_path.read_text(encoding="utf-8"))

hooks = settings.setdefault("hooks", {})

for event, fragment_items in fragment.get("hooks", {}).items():
    existing = hooks.setdefault(event, [])
    seen = {json.dumps(item, sort_keys=True, ensure_ascii=False) for item in existing}
    for item in fragment_items:
        serialized = json.dumps(item, sort_keys=True, ensure_ascii=False)
        if serialized not in seen:
            existing.append(item)
            seen.add(serialized)

output_path.write_text(
    json.dumps(settings, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

  mv "$tmp" "$settings"
  rm -f "$fragment"
  log "已合并 hooks fragment -> $settings"
}

inject_claude_skill_hooks_from_registry() {
  local skills_dir="$1"

  python3 "$HOOK_RENDERER" inject-claude-skill-hooks \
    --registry "$HOOK_REGISTRY" \
    --skills-dir "$skills_dir" \
    --runtime-home "\$HOME/.claude"
}

check_hooks_registration() {
  local settings="$CLAUDE_DIR/settings.json"
  local missing=0
  local cmd

  [ -f "$settings" ] || fail "Quick Check 失败: ~/.claude/settings.json 不存在"

  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    if ! grep -Fq "$cmd" "$settings"; then
      warn "settings.json 缺少 hooks 注册: $cmd"
      missing=$((missing + 1))
    fi
  done < <(required_claude_hook_commands)

  if [ "$missing" -eq 0 ]; then
    log "hooks 注册检查通过"
  else
    fail "Quick Check 失败: ~/.claude/settings.json 缺少 $missing 项 hooks 注册"
  fi

  return 0
}

render_codex_hooks_payload() {
  local output="$1"

  python3 "$HOOK_RENDERER" codex-hooks \
    --registry "$HOOK_REGISTRY" \
    --runtime-home "$CODEX_DIR" > "$output"
}

codex_hooks_feature_state_file() {
  printf '%s/codex-hooks-feature-state.json\n' "$(target_state_dir codex)"
}

codex_hooks_baseline_file() {
  printf '%s/codex-hooks-baseline.json\n' "$(target_state_dir codex)"
}

enable_codex_hooks_feature() {
  local config_file="$CODEX_DIR/config.toml"
  local state_file
  state_file="$(codex_hooks_feature_state_file)"

  python3 "$CODEX_RUNTIME_MANAGER" enable-feature \
    --config "$config_file" \
    --state "$state_file"
}

restore_codex_hooks_feature() {
  local config_file="$CODEX_DIR/config.toml"
  local state_file
  state_file="$(codex_hooks_feature_state_file)"

  python3 "$CODEX_RUNTIME_MANAGER" restore-feature \
    --config "$config_file" \
    --state "$state_file"
}

snapshot_codex_hooks_json_baseline() {
  local hooks_file="$CODEX_DIR/hooks.json"
  local baseline_file
  baseline_file="$(codex_hooks_baseline_file)"

  [ -f "$baseline_file" ] && return 0
  [ -f "$hooks_file" ] || return 0

  mkdir -p "$(dirname "$baseline_file")"
  cp -a "$hooks_file" "$baseline_file"
}

merge_codex_hooks_json() {
  local hooks_file="$CODEX_DIR/hooks.json"
  local managed_root="$CODEX_DIR/hooks/managed"
  local rendered
  rendered=$(mktemp)
  render_codex_hooks_payload "$rendered"

  python3 "$CODEX_RUNTIME_MANAGER" merge-hooks \
    --hooks-file "$hooks_file" \
    --managed-file "$rendered" \
    --managed-root "$managed_root"
  rm -f "$rendered"
}

cleanup_codex_hooks_json() {
  local hooks_file="$CODEX_DIR/hooks.json"
  local managed_root="$CODEX_DIR/hooks/managed"

  python3 "$CODEX_RUNTIME_MANAGER" cleanup-hooks \
    --hooks-file "$hooks_file" \
    --managed-root "$managed_root"
}

restore_codex_hooks_json_baseline() {
  local hooks_file="$CODEX_DIR/hooks.json"
  local baseline_file
  baseline_file="$(codex_hooks_baseline_file)"

  if [ -f "$baseline_file" ]; then
    mkdir -p "$(dirname "$hooks_file")"
    cp -a "$baseline_file" "$hooks_file"
    rm -f "$baseline_file"
    return 0
  fi

  cleanup_codex_hooks_json
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

community_superpowers_selected() {
  printf '%s\n' \
    "using-superpowers" \
    "brainstorming" \
    "using-git-worktrees" \
    "writing-plans" \
    "subagent-driven-development" \
    "requesting-code-review" \
    "verification-before-completion" \
    "finishing-a-development-branch" \
    "verify-change" \
    "archive" \
    "test-driven-development"
}

claude_only_skills() {
  printf '%s\n' \
    "code-review-fix" \
    "doc-review-fix" \
    "review-fix-loop" \
    "codex-doc-review"
}

community_superpowers_auto_skills() {
  printf '%s\n' \
    "brainstorming"
}

community_superpowers_manual_only_skills() {
  printf '%s\n' \
    "using-superpowers" \
    "using-git-worktrees" \
    "writing-plans" \
    "subagent-driven-development" \
    "requesting-code-review" \
    "verification-before-completion" \
    "finishing-a-development-branch" \
    "verify-change" \
    "archive" \
    "test-driven-development"
}

community_anthropic_selected() {
  printf '%s\n' \
    "algorithmic-art" \
    "brand-guidelines" \
    "canvas-design" \
    "claude-api" \
    "doc-coauthoring" \
    "docx" \
    "frontend-design" \
    "internal-comms" \
    "mcp-builder" \
    "pdf" \
    "pptx" \
    "skill-creator" \
    "slack-gif-creator" \
    "theme-factory" \
    "web-artifacts-builder" \
    "webapp-testing" \
    "xlsx"
}

# Selected Vercel community skills are vendored as a third-party source.
community_vercel_selected() {
  printf '%s\n' \
    "find-skills" \
    "agent-browser"
}

community_anthropic_override_skills() {
  printf '%s\n' \
    "mcp-builder"
}

local_manual_only_skills() {
  printf '%s\n' \
    "product" \
    "design" \
    "test-design" \
    "tech-lead" \
    "delivery-owner" \
    "developer" \
    "review" \
    "verify" \
    "qa" \
    "fix" \
    "worktree" \
    "commit" \
    "ux" \
    "rules-manager" \
    "project-memory"
}

community_anthropic_should_override() {
  local skill="$1"
  while IFS= read -r override; do
    [ -n "$override" ] || continue
    if [ "$override" = "$skill" ]; then
      return 0
    fi
  done < <(community_anthropic_override_skills)
  return 1
}

copy_superpowers_agents() {
  local dst="$1"
  mkdir -p "$dst"
  cp "$COMMUNITY_SOURCE/superpowers/agents/generic-code-reviewer.md" "$dst/generic-code-reviewer.md"
}

copy_selected_superpowers_skills() {
  local dst="$1"
  local skill

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    cp -R "$COMMUNITY_SOURCE/superpowers/skills/$skill" "$dst/$skill"
  done < <(community_superpowers_selected)
}

copy_selected_anthropic_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/anthropic/skills/$skill"
    [ -d "$src" ] || fail "缺少 Anthropic skill 源目录: $src"

    if [ -e "$dst/$skill" ] && ! community_anthropic_should_override "$skill"; then
      continue
    fi

    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
  done < <(community_anthropic_selected)
}

# Copy the vendored Vercel skill trees into the runtime staging area.
copy_selected_vercel_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/vercel/skills/$skill"
    [ -d "$src" ] || fail "缺少 Vercel skill 源目录: $src"

    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
  done < <(community_vercel_selected)
}

overlay_codex_community_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/superpowers/codex/skills"
  local skill

  [ -d "$adapter_root" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || continue
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done < <(community_superpowers_auto_skills)
}

overlay_codex_anthropic_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/anthropic/codex/skills"
  local skill

  [ -d "$adapter_root" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || fail "缺少 Anthropic Codex adapter: $adapter_root/$skill"
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done < <(community_anthropic_selected)
}

# Overlay generated Codex auto-skill metadata for vendored Vercel skills.
overlay_codex_vercel_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/vercel/codex/skills"
  local skill

  [ -d "$adapter_root" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || fail "缺少 Vercel Codex adapter: $adapter_root/$skill"
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done < <(community_vercel_selected)
}

apply_claude_skill_visibility() {
  local skills_dir="$1"

  ORG_SKILLS_DIR="$skills_dir" \
  ORG_LOCAL_MANUAL_ONLY="$(local_manual_only_skills | paste -sd, -)" \
  ORG_COMMUNITY_MANUAL_ONLY="$(community_superpowers_manual_only_skills | paste -sd, -)" \
  ORG_COMMUNITY_AUTO="$(community_superpowers_auto_skills | paste -sd, -)" \
  python3 <<'PY'
import os

skills_dir = os.environ["ORG_SKILLS_DIR"]
local_manual_only = {item for item in os.environ.get("ORG_LOCAL_MANUAL_ONLY", "").split(",") if item}
community_manual_only = {item for item in os.environ.get("ORG_COMMUNITY_MANUAL_ONLY", "").split(",") if item}
community_auto = {item for item in os.environ.get("ORG_COMMUNITY_AUTO", "").split(",") if item}
manual_only = local_manual_only | community_manual_only
community_skills = community_manual_only | community_auto

for entry in sorted(os.listdir(skills_dir)):
    skill_file = os.path.join(skills_dir, entry, "SKILL.md")
    if not os.path.isfile(skill_file):
      continue

    text = open(skill_file, encoding="utf-8").read()
    if not text.startswith("---\n"):
      continue

    parts = text.split("---\n", 2)
    if len(parts) != 3:
      continue

    _, frontmatter, body = parts
    lines = [line for line in frontmatter.splitlines() if line.strip()]

    def find_key(key: str):
        for idx, line in enumerate(lines):
            if line.startswith(f"{key}:"):
                return idx
        return None

    if entry in community_skills and find_key("user-invocable") is None:
        lines.insert(1 if lines else 0, "user-invocable: true")

    manual_idx = find_key("disable-model-invocation")
    if entry in manual_only:
        if manual_idx is None:
            lines.insert(2 if len(lines) >= 2 else len(lines), "disable-model-invocation: true")
        else:
            lines[manual_idx] = "disable-model-invocation: true"
    elif entry in community_auto and manual_idx is not None:
        lines.pop(manual_idx)

    updated = "---\n" + "\n".join(lines).rstrip() + "\n---\n\n" + body.lstrip("\n")
    if updated != text:
        with open(skill_file, "w", encoding="utf-8") as f:
            f.write(updated)
PY
}

prune_codex_manual_only_openai_yaml() {
  local skills_dir="$1"
  local skill

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    rm -f "$skills_dir/$skill/agents/openai.yaml"
    rmdir "$skills_dir/$skill/agents" 2>/dev/null || true
  done < <(local_manual_only_skills)
}

render_runtime_placeholders() {
  local tree="$1"
  local runtime_home="$2"
  local entry_doc="$3"
  local file

  while IFS= read -r -d '' file; do
    ORG_RENDER_RUNTIME_HOME="$runtime_home" ORG_RENDER_ENTRY_DOC="$entry_doc" perl -0pi -e '
      s/\{\{RUNTIME_HOME\}\}/$ENV{ORG_RENDER_RUNTIME_HOME}/g;
      s/\{\{ENTRY_DOC\}\}/$ENV{ORG_RENDER_ENTRY_DOC}/g;
    ' "$file"
  done < <(find "$tree" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' -o -name '*.toml' -o -name '*.yaml' \) -print0)
}

render_runtime_contract() {
  local tree="$1"
  local runtime_home="$2"
  local catalog="$SHARED_SOURCE/runtime/runtime-catalog.json"
  local renderer="$REPO_ROOT/tools/community/render_runtime_contract.py"

  [ -f "$catalog" ] || fail "缺少 runtime catalog: $catalog"
  [ -f "$renderer" ] || fail "缺少 runtime contract renderer: $renderer"

  python3 "$renderer" \
    --staging-root "$tree" \
    --catalog "$catalog" \
    --runtime-home "$runtime_home"
}

rewrite_codex_skill_docs() {
  local skills_dir="$1"

  python3 - "$skills_dir" <<'PY'
import os
import sys

skills_dir = sys.argv[1]

note_template = (
    "> Codex 运行说明：completion gate 默认通过 `~/.codex/hooks.json` 自动执行。\n"
    "> 若 hooks 不可用或需要 fresh proving command，请显式运行：\n"
    "> `bash $HOME/.codex/skills/{skill}/scripts/completion_check.sh`\n"
)

for entry in sorted(os.listdir(skills_dir)):
    skill_dir = os.path.join(skills_dir, entry)
    skill_file = os.path.join(skill_dir, "SKILL.md")
    completion_check = os.path.join(skill_dir, "scripts", "completion_check.sh")

    if not os.path.isfile(skill_file):
        continue

    text = open(skill_file, encoding="utf-8").read()
    if not text.startswith("---\n"):
        continue

    parts = text.split("---\n", 2)
    if len(parts) != 3:
        continue

    _, frontmatter, body = parts
    lines = frontmatter.splitlines()
    new_lines = []
    i = 0
    removed_hooks = False

    while i < len(lines):
        line = lines[i]
        if line.startswith("hooks:"):
            removed_hooks = True
            i += 1
            while i < len(lines):
                next_line = lines[i]
                if next_line.startswith(" ") or next_line.startswith("\t"):
                    i += 1
                    continue
                break
            continue
        new_lines.append(line)
        i += 1

    new_frontmatter = "\n".join(new_lines).rstrip()
    new_body = body.lstrip("\n")

    if os.path.isfile(completion_check):
        note = note_template.format(skill=entry)
        if note not in new_body:
            new_body = note + "\n" + new_body
        new_body = new_body.replace(
            "- [ ] Stop hook（`completion_check.sh`）执行通过，无 FAIL 项",
            "- [ ] 显式执行 `scripts/completion_check.sh` 并通过，无 FAIL 项",
        )

    updated = f"---\n{new_frontmatter}\n---\n\n{new_body}"

    if removed_hooks or updated != text:
        with open(skill_file, "w", encoding="utf-8") as f:
            f.write(updated)
PY
}

build_staging_claude() {
  local staging="$1"
  mkdir -p "$staging"/{skills,rules,reference,protocols,hooks,agents,commands}

  cp "$SHARED_SOURCE/assistant.md" "$staging/CLAUDE.md"
  copy_tree_contents "$SHARED_SOURCE/skills" "$staging/skills"
  copy_selected_superpowers_skills "$staging/skills"
  copy_selected_anthropic_skills "$staging/skills"
  copy_selected_vercel_skills "$staging/skills"
  if [ -d "$CLAUDE_SOURCE/skills" ]; then
    copy_tree_contents "$CLAUDE_SOURCE/skills" "$staging/skills"
  fi
  copy_tree_contents "$SHARED_SOURCE/rules" "$staging/rules"
  copy_tree_contents "$SHARED_SOURCE/reference" "$staging/reference"
  copy_tree_contents "$SHARED_SOURCE/protocols" "$staging/protocols"
  copy_tree_contents "$SHARED_SOURCE/agents" "$staging/agents"
  copy_superpowers_agents "$staging/agents"
  if [ -d "$CLAUDE_SOURCE/agents" ]; then
    copy_tree_contents "$CLAUDE_SOURCE/agents" "$staging/agents"
  fi
  copy_tree_contents "$SHARED_SOURCE/hooks" "$staging/hooks"
  copy_tree_contents "$CLAUDE_SOURCE/hooks" "$staging/hooks"
  rm -rf \
    "$staging/skills/review-fix-loop" \
    "$staging/skills/codex-doc-review"
  rm -f "$staging/agents/codex-doc-reviewer.md"
  find "$staging/skills" -mindepth 2 -maxdepth 2 -type d -name agents -exec rm -rf {} +
  apply_claude_skill_visibility "$staging/skills"
  inject_claude_skill_hooks_from_registry "$staging/skills"
  render_runtime_placeholders "$staging" "\$HOME/.claude" "CLAUDE.md"
  render_runtime_contract "$staging" "\$HOME/.claude"
}

build_staging_codex() {
  local staging="$1"
  mkdir -p "$staging"/{skills,rules,reference,protocols,agents,hooks}

  cp "$SHARED_SOURCE/assistant.md" "$staging/AGENTS.md"
  copy_tree_contents "$SHARED_SOURCE/skills" "$staging/skills"
  copy_selected_superpowers_skills "$staging/skills"
  copy_selected_anthropic_skills "$staging/skills"
  copy_selected_vercel_skills "$staging/skills"
  overlay_codex_community_skill_adapters "$staging/skills"
  overlay_codex_anthropic_skill_adapters "$staging/skills"
  overlay_codex_vercel_skill_adapters "$staging/skills"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    rm -rf "$staging/skills/$skill"
  done < <(claude_only_skills)
  prune_codex_manual_only_openai_yaml "$staging/skills"
  copy_tree_contents "$SHARED_SOURCE/rules" "$staging/rules"
  copy_tree_contents "$SHARED_SOURCE/reference" "$staging/reference"
  copy_tree_contents "$SHARED_SOURCE/protocols" "$staging/protocols"
  copy_tree_contents "$SHARED_SOURCE/agents" "$staging/agents"
  copy_superpowers_agents "$staging/agents"
  copy_tree_contents "$SHARED_SOURCE/hooks" "$staging/hooks"
  local f
  for f in "$CODEX_SOURCE"/agents/*.toml; do
    [ -f "$f" ] || continue
    sed "s|{{HOME}}|$HOME|g" "$f" > "$staging/agents/$(basename "$f")"
  done

  render_runtime_placeholders "$staging" "\$HOME/.codex" "AGENTS.md"
  render_runtime_contract "$staging" "\$HOME/.codex"
  rewrite_codex_skill_docs "$staging/skills"
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

build_allowed_codex_rule_names() {
  find "$SHARED_SOURCE/rules" -maxdepth 1 -type f -name '*.md' -exec basename {} \; 2>/dev/null | sort
  printf '%s\n' "default.rules"
}

RUNTIME_AUDIT_DIRTY=0

audit_codex_runtime_rules() {
  local target_dir="$1"
  local state_dir="$2"
  local allowed_names name path archive_root=""

  RUNTIME_AUDIT_DIRTY=0
  [ -d "$target_dir/rules" ] || return 0

  allowed_names="$(build_allowed_codex_rule_names)"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    name="$(basename "$path")"

    if printf '%s\n' "$allowed_names" | grep -Fxq "$name"; then
      if [ "$name" != "default.rules" ] && [ -L "$path" ]; then
        RUNTIME_AUDIT_DIRTY=1
        if [ "$DRY_RUN" -eq 1 ]; then
          log "[dry-run] codex 将重建受管规则软链接为真实文件: $path"
        else
          rm -f "$path"
          log "codex 已移除受管规则软链接，后续将重建为真实文件: $path"
        fi
      fi
      continue
    fi

    case "$name" in
      *.md)
        RUNTIME_AUDIT_DIRTY=1
        if [ "$DRY_RUN" -eq 1 ]; then
          log "[dry-run] codex 将归档并清理非受管规则残留: $path"
          continue
        fi

        [ -n "$archive_root" ] || archive_root="$state_dir/unexpected-artifacts/$(date +%Y%m%d%H%M%S)-$$"
        mkdir -p "$archive_root/rules"
        cp -a "$path" "$archive_root/rules/$name"
        rm -f "$path"
        log "codex 已归档并清理非受管规则残留: $path -> $archive_root/rules/$name"
        ;;
    esac
  done < <(find "$target_dir/rules" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | sort)
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

runtime_target_complete() {
  local name="$1"
  local target_dir="$2"

  if [ "$name" = "claude" ]; then
    [ -f "$target_dir/skills/brainstorming/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/verify-change/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/archive/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/code-review-fix/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/doc-review-fix/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/docx/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/skill-creator/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/mcp-builder/SKILL.md" ] || return 1
    [ ! -e "$target_dir/skills/review-fix-loop" ] || return 1
    [ ! -e "$target_dir/skills/codex-doc-review" ] || return 1
    [ ! -e "$target_dir/agents/codex-doc-reviewer.md" ] || return 1
    [ -f "$target_dir/hooks/block_dangerous.sh" ] || return 1
    [ -f "$target_dir/hooks/managed/block_dangerous.sh" ] || return 1
    [ -f "$target_dir/hooks/registry.json" ] || return 1
    [ -f "$target_dir/CLAUDE.md" ] || return 1
    claude_hooks_registered "$target_dir/settings.json" || return 1
    [ -f "$target_dir/protocols/phase-selection-protocol.md" ] || return 1
    [ ! -f "$target_dir/reference/phase-selection-protocol.md" ] || return 1
    [ ! -e "$target_dir/.org-installed-version" ] || return 1
    [ ! -e "$target_dir/.org-backups" ] || return 1
    return 0
  fi

  if [ "$name" = "codex" ]; then
    [ -f "$target_dir/AGENTS.md" ] || return 1
    [ -f "$target_dir/skills/brainstorming/agents/openai.yaml" ] || return 1
    [ ! -L "$target_dir/skills/brainstorming/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/verify-change/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/archive/SKILL.md" ] || return 1
    [ ! -e "$target_dir/skills/code-review-fix" ] || return 1
    [ ! -e "$target_dir/skills/doc-review-fix" ] || return 1
    [ ! -e "$target_dir/skills/review-fix-loop" ] || return 1
    [ ! -e "$target_dir/skills/codex-doc-review" ] || return 1
    [ -f "$target_dir/skills/docx/agents/openai.yaml" ] || return 1
    [ -f "$target_dir/skills/skill-creator/agents/openai.yaml" ] || return 1
    [ -f "$target_dir/skills/mcp-builder/agents/openai.yaml" ] || return 1
    [ -f "$target_dir/agents/developer.toml" ] || return 1
    [ -f "$target_dir/hooks/lib/common.sh" ] || return 1
    [ -f "$target_dir/hooks/lib/constraint.sh" ] || return 1
    [ -f "$target_dir/hooks/managed/block_dangerous.sh" ] || return 1
    [ -f "$target_dir/hooks/managed/codex_user_prompt_submit.py" ] || return 1
    [ -f "$target_dir/hooks/managed/codex_stop_dispatch.py" ] || return 1
    [ -f "$target_dir/hooks/registry.json" ] || return 1
    [ -f "$target_dir/protocols/phase-selection-protocol.md" ] || return 1
    [ ! -f "$target_dir/reference/phase-selection-protocol.md" ] || return 1
    [ ! -e "$target_dir/.org-installed-version" ] || return 1
    [ ! -e "$target_dir/.org-backups" ] || return 1
    return 0
  fi

  return 1
}

install_to_target() {
  local name="$1"
  local target_dir="$2"
  local build_fn="$3"
  local version_tag="$4"
  local state_dir
  state_dir="$(target_state_dir "$name")"
  local runtime_audit_dirty=0

  mkdir -p "$target_dir"
  migrate_legacy_runtime_state "$name" "$target_dir" "$state_dir"
  precheck_metadata_health "$state_dir"

  if [ "$name" = "codex" ]; then
    audit_codex_runtime_rules "$target_dir" "$state_dir"
    runtime_audit_dirty="$RUNTIME_AUDIT_DIRTY"
  fi

  local version_file="$state_dir/installed-version"
  local manifest_file="$state_dir/installed-manifest"
  local backup_manifest_file="$state_dir/backup-manifest"

  if [ "$FORCE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] \
    && [ -f "$version_file" ] && [ -f "$manifest_file" ] && [ -f "$backup_manifest_file" ] \
    && [ "$runtime_audit_dirty" -eq 0 ]; then
    local installed
    installed="$(trim < "$version_file")"
    if [ "$installed" = "$version_tag" ]; then
      if runtime_target_complete "$name" "$target_dir"; then
        log "$name 已是最新版本 ($installed)，跳过安装"
        return 0
      fi
      warn "$name 版本已匹配 ($installed)，但运行面不完整，继续重装"
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

  if [ "$name" = "claude" ]; then
    restore_claude_settings_baseline
  fi

  if [ "$name" = "codex" ]; then
    restore_codex_hooks_json_baseline
    rm -rf "$target_dir/hooks/state"
    restore_codex_hooks_feature
    remove_if_empty "$target_dir/hooks" "$target_dir"
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
    [ -f "$CLAUDE_DIR/skills/brainstorming/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/brainstorming/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/verify-change/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/verify-change/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/archive/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/archive/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/code-review-fix/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/code-review-fix/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/doc-review-fix/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/doc-review-fix/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/docx/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/docx/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/skill-creator/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/skill-creator/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/mcp-builder/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/mcp-builder/SKILL.md 不存在"
    [ ! -e "$CLAUDE_DIR/skills/review-fix-loop" ] || fail "Quick Check 失败: ~/.claude/skills/review-fix-loop 不应存在"
    [ ! -e "$CLAUDE_DIR/skills/codex-doc-review" ] || fail "Quick Check 失败: ~/.claude/skills/codex-doc-review 不应存在"
    [ ! -e "$CLAUDE_DIR/agents/codex-doc-reviewer.md" ] || fail "Quick Check 失败: ~/.claude/agents/codex-doc-reviewer.md 不应存在"
    [ -f "$CLAUDE_DIR/hooks/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.claude/hooks/block_dangerous.sh 不存在"
    [ -f "$CLAUDE_DIR/hooks/managed/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.claude/hooks/managed/block_dangerous.sh 不存在"
    [ -f "$CLAUDE_DIR/hooks/registry.json" ] || fail "Quick Check 失败: ~/.claude/hooks/registry.json 不存在"
    [ -f "$CLAUDE_DIR/CLAUDE.md" ] || fail "Quick Check 失败: ~/.claude/CLAUDE.md 不存在"
    [ -f "$CLAUDE_DIR/protocols/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.claude/protocols/phase-selection-protocol.md 不存在"
    [ ! -f "$CLAUDE_DIR/reference/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.claude/reference/phase-selection-protocol.md 不应存在"
    [ ! -e "$CLAUDE_DIR/.org-installed-version" ] || fail "Quick Check 失败: ~/.claude 不应残留 .org-installed-version"
    [ ! -e "$CLAUDE_DIR/.org-backups" ] || fail "Quick Check 失败: ~/.claude 不应残留 .org-backups"
    [ -f "$(target_state_dir claude)/installed-version" ] || fail "Quick Check 失败: ~/.org-skills-state/claude/installed-version 不存在"
    check_hooks_registration
  fi

  if [ "$target" = "codex" ] || [ "$target" = "all" ]; then
    [ -f "$CODEX_DIR/AGENTS.md" ] || fail "Quick Check 失败: ~/.codex/AGENTS.md 不存在"
    [ -f "$CODEX_DIR/skills/brainstorming/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.codex/skills/brainstorming/agents/openai.yaml 不存在"
    [ ! -L "$CODEX_DIR/skills/brainstorming/SKILL.md" ] || fail "Quick Check 失败: ~/.codex/skills/brainstorming/SKILL.md 不应为软链接"
    [ -f "$CODEX_DIR/skills/verify-change/SKILL.md" ] || fail "Quick Check 失败: ~/.codex/skills/verify-change/SKILL.md 不存在"
    [ -f "$CODEX_DIR/skills/archive/SKILL.md" ] || fail "Quick Check 失败: ~/.codex/skills/archive/SKILL.md 不存在"
    [ ! -e "$CODEX_DIR/skills/code-review-fix" ] || fail "Quick Check 失败: ~/.codex/skills/code-review-fix 不应存在"
    [ ! -e "$CODEX_DIR/skills/doc-review-fix" ] || fail "Quick Check 失败: ~/.codex/skills/doc-review-fix 不应存在"
    [ ! -e "$CODEX_DIR/skills/review-fix-loop" ] || fail "Quick Check 失败: ~/.codex/skills/review-fix-loop 不应存在"
    [ ! -e "$CODEX_DIR/skills/codex-doc-review" ] || fail "Quick Check 失败: ~/.codex/skills/codex-doc-review 不应存在"
    [ -f "$CODEX_DIR/skills/docx/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.codex/skills/docx/agents/openai.yaml 不存在"
    [ -f "$CODEX_DIR/skills/skill-creator/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.codex/skills/skill-creator/agents/openai.yaml 不存在"
    [ -f "$CODEX_DIR/skills/mcp-builder/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.codex/skills/mcp-builder/agents/openai.yaml 不存在"
    [ -f "$CODEX_DIR/skills/find-skills/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.codex/skills/find-skills/agents/openai.yaml 不存在"
    [ -f "$CODEX_DIR/skills/agent-browser/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.codex/skills/agent-browser/agents/openai.yaml 不存在"
    [ -f "$CODEX_DIR/agents/developer.toml" ] || fail "Quick Check 失败: ~/.codex/agents/developer.toml 不存在"
    [ -f "$CODEX_DIR/hooks/lib/common.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/lib/common.sh 不存在"
    [ -f "$CODEX_DIR/hooks/lib/constraint.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/lib/constraint.sh 不存在"
    [ -f "$CODEX_DIR/hooks/managed/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/block_dangerous.sh 不存在"
    [ -f "$CODEX_DIR/hooks/managed/codex_user_prompt_submit.py" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/codex_user_prompt_submit.py 不存在"
    [ -f "$CODEX_DIR/hooks/managed/codex_stop_dispatch.py" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/codex_stop_dispatch.py 不存在"
    [ -f "$CODEX_DIR/hooks/registry.json" ] || fail "Quick Check 失败: ~/.codex/hooks/registry.json 不存在"
    [ -f "$CODEX_DIR/protocols/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.codex/protocols/phase-selection-protocol.md 不存在"
    [ ! -f "$CODEX_DIR/reference/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.codex/reference/phase-selection-protocol.md 不应存在"
    [ ! -e "$CODEX_DIR/.org-installed-version" ] || fail "Quick Check 失败: ~/.codex 不应残留 .org-installed-version"
    [ ! -e "$CODEX_DIR/.org-backups" ] || fail "Quick Check 失败: ~/.codex 不应残留 .org-backups"
    [ -f "$(target_state_dir codex)/installed-version" ] || fail "Quick Check 失败: ~/.org-skills-state/codex/installed-version 不存在"
    [ -f "$CODEX_DIR/hooks.json" ] || fail "Quick Check 失败: ~/.codex/hooks.json 不存在"
    grep -Fq 'codex_hooks = true' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 未启用 codex_hooks"
    grep -Fq "$CODEX_DIR/hooks/managed/block_dangerous.sh" "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 managed dangerous hook"
    grep -Fq "$CODEX_DIR/hooks/managed/codex_user_prompt_submit.py" "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 active skill tracker"
    grep -Fq "$CODEX_DIR/hooks/managed/codex_stop_dispatch.py" "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 stop dispatcher"
    grep -Fq '"PostToolUse": []' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少空 PostToolUse 标准事件"
    grep -Fq '"PostCompact": []' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少空 PostCompact 标准事件"
    grep -Fq '"TaskCompleted": []' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少空 TaskCompleted 标准事件"
    if grep -Fq '"SessionStart"' "$CODEX_DIR/hooks.json"; then
      fail "Quick Check 失败: ~/.codex/hooks.json 不应残留非标准 SessionStart"
    fi
    if [ -f "$CODEX_DIR/hooks.json" ] && grep -Fq 'codex-hooks-probe.' "$CODEX_DIR/hooks.json"; then
      fail "Quick Check 失败: ~/.codex/hooks.json 不应残留 codex-hooks-probe 临时路径"
    fi
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
    if [ "$DRY_RUN" -eq 0 ]; then
      enable_codex_hooks_feature
      snapshot_codex_hooks_json_baseline
      merge_codex_hooks_json
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run 模式，跳过安装后检查"
  else
    run_checks "$TARGET"
  fi
  log "安装流程完成：target=$TARGET, version=$version_tag"
}

main "$@"
