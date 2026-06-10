#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
export PYTHONDONTWRITEBYTECODE=1
SHARED_SOURCE="$REPO_ROOT/shared"
CLAUDE_SOURCE="$REPO_ROOT/claude"
COMMUNITY_SOURCE="$REPO_ROOT/community"
HOOK_REGISTRY="$SHARED_SOURCE/hooks/registry.json"
HOOK_RENDERER="$REPO_ROOT/tools/community/render_hook_registry.py"
CODEX_RUNTIME_MANAGER="$REPO_ROOT/tools/community/manage_codex_runtime.py"
CODEX_HOOK_TRUST_AUDITOR="$REPO_ROOT/tools/community/audit_codex_hook_trust.py"
SKILL_RUNTIME_SURFACE_CONTRACT="$REPO_ROOT/contracts/skill-runtime-surface.json"
SKILL_RUNTIME_SURFACE_TOOL="$REPO_ROOT/tools/skills/apply_skill_runtime_surface.py"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
CODEX_USER_SKILLS_DIR="$HOME/.agents/skills"
ORG_STATE_ROOT="${ORG_STATE_ROOT:-$HOME/.org-skills-state}"
PYTHON_LAUNCHER="${ORG_HOOK_PYTHON:-$(command -v python3 || true)}"

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
  [ -d "$SHARED_SOURCE/agents/claude" ] || fail "缺少目录: $SHARED_SOURCE/agents/claude"
  [ -d "$SHARED_SOURCE/agents/codex" ] || fail "缺少目录: $SHARED_SOURCE/agents/codex"
  [ -d "$CLAUDE_SOURCE" ] || fail "缺少目录: $CLAUDE_SOURCE"
  [ -d "$COMMUNITY_SOURCE/superpowers/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/superpowers/skills"
  [ -d "$COMMUNITY_SOURCE/anthropic/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/anthropic/skills"
  [ -d "$COMMUNITY_SOURCE/anthropic/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/anthropic/codex/skills"
  [ -d "$COMMUNITY_SOURCE/vercel/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/vercel/skills"
  [ -d "$COMMUNITY_SOURCE/vercel/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/vercel/codex/skills"
  [ -d "$COMMUNITY_SOURCE/alchaincyf/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/alchaincyf/skills"
  [ -d "$COMMUNITY_SOURCE/alchaincyf/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/alchaincyf/codex/skills"
  [ -d "$COMMUNITY_SOURCE/nextlevelbuilder/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/nextlevelbuilder/skills"
  [ -d "$COMMUNITY_SOURCE/nextlevelbuilder/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/nextlevelbuilder/codex/skills"
  [ -d "$COMMUNITY_SOURCE/panniantong/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/panniantong/skills"
  [ -d "$COMMUNITY_SOURCE/panniantong/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/panniantong/codex/skills"
  [ -d "$COMMUNITY_SOURCE/skills-sh/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/skills-sh/skills"
  [ -d "$COMMUNITY_SOURCE/skills-sh/codex/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/skills-sh/codex/skills"
  [ -d "$COMMUNITY_SOURCE/persona/skills" ] || fail "缺少目录: $COMMUNITY_SOURCE/persona/skills"
  [ -f "$COMMUNITY_SOURCE/SOURCES.yaml" ] || fail "缺少文件: $COMMUNITY_SOURCE/SOURCES.yaml"
  [ -f "$SKILL_RUNTIME_SURFACE_CONTRACT" ] || fail "缺少 Skill runtime surface 合同: contracts/skill-runtime-surface.json"
  [ -x "$SKILL_RUNTIME_SURFACE_TOOL" ] || fail "缺少可执行 Skill runtime surface 工具: tools/skills/apply_skill_runtime_surface.py"
  [ -f "$REPO_ROOT/tools/validate-contracts.sh" ] || fail "缺少校验脚本: tools/validate-contracts.sh"
  [ -f "$REPO_ROOT/tools/community/sync_vercel_skills_from_upstream.py" ] || fail "缺少 Vercel sync 脚本: tools/community/sync_vercel_skills_from_upstream.py"
  [ -f "$REPO_ROOT/tools/community/sync_alchaincyf_skills_from_upstream.py" ] || fail "缺少 Alchaincyf sync 脚本: tools/community/sync_alchaincyf_skills_from_upstream.py"
  [ -f "$REPO_ROOT/tools/community/sync_nextlevelbuilder_skills_from_upstream.py" ] || fail "缺少 NextLevelBuilder sync 脚本: tools/community/sync_nextlevelbuilder_skills_from_upstream.py"
  [ -f "$REPO_ROOT/tools/community/sync_panniantong_skills_from_upstream.py" ] || fail "缺少 Panniantong sync 脚本: tools/community/sync_panniantong_skills_from_upstream.py"
  [ -f "$REPO_ROOT/tools/community/sync_skills_sh_skills_from_upstream.py" ] || fail "缺少 skills.sh sync 脚本: tools/community/sync_skills_sh_skills_from_upstream.py"
  [ -f "$REPO_ROOT/tools/community/sync_persona_skills_from_upstream.py" ] || fail "缺少 Persona sync 脚本: tools/community/sync_persona_skills_from_upstream.py"
  [ -f "$HOOK_REGISTRY" ] || fail "缺少 hook registry: $HOOK_REGISTRY"
  [ -f "$HOOK_RENDERER" ] || fail "缺少 hook renderer: $HOOK_RENDERER"
  [ -f "$CODEX_RUNTIME_MANAGER" ] || fail "缺少 Codex runtime manager: $CODEX_RUNTIME_MANAGER"
  [ -f "$CODEX_HOOK_TRUST_AUDITOR" ] || fail "缺少 Codex hook trust auditor: $CODEX_HOOK_TRUST_AUDITOR"
}

compute_repo_fingerprint() {
  python3 - "$REPO_ROOT" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
targets = ["VERSION", "install.sh", "uninstall.sh", "shared", "claude", "codex", "community", "contracts", "tools", "tests", ".github"]
ignored_dirs = {".git", "__pycache__"}
ignored_files = {".DS_Store"}


def is_runtime_pruned_skill_tree(path):
    rel = os.path.relpath(path, root)
    parts = rel.split(os.sep)
    internal_dirs = {"evals", "fixtures", "examples", "selves"}
    for idx, part in enumerate(parts):
        if part != "skills":
            continue
        if len(parts) > idx + 1 and parts[idx + 1].endswith("-workspace"):
            return True
        # Runtime staging prunes these internal directories from every skill.
        if len(parts) > idx + 2 and any(p in internal_dirs for p in parts[idx + 2 :]):
            return True
    return False


paths = []
for t in targets:
    p = os.path.join(root, t)
    if os.path.isfile(p):
        name = os.path.basename(p)
        if name not in ignored_files and not name.endswith(".pyc"):
            paths.append(p)
    elif os.path.isdir(p):
        for dirpath, dirnames, filenames in os.walk(p):
            dirnames[:] = sorted(
                d
                for d in dirnames
                if d not in ignored_dirs and not is_runtime_pruned_skill_tree(os.path.join(dirpath, d))
            )
            for fn in sorted(filenames):
                if fn in ignored_files or fn.endswith(".pyc"):
                    continue
                path = os.path.join(dirpath, fn)
                if is_runtime_pruned_skill_tree(path):
                    continue
                paths.append(path)

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
    --runtime-home "\$HOME/.claude" \
    --python-launcher "$PYTHON_LAUNCHER" > "$output"
}

claude_settings_baseline_file() {
  printf '%s/claude-settings-baseline.json\n' "$(target_state_dir claude)"
}

claude_settings_missing_marker() {
  printf '%s/claude-settings-baseline.missing\n' "$(target_state_dir claude)"
}

required_claude_hook_commands() {
  cat <<EOF
bash \$HOME/.claude/hooks/block_dangerous.sh
bash \$HOME/.claude/hooks/code_quality_check.sh
bash \$HOME/.claude/hooks/auto_format.sh
bash \$HOME/.claude/hooks/post_compact.sh
bash \$HOME/.claude/hooks/task_verify.sh
$PYTHON_LAUNCHER \$HOME/.claude/hooks/managed/context_contract_validator.py
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

claude_hooks_no_duplicates() {
  local settings="$1"

  [ -f "$settings" ] || return 1

  python3 - "$settings" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for event, entries in (data.get("hooks") or {}).items():
    if not isinstance(entries, list):
        continue
    counts = Counter(json.dumps(item, sort_keys=True, ensure_ascii=False) for item in entries)
    if any(count > 1 for count in counts.values()):
        raise SystemExit(1)
PY
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

def command_target(item):
    hooks_list = item.get("hooks")
    if not isinstance(hooks_list, list) or len(hooks_list) != 1:
        return None
    command = hooks_list[0].get("command") if isinstance(hooks_list[0], dict) else None
    if not isinstance(command, str) or " " not in command:
        return None
    return command.split(" ", 1)[1]

for event, fragment_items in fragment.get("hooks", {}).items():
    existing = hooks.setdefault(event, [])
    managed_targets = {
        (item.get("matcher"), command_target(item))
        for item in fragment_items
        if command_target(item)
    }
    existing = [
        item for item in existing
        if (item.get("matcher"), command_target(item)) not in managed_targets
    ]
    seen = set()
    deduped_existing = []
    for item in existing:
        serialized = json.dumps(item, sort_keys=True, ensure_ascii=False)
        if serialized in seen:
            continue
        deduped_existing.append(item)
        seen.add(serialized)
    hooks[event] = deduped_existing
    existing = deduped_existing
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
    --runtime-home "\$HOME/.claude" \
    --python-launcher "$PYTHON_LAUNCHER"
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
  claude_hooks_no_duplicates "$settings" || fail "Quick Check 失败: ~/.claude/settings.json 存在重复 hooks 注册"

  return 0
}

render_codex_hooks_payload() {
  local output="$1"

  python3 "$HOOK_RENDERER" codex-hooks \
    --registry "$HOOK_REGISTRY" \
    --runtime-home "$CODEX_DIR" \
    --python-launcher "$PYTHON_LAUNCHER" > "$output"
}

required_codex_hook_commands() {
  cat <<EOF
bash $CODEX_DIR/hooks/managed/block_dangerous.sh
$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/context_contract_validator.py
$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/codex_user_prompt_submit.py
$PYTHON_LAUNCHER $CODEX_DIR/hooks/managed/codex_stop_dispatch.py
EOF
}

check_codex_hook_trust() {
  local args=()
  local cmd

  if [ "${ORG_SKIP_CODEX_HOOK_TRUST_AUDIT:-0}" = "1" ]; then
    warn "跳过 Codex hooks trust 审计: ORG_SKIP_CODEX_HOOK_TRUST_AUDIT=1"
    return 0
  fi

  command -v codex >/dev/null 2>&1 || fail "Quick Check 失败: 未找到 codex CLI，无法验证 Codex hooks trust 状态"

  args=(
    "--codex-home" "$CODEX_DIR"
    "--cwd" "$REPO_ROOT"
    "--require-ready"
  )

  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    args+=("--expected-command" "$cmd")
  done < <(required_codex_hook_commands)

  local audit_rc
  set +e
  python3 "$CODEX_HOOK_TRUST_AUDITOR" "${args[@]}"
  audit_rc=$?
  set -e

  case "$audit_rc" in
    0)
      return 0
      ;;
    2)
      warn "Codex hooks 已安装但尚未 trusted/managed；在 Codex 当前仓库执行 /hooks，逐条核对并信任后 hook 才会运行"
      return 0
      ;;
    *)
      fail "Quick Check 失败: Codex hooks trust 审计异常或缺少预期 hook（rc=${audit_rc}）"
      ;;
  esac
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

configure_codex_agents() {
  local config_file="$CODEX_DIR/config.toml"

  python3 "$CODEX_RUNTIME_MANAGER" configure-agents \
    --config "$config_file"
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
  local rendered
  rendered=$(mktemp)
  render_codex_hooks_payload "$rendered"

  python3 "$CODEX_RUNTIME_MANAGER" cleanup-hooks \
    --hooks-file "$hooks_file" \
    --managed-root "$managed_root" \
    --managed-file "$rendered"
  rm -f "$rendered"
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
  find "$staging" -type d -name '__pycache__' -prune -o \
    -type f ! -name '*.pyc' ! -name '.DS_Store' -print \
    | sed "s|^$staging/||" | sort
}

prune_runtime_noise() {
  local root="$1"

  [ -d "$root" ] || return 0
  find "$root" -type f \( -name '*.pyc' -o -name '.DS_Store' \) -exec rm -f {} + 2>/dev/null || true
  find "$root" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
}

copy_tree_contents() {
  local src="$1"
  local dst="$2"

  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  cp -R "$src"/. "$dst"/
  prune_runtime_noise "$dst"
}

copy_runtime_skill_contracts() {
  local staging="$1"
  local resource skill_dir skill_name

  for skill_dir in "$SHARED_SOURCE"/skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    for resource in contracts templates; do
      copy_tree_contents "$skill_dir/$resource" "$staging/shared/skills/$skill_name/$resource"
    done
  done
}

prune_runtime_reference_artifacts() {
  local staging="$1"

  find "$staging/reference" -maxdepth 1 -type f -name '*-review-report.md' -delete 2>/dev/null || true
}

prune_internal_skill_roots() {
  local skills_dir="$1"

  [ -d "$skills_dir" ] || return 0
  find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -name '*-workspace' \
    -prune -exec rm -rf {} + 2>/dev/null || true
  find "$skills_dir" -mindepth 2 -type d \
    \( -name evals -o -name fixtures -o -name examples -o -name selves \) \
    -prune -exec rm -rf {} + 2>/dev/null || true
}

community_superpowers_selected() {
  find "$COMMUNITY_SOURCE/superpowers/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

claude_only_skills() {
  printf '%s\n' \
    "code-review-fix" \
    "doc-review-fix" \
    "review-fix-loop" \
    "codex-doc-review"
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

community_anthropic_adapter_selected() {
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    printf '%s\n' "$skill"
  done < <(community_anthropic_selected)
}

# Selected Vercel community skills are vendored as a third-party source.
community_vercel_selected() {
  printf '%s\n' \
    "find-skills" \
    "agent-browser"
}

community_alchaincyf_selected() {
  printf '%s\n' \
    "darwin-skill"
}

community_nextlevelbuilder_selected() {
  printf '%s\n' \
    "ui-ux-pro-max"
}

community_panniantong_selected() {
  printf '%s\n' \
    "agent-reach"
}

community_skills_sh_selected() {
  printf '%s\n' \
    "architecture" \
    "baoyu-markdown-to-html" \
    "bb-browser" \
    "code-to-prd" \
    "graphify" \
    "mermaid-diagrams" \
    "humanizer-zh" \
    "notebooklm" \
    "planning-with-files" \
    "prd" \
    "to-prd" \
    "self-improving-agent"
}

community_skills_sh_adapter_selected() {
  printf '%s\n' \
    "bb-browser" \
    "humanizer-zh" \
    "notebooklm"
}

community_persona_selected() {
  printf '%s\n' \
    "colleague-skill" \
    "nuwa-skill" \
    "yourself-skill" \
    "midas-skill"
}

community_anthropic_override_skills() {
  printf '%s\n' \
    "mcp-builder"
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

copy_selected_superpowers_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/superpowers/skills/$skill"
    [ -d "$src" ] || fail "缺少 Superpowers skill 源目录: $src"
    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
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

# Copy the vendored Alchaincyf skill trees into the runtime staging area.
copy_selected_alchaincyf_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/alchaincyf/skills/$skill"
    [ -d "$src" ] || fail "缺少 Alchaincyf skill 源目录: $src"

    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
  done < <(community_alchaincyf_selected)
}

# Copy the vendored NextLevelBuilder skill trees into the runtime staging area.
copy_selected_nextlevelbuilder_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/nextlevelbuilder/skills/$skill"
    [ -d "$src" ] || fail "缺少 NextLevelBuilder skill 源目录: $src"

    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
  done < <(community_nextlevelbuilder_selected)
}

# Copy the vendored Panniantong skill trees into the runtime staging area.
copy_selected_panniantong_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/panniantong/skills/$skill"
    [ -d "$src" ] || fail "缺少 Panniantong skill 源目录: $src"

    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
  done < <(community_panniantong_selected)
}

# Copy the vendored skills.sh skill trees into the runtime staging area.
copy_selected_skills_sh_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/skills-sh/skills/$skill"
    [ -d "$src" ] || fail "缺少 skills.sh skill 源目录: $src"

    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
  done < <(community_skills_sh_selected)
}

# Copy the vendored persona/distillation skill trees into the runtime staging area.
copy_selected_persona_skills() {
  local dst="$1"
  local skill src

  mkdir -p "$dst"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    src="$COMMUNITY_SOURCE/persona/skills/$skill"
    [ -d "$src" ] || fail "缺少 Persona skill 源目录: $src"

    rm -rf "${dst:?}/$skill"
    cp -R "$src" "$dst/$skill"
  done < <(community_persona_selected)
}

overlay_codex_anthropic_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/anthropic/codex/skills"
  local skill skills

  [ -d "$adapter_root" ] || return 0

  skills="$(community_anthropic_adapter_selected)"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || fail "缺少 Anthropic Codex adapter: $adapter_root/$skill"
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done <<< "$skills"
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

# Overlay generated Codex auto-skill metadata for vendored Alchaincyf skills.
overlay_codex_alchaincyf_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/alchaincyf/codex/skills"
  local skill

  [ -d "$adapter_root" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || fail "缺少 Alchaincyf Codex adapter: $adapter_root/$skill"
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done < <(community_alchaincyf_selected)
}

# Overlay generated Codex auto-skill metadata for vendored NextLevelBuilder skills.
overlay_codex_nextlevelbuilder_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/nextlevelbuilder/codex/skills"
  local skill

  [ -d "$adapter_root" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || fail "缺少 NextLevelBuilder Codex adapter: $adapter_root/$skill"
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done < <(community_nextlevelbuilder_selected)
}

# Overlay generated Codex auto-skill metadata for vendored Panniantong skills.
overlay_codex_panniantong_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/panniantong/codex/skills"
  local skill

  [ -d "$adapter_root" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || fail "缺少 Panniantong Codex adapter: $adapter_root/$skill"
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done < <(community_panniantong_selected)
}

# Overlay generated Codex auto-skill metadata for vendored skills.sh skills.
overlay_codex_skills_sh_skill_adapters() {
  local skills_dir="$1"
  local adapter_root="$COMMUNITY_SOURCE/skills-sh/codex/skills"
  local skill

  [ -d "$adapter_root" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -d "$adapter_root/$skill" ] || fail "缺少 skills.sh Codex adapter: $adapter_root/$skill"
    mkdir -p "$skills_dir/$skill"
    copy_tree_contents "$adapter_root/$skill" "$skills_dir/$skill"
  done < <(community_skills_sh_adapter_selected)
}

render_runtime_placeholders() {
  local tree="$1"
  local runtime_home="$2"
  local entry_doc="$3"
  local skills_home="${4:-$runtime_home/skills}"
  local file

  while IFS= read -r -d '' file; do
    ORG_RENDER_RUNTIME_HOME="$runtime_home" ORG_RENDER_ENTRY_DOC="$entry_doc" ORG_RENDER_SKILLS_HOME="$skills_home" perl -0pi -e '
      s/\{\{RUNTIME_HOME\}\}/$ENV{ORG_RENDER_RUNTIME_HOME}/g;
      s/\{\{ENTRY_DOC\}\}/$ENV{ORG_RENDER_ENTRY_DOC}/g;
      s/\{\{SKILLS_HOME\}\}/$ENV{ORG_RENDER_SKILLS_HOME}/g;
    ' "$file"
  done < <(find "$tree" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' -o -name '*.toml' -o -name '*.yaml' \) -print0)
}

rewrite_codex_skill_script_runtime_paths() {
  local skills_dir="$1"
  local file

  [ -d "$skills_dir" ] || return 0
  while IFS= read -r -d '' file; do
    perl -0pi -e '
      s#HOOKS_LIB="\$\(cd "\$\(dirname "\$0"\)/\.\./\.\./\.\./hooks/lib" && pwd\)"#q{HOOKS_LIB="$HOME/.codex/hooks/lib"}#ge;
      s#HOOKS_LIB="\$\(cd "\$SCRIPT_DIR/\.\./\.\./\.\./hooks/lib" && pwd\)"#q{HOOKS_LIB="$HOME/.codex/hooks/lib"}#ge;
      s#HOOKS_LIB="\$SCRIPT_DIR/\.\./\.\./\.\./hooks/lib"#q{HOOKS_LIB="$HOME/.codex/hooks/lib"}#ge;
      s#source "\$\(cd "\$\(dirname "\$0"\)/\.\./\.\./\.\./hooks/lib" && pwd\)/common\.sh"#q{source "$HOME/.codex/hooks/lib/common.sh"}#ge;
    ' "$file"
  done < <(find "$skills_dir" -path '*/scripts/*.sh' -type f -print0)
}

rewrite_codex_skill_docs() {
  local skills_dir="$1"

  python3 - "$skills_dir" <<'PY'
import os
import sys

skills_dir = sys.argv[1]

for entry in sorted(os.listdir(skills_dir)):
    skill_dir = os.path.join(skills_dir, entry)
    skill_file = os.path.join(skill_dir, "SKILL.md")

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

    updated = f"---\n{new_frontmatter}\n---\n\n{new_body}"

    if removed_hooks or updated != text:
        with open(skill_file, "w", encoding="utf-8") as f:
            f.write(updated)
PY
}

apply_skill_runtime_surface() {
  local skills_dir="$1"
  local runtime="$2"

  python3 "$SKILL_RUNTIME_SURFACE_TOOL" \
    --contract "$SKILL_RUNTIME_SURFACE_CONTRACT" \
    --skills-dir "$skills_dir" \
    --runtime "$runtime"
}

build_staging_claude() {
  local staging="$1"
  mkdir -p "$staging"/{skills,rules,reference,protocols,hooks,agents,commands,tools,contracts,shared}

  cp "$SHARED_SOURCE/assistant.md" "$staging/CLAUDE.md"
  copy_tree_contents "$SHARED_SOURCE/skills" "$staging/skills"
  copy_selected_superpowers_skills "$staging/skills"
  copy_selected_anthropic_skills "$staging/skills"
  copy_selected_vercel_skills "$staging/skills"
  copy_selected_alchaincyf_skills "$staging/skills"
  copy_selected_nextlevelbuilder_skills "$staging/skills"
  copy_selected_panniantong_skills "$staging/skills"
  copy_selected_skills_sh_skills "$staging/skills"
  copy_selected_persona_skills "$staging/skills"
  if [ -d "$CLAUDE_SOURCE/skills" ]; then
    copy_tree_contents "$CLAUDE_SOURCE/skills" "$staging/skills"
  fi
  prune_internal_skill_roots "$staging/skills"
  copy_tree_contents "$SHARED_SOURCE/rules" "$staging/rules"
  copy_tree_contents "$SHARED_SOURCE/reference" "$staging/reference"
  prune_runtime_reference_artifacts "$staging"
  copy_tree_contents "$SHARED_SOURCE/protocols" "$staging/protocols"
  copy_tree_contents "$SHARED_SOURCE/agents/claude" "$staging/agents"
  if [ -d "$CLAUDE_SOURCE/agents" ]; then
    copy_tree_contents "$CLAUDE_SOURCE/agents" "$staging/agents"
  fi
  copy_tree_contents "$SHARED_SOURCE/hooks" "$staging/hooks"
  copy_tree_contents "$CLAUDE_SOURCE/hooks" "$staging/hooks"
  copy_tree_contents "$REPO_ROOT/tools/community" "$staging/tools/community"
  cp "$REPO_ROOT/contracts/product-artifacts.yaml" "$staging/contracts/product-artifacts.yaml"
  copy_tree_contents "$REPO_ROOT/contracts/canonical" "$staging/contracts/canonical"
  copy_tree_contents "$SHARED_SOURCE/runtime" "$staging/shared/runtime"
  copy_runtime_skill_contracts "$staging"
  rm -rf \
    "$staging/skills/review-fix-loop" \
    "$staging/skills/codex-doc-review"
  rm -f "$staging/agents/codex-doc-reviewer.md"
  find "$staging/skills" -mindepth 2 -maxdepth 2 -type d -name agents -exec rm -rf {} +
  apply_skill_runtime_surface "$staging/skills" claude
  inject_claude_skill_hooks_from_registry "$staging/skills"
  render_runtime_placeholders "$staging" "\$HOME/.claude" "CLAUDE.md" "\$HOME/.claude/skills"
}

build_staging_codex() {
  local staging="$1"
  mkdir -p "$staging"/{skills,rules,reference,protocols,agents,hooks,tools,contracts,shared}

  cp "$SHARED_SOURCE/assistant.md" "$staging/AGENTS.md"
  copy_tree_contents "$SHARED_SOURCE/skills" "$staging/skills"
  copy_selected_superpowers_skills "$staging/skills"
  copy_selected_anthropic_skills "$staging/skills"
  copy_selected_vercel_skills "$staging/skills"
  copy_selected_alchaincyf_skills "$staging/skills"
  copy_selected_nextlevelbuilder_skills "$staging/skills"
  copy_selected_panniantong_skills "$staging/skills"
  copy_selected_skills_sh_skills "$staging/skills"
  copy_selected_persona_skills "$staging/skills"
  prune_internal_skill_roots "$staging/skills"
  overlay_codex_anthropic_skill_adapters "$staging/skills"
  overlay_codex_vercel_skill_adapters "$staging/skills"
  overlay_codex_alchaincyf_skill_adapters "$staging/skills"
  overlay_codex_nextlevelbuilder_skill_adapters "$staging/skills"
  overlay_codex_panniantong_skill_adapters "$staging/skills"
  overlay_codex_skills_sh_skill_adapters "$staging/skills"
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    rm -rf "$staging/skills/$skill"
  done < <(claude_only_skills)
  apply_skill_runtime_surface "$staging/skills" codex
  copy_tree_contents "$SHARED_SOURCE/rules" "$staging/rules"
  copy_tree_contents "$SHARED_SOURCE/reference" "$staging/reference"
  prune_runtime_reference_artifacts "$staging"
  copy_tree_contents "$SHARED_SOURCE/protocols" "$staging/protocols"
  local f
  for f in "$SHARED_SOURCE"/agents/codex/*.toml; do
    [ -f "$f" ] || continue
    sed "s|{{HOME}}|$HOME|g" "$f" > "$staging/agents/$(basename "$f")"
  done
  copy_tree_contents "$SHARED_SOURCE/hooks" "$staging/hooks"
  copy_tree_contents "$REPO_ROOT/tools/community" "$staging/tools/community"
  cp "$REPO_ROOT/contracts/product-artifacts.yaml" "$staging/contracts/product-artifacts.yaml"
  copy_tree_contents "$REPO_ROOT/contracts/canonical" "$staging/contracts/canonical"
  copy_tree_contents "$SHARED_SOURCE/runtime" "$staging/shared/runtime"
  copy_runtime_skill_contracts "$staging"
  render_runtime_placeholders "$staging" "\$HOME/.codex" "AGENTS.md" "\$HOME/.agents/skills"
  rewrite_codex_skill_script_runtime_paths "$staging/skills"
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

build_allowed_runtime_rule_names() {
  local name="$1"

  find "$SHARED_SOURCE/rules" -maxdepth 1 -type f -name '*.md' -exec basename {} \; 2>/dev/null | sort
  if [ "$name" = "codex" ]; then
    printf '%s\n' "default.rules"
  fi
}

retired_runtime_rule_names() {
  cat <<'EOF'
代码规范.md
完成前验证.md
交付验收底线.md
执行纪律.md
文档管理.md
旧质量指南.md
铁律.md
EOF
}

retired_runtime_reference_names() {
  cat <<'EOF'
代码复用.md
完成前验证.md
性能效率.md
硬编码治理规范.md
EOF
}

path_exists_or_symlink() {
  [ -e "$1" ] || [ -L "$1" ]
}

retired_runtime_skills() {
  local skill_auditor_retired="skill-auditor" # should not install
  local skill_refiner_retired="skill-refiner" # replaced by skill-quality-audit

  printf '%s\n' \
    "$skill_auditor_retired" \
    "$skill_refiner_retired" \
    "ai-cli-updater" \
    "new-skills" \
    "project-agents-init" \
    "product" \
    "product-shared"
}

RUNTIME_AUDIT_DIRTY=0
CLAUDE_ALLOW_LOCAL_RUNTIME_EDITS=0
CODEX_ALLOW_LOCAL_RUNTIME_EDITS=0

runtime_skills_dir_for_target() {
  local name="$1"
  local target_dir="$2"

  if [ "$name" = "codex" ]; then
    printf '%s\n' "$CODEX_USER_SKILLS_DIR"
  else
    printf '%s/skills\n' "$target_dir"
  fi
}

external_runtime_skill_list_file() {
  local name="$1"

  printf '%s/external-runtime-skills/%s.txt\n' "$ORG_STATE_ROOT" "$name"
}

external_runtime_skill_names() {
  local name="$1"
  local list_file
  list_file="$(external_runtime_skill_list_file "$name")"

  [ -f "$list_file" ] || return 0
  awk '
    {
      sub(/[[:space:]]*#.*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 != "") print
    }
  ' "$list_file"
}

is_external_runtime_skill() {
  local name="$1"
  local skill="$2"

  [ -n "$skill" ] || return 1
  external_runtime_skill_names "$name" | grep -Fxq "$skill"
}

runtime_skill_name_for_path() {
  local name="$1"
  local target_dir="$2"
  local path="$3"
  local skills_dir rel

  skills_dir="$(runtime_skills_dir_for_target "$name" "$target_dir")"
  case "$path" in
    "$skills_dir"/*)
      rel="${path#"$skills_dir"/}"
      [ -n "$rel" ] || return 1
      printf '%s\n' "${rel%%/*}"
      return 0
      ;;
  esac

  return 1
}

cleanup_legacy_codex_system_skill_creator() {
  local codex_home="$1"

  rm -rf "$codex_home/skills/.system/skill-creator"
}

external_runtime_skill_path() {
  local name="$1"
  local target_dir="$2"
  local path="$3"
  local skill

  skill="$(runtime_skill_name_for_path "$name" "$target_dir" "$path" || true)"
  is_external_runtime_skill "$name" "$skill"
}

claude_agent_files_match_contract() {
  local target_dir="$1"
  local agents_dir="$target_dir/agents"
  local agent file expected_skill expected_instruction
  local duplicated_skill_detail_pattern='先读并严格遵循|硬约束|完整方法论|可用工具|Write 仅用于|禁止使用 Edit|禁止 Edit|developer-report\.json|verify-result\.json|qa-result\.json|code-review-result\.json|consistency-audit-result\.json|\{\{HOME\}\}/\.codex/rules|\{\{HOME\}\}/\.agents/skills|/\.codex/rules|/\.agents/skills'

  [ -d "$agents_dir" ] || return 1
  [ "$(find "$agents_dir" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')" = "5" ] || return 1

  for agent in consistency-auditor developer fixer qa verifier; do
    file="$agents_dir/$agent.md"
    [ -f "$file" ] || return 1
    grep -Fq 'tools:' "$file" || return 1
    grep -Fq 'skills:' "$file" || return 1
    ! grep -Eq '^model:|^maxTurns:|^memory:' "$file" || return 1
    ! grep -Eq "$duplicated_skill_detail_pattern" "$file" || return 1

    case "$agent" in
      consistency-auditor)
        expected_skill='consistency-audit'
        expected_instruction='加载 consistency-audit skill 结合目标和成功标准交付结果。'
        ;;
      developer)
        expected_skill='developer'
        expected_instruction='加载 developer skill 结合目标和成功标准交付结果。'
        ;;
      fixer)
        expected_skill='fix'
        expected_instruction='加载 fix skill 结合目标和成功标准交付结果。'
        ;;
      qa)
        expected_skill='qa'
        expected_instruction='加载 qa skill 结合目标和成功标准交付结果。'
        ;;
      verifier)
        expected_skill='verify'
        expected_instruction='加载 verify skill 结合目标和成功标准交付结果。'
        ;;
      *)
        return 1
        ;;
    esac

    grep -Fq "  - $expected_skill" "$file" || return 1
    grep -Fq "$expected_instruction" "$file" || return 1
  done

  for retired in code-reviewer designer tech-lead test-designer generic-code-reviewer codex-doc-reviewer; do
    [ ! -e "$agents_dir/$retired.md" ] || return 1
  done
}

codex_agent_config_inherits_defaults() {
  local config_file="$1"

  PYTHONPATH="$REPO_ROOT/tools/community" python3 - "$config_file" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

from codex_runtime_agents import MANAGED_AGENT_ROLES, MANAGED_AGENT_ROLE_NAMES, RETIRED_AGENT_ROLE_NAMES, agent_section_role
from codex_runtime_toml import key_line_index, matching_section_bounds, read_toml_lines, section_bounds, strip_toml_comment

config_path = Path(sys.argv[1])
lines = read_toml_lines(config_path)

def line_section(line: str) -> str:
    return line.strip()[1:-1].strip()


def direct_string_value(line: str, key: str) -> str | None:
    body = strip_toml_comment(line).strip()
    if "=" not in body:
        return None
    current_key, raw_value = body.split("=", 1)
    if current_key.strip() != key:
        return None
    value = raw_value.strip()
    if len(value) >= 2 and value[0] == value[-1] == '"':
        content = value[1:-1]
        if "\\" not in content:
            return content
        try:
            return bytes(content, "utf-8").decode("unicode_escape")
        except UnicodeDecodeError:
            return None
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1]
    return None


retired_sections = [
    section
    for start, _end in matching_section_bounds(lines, lambda section: agent_section_role(section) in RETIRED_AGENT_ROLE_NAMES)
    for section in [line_section(lines[start])]
]
if retired_sections:
    raise SystemExit(f"retired agent sections remain: {', '.join(retired_sections)}")

for role, _description, config_file in MANAGED_AGENT_ROLES:
    start, end = section_bounds(lines, f"agents.{role}")
    if start is None or end is None:
        raise SystemExit(f"missing managed agent section: agents.{role}")
    idx = key_line_index(lines, start, end, "config_file")
    if idx is None or direct_string_value(lines[idx], "config_file") != config_file:
        raise SystemExit(f"managed agent config_file drift: agents.{role}")

for start, end in matching_section_bounds(lines, lambda section: agent_section_role(section) in MANAGED_AGENT_ROLE_NAMES):
    role = agent_section_role(line_section(lines[start]))
    for key in ("model", "model_reasoning_effort"):
        if key_line_index(lines, start, end, key) is not None:
            raise SystemExit(f"managed agent must inherit default {key}: agents.{role}")
PY
}

codex_agent_files_match_contract() {
  local target_dir="$1"
  local agents_dir="$target_dir/agents"
  local agent file
  local duplicated_skill_detail_pattern='先读并严格遵循|硬约束|完整方法论|可用工具|Write 仅用于|禁止使用 Edit|禁止 Edit|developer-report\.json|verify-result\.json|qa-result\.json|code-review-result\.json|consistency-audit-result\.json|\{\{HOME\}\}/\.codex/rules|\{\{HOME\}\}/\.agents/skills|/\.codex/rules|/\.agents/skills'

  [ -d "$agents_dir" ] || return 1
  for agent in code-reviewer consistency-auditor developer fixer qa verifier; do
    [ -f "$agents_dir/$agent.toml" ] || return 1
  done

  ! grep -REq '^(model|model_reasoning_effort)[[:space:]]*=' "$agents_dir"/*.toml || return 1
  if find "$agents_dir" -maxdepth 1 -type f -name '*.md' | grep -q .; then
    return 1
  fi

  for agent in code-reviewer consistency-auditor developer fixer qa verifier; do
    file="$agents_dir/$agent.toml"
    grep -Fq 'sandbox_mode = "workspace-write"' "$file" || return 1
  done

  ! grep -REq "$duplicated_skill_detail_pattern" "$agents_dir"/*.toml || return 1
  grep -Fq "加载 \`review\` skill，结合目标和成功标准交付结果。" "$agents_dir/code-reviewer.toml" || return 1
  grep -Fq "加载 \`consistency-audit\` skill，结合目标和成功标准交付结果。" "$agents_dir/consistency-auditor.toml" || return 1
  grep -Fq "加载 \`developer\` skill，结合目标和成功标准交付结果。" "$agents_dir/developer.toml" || return 1
  grep -Fq "加载 \`fix\` skill，结合目标和成功标准交付结果。" "$agents_dir/fixer.toml" || return 1
  grep -Fq "加载 \`qa\` skill，结合目标和成功标准交付结果。" "$agents_dir/qa.toml" || return 1
  grep -Fq "加载 \`verify\` skill，结合目标和成功标准交付结果。" "$agents_dir/verifier.toml" || return 1
}

audit_runtime_rules() {
  local name="$1"
  local target_dir="$2"
  local state_dir="$3"
  local apply_cleanup="${4:-0}"
  local backup_root="${5:-}"
  local backup_tmp="${6:-}"
  local allowed_names retired_names rule_name path archive_root=""

  RUNTIME_AUDIT_DIRTY=0
  [ -d "$target_dir/rules" ] || return 0

  allowed_names="$(build_allowed_runtime_rule_names "$name")"
  retired_names="$(retired_runtime_rule_names)"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rule_name="$(basename "$path")"

    if printf '%s\n' "$allowed_names" | grep -Fxq "$rule_name"; then
      if [ "$rule_name" != "default.rules" ] && [ -L "$path" ]; then
        RUNTIME_AUDIT_DIRTY=1
        if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
          log "[dry-run] $name 将重建受管规则软链接为真实文件: $path"
        else
          if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
            backup_existing_path "$name" "$target_dir" "$path" "$backup_root" "$backup_tmp"
          fi
          rm -f "$path"
          log "$name 已移除受管规则软链接，后续将重建为真实文件: $path"
        fi
      fi
      continue
    fi

    if printf '%s\n' "$retired_names" | grep -Fxq "$rule_name"; then
      RUNTIME_AUDIT_DIRTY=1
      if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
        log "[dry-run] $name 将归档并清理退休规则残留: $path"
        continue
      fi

      [ -n "$archive_root" ] || archive_root="$state_dir/unexpected-artifacts/$(date +%Y%m%d%H%M%S)-$$"
      mkdir -p "$archive_root/rules"
      cp -a "$path" "$archive_root/rules/$rule_name"
      if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
        backup_existing_path "$name" "$target_dir" "$path" "$backup_root" "$backup_tmp"
      fi
      rm -f "$path"
      log "$name 已归档并清理退休规则残留: $path -> $archive_root/rules/$rule_name"
    fi
  done < <(find "$target_dir/rules" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | sort)
}

audit_runtime_references() {
  local name="$1"
  local target_dir="$2"
  local state_dir="$3"
  local apply_cleanup="${4:-0}"
  local backup_root="${5:-}"
  local backup_tmp="${6:-}"
  local allowed_names retired_names reference_name path archive_root=""

  [ -d "$target_dir/reference" ] || return 0

  allowed_names="$(find "$SHARED_SOURCE/reference" -maxdepth 1 -type f -name '*.md' -exec basename {} \; 2>/dev/null | sort)"
  retired_names="$(retired_runtime_reference_names)"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    reference_name="$(basename "$path")"

    if printf '%s\n' "$allowed_names" | grep -Fxq "$reference_name"; then
      if [ -L "$path" ]; then
        RUNTIME_AUDIT_DIRTY=1
        if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
          log "[dry-run] $name 将重建受管 reference 软链接为真实文件: $path"
        else
          if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
            backup_existing_path "$name" "$target_dir" "$path" "$backup_root" "$backup_tmp"
          fi
          rm -f "$path"
          log "$name 已移除受管 reference 软链接，后续将重建为真实文件: $path"
        fi
      fi
      continue
    fi

    if printf '%s\n' "$retired_names" | grep -Fxq "$reference_name"; then
      RUNTIME_AUDIT_DIRTY=1
      if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
        log "[dry-run] $name 将归档并清理退休 reference 残留: $path"
        continue
      fi

      [ -n "$archive_root" ] || archive_root="$state_dir/unexpected-artifacts/$(date +%Y%m%d%H%M%S)-$$"
      mkdir -p "$archive_root/reference"
      cp -a "$path" "$archive_root/reference/$reference_name"
      if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
        backup_existing_path "$name" "$target_dir" "$path" "$backup_root" "$backup_tmp"
      fi
      rm -f "$path"
      log "$name 已归档并清理退休 reference 残留: $path -> $archive_root/reference/$reference_name"
    fi
  done < <(find "$target_dir/reference" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | sort)
}

is_retired_runtime_path() {
  local name="$1"
  local target_dir="$2"
  local path="$3"
  local item_name

  case "$path" in
    "$target_dir/rules/"*)
      item_name="$(basename "$path")"
      retired_runtime_rule_names | grep -Fxq "$item_name"
      return $?
      ;;
    "$target_dir/reference/"*)
      item_name="$(basename "$path")"
      retired_runtime_reference_names | grep -Fxq "$item_name"
      return $?
      ;;
  esac

  return 1
}

is_runtime_audit_cleanup_path() {
  local name="$1"
  local target_dir="$2"
  local path="$3"
  local skills_dir legacy_skills_dir rel skill

  if is_retired_runtime_path "$name" "$target_dir" "$path"; then
    return 0
  fi

  skills_dir="$(runtime_skills_dir_for_target "$name" "$target_dir")"
  case "$path" in
    "$skills_dir"/*)
      rel="${path#"$skills_dir"/}"
      [ -n "$rel" ] || return 1
      skill="${rel%%/*}"
      if retired_runtime_skills | grep -Fxq "$skill"; then
        return 0
      fi
      case "$skill" in
        zz-runtime-probe*) return 0 ;;
      esac
      case "$rel" in
        *-workspace|*-workspace/*|*/evals|*/evals/*|*/fixtures|*/fixtures/*|*/examples|*/examples/*|*/selves|*/selves/*)
          return 0
          ;;
      esac
      ;;
  esac

  if [ "$name" = "codex" ]; then
    legacy_skills_dir="$target_dir/skills"
    case "$path" in
      "$legacy_skills_dir"/*) return 0 ;;
    esac
  fi

  return 1
}

audit_retired_runtime_skills() {
  local name="$1"
  local target_dir="$2"
  local state_dir="$3"
  local apply_cleanup="${4:-0}"
  local backup_root="${5:-}"
  local backup_tmp="${6:-}"
  local skills_dir skill skill_path archive_root=""

  skills_dir="$(runtime_skills_dir_for_target "$name" "$target_dir")"
  [ -d "$skills_dir" ] || return 0

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    skill_path="$skills_dir/$skill"
    [ -e "$skill_path" ] || [ -L "$skill_path" ] || continue

    RUNTIME_AUDIT_DIRTY=1
    if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
      log "[dry-run] $name 将归档并清理退役 skill 残留: $skill_path"
      continue
    fi

    [ -n "$archive_root" ] || archive_root="$state_dir/unexpected-artifacts/$(date +%Y%m%d%H%M%S)-$$"
    mkdir -p "$archive_root/skills"
    cp -a "$skill_path" "$archive_root/skills/$skill"
    if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
      backup_existing_path "$name" "$target_dir" "$skill_path" "$backup_root" "$backup_tmp"
    fi
    rm -rf "$skill_path"
    remove_if_empty "$(dirname "$skill_path")" "$skills_dir"
    log "$name 已归档并清理退役 skill 残留: $skill_path -> $archive_root/skills/$skill"
  done < <(retired_runtime_skills)
}

audit_runtime_probe_skills() {
  local name="$1"
  local target_dir="$2"
  local state_dir="$3"
  local apply_cleanup="${4:-0}"
  local backup_root="${5:-}"
  local backup_tmp="${6:-}"
  local skills_dir skill_path skill archive_root=""

  skills_dir="$(runtime_skills_dir_for_target "$name" "$target_dir")"
  [ -d "$skills_dir" ] || return 0

  while IFS= read -r skill_path; do
    [ -n "$skill_path" ] || continue
    [ -e "$skill_path" ] || [ -L "$skill_path" ] || continue
    skill="$(basename "$skill_path")"

    RUNTIME_AUDIT_DIRTY=1
    if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
      log "[dry-run] $name 将归档并清理 runtime 探针 skill 残留: $skill_path"
      continue
    fi

    [ -n "$archive_root" ] || archive_root="$state_dir/unexpected-artifacts/$(date +%Y%m%d%H%M%S)-$$"
    mkdir -p "$archive_root/skills"
    cp -a "$skill_path" "$archive_root/skills/$skill"
    if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
      backup_existing_path "$name" "$target_dir" "$skill_path" "$backup_root" "$backup_tmp"
    fi
    rm -rf "$skill_path"
    remove_if_empty "$(dirname "$skill_path")" "$skills_dir"
    log "$name 已归档并清理 runtime 探针 skill 残留: $skill_path -> $archive_root/skills/$skill"
  done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -name 'zz-runtime-probe*' 2>/dev/null | sort)
}

audit_runtime_internal_skill_roots() {
  local name="$1"
  local target_dir="$2"
  local state_dir="$3"
  local apply_cleanup="${4:-0}"
  local backup_root="${5:-}"
  local backup_tmp="${6:-}"
  local skills_dir internal_path rel archive_root=""

  skills_dir="$(runtime_skills_dir_for_target "$name" "$target_dir")"
  [ -d "$skills_dir" ] || return 0

  while IFS= read -r internal_path; do
    [ -n "$internal_path" ] || continue
    [ -e "$internal_path" ] || [ -L "$internal_path" ] || continue

    RUNTIME_AUDIT_DIRTY=1
    if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
      log "[dry-run] $name 将归档并清理 runtime skill 内部目录残留: $internal_path"
      continue
    fi

    rel="${internal_path#"$skills_dir"/}"
    [ -n "$archive_root" ] || archive_root="$state_dir/unexpected-artifacts/$(date +%Y%m%d%H%M%S)-$$"
    mkdir -p "$(dirname "$archive_root/skills/$rel")"
    cp -a "$internal_path" "$archive_root/skills/$rel"
    if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
      backup_existing_path "$name" "$target_dir" "$internal_path" "$backup_root" "$backup_tmp"
    fi
    rm -rf "$internal_path"
    remove_if_empty "$(dirname "$internal_path")" "$skills_dir"
    log "$name 已归档并清理 runtime skill 内部目录残留: $internal_path -> $archive_root/skills/$rel"
  done < <(
    {
      find "$skills_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -name '*-workspace' -print 2>/dev/null || true
      find "$skills_dir" -mindepth 2 \( -type d -o -type l \) \
        \( -name evals -o -name fixtures -o -name examples -o -name selves \) \
        -prune -print 2>/dev/null || true
    } | sort
  )
}

audit_codex_legacy_skill_root() {
  local target_dir="$1"
  local staging_skills_dir="$2"
  local state_dir="$3"
  local apply_cleanup="${4:-0}"
  local backup_root="${5:-}"
  local backup_tmp="${6:-}"
  local legacy_dir="$target_dir/skills"
  local skill_path skill staged_skill archive_root=""

  [ -d "$legacy_dir" ] || return 0

  while IFS= read -r skill_path; do
    [ -n "$skill_path" ] || continue
    [ -e "$skill_path" ] || [ -L "$skill_path" ] || continue
    skill="$(basename "$skill_path")"
    staged_skill="$staging_skills_dir/$skill"

    if [ -e "$staged_skill" ] || [ -L "$staged_skill" ]; then
      if [ "$FORCE" -eq 0 ] && ! diff -qr "$skill_path" "$staged_skill" >/dev/null 2>&1; then
        fail "codex 检测到旧路径 ~/.codex/skills/$skill 与官方 ~/.agents/skills/$skill 目标内容不同；请人工确认后使用 --force 归档旧路径"
      fi
    else
      case "$skill" in
        zz-runtime-probe*) ;;
        *)
          if ! retired_runtime_skills | grep -Fxq "$skill"; then
            if [ "$FORCE" -eq 0 ]; then
              fail "codex 检测到旧路径 ~/.codex/skills/${skill}；请人工确认后使用 --force 归档，避免 Codex skill 双路径残留"
            fi
          fi
          ;;
      esac
    fi

    RUNTIME_AUDIT_DIRTY=1
    if [ "$DRY_RUN" -eq 1 ] || [ "$apply_cleanup" -eq 0 ]; then
      log "[dry-run] codex 将归档并清理旧 skill 路径残留: $skill_path"
      continue
    fi

    [ -n "$archive_root" ] || archive_root="$state_dir/unexpected-artifacts/$(date +%Y%m%d%H%M%S)-$$"
    mkdir -p "$archive_root/skills"
    cp -a "$skill_path" "$archive_root/skills/$skill"
    if [ -n "$backup_root" ] && [ -n "$backup_tmp" ]; then
      backup_existing_path "codex" "$target_dir" "$skill_path" "$backup_root" "$backup_tmp"
    fi
    rm -rf "$skill_path"
    remove_if_empty "$(dirname "$skill_path")" "$legacy_dir"
    log "codex 已归档并清理旧 skill 路径残留: $skill_path -> $archive_root/skills/$skill"
  done < <(find "$legacy_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) ! -name '.*' 2>/dev/null | sort)
}

codex_legacy_skill_root_clean() {
  local legacy_dir="$CODEX_DIR/skills"

  [ ! -d "$legacy_dir" ] || [ -z "$(find "$legacy_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) ! -name '.*' -print -quit 2>/dev/null || true)" ]
}

runtime_probe_skills_absent() {
  local skills_dir="$1"

  [ ! -d "$skills_dir" ] || [ -z "$(find "$skills_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -name 'zz-runtime-probe*' -print -quit 2>/dev/null || true)" ]
}

runtime_internal_skill_roots_absent() {
  local skills_dir="$1"

  [ ! -d "$skills_dir" ] || [ -z "$(
    {
      find "$skills_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -name '*-workspace' -print -quit 2>/dev/null || true
      find "$skills_dir" -mindepth 2 \( -type d -o -type l \) \
        \( -name evals -o -name fixtures -o -name examples -o -name selves \) \
        -print -quit 2>/dev/null || true
    } | head -1
  )" ]
}

runtime_noise_absent() {
  local target_dir="$1"
  local rel path

  for rel in skills hooks agents rules reference protocols shared contracts tools CLAUDE.md AGENTS.md; do
    path="$target_dir/$rel"
    [ -e "$path" ] || [ -L "$path" ] || continue
    if [ -n "$(find "$path" \( -type d -name '__pycache__' -o -type f -name '*.pyc' -o -type f -name '.DS_Store' \) -print -quit 2>/dev/null || true)" ]; then
      return 1
    fi
  done
  return 0
}

is_in_manifest() {
  local manifest_file="$1"
  local path="$2"

  [ -f "$manifest_file" ] || return 1
  grep -Fxq "$path" "$manifest_file"
}

codex_skill_rel() {
  local name="$1"
  local rel="$2"

  [ "$name" = "codex" ] && case "$rel" in skills/*) return 0 ;; esac
  return 1
}

dst_for_stage_rel() {
  local name="$1"
  local target_dir="$2"
  local rel="$3"

  if codex_skill_rel "$name" "$rel"; then
    printf '%s/%s\n' "$CODEX_USER_SKILLS_DIR" "${rel#skills/}"
  else
    printf '%s/%s\n' "$target_dir" "$rel"
  fi
}

runtime_path_belongs_to_target() {
  local name="$1"
  local target_dir="$2"
  local path="$3"

  case "$path" in
    "$target_dir"/*) return 0 ;;
  esac

  if [ "$name" = "codex" ]; then
    case "$path" in
      "$CODEX_USER_SKILLS_DIR"/*) return 0 ;;
    esac
  fi

  return 1
}

runtime_root_for_path() {
  local name="$1"
  local target_dir="$2"
  local path="$3"

  if [ "$name" = "codex" ]; then
    case "$path" in
      "$CODEX_USER_SKILLS_DIR"/*)
        printf '%s\n' "$CODEX_USER_SKILLS_DIR"
        return 0
        ;;
    esac
  fi

  printf '%s\n' "$target_dir"
}

backup_rel_for_path() {
  local name="$1"
  local target_dir="$2"
  local path="$3"

  if [ "$name" = "codex" ]; then
    case "$path" in
      "$CODEX_USER_SKILLS_DIR"/*)
        printf 'skills/%s\n' "${path#"$CODEX_USER_SKILLS_DIR"/}"
        return 0
        ;;
      "$target_dir/skills/"*)
        printf 'codex-legacy-skills/%s\n' "${path#"$target_dir/skills"/}"
        return 0
        ;;
    esac
  fi

  printf '%s\n' "${path#"$target_dir"/}"
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
  if [ -n "$backup" ] && path_exists_or_symlink "$backup"; then
    printf '%s\t%s\n' "$path" "$backup" >> "$backup_tmp"
    return 0
  fi

  return 1
}

check_conflicts() {
  local name="$1"
  local target_dir="$2"
  local staging="$3"
  local prev_manifest="$4"
  local conflicts_file="$5"

  : > "$conflicts_file"

  local rel dst
  while IFS= read -r rel; do
    dst="$(dst_for_stage_rel "$name" "$target_dir" "$rel")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if is_in_manifest "$prev_manifest" "$dst"; then
        continue
      fi
      printf '%s\n' "$dst" >> "$conflicts_file"
    fi
  done < <(collect_stage_files "$staging")
}

backup_existing_path() {
  local name="$1"
  local target_dir="$2"
  local dst="$3"
  local backup_root="$4"
  local backup_tmp="$5"

  local rel backup_path
  rel="$(backup_rel_for_path "$name" "$target_dir" "$dst")"
  backup_path="$backup_root/$rel"
  mkdir -p "$(dirname "$backup_path")"
  cp -a "$dst" "$backup_path"
  printf '%s\t%s\n' "$dst" "$backup_path" >> "$backup_tmp"
}

normalize_parent_symlinks() {
  local name="$1"
  local target_dir="$2"
  local dst="$3"
  local backup_root="$4"
  local backup_tmp="$5"

  local root rel_dir
  root="$(runtime_root_for_path "$name" "$target_dir" "$dst")"
  rel_dir="$(dirname "${dst#"$root"/}")"
  [ "$rel_dir" = "." ] && return 0

  local current segment
  current="$root"

  local IFS='/'
  for segment in $rel_dir; do
    current="$current/$segment"
    if [ -L "$current" ]; then
      # 兼容历史安装中的目录软链接，改为真实目录，避免写穿到外部路径。
      backup_existing_path "$name" "$target_dir" "$current" "$backup_root" "$backup_tmp"
      rm -f "$current"
    fi
  done
}

remove_stale_managed_files() {
  local name="$1"
  local target_dir="$2"
  local prev_manifest="$3"
  local prev_backup_manifest="$4"
  local staged_abs_file="$5"
  local backup_root="$6"
  local backup_tmp="$7"
  local pruned_tmp="$8"

  [ -f "$prev_manifest" ] || return 0

  local dst
  while IFS= read -r dst; do
    [ -n "$dst" ] || continue
    runtime_path_belongs_to_target "$name" "$target_dir" "$dst" || continue

    if grep -Fxq "$dst" "$staged_abs_file"; then
      continue
    fi

    if external_runtime_skill_path "$name" "$target_dir" "$dst"; then
      continue
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if ! reuse_existing_backup_mapping "$prev_backup_manifest" "$dst" "$backup_tmp"; then
        backup_existing_path "$name" "$target_dir" "$dst" "$backup_root" "$backup_tmp"
      fi
      rm -f "$dst"
      remove_if_empty "$(dirname "$dst")" "$(runtime_root_for_path "$name" "$target_dir" "$dst")"
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
      path_exists_or_symlink "$backup" || continue
      mkdir -p "$(dirname "$dst")"
      rm -rf "$dst"
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

runtime_catalog_missing_paths() {
  local target_dir="$1"

  python3 - "$target_dir" <<'PY'
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
catalog_path = target / "shared/runtime/standard-chain-catalog.json"
if not catalog_path.is_file():
    print("shared/runtime/standard-chain-catalog.json")
    raise SystemExit(0)

catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
missing = []
for entry in catalog.get("artifacts", {}).values():
    for key in ("schema_path", "template_path"):
        value = entry.get(key)
        if isinstance(value, str) and value and not (target / value).is_file():
            missing.append(value)

for value in sorted(set(missing)):
    print(value)
PY
}

runtime_catalog_paths_complete() {
  local target_dir="$1"

  [ -z "$(runtime_catalog_missing_paths "$target_dir")" ]
}

runtime_control_plane_complete() {
  local target_dir="$1"

  [ -f "$target_dir/tools/community/validate_product_closure.py" ] || return 1
  [ -f "$target_dir/tools/community/validate_readiness_contract.py" ] || return 1
  [ -f "$target_dir/tools/community/validate_standard_chain_readiness.py" ] || return 1
  [ -f "$target_dir/tools/community/validate_delivery_owner_input_readiness.py" ] || return 1
  [ -f "$target_dir/tools/community/validate_canonical_rules.py" ] || return 1
  [ -f "$target_dir/tools/community/validate_standard_chain_phase.py" ] || return 1
  [ -f "$target_dir/tools/community/authority_proof.py" ] || return 1
  [ -f "$target_dir/tools/community/manage_artifact_registry.py" ] || return 1
  [ -f "$target_dir/tools/community/normalize_canonical_artifact.py" ] || return 1
  [ -f "$target_dir/tools/community/canonical_rule_common.py" ] || return 1
  [ -f "$target_dir/tools/community/canonical_design_rules.py" ] || return 1
  [ -f "$target_dir/tools/community/canonical_design_confirmation_rules.py" ] || return 1
  [ -f "$target_dir/tools/community/canonical_design_errors.py" ] || return 1
  [ -f "$target_dir/tools/community/canonical_design_trace_rules.py" ] || return 1
  [ -f "$target_dir/tools/community/canonical_test_case_rules.py" ] || return 1
  [ -f "$target_dir/tools/community/update_delivery_state.py" ] || return 1
  [ -f "$target_dir/tools/community/delivery_owner_optional_artifacts.py" ] || return 1
  [ -f "$target_dir/tools/community/delivery_owner_freshness.py" ] || return 1
  [ -f "$target_dir/tools/community/standard_chain_readiness_rollback.py" ] || return 1
  [ -f "$target_dir/tools/community/runtime_yaml.py" ] || return 1
  [ -f "$target_dir/tools/community/simple_json_schema.py" ] || return 1
  [ -f "$target_dir/tools/community/validate_canonical_schema.py" ] || return 1
  [ -f "$target_dir/tools/community/validate_context_contract.py" ] || return 1
  [ -f "$target_dir/tools/community/recover_context.py" ] || return 1
  [ -f "$target_dir/tools/community/update_active_doc_scope.py" ] || return 1
  [ -f "$target_dir/tools/community/canonical_ref_resolver.py" ] || return 1
  [ -f "$target_dir/tools/community/write_user_decision.py" ] || return 1
  [ -f "$target_dir/contracts/product-artifacts.yaml" ] || return 1
  [ -f "$target_dir/contracts/canonical/registry-bundle.yaml" ] || return 1
  [ -f "$target_dir/shared/runtime/standard-chain-catalog.json" ] || return 1
  [ -f "$target_dir/shared/skills/lib/contracts/shared-core.schema.json" ] || return 1
  [ -f "$target_dir/shared/skills/developer/contracts/developer-report.schema.json" ] || return 1
  [ -f "$target_dir/shared/skills/developer/templates/developer-report.template.json" ] || return 1
  runtime_catalog_paths_complete "$target_dir" || return 1
  return 0
}

runtime_superpowers_clean() {
  local skills_dir="$1"
  local allow_local_edits="${2:-0}"
  local skill

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -f "$skills_dir/$skill/SKILL.md" ] || return 1
    [ ! -f "$skills_dir/$skill/agents/openai.yaml" ] || return 1
    if grep -Eq '^(user-invocable|disable-model-invocation):' "$skills_dir/$skill/SKILL.md"; then
      return 1
    fi
    if [ "$allow_local_edits" -eq 0 ]; then
      cmp -s "$COMMUNITY_SOURCE/superpowers/skills/$skill/SKILL.md" "$skills_dir/$skill/SKILL.md" || return 1
    fi
  done < <(community_superpowers_selected)

  [ ! -e "$skills_dir/verify-change" ] || return 1
  [ ! -e "$skills_dir/archive" ] || return 1
  [ ! -e "$skills_dir/parallel-subagent-development" ] || return 1
  return 0
}

codex_runtime_surface_applied() {
  local skills_dir="$1"
  local external_skill_list
  external_skill_list="$(external_runtime_skill_list_file codex)"

  python3 - "$SKILL_RUNTIME_SURFACE_CONTRACT" "$skills_dir" "$external_skill_list" <<'PY'
import json
import re
import sys
from pathlib import Path

contract = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
skills_dir = Path(sys.argv[2])
external_skill_list = Path(sys.argv[3])
skills = contract["skills"]
auto_count = 0
auto_limit = int(contract.get("limits", {}).get("max_auto_invoked_skills", 25))


def external_skill_names(path: Path) -> set[str]:
    if not path.is_file():
        return set()

    names = set()
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if line:
            names.add(line)
    return names


def frontmatter(text: str, path: Path) -> str:
    if not text.startswith("---\n"):
        raise SystemExit(f"{path}: missing frontmatter")
    parts = text.split("---\n", 2)
    if len(parts) != 3:
        raise SystemExit(f"{path}: invalid frontmatter")
    return parts[1]


def scalar(fm: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}:\s*['\"]?([^'\"\n]+)", fm, re.MULTILINE)
    return match.group(1).strip() if match else ""


external_skills = external_skill_names(external_skill_list)

for skill_file in sorted(skills_dir.glob("*/SKILL.md")):
    if skill_file.parent.name in external_skills:
        continue

    text = skill_file.read_text(encoding="utf-8")
    fm = frontmatter(text, skill_file)
    name = scalar(fm, "name") or skill_file.parent.name
    if name in external_skills:
        continue

    entry = skills.get(name) or skills.get(skill_file.parent.name)
    if entry is None:
        raise SystemExit(f"{name}: missing from runtime surface contract")

    mode = entry["mode"]
    owner = entry.get("owner")
    policy_file = skill_file.parent / "agents" / "openai.yaml"
    policy_text = policy_file.read_text(encoding="utf-8") if policy_file.exists() else ""
    disables_model = bool(re.search(r"^disable-model-invocation:\s*true\s*$", fm, re.MULTILINE))
    user_invocable = bool(re.search(r"^user-invocable:\s*true\s*$", fm, re.MULTILINE))
    disables_implicit = bool(re.search(r"^\s*allow_implicit_invocation:\s*false\s*$", policy_text, re.MULTILINE))

    if owner == "superpowers":
        if policy_file.exists() or disables_model or user_invocable:
            raise SystemExit(f"{name}: Superpowers mirror must not be runtime-mutated")
        auto_count += 1
        continue

    if mode == "manual":
        if not disables_model or not user_invocable or not disables_implicit:
            raise SystemExit(f"{name}: manual skill must disable model and implicit invocation")
    elif mode == "auto":
        auto_count += 1
        if disables_model or disables_implicit:
            raise SystemExit(f"{name}: auto skill must allow implicit invocation")

if auto_count > auto_limit:
    raise SystemExit(f"auto skill count exceeds limit: {auto_count} > {auto_limit}")
PY
}

runtime_target_complete() {
  local name="$1"
  local target_dir="$2"
  local allow_local_edits="${3:-0}"
  local skill_pull_skill="skill-pull"

  if [ "$name" = "claude" ]; then
    runtime_superpowers_clean "$target_dir/skills" "$allow_local_edits" || return 1
    claude_agent_files_match_contract "$target_dir" || return 1
    [ -f "$target_dir/skills/product-director/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/product-manager/SKILL.md" ] || return 1
    [ ! -e "$target_dir/skills/project-agents-init" ] || return 1
    [ -f "$target_dir/skills/code-review-fix/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/doc-review-fix/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/docx/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/skill-creator/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/$skill_pull_skill/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/feishu-docs/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/deep-research/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/to-prd/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/prd/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/baoyu-markdown-to-html/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/code-to-prd/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/graphify/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/architecture/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/mermaid-diagrams/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/bb-browser/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/humanizer-zh/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/notebooklm/SKILL.md" ] || return 1
    [ -f "$target_dir/skills/self-improving-agent/SKILL.md" ] || return 1
    grep -Fq 'disable-model-invocation: true' "$target_dir/skills/self-improving-agent/SKILL.md" || return 1
    [ ! -e "$target_dir/skills/skill-auditor" ] || return 1
    [ ! -e "$target_dir/skills/skill-refiner" ] || return 1
    [ ! -e "$target_dir/skills/new-skills" ] || return 1
    [ -f "$target_dir/skills/mcp-builder/SKILL.md" ] || return 1
    [ ! -e "$target_dir/skills/review-fix-loop" ] || return 1
    [ ! -e "$target_dir/skills/codex-doc-review" ] || return 1
    runtime_probe_skills_absent "$target_dir/skills" || return 1
    runtime_internal_skill_roots_absent "$target_dir/skills" || return 1
    [ ! -e "$target_dir/agents/codex-doc-reviewer.md" ] || return 1
    [ -f "$target_dir/hooks/block_dangerous.sh" ] || return 1
    [ -x "$target_dir/hooks/block_dangerous.sh" ] || return 1
    [ -f "$target_dir/hooks/managed/block_dangerous.sh" ] || return 1
    [ -x "$target_dir/hooks/managed/block_dangerous.sh" ] || return 1
    [ -f "$target_dir/hooks/managed/context_contract_validator.py" ] || return 1
    [ -f "$target_dir/hooks/registry.json" ] || return 1
    [ -f "$target_dir/CLAUDE.md" ] || return 1
    claude_hooks_registered "$target_dir/settings.json" || return 1
    [ -f "$target_dir/protocols/phase-selection-protocol.md" ] || return 1
    [ ! -f "$target_dir/reference/phase-selection-protocol.md" ] || return 1
    runtime_control_plane_complete "$target_dir" || return 1
    runtime_noise_absent "$target_dir" || return 1
    [ ! -e "$target_dir/.org-installed-version" ] || return 1
    [ ! -e "$target_dir/.org-backups" ] || return 1
    return 0
  fi

  if [ "$name" = "codex" ]; then
    local codex_skills_dir="$CODEX_USER_SKILLS_DIR"
    [ -f "$target_dir/AGENTS.md" ] || return 1
    [ -f "$target_dir/config.toml" ] || return 1
    codex_agent_config_inherits_defaults "$target_dir/config.toml" || return 1
    codex_agent_files_match_contract "$target_dir" || return 1
    codex_legacy_skill_root_clean || return 1
    runtime_superpowers_clean "$codex_skills_dir" "$allow_local_edits" || return 1
    [ -f "$codex_skills_dir/product-director/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/product-manager/SKILL.md" ] || return 1
    [ ! -e "$codex_skills_dir/project-agents-init" ] || return 1
    [ ! -e "$codex_skills_dir/code-review-fix" ] || return 1
    [ ! -e "$codex_skills_dir/doc-review-fix" ] || return 1
    [ ! -e "$codex_skills_dir/review-fix-loop" ] || return 1
    [ ! -e "$codex_skills_dir/codex-doc-review" ] || return 1
    runtime_probe_skills_absent "$codex_skills_dir" || return 1
    runtime_internal_skill_roots_absent "$codex_skills_dir" || return 1
    codex_runtime_surface_applied "$codex_skills_dir" || return 1
    [ ! -e "$CODEX_DIR/skills/.system/skill-creator" ] || return 1
    [ -f "$codex_skills_dir/skill-creator/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/$skill_pull_skill/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/feishu-docs/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/deep-research/SKILL.md" ] || return 1
    [ ! -e "$codex_skills_dir/skill-auditor" ] || return 1
    [ ! -e "$codex_skills_dir/skill-refiner" ] || return 1
    [ ! -e "$codex_skills_dir/new-skills" ] || return 1
    [ -f "$codex_skills_dir/agent-browser/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/agent-browser/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/bb-browser/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/bb-browser/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/to-prd/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/to-prd/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/prd/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/prd/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/baoyu-markdown-to-html/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/baoyu-markdown-to-html/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/code-to-prd/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/code-to-prd/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/graphify/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/graphify/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/architecture/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/architecture/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/mermaid-diagrams/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/mermaid-diagrams/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/humanizer-zh/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/humanizer-zh/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/notebooklm/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/notebooklm/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/self-improving-agent/SKILL.md" ] || return 1
    grep -Fq 'disable-model-invocation: true' "$codex_skills_dir/self-improving-agent/SKILL.md" || return 1
    [ -f "$codex_skills_dir/cli-updater/SKILL.md" ] || return 1
    grep -Fq 'disable-model-invocation: true' "$codex_skills_dir/cli-updater/SKILL.md" || return 1
    [ -f "$codex_skills_dir/ui-ux-pro-max/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/ui-ux-pro-max/agents/openai.yaml" ] || return 1
    [ -f "$codex_skills_dir/webapp-testing/SKILL.md" ] || return 1
    [ -f "$codex_skills_dir/webapp-testing/agents/openai.yaml" ] || return 1
    [ -f "$target_dir/agents/developer.toml" ] || return 1
    [ -f "$target_dir/agents/code-reviewer.toml" ] || return 1
    [ -f "$target_dir/agents/consistency-auditor.toml" ] || return 1
    [ ! -e "$target_dir/agents/generic-code-reviewer.toml" ] || return 1
    [ ! -e "$target_dir/agents/designer.toml" ] || return 1
    [ ! -e "$target_dir/agents/tech-lead.toml" ] || return 1
    [ ! -e "$target_dir/agents/test-designer.toml" ] || return 1
    [ ! -e "$target_dir/agents/generic-code-reviewer.md" ] || return 1
    [ ! -e "$target_dir/agents/code-reviewer.md" ] || return 1
    [ ! -e "$target_dir/agents/consistency-auditor.md" ] || return 1
    [ ! -e "$target_dir/agents/designer.md" ] || return 1
    [ ! -e "$target_dir/agents/tech-lead.md" ] || return 1
    [ ! -e "$target_dir/agents/test-designer.md" ] || return 1
    [ -f "$target_dir/hooks/lib/common.sh" ] || return 1
    [ -f "$target_dir/hooks/lib/constraint.sh" ] || return 1
    [ -f "$target_dir/hooks/managed/block_dangerous.sh" ] || return 1
    [ -x "$target_dir/hooks/managed/block_dangerous.sh" ] || return 1
    [ -f "$target_dir/hooks/managed/context_contract_validator.py" ] || return 1
    [ -f "$target_dir/hooks/managed/codex_user_prompt_submit.py" ] || return 1
    [ -f "$target_dir/hooks/managed/codex_stop_dispatch.py" ] || return 1
    [ -f "$target_dir/hooks/registry.json" ] || return 1
    [ -f "$target_dir/protocols/phase-selection-protocol.md" ] || return 1
    [ ! -f "$target_dir/reference/phase-selection-protocol.md" ] || return 1
    runtime_control_plane_complete "$target_dir" || return 1
    runtime_noise_absent "$target_dir" || return 1
    runtime_noise_absent "$HOME/.agents" || return 1
    [ ! -e "$target_dir/.org-installed-version" ] || return 1
    [ ! -e "$target_dir/.org-backups" ] || return 1
    return 0
  fi

  return 1
}

mark_allow_local_runtime_edits() {
  local name="$1"

  case "$name" in
    claude)
      CLAUDE_ALLOW_LOCAL_RUNTIME_EDITS=1
      ;;
    codex)
      CODEX_ALLOW_LOCAL_RUNTIME_EDITS=1
      ;;
  esac
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
  RUNTIME_AUDIT_DIRTY=0

  audit_runtime_rules "$name" "$target_dir" "$state_dir"
  audit_runtime_references "$name" "$target_dir" "$state_dir"
  audit_retired_runtime_skills "$name" "$target_dir" "$state_dir"
  audit_runtime_probe_skills "$name" "$target_dir" "$state_dir"
  audit_runtime_internal_skill_roots "$name" "$target_dir" "$state_dir"
  runtime_audit_dirty="$RUNTIME_AUDIT_DIRTY"

  local version_file="$state_dir/installed-version"
  local manifest_file="$state_dir/installed-manifest"
  local backup_manifest_file="$state_dir/backup-manifest"
  local metadata_version_tag="$version_tag"

  if [ "$runtime_audit_dirty" -ne 0 ] && [ -f "$version_file" ]; then
    metadata_version_tag="$(trim < "$version_file")"
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    prune_runtime_noise "$target_dir"
    if [ "$name" = "codex" ]; then
      prune_runtime_noise "$HOME/.agents"
      cleanup_legacy_codex_system_skill_creator "$target_dir"
    fi
  fi

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
      if runtime_target_complete "$name" "$target_dir" 1; then
        mark_allow_local_runtime_edits "$name"
        log "$name 已是最新版本 ($installed)，跳过安装"
        return 0
      fi
      warn "$name 版本已匹配 ($installed)，但运行面不完整，继续重装"
    fi
  fi

  local staging
  staging=$(mktemp -d)
  "$build_fn" "$staging"
  prune_runtime_noise "$staging"
  if [ "$name" = "codex" ]; then
    audit_codex_legacy_skill_root "$target_dir" "$staging/skills" "$state_dir"
  fi

  local conflicts
  conflicts=$(mktemp)
  check_conflicts "$name" "$target_dir" "$staging" "$manifest_file" "$conflicts"

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
    dst="$(dst_for_stage_rel "$name" "$target_dir" "$rel")"
    printf '%s\n' "$dst" >> "$staged_abs"
  done < "$staged_rel"

  if [ -f "$manifest_file" ]; then
    while IFS= read -r dst; do
      [ -n "$dst" ] || continue
      runtime_path_belongs_to_target "$name" "$target_dir" "$dst" || continue
      if grep -Fxq "$dst" "$staged_abs"; then
        continue
      fi
      if external_runtime_skill_path "$name" "$target_dir" "$dst"; then
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

  audit_runtime_rules "$name" "$target_dir" "$state_dir" 1 "$backup_root" "$backup_tmp"
  audit_runtime_references "$name" "$target_dir" "$state_dir" 1 "$backup_root" "$backup_tmp"
  audit_retired_runtime_skills "$name" "$target_dir" "$state_dir" 1 "$backup_root" "$backup_tmp"
  audit_runtime_probe_skills "$name" "$target_dir" "$state_dir" 1 "$backup_root" "$backup_tmp"
  audit_runtime_internal_skill_roots "$name" "$target_dir" "$state_dir" 1 "$backup_root" "$backup_tmp"
  if [ "$name" = "codex" ]; then
    audit_codex_legacy_skill_root "$target_dir" "$staging/skills" "$state_dir" 1 "$backup_root" "$backup_tmp"
  fi
  remove_stale_managed_files "$name" "$target_dir" "$manifest_file" "$backup_manifest_file" "$staged_abs" "$backup_root" "$backup_tmp" "$pruned_tmp"

  local src
  while IFS= read -r rel; do
    src="$staging/$rel"
    dst="$(dst_for_stage_rel "$name" "$target_dir" "$rel")"
    local carried_backup=0

    if is_in_manifest "$manifest_file" "$dst" && reuse_existing_backup_mapping "$backup_manifest_file" "$dst" "$backup_tmp"; then
      carried_backup=1
    fi

    normalize_parent_symlinks "$name" "$target_dir" "$dst" "$backup_root" "$backup_tmp"
    mkdir -p "$(dirname "$dst")"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if [ "$carried_backup" -eq 0 ]; then
        backup_existing_path "$name" "$target_dir" "$dst" "$backup_root" "$backup_tmp"
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

  prune_runtime_noise "$target_dir"
  persist_metadata "$state_dir" "$manifest_tmp" "$backup_tmp" "$pruned_tmp" "$metadata_version_tag"
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
    if is_runtime_audit_cleanup_path "$name" "$target_dir" "$dst"; then
      continue
    fi
    [ -n "$backup" ] || continue
    path_exists_or_symlink "$backup" || fail "$name 备份文件缺失，拒绝卸载以避免数据丢失: $backup"
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

  local manifest_restore_plan pruned_restore_plan backup_only_restore_plan managed_restore_paths
  manifest_restore_plan=$(mktemp)
  pruned_restore_plan=$(mktemp)
  backup_only_restore_plan=$(mktemp)
  managed_restore_paths=$(mktemp)

  awk -F '\t' '
    FILENAME == ARGV[1] { backup[$1]=$2; next }
    { printf "%s\t%s\n", $0, backup[$0] }
  ' "$backup_manifest" "$manifest" > "$manifest_restore_plan"

  if [ -f "$pruned_manifest" ]; then
    awk -F '\t' '
      FILENAME == ARGV[1] { backup[$1]=$2; next }
      { printf "%s\t%s\n", $0, backup[$0] }
    ' "$backup_manifest" "$pruned_manifest" > "$pruned_restore_plan"
  else
    : > "$pruned_restore_plan"
  fi

  cp "$manifest" "$managed_restore_paths"
  if [ -f "$pruned_manifest" ]; then
    cat "$pruned_manifest" >> "$managed_restore_paths"
  fi
  awk -F '\t' '
    FILENAME == ARGV[1] { managed[$0]=1; next }
    !($1 in managed) { print }
  ' "$managed_restore_paths" "$backup_manifest" > "$backup_only_restore_plan"

  local dst_dir
  while IFS=$'\t' read -r dst backup; do
    [ -n "$dst" ] || continue
    dst_dir="${dst%/*}"
    if external_runtime_skill_path "$name" "$target_dir" "$dst"; then
      continue
    fi
    if is_runtime_audit_cleanup_path "$name" "$target_dir" "$dst"; then
      rm -rf "$dst"
      remove_if_empty "$dst_dir" "$(runtime_root_for_path "$name" "$target_dir" "$dst")"
      continue
    fi
    if [ -n "$backup" ] && path_exists_or_symlink "$backup"; then
      mkdir -p "$dst_dir"
      rm -rf "$dst"
      cp -a "$backup" "$dst"
    else
      rm -f "$dst"
    fi
    remove_if_empty "$dst_dir" "$(runtime_root_for_path "$name" "$target_dir" "$dst")"
  done < "$manifest_restore_plan"

  while IFS=$'\t' read -r dst backup; do
    [ -n "$dst" ] || continue
    dst_dir="${dst%/*}"
    if external_runtime_skill_path "$name" "$target_dir" "$dst"; then
      continue
    fi
    if is_runtime_audit_cleanup_path "$name" "$target_dir" "$dst"; then
      continue
    fi
    if [ -n "$backup" ] && path_exists_or_symlink "$backup"; then
      mkdir -p "$dst_dir"
      rm -rf "$dst"
      cp -a "$backup" "$dst"
    fi
  done < "$pruned_restore_plan"

  while IFS=$'\t' read -r dst backup; do
    [ -n "$dst" ] || continue
    [ -n "$backup" ] || continue
    dst_dir="${dst%/*}"
    if external_runtime_skill_path "$name" "$target_dir" "$dst"; then
      continue
    fi
    if is_runtime_audit_cleanup_path "$name" "$target_dir" "$dst"; then
      continue
    fi
    if path_exists_or_symlink "$backup"; then
      rm -rf "$dst"
      mkdir -p "$dst_dir"
      cp -a "$backup" "$dst"
      remove_if_empty "$dst_dir" "$(runtime_root_for_path "$name" "$target_dir" "$dst")"
    fi
  done < "$backup_only_restore_plan"

  rm -f "$manifest_restore_plan" "$pruned_restore_plan" "$backup_only_restore_plan" "$managed_restore_paths"

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

quick_check_control_plane_files() {
  local target_dir="$1"
  local display="$2"
  local missing_catalog_paths

  [ -f "$target_dir/tools/community/validate_product_closure.py" ] || fail "Quick Check 失败: $display/tools/community/validate_product_closure.py 不存在"
  [ -f "$target_dir/tools/community/validate_readiness_contract.py" ] || fail "Quick Check 失败: $display/tools/community/validate_readiness_contract.py 不存在"
  [ -f "$target_dir/tools/community/validate_standard_chain_readiness.py" ] || fail "Quick Check 失败: $display/tools/community/validate_standard_chain_readiness.py 不存在"
  [ -f "$target_dir/tools/community/validate_delivery_owner_input_readiness.py" ] || fail "Quick Check 失败: $display/tools/community/validate_delivery_owner_input_readiness.py 不存在"
  [ -f "$target_dir/tools/community/validate_canonical_rules.py" ] || fail "Quick Check 失败: $display/tools/community/validate_canonical_rules.py 不存在"
  [ -f "$target_dir/tools/community/validate_standard_chain_phase.py" ] || fail "Quick Check 失败: $display/tools/community/validate_standard_chain_phase.py 不存在"
  [ -f "$target_dir/tools/community/authority_proof.py" ] || fail "Quick Check 失败: $display/tools/community/authority_proof.py 不存在"
  [ -f "$target_dir/tools/community/manage_artifact_registry.py" ] || fail "Quick Check 失败: $display/tools/community/manage_artifact_registry.py 不存在"
  [ -f "$target_dir/tools/community/normalize_canonical_artifact.py" ] || fail "Quick Check 失败: $display/tools/community/normalize_canonical_artifact.py 不存在"
  [ -f "$target_dir/tools/community/canonical_rule_common.py" ] || fail "Quick Check 失败: $display/tools/community/canonical_rule_common.py 不存在"
  [ -f "$target_dir/tools/community/canonical_design_rules.py" ] || fail "Quick Check 失败: $display/tools/community/canonical_design_rules.py 不存在"
  [ -f "$target_dir/tools/community/canonical_design_confirmation_rules.py" ] || fail "Quick Check 失败: $display/tools/community/canonical_design_confirmation_rules.py 不存在"
  [ -f "$target_dir/tools/community/canonical_design_errors.py" ] || fail "Quick Check 失败: $display/tools/community/canonical_design_errors.py 不存在"
  [ -f "$target_dir/tools/community/canonical_design_trace_rules.py" ] || fail "Quick Check 失败: $display/tools/community/canonical_design_trace_rules.py 不存在"
  [ -f "$target_dir/tools/community/canonical_test_case_rules.py" ] || fail "Quick Check 失败: $display/tools/community/canonical_test_case_rules.py 不存在"
  [ -f "$target_dir/tools/community/update_delivery_state.py" ] || fail "Quick Check 失败: $display/tools/community/update_delivery_state.py 不存在"
  [ -f "$target_dir/tools/community/delivery_owner_optional_artifacts.py" ] || fail "Quick Check 失败: $display/tools/community/delivery_owner_optional_artifacts.py 不存在"
  [ -f "$target_dir/tools/community/delivery_owner_freshness.py" ] || fail "Quick Check 失败: $display/tools/community/delivery_owner_freshness.py 不存在"
  [ -f "$target_dir/tools/community/standard_chain_readiness_rollback.py" ] || fail "Quick Check 失败: $display/tools/community/standard_chain_readiness_rollback.py 不存在"
  [ -f "$target_dir/tools/community/runtime_yaml.py" ] || fail "Quick Check 失败: $display/tools/community/runtime_yaml.py 不存在"
  [ -f "$target_dir/tools/community/simple_json_schema.py" ] || fail "Quick Check 失败: $display/tools/community/simple_json_schema.py 不存在"
  [ -f "$target_dir/tools/community/validate_canonical_schema.py" ] || fail "Quick Check 失败: $display/tools/community/validate_canonical_schema.py 不存在"
  [ -f "$target_dir/tools/community/validate_context_contract.py" ] || fail "Quick Check 失败: $display/tools/community/validate_context_contract.py 不存在"
  [ -f "$target_dir/tools/community/recover_context.py" ] || fail "Quick Check 失败: $display/tools/community/recover_context.py 不存在"
  [ -f "$target_dir/tools/community/update_active_doc_scope.py" ] || fail "Quick Check 失败: $display/tools/community/update_active_doc_scope.py 不存在"
  [ -f "$target_dir/tools/community/canonical_ref_resolver.py" ] || fail "Quick Check 失败: $display/tools/community/canonical_ref_resolver.py 不存在"
  [ -f "$target_dir/tools/community/write_user_decision.py" ] || fail "Quick Check 失败: $display/tools/community/write_user_decision.py 不存在"
  [ -f "$target_dir/contracts/product-artifacts.yaml" ] || fail "Quick Check 失败: $display/contracts/product-artifacts.yaml 不存在"
  [ -f "$target_dir/contracts/canonical/registry-bundle.yaml" ] || fail "Quick Check 失败: $display/contracts/canonical/registry-bundle.yaml 不存在"
  [ -f "$target_dir/shared/runtime/standard-chain-catalog.json" ] || fail "Quick Check 失败: $display/shared/runtime/standard-chain-catalog.json 不存在"
  [ -f "$target_dir/shared/skills/lib/contracts/shared-core.schema.json" ] || fail "Quick Check 失败: $display/shared/skills/lib/contracts/shared-core.schema.json 不存在"
  [ -f "$target_dir/shared/skills/developer/contracts/developer-report.schema.json" ] || fail "Quick Check 失败: $display/shared/skills/developer/contracts/developer-report.schema.json 不存在"
  [ -f "$target_dir/shared/skills/developer/templates/developer-report.template.json" ] || fail "Quick Check 失败: $display/shared/skills/developer/templates/developer-report.template.json 不存在"
  missing_catalog_paths="$(runtime_catalog_missing_paths "$target_dir")"
  [ -z "$missing_catalog_paths" ] || fail "Quick Check 失败: $display 缺少 standard-chain catalog 资源: $missing_catalog_paths"
}

quick_check_rendered_shared_tree() {
  local source_dir="$1"
  local target_dir="$2"
  local runtime_home_literal="$3"
  local display="$4"
  local source rel expected

  while IFS= read -r source; do
    [ -n "$source" ] || continue
    rel="${source#"$source_dir"/}"
    [ -f "$target_dir/$rel" ] || fail "Quick Check 失败: $display/$rel 不存在"
    expected="$(mktemp)"
    sed "s|{{RUNTIME_HOME}}|$runtime_home_literal|g" "$source" > "$expected"
    if ! cmp -s "$expected" "$target_dir/$rel"; then
      rm -f "$expected"
      fail "Quick Check 失败: $display/$rel 与 shared 源不一致"
    fi
    rm -f "$expected"
  done < <(find "$source_dir" -maxdepth 1 -type f -name '*.md' | sort)
}

quick_check_superpowers_clean() {
  local skills_dir="$1"
  local display="$2"
  local allow_local_edits="${3:-0}"
  local skill

  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -f "$skills_dir/$skill/SKILL.md" ] || fail "Quick Check 失败: $display/$skill/SKILL.md 不存在"
    [ ! -f "$skills_dir/$skill/agents/openai.yaml" ] || fail "Quick Check 失败: $display/$skill/agents/openai.yaml 不应存在"
    if grep -Eq '^(user-invocable|disable-model-invocation):' "$skills_dir/$skill/SKILL.md"; then
      fail "Quick Check 失败: $display/$skill/SKILL.md 不应注入运行时 frontmatter"
    fi
    if [ "$allow_local_edits" -eq 0 ]; then
      cmp -s "$COMMUNITY_SOURCE/superpowers/skills/$skill/SKILL.md" "$skills_dir/$skill/SKILL.md" || fail "Quick Check 失败: $display/$skill/SKILL.md 与官方镜像不一致"
    fi
  done < <(community_superpowers_selected)

  [ ! -e "$skills_dir/verify-change" ] || fail "Quick Check 失败: $display/verify-change 不应存在"
  [ ! -e "$skills_dir/archive" ] || fail "Quick Check 失败: $display/archive 不应存在"
  [ ! -e "$skills_dir/parallel-subagent-development" ] || fail "Quick Check 失败: $display/parallel-subagent-development 不应存在"
}

quick_check() {
  local target="$1"

  if [ "$target" = "claude" ] || [ "$target" = "all" ]; then
    prune_runtime_noise "$CLAUDE_DIR"
    quick_check_superpowers_clean "$CLAUDE_DIR/skills" "$HOME/.claude/skills" "$CLAUDE_ALLOW_LOCAL_RUNTIME_EDITS"
    [ -f "$CLAUDE_DIR/skills/product-director/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/product-director/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/product-manager/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/product-manager/SKILL.md 不存在"
    [ ! -e "$CLAUDE_DIR/skills/project-agents-init" ] || fail "Quick Check 失败: ~/.claude/skills/project-agents-init 不应存在"
    [ -f "$CLAUDE_DIR/skills/code-review-fix/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/code-review-fix/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/doc-review-fix/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/doc-review-fix/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/docx/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/docx/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/skill-creator/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/skill-creator/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/feishu-docs/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/feishu-docs/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/deep-research/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/deep-research/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/architecture/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/architecture/SKILL.md 不存在"
    [ -f "$CLAUDE_DIR/skills/mermaid-diagrams/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/mermaid-diagrams/SKILL.md 不存在"
    [ ! -e "$CLAUDE_DIR/skills/skill-auditor" ] || fail "Quick Check 失败: ~/.claude/skills/skill-auditor 不应存在"
    [ ! -e "$CLAUDE_DIR/skills/skill-refiner" ] || fail "Quick Check 失败: ~/.claude/skills/skill-refiner 不应存在"
    [ ! -e "$CLAUDE_DIR/skills/new-skills" ] || fail "Quick Check 失败: ~/.claude/skills/new-skills 不应存在"
    [ -f "$CLAUDE_DIR/skills/mcp-builder/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/mcp-builder/SKILL.md 不存在"
    [ ! -e "$CLAUDE_DIR/skills/review-fix-loop" ] || fail "Quick Check 失败: ~/.claude/skills/review-fix-loop 不应存在"
    [ ! -e "$CLAUDE_DIR/skills/codex-doc-review" ] || fail "Quick Check 失败: ~/.claude/skills/codex-doc-review 不应存在"
    runtime_probe_skills_absent "$CLAUDE_DIR/skills" || fail "Quick Check 失败: ~/.claude/skills 不应残留 runtime 探针 skill"
    runtime_internal_skill_roots_absent "$CLAUDE_DIR/skills" || fail "Quick Check 失败: ~/.claude/skills 不应暴露 evals/fixtures/examples/selves/workspace 内部文件"
    [ -f "$CLAUDE_DIR/skills/darwin-skill/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/darwin-skill/SKILL.md 不存在"
    [ ! -e "$CLAUDE_DIR/agents/codex-doc-reviewer.md" ] || fail "Quick Check 失败: ~/.claude/agents/codex-doc-reviewer.md 不应存在"
    [ -f "$CLAUDE_DIR/hooks/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.claude/hooks/block_dangerous.sh 不存在"
    [ -x "$CLAUDE_DIR/hooks/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.claude/hooks/block_dangerous.sh 不可执行"
    [ -f "$CLAUDE_DIR/hooks/managed/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.claude/hooks/managed/block_dangerous.sh 不存在"
    [ -x "$CLAUDE_DIR/hooks/managed/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.claude/hooks/managed/block_dangerous.sh 不可执行"
    [ -f "$CLAUDE_DIR/hooks/registry.json" ] || fail "Quick Check 失败: ~/.claude/hooks/registry.json 不存在"
    [ -f "$CLAUDE_DIR/CLAUDE.md" ] || fail "Quick Check 失败: ~/.claude/CLAUDE.md 不存在"
    quick_check_rendered_shared_tree "$SHARED_SOURCE/rules" "$CLAUDE_DIR/rules" "\$HOME/.claude" "$HOME/.claude/rules"
    quick_check_rendered_shared_tree "$SHARED_SOURCE/reference" "$CLAUDE_DIR/reference" "\$HOME/.claude" "$HOME/.claude/reference"
    claude_agent_files_match_contract "$CLAUDE_DIR" || fail "Quick Check 失败: ~/.claude/agents 不符合 Claude Code 平台 agent 合同或重复了 skill 能力细节"
    [ -f "$CLAUDE_DIR/protocols/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.claude/protocols/phase-selection-protocol.md 不存在"
    [ ! -f "$CLAUDE_DIR/reference/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.claude/reference/phase-selection-protocol.md 不应存在"
    quick_check_control_plane_files "$CLAUDE_DIR" "$HOME/.claude"
    runtime_noise_absent "$CLAUDE_DIR" || fail "Quick Check 失败: ~/.claude 不应包含 __pycache__、*.pyc 或 .DS_Store"
    [ ! -e "$CLAUDE_DIR/.org-installed-version" ] || fail "Quick Check 失败: ~/.claude 不应残留 .org-installed-version"
    [ ! -e "$CLAUDE_DIR/.org-backups" ] || fail "Quick Check 失败: ~/.claude 不应残留 .org-backups"
    [ -f "$(target_state_dir claude)/installed-version" ] || fail "Quick Check 失败: ~/.org-skills-state/claude/installed-version 不存在"
    check_hooks_registration
    claude_hooks_no_duplicates "$CLAUDE_DIR/settings.json" || fail "Quick Check 失败: ~/.claude/settings.json 存在重复 hooks 注册"
  fi

  if [ "$target" = "codex" ] || [ "$target" = "all" ]; then
    local codex_skills_dir="$CODEX_USER_SKILLS_DIR"
    prune_runtime_noise "$CODEX_DIR"
    prune_runtime_noise "$HOME/.agents"
    [ -f "$CODEX_DIR/AGENTS.md" ] || fail "Quick Check 失败: ~/.codex/AGENTS.md 不存在"
    codex_legacy_skill_root_clean || fail "Quick Check 失败: ~/.codex/skills 不应残留非隐藏 skill；Codex skill 统一安装到 ~/.agents/skills"
    quick_check_superpowers_clean "$codex_skills_dir" "$HOME/.agents/skills" "$CODEX_ALLOW_LOCAL_RUNTIME_EDITS"
    [ -f "$codex_skills_dir/product-director/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/product-director/SKILL.md 不存在"
    [ -f "$codex_skills_dir/product-manager/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/product-manager/SKILL.md 不存在"
    [ ! -e "$codex_skills_dir/project-agents-init" ] || fail "Quick Check 失败: ~/.agents/skills/project-agents-init 不应存在"
    [ ! -e "$codex_skills_dir/code-review-fix" ] || fail "Quick Check 失败: ~/.agents/skills/code-review-fix 不应存在"
    [ ! -e "$codex_skills_dir/doc-review-fix" ] || fail "Quick Check 失败: ~/.agents/skills/doc-review-fix 不应存在"
    [ ! -e "$codex_skills_dir/review-fix-loop" ] || fail "Quick Check 失败: ~/.agents/skills/review-fix-loop 不应存在"
    [ ! -e "$codex_skills_dir/codex-doc-review" ] || fail "Quick Check 失败: ~/.agents/skills/codex-doc-review 不应存在"
    codex_runtime_surface_applied "$codex_skills_dir" || fail "Quick Check 失败: ~/.agents/skills 未满足 contracts/skill-runtime-surface.json"
    [ -f "$codex_skills_dir/skill-creator/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/skill-creator/SKILL.md 不存在"
    [ -f "$codex_skills_dir/skill-creator/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/skill-creator/agents/openai.yaml 不存在"
    [ ! -e "$CODEX_DIR/skills/.system/skill-creator" ] || fail "Quick Check 失败: ~/.codex/skills/.system/skill-creator 旧残留未清理"
    [ -f "$codex_skills_dir/find-skills/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/find-skills/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/webapp-testing/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/webapp-testing/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/agent-reach/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/agent-reach/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/feishu-docs/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/feishu-docs/SKILL.md 不存在"
    [ -f "$codex_skills_dir/deep-research/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/deep-research/SKILL.md 不存在"
    [ ! -e "$codex_skills_dir/skill-auditor" ] || fail "Quick Check 失败: ~/.agents/skills/skill-auditor 不应存在"
    [ ! -e "$codex_skills_dir/skill-refiner" ] || fail "Quick Check 失败: ~/.agents/skills/skill-refiner 不应存在"
    [ ! -e "$codex_skills_dir/new-skills" ] || fail "Quick Check 失败: ~/.agents/skills/new-skills 不应存在"
    runtime_probe_skills_absent "$codex_skills_dir" || fail "Quick Check 失败: ~/.agents/skills 不应残留 runtime 探针 skill"
    runtime_internal_skill_roots_absent "$codex_skills_dir" || fail "Quick Check 失败: ~/.agents/skills 不应暴露 evals/fixtures/examples/selves/workspace 内部文件"
    [ -f "$codex_skills_dir/agent-browser/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/agent-browser/SKILL.md 不存在"
    [ -f "$codex_skills_dir/agent-browser/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/agent-browser/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/darwin-skill/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/darwin-skill/SKILL.md 不存在"
    [ -f "$codex_skills_dir/ui-ux-pro-max/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/ui-ux-pro-max/SKILL.md 不存在"
    [ -f "$codex_skills_dir/ui-ux-pro-max/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/ui-ux-pro-max/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/ui-ux-pro-max/scripts/search.py" ] || fail "Quick Check 失败: ~/.agents/skills/ui-ux-pro-max/scripts/search.py 不存在"
    [ -f "$codex_skills_dir/webapp-testing/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/webapp-testing/SKILL.md 不存在"
    [ -f "$codex_skills_dir/agent-reach/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/agent-reach/SKILL.md 不存在"
    [ -f "$codex_skills_dir/bb-browser/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/bb-browser/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/humanizer-zh/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/humanizer-zh/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/architecture/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/architecture/SKILL.md 不存在"
    [ -f "$codex_skills_dir/architecture/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/architecture/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/mermaid-diagrams/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/mermaid-diagrams/SKILL.md 不存在"
    [ -f "$codex_skills_dir/mermaid-diagrams/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/mermaid-diagrams/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/notebooklm/agents/openai.yaml" ] || fail "Quick Check 失败: ~/.agents/skills/notebooklm/agents/openai.yaml 不存在"
    [ -f "$codex_skills_dir/self-improving-agent/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/self-improving-agent/SKILL.md 不存在"
    [ -f "$codex_skills_dir/cli-updater/SKILL.md" ] || fail "Quick Check 失败: ~/.agents/skills/cli-updater/SKILL.md 不存在"
    [ -f "$CODEX_DIR/agents/developer.toml" ] || fail "Quick Check 失败: ~/.codex/agents/developer.toml 不存在"
    quick_check_rendered_shared_tree "$SHARED_SOURCE/rules" "$CODEX_DIR/rules" "\$HOME/.codex" "$HOME/.codex/rules"
    quick_check_rendered_shared_tree "$SHARED_SOURCE/reference" "$CODEX_DIR/reference" "\$HOME/.codex" "$HOME/.codex/reference"
    [ -f "$CODEX_DIR/agents/code-reviewer.toml" ] || fail "Quick Check 失败: ~/.codex/agents/code-reviewer.toml 不存在"
    [ -f "$CODEX_DIR/agents/consistency-auditor.toml" ] || fail "Quick Check 失败: ~/.codex/agents/consistency-auditor.toml 不存在"
    [ ! -e "$CODEX_DIR/agents/generic-code-reviewer.toml" ] || fail "Quick Check 失败: ~/.codex/agents/generic-code-reviewer.toml 不应存在"
    [ ! -e "$CODEX_DIR/agents/designer.toml" ] || fail "Quick Check 失败: ~/.codex/agents/designer.toml 不应存在"
    [ ! -e "$CODEX_DIR/agents/tech-lead.toml" ] || fail "Quick Check 失败: ~/.codex/agents/tech-lead.toml 不应存在"
    [ ! -e "$CODEX_DIR/agents/test-designer.toml" ] || fail "Quick Check 失败: ~/.codex/agents/test-designer.toml 不应存在"
    [ ! -e "$CODEX_DIR/agents/generic-code-reviewer.md" ] || fail "Quick Check 失败: ~/.codex/agents/generic-code-reviewer.md 不应存在"
    [ ! -e "$CODEX_DIR/agents/code-reviewer.md" ] || fail "Quick Check 失败: ~/.codex/agents/code-reviewer.md 不应存在"
    [ ! -e "$CODEX_DIR/agents/consistency-auditor.md" ] || fail "Quick Check 失败: ~/.codex/agents/consistency-auditor.md 不应存在"
    [ ! -e "$CODEX_DIR/agents/designer.md" ] || fail "Quick Check 失败: ~/.codex/agents/designer.md 不应存在"
    [ ! -e "$CODEX_DIR/agents/tech-lead.md" ] || fail "Quick Check 失败: ~/.codex/agents/tech-lead.md 不应存在"
    [ ! -e "$CODEX_DIR/agents/test-designer.md" ] || fail "Quick Check 失败: ~/.codex/agents/test-designer.md 不应存在"
    [ -f "$CODEX_DIR/hooks/lib/common.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/lib/common.sh 不存在"
    [ -f "$CODEX_DIR/hooks/lib/constraint.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/lib/constraint.sh 不存在"
    [ -f "$CODEX_DIR/hooks/managed/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/block_dangerous.sh 不存在"
    [ -x "$CODEX_DIR/hooks/managed/block_dangerous.sh" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/block_dangerous.sh 不可执行"
    [ -f "$CODEX_DIR/hooks/managed/context_contract_validator.py" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/context_contract_validator.py 不存在"
    [ -f "$CODEX_DIR/hooks/managed/codex_user_prompt_submit.py" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/codex_user_prompt_submit.py 不存在"
    [ -f "$CODEX_DIR/hooks/managed/codex_stop_dispatch.py" ] || fail "Quick Check 失败: ~/.codex/hooks/managed/codex_stop_dispatch.py 不存在"
    [ -f "$CODEX_DIR/hooks/registry.json" ] || fail "Quick Check 失败: ~/.codex/hooks/registry.json 不存在"
    [ -f "$CODEX_DIR/protocols/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.codex/protocols/phase-selection-protocol.md 不存在"
    [ ! -f "$CODEX_DIR/reference/phase-selection-protocol.md" ] || fail "Quick Check 失败: ~/.codex/reference/phase-selection-protocol.md 不应存在"
    quick_check_control_plane_files "$CODEX_DIR" "$HOME/.codex"
    runtime_noise_absent "$HOME/.agents" || fail "Quick Check 失败: ~/.agents 不应包含 __pycache__、*.pyc 或 .DS_Store"
    [ ! -e "$CODEX_DIR/.org-installed-version" ] || fail "Quick Check 失败: ~/.codex 不应残留 .org-installed-version"
    [ ! -e "$CODEX_DIR/.org-backups" ] || fail "Quick Check 失败: ~/.codex 不应残留 .org-backups"
    [ -f "$(target_state_dir codex)/installed-version" ] || fail "Quick Check 失败: ~/.org-skills-state/codex/installed-version 不存在"
    [ -f "$CODEX_DIR/hooks.json" ] || fail "Quick Check 失败: ~/.codex/hooks.json 不存在"
    grep -Fq 'hooks = true' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 未启用 hooks feature"
    ! grep -Eq '^[[:space:]]*codex_hooks[[:space:]]*=' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 不应保留已弃用的 codex_hooks feature"
    grep -Fq '[agents]' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 缺少 [agents]"
    grep -Fq 'max_threads = 6' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 缺少 agents.max_threads"
    grep -Fq 'max_depth = 1' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 缺少 agents.max_depth"
    grep -Fq 'job_max_runtime_seconds = 1800' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 缺少 agents.job_max_runtime_seconds"
    grep -Fq './agents/code-reviewer.toml' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 缺少 code-reviewer agent"
    grep -Fq './agents/consistency-auditor.toml' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 缺少 consistency-auditor agent"
    ! grep -Fq './agents/generic-code-reviewer.toml' "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml 不应保留 generic-code-reviewer agent"
    codex_agent_config_inherits_defaults "$CODEX_DIR/config.toml" || fail "Quick Check 失败: ~/.codex/config.toml agent 配置不应保留退休角色或钉死 model/model_reasoning_effort"
    codex_agent_files_match_contract "$CODEX_DIR" || fail "Quick Check 失败: ~/.codex/agents agent 文件不应钉死模型，且 developer_instructions 不应重复 skill 能力细节"
    for removed_feature in codex_hooks collaboration_modes sqlite steer tui_app_server; do
      ! grep -Eq "^[[:space:]]*${removed_feature}[[:space:]]*=" "$CODEX_DIR/config.toml" \
        || fail "Quick Check 失败: ~/.codex/config.toml 不应保留已移除的 ${removed_feature} feature"
    done
    ! grep -REq '^(model|model_reasoning_effort)[[:space:]]*=' "$CODEX_DIR/agents"/*.toml || fail "Quick Check 失败: ~/.codex/agents 不应钉死 model 或 model_reasoning_effort，应继承 Codex 默认设置"
    grep -Fq "$CODEX_DIR/hooks/managed/block_dangerous.sh" "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 managed dangerous hook"
    grep -Fq "$CODEX_DIR/hooks/managed/context_contract_validator.py" "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 context contract validator hook"
    grep -Fq "$CODEX_DIR/hooks/managed/codex_user_prompt_submit.py" "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 active skill tracker"
    grep -Fq "$CODEX_DIR/hooks/managed/codex_stop_dispatch.py" "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 stop dispatcher"
    grep -Fq '"SessionStart"' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 Codex SessionStart 事件面"
    grep -Fq '"PermissionRequest"' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 Codex PermissionRequest 事件面"
    grep -Fq '"PostToolUse"' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 Codex PostToolUse 事件面"
    grep -Fq '"matcher": "Write|Edit"' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 缺少 PostToolUse Write|Edit matcher"
    ! grep -Fq '"PostCompact"' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 不应渲染 Claude-only PostCompact"
    ! grep -Fq '"TaskCompleted"' "$CODEX_DIR/hooks.json" || fail "Quick Check 失败: ~/.codex/hooks.json 不应渲染 Claude-only TaskCompleted"
    if [ -f "$CODEX_DIR/hooks.json" ] && grep -Fq 'codex-hooks-probe.' "$CODEX_DIR/hooks.json"; then
      fail "Quick Check 失败: ~/.codex/hooks.json 不应残留 codex-hooks-probe 临时路径"
    fi
    check_codex_hook_trust
    runtime_noise_absent "$CODEX_DIR" || fail "Quick Check 失败: ~/.codex 不应包含 __pycache__、*.pyc 或 .DS_Store"
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

validate_python_launcher() {
  [ -n "$PYTHON_LAUNCHER" ] || fail "未找到 python3，无法安装 Python hooks"

  case "$PYTHON_LAUNCHER" in
    *[[:space:]]*)
      fail "Python hook launcher 不允许包含空白字符: $PYTHON_LAUNCHER"
      ;;
  esac

  if [ ! -x "$PYTHON_LAUNCHER" ]; then
    fail "Python hook launcher 不可执行: $PYTHON_LAUNCHER"
  fi
}

main() {
  parse_args "$@"
  validate_python_launcher
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

  local version_base git_hash version_tag fingerprint
  version_base="$(trim < "$REPO_ROOT/VERSION")"
  if git -C "$REPO_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
    git_hash="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
    if ! git -C "$REPO_ROOT" diff --quiet --ignore-submodules -- \
      || ! git -C "$REPO_ROOT" diff --cached --quiet --ignore-submodules --; then
      fingerprint="$(compute_repo_fingerprint)"
      git_hash="${git_hash}-dirty-${fingerprint}"
    fi
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
      configure_codex_agents
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
