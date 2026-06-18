#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERVIEW_DIR="$ROOT/shared/skills/overview"
DIR_TREE="$OVERVIEW_DIR/scripts/dir-tree.sh"
PROJECT_DETECT="$OVERVIEW_DIR/scripts/project-detect.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

require_output_contains() {
  local output="$1"
  local needle="$2"
  local label="$3"

  case "$output" in
    *"$needle"*) ;;
    *) fail "$label missing expected output: $needle" ;;
  esac
}

make_no_tree_path() {
  local bin_dir="$TMP_DIR/no-tree-bin"
  local tool

  mkdir -p "$bin_dir"
  for tool in dirname find sort awk tr; do
    local tool_path
    tool_path="$(command -v "$tool")" || fail "missing required test tool: $tool"
    ln -sf "$tool_path" "$bin_dir/$tool"
  done
  printf '%s\n' "$bin_dir"
}

assert_dir_tree_fallback_handles_globs_and_spaces() {
  local cwd="$TMP_DIR/glob-cwd"
  local project="$cwd/project with spaces"
  local output
  local status=0

  mkdir -p "$cwd/tests/__pycache__" "$project/src/app"
  printf 'pyc fixture\n' >"$cwd/tests/__pycache__/expanded.pyc"

  output="$(
    cd "$cwd"
    PATH="$(make_no_tree_path)" /bin/bash "$DIR_TREE" "$project" 3
  )" || status=$?
  [ "$status" -eq 0 ] || fail "dir-tree fallback should handle glob expansion and spaces; exit=$status output=$output"

  require_output_contains "$output" "$project" "dir-tree fallback"
  require_output_contains "$output" "src/" "dir-tree fallback"
  require_output_contains "$output" "app/" "dir-tree fallback"
}

assert_dir_tree_rejects_invalid_depth() {
  local project="$TMP_DIR/depth-project"
  local output

  mkdir -p "$project/src"
  if output="$(PATH="$(make_no_tree_path)" /bin/bash "$DIR_TREE" "$project" not-a-number 2>&1)"; then
    fail "dir-tree should reject non-numeric depth"
  fi

  require_output_contains "$output" "Depth must be a positive integer" "dir-tree invalid-depth error"
}

assert_project_detect_typescript_vite() {
  local project="$TMP_DIR/typescript-vite"
  local output

  mkdir -p "$project/src"
  printf '{"scripts":{"dev":"vite"},"dependencies":{"vite":"latest"}}\n' >"$project/package.json"
  printf '{"compilerOptions":{}}\n' >"$project/tsconfig.json"
  printf 'export default {}\n' >"$project/vite.config.ts"
  printf 'console.log("hello")\n' >"$project/src/main.ts"

  output="$("$PROJECT_DETECT" "$project")"
  python3 - "$output" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["language"] == "typescript", payload
assert payload["framework"] == "vite", payload
assert any(path.endswith("src/main.ts") for path in payload["entry_files"]), payload
assert any(path.endswith("package.json") for path in payload["config_files"]), payload
PY
}

assert_overview_runtime_steps_exclude_maintenance_sync() {
  python3 - "$OVERVIEW_DIR/SKILL.md" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
try:
    workflow = text.split("## 流程", 1)[1].split("## 项目类型识别", 1)[0]
except IndexError as exc:
    raise SystemExit("overview SKILL.md must keep a workflow section before project-type detection") from exc

for line in workflow.splitlines():
    if "Sync:" not in line:
        continue
    sync_text = line.split("Sync:", 1)[1]
    forbidden_terms = ("更新", "治理测试", "模板", "template")
    if any(term in sync_text for term in forbidden_terms):
        raise SystemExit("overview runtime Sync field must not assign maintainer update work")
PY
}

assert_overview_formal_path_is_agent_team_only() {
  python3 - "$OVERVIEW_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

overview_dir = Path(sys.argv[1])
checked_files = [
    overview_dir / "SKILL.md",
    overview_dir / "references" / "mode-selection.md",
    overview_dir / "references" / "agent-assignments.md",
    overview_dir / "test-prompts.json",
]

for path in checked_files:
    text = path.read_text(encoding="utf-8")
    for forbidden in ("串行", "轻量"):
        if forbidden in text:
            raise SystemExit(f"{path.relative_to(overview_dir.parent.parent.parent)} must not contain formal overview fallback term: {forbidden}")

skill_text = (overview_dir / "SKILL.md").read_text(encoding="utf-8")
frontmatter = skill_text.split("---", 2)[1]
if "disable-model-invocation: true" not in frontmatter:
    raise SystemExit("overview SKILL.md frontmatter must disable direct model invocation")
allowed_tools = next(
    (
        line.split(":", 1)[1]
        for line in frontmatter.splitlines()
        if line.startswith("allowed-tools:")
    ),
    "",
)
for tool in ("Agent", "AskUserQuestion"):
    if tool not in allowed_tools:
        raise SystemExit(f"overview SKILL.md allowed-tools must include {tool}")

step_matches = list(re.finditer(r"(?m)^(\d+)\. .+$", skill_text))
steps = {}
for index, match in enumerate(step_matches):
    end = step_matches[index + 1].start() if index + 1 < len(step_matches) else len(skill_text)
    steps[int(match.group(1))] = skill_text[match.start():end]
if "AskUserQuestion" not in steps.get(2, ""):
    raise SystemExit("overview step 2 must require AskUserQuestion before execution")
if "references/mode-selection.md" not in steps.get(2, ""):
    raise SystemExit("overview step 2 must bind mode-selection reference")
if "agent team" not in steps.get(3, ""):
    raise SystemExit("overview step 3 must execute through agent team")

mode_lines = (
    overview_dir / "references" / "mode-selection.md"
).read_text(encoding="utf-8").splitlines()
choices = [
    line.split("`", 2)[1]
    for line in mode_lines
    if line.startswith("- `") and "`：" in line
]
if choices != ["确认执行 agent team", "暂停执行"]:
    raise SystemExit(f"overview mode-selection choices must only expose agent team confirmation or pause: {choices}")

prompts = json.loads((overview_dir / "test-prompts.json").read_text(encoding="utf-8"))
for item in prompts:
    expected = item.get("expected", "")
    if "agent team" not in expected:
        raise SystemExit(f"overview test prompt {item.get('id')} must expect agent-team execution")
PY
}

assert_dir_tree_fallback_handles_globs_and_spaces
assert_dir_tree_rejects_invalid_depth
assert_project_detect_typescript_vite
assert_overview_runtime_steps_exclude_maintenance_sync
assert_overview_formal_path_is_agent_team_only

printf '[PASS] overview skill contract\n'
