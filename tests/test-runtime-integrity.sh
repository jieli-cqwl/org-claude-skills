#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
TMP_HOME="$(mktemp -d)"
STATE_ROOT="$TMP_HOME/.org-skills-state"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_runtime_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing runtime pattern in $file: $pattern"
}

assert_runtime_count() {
  local expected="$1"
  local pattern="$2"
  local file="$3"
  local actual
  actual="$( (rg -n "$pattern" "$file" 2>/dev/null || true) | wc -l | tr -d ' ' )"
  [ "$actual" = "$expected" ] || fail "unexpected runtime match count in $file: $pattern (expected $expected, got $actual)"
}

extract_global_doc_refs() {
  local source_file="$1"
  python3 - "$source_file" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
pattern = re.compile(r'(?:reference|protocols)/[^"\'` )(]+\.md')

for ref in sorted(set(pattern.findall(text))):
    print(ref)
PY
}

extract_skill_local_refs() {
  local source_file="$1"
  python3 - "$source_file" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
pattern = re.compile(r'reference(?:s)?/[^"\'` )(]+\.md')

for ref in sorted(set(pattern.findall(text))):
    print(ref)
PY
}

check_global_refs() {
  local runtime_dir="$1"
  local source_file ref skill_dir source_list ref_list

  source_list="$(mktemp)"
  ref_list="$(mktemp)"
  rg --files \
    "$runtime_dir/rules" \
    "$runtime_dir/reference" \
    "$runtime_dir/protocols" \
    "$runtime_dir/skills" \
    -g '*.md' \
    -g 'SKILL.md' | sort >"$source_list"

  while IFS= read -r source_file; do
    [ -f "$source_file" ] || continue
    extract_global_doc_refs "$source_file" >"$ref_list"
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      if [ -f "$runtime_dir/$ref" ]; then
        continue
      fi
      if [[ "$source_file" == "$runtime_dir"/skills/* ]]; then
        skill_dir="$(dirname "$source_file")"
        if [ -f "$skill_dir/$ref" ]; then
          continue
        fi
      fi
      fail "$source_file 引用了缺失全局文档: $ref"
    done <"$ref_list"
  done <"$source_list"

  rm -f "$source_list" "$ref_list"
}

check_skill_refs() {
  local runtime_dir="$1"
  local skill_dir skill_file ref ref_list

  ref_list="$(mktemp)"

  for skill_dir in "$runtime_dir"/skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_file="$skill_dir/SKILL.md"
    [ -f "$skill_file" ] || continue

    extract_skill_local_refs "$skill_file" >"$ref_list"
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      if [ -f "$skill_dir/$ref" ] || [ -f "$runtime_dir/$ref" ]; then
        continue
      fi
      fail "$skill_file 引用了缺失局部文档: $ref"
    done <"$ref_list"
  done

  rm -f "$ref_list"
}

check_no_claude_runtime_refs() {
  local runtime_dir="$1"
  if rg -n '\$HOME/\.claude|~/.claude' \
    "$runtime_dir/skills" \
    "$runtime_dir/reference" \
    "$runtime_dir/protocols" \
    "$runtime_dir/agents" \
    "$runtime_dir/hooks" >/tmp/org_runtime_no_claude_refs.out 2>&1; then
    cat /tmp/org_runtime_no_claude_refs.out >&2
    fail "$runtime_dir should not retain ~/.claude runtime references"
  fi
}

check_no_unrendered_placeholders() {
  local runtime_dir="$1"
  if rg -n '\{\{RUNTIME_HOME\}\}' \
    "$runtime_dir/skills" \
    "$runtime_dir/reference" \
    "$runtime_dir/protocols" \
    "$runtime_dir/agents" \
    "$runtime_dir/hooks" >/tmp/org_runtime_no_placeholders.out 2>&1; then
    cat /tmp/org_runtime_no_placeholders.out >&2
    fail "$runtime_dir should not retain {{RUNTIME_HOME}} placeholders"
  fi
}

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
TOML

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_runtime_integrity_install.out 2>&1 || {
  cat /tmp/org_runtime_integrity_install.out >&2
  fail "install failed"
}

test -f "$TMP_HOME/.claude/CLAUDE.md" || fail "missing ~/.claude/CLAUDE.md"
test -f "$TMP_HOME/.codex/AGENTS.md" || fail "missing ~/.codex/AGENTS.md"
python3 "$ROOT/tools/community/source_lock_check.py" || fail "source lock invalid"
python3 "$ROOT/tools/community/render_canonical.py" || fail "canonical assets missing"
test -f "$TMP_HOME/.claude/skills/brainstorming/SKILL.md" || fail "missing small-chain default skill brainstorming"
test -f "$TMP_HOME/.claude/skills/verification-before-completion/SKILL.md" || fail "missing ~/.claude/skills/verification-before-completion/SKILL.md"
test -f "$TMP_HOME/.claude/skills/finishing-a-development-branch/SKILL.md" || fail "missing ~/.claude/skills/finishing-a-development-branch/SKILL.md"
grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/using-superpowers/SKILL.md" || fail "using-superpowers should be manual-only in claude runtime"
test -f "$TMP_HOME/.claude/skills/verify-change/SKILL.md" || fail "missing ~/.claude/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.claude/skills/verify-change/scripts/check_task_plan_consistency.py" || fail "missing ~/.claude/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.claude/skills/archive/SKILL.md" || fail "missing ~/.claude/skills/archive/SKILL.md"
test -f "$TMP_HOME/.claude/skills/docx/SKILL.md" || fail "missing ~/.claude/skills/docx/SKILL.md"
test -f "$TMP_HOME/.claude/skills/skill-creator/SKILL.md" || fail "missing ~/.claude/skills/skill-creator/SKILL.md"
test -f "$TMP_HOME/.claude/skills/mcp-builder/SKILL.md" || fail "missing ~/.claude/skills/mcp-builder/SKILL.md"
test -f "$TMP_HOME/.claude/protocols/phase-selection-protocol.md" || fail "missing ~/.claude/protocols/phase-selection-protocol.md"
test -f "$TMP_HOME/.claude/protocols/review-fix-loop-protocol.md" || fail "missing ~/.claude/protocols/review-fix-loop-protocol.md"
test -f "$TMP_HOME/.claude/protocols/review-iteration-protocol.md" || fail "missing ~/.claude/protocols/review-iteration-protocol.md"
test -f "$TMP_HOME/.claude/protocols/team-review-protocol.md" || fail "missing ~/.claude/protocols/team-review-protocol.md"
test ! -f "$TMP_HOME/.claude/reference/phase-selection-protocol.md" || fail "protocol should not remain in ~/.claude/reference"
test -f "$TMP_HOME/.codex/skills/brainstorming/agents/openai.yaml" || fail "missing brainstorming codex adapter"
grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.codex/skills/using-superpowers/SKILL.md" || fail "using-superpowers should be manual-only in codex runtime"
test ! -f "$TMP_HOME/.codex/skills/using-superpowers/agents/openai.yaml" || fail "using-superpowers should be manual-only in codex runtime"
test ! -f "$TMP_HOME/.codex/skills/product/agents/openai.yaml" || fail "product should be manual-only in codex runtime"
test -f "$TMP_HOME/.codex/skills/verification-before-completion/SKILL.md" || fail "missing ~/.codex/skills/verification-before-completion/SKILL.md"
test -f "$TMP_HOME/.codex/skills/finishing-a-development-branch/SKILL.md" || fail "missing ~/.codex/skills/finishing-a-development-branch/SKILL.md"
test -f "$TMP_HOME/.codex/skills/verify-change/SKILL.md" || fail "missing ~/.codex/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.codex/skills/verify-change/scripts/check_task_plan_consistency.py" || fail "missing ~/.codex/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.codex/skills/archive/SKILL.md" || fail "missing ~/.codex/skills/archive/SKILL.md"
test -f "$TMP_HOME/.codex/skills/docx/agents/openai.yaml" || fail "missing ~/.codex/skills/docx/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/skill-creator/agents/openai.yaml" || fail "missing ~/.codex/skills/skill-creator/agents/openai.yaml"
test -f "$TMP_HOME/.codex/skills/mcp-builder/agents/openai.yaml" || fail "missing ~/.codex/skills/mcp-builder/agents/openai.yaml"
test -f "$TMP_HOME/.codex/protocols/phase-selection-protocol.md" || fail "missing ~/.codex/protocols/phase-selection-protocol.md"
test -f "$TMP_HOME/.codex/protocols/review-fix-loop-protocol.md" || fail "missing ~/.codex/protocols/review-fix-loop-protocol.md"
test -f "$TMP_HOME/.codex/protocols/review-iteration-protocol.md" || fail "missing ~/.codex/protocols/review-iteration-protocol.md"
test -f "$TMP_HOME/.codex/protocols/team-review-protocol.md" || fail "missing ~/.codex/protocols/team-review-protocol.md"
test ! -f "$TMP_HOME/.codex/reference/phase-selection-protocol.md" || fail "protocol should not remain in ~/.codex/reference"
test -f "$STATE_ROOT/claude/installed-version" || fail "missing claude state version"
test -f "$STATE_ROOT/codex/installed-version" || fail "missing codex state version"
test -f "$TMP_HOME/.claude/skills/codex-doc-review/SKILL.md" || fail "missing claude-only skill codex-doc-review"
test -f "$TMP_HOME/.claude/agents/codex-doc-reviewer.md" || fail "missing claude-only agent codex-doc-reviewer.md"
test -f "$TMP_HOME/.claude/agents/cross-review-lead.md" || fail "missing ~/.claude/agents/cross-review-lead.md"
test -f "$TMP_HOME/.claude/agents/cross-reviewer.md" || fail "missing ~/.claude/agents/cross-reviewer.md"
test ! -e "$TMP_HOME/.codex/skills/codex-doc-review" || fail "codex runtime should not contain claude-only skill codex-doc-review"
test ! -e "$TMP_HOME/.codex/agents/codex-doc-reviewer.md" || fail "codex runtime should not contain claude-only agent codex-doc-reviewer.md"
test -f "$TMP_HOME/.codex/agents/cross-review-lead.md" || fail "missing ~/.codex/agents/cross-review-lead.md"
test -f "$TMP_HOME/.codex/agents/cross-reviewer.md" || fail "missing ~/.codex/agents/cross-reviewer.md"

find "$TMP_HOME/.claude" -maxdepth 1 \( -name '.org-*' -o -name '.org-backups' \) | grep -q . && fail "runtime ~/.claude should not retain .org metadata"
find "$TMP_HOME/.codex" -maxdepth 1 \( -name '.org-*' -o -name '.org-backups' \) | grep -q . && fail "runtime ~/.codex should not retain .org metadata"

check_global_refs "$TMP_HOME/.claude"
check_global_refs "$TMP_HOME/.codex"
check_skill_refs "$TMP_HOME/.claude"
check_skill_refs "$TMP_HOME/.codex"
check_no_claude_runtime_refs "$TMP_HOME/.codex"
check_no_unrendered_placeholders "$TMP_HOME/.claude"
check_no_unrendered_placeholders "$TMP_HOME/.codex"

for runtime_dir in "$TMP_HOME/.claude" "$TMP_HOME/.codex"; do
  assert_runtime_present 'Treat "可以交付了" / "ready to ship" as a closeout trigger' "$runtime_dir/skills/verification-before-completion/SKILL.md"
  assert_runtime_present '1\. Small-chain artifacts exist' "$runtime_dir/skills/verification-before-completion/SKILL.md"
  assert_runtime_present 'before any merge, PR, archive' "$runtime_dir/skills/verification-before-completion/SKILL.md"
  assert_runtime_present 'before branch integration or archive' "$runtime_dir/skills/verify-change/SKILL.md"
  assert_runtime_present 'If branch integration or worktree cleanup is still pending' "$runtime_dir/skills/verify-change/SKILL.md"
  assert_runtime_present 'Require verify-change PASS' "$runtime_dir/skills/finishing-a-development-branch/SKILL.md"
  assert_runtime_present 'Archive is only valid after the change is integrated on the target branch' "$runtime_dir/skills/finishing-a-development-branch/SKILL.md"

  assert_runtime_present 'challenge_result' "$runtime_dir/protocols/team-review-protocol.md"
  assert_runtime_present 'lead_decision' "$runtime_dir/protocols/team-review-protocol.md"
  assert_runtime_present '\[FALLBACK-MODE\]' "$runtime_dir/protocols/team-review-protocol.md"

  assert_runtime_present 'protocols/team-review-protocol.md' "$runtime_dir/skills/product/SKILL.md"
  assert_runtime_present 'R2\.5' "$runtime_dir/skills/product/SKILL.md"
  assert_runtime_present 'fix_mode=user_directed' "$runtime_dir/skills/product/SKILL.md"
  assert_runtime_present '仅对 FAIL 视角重审' "$runtime_dir/skills/product/SKILL.md"
  assert_runtime_present 'Team 模式.*发送结构化消息给 Review Lead' "$runtime_dir/skills/product/references/prd-reviewer-prompt.md"
  assert_runtime_present 'fallback.*直接写' "$runtime_dir/skills/product/references/prd-reviewer-prompt.md"
  assert_runtime_present 'Team 模式.*发送结构化消息给 Review Lead' "$runtime_dir/skills/product/references/architect-reviewer-prompt.md"
  assert_runtime_present 'fallback.*直接写' "$runtime_dir/skills/product/references/architect-reviewer-prompt.md"
  assert_runtime_present 'Team 模式.*发送结构化消息给 Review Lead' "$runtime_dir/skills/product/references/tester-reviewer-prompt.md"
  assert_runtime_present 'fallback.*直接写' "$runtime_dir/skills/product/references/tester-reviewer-prompt.md"

  assert_runtime_present 'protocols/team-review-protocol.md' "$runtime_dir/skills/design/SKILL.md"
  assert_runtime_present 'R2\.5' "$runtime_dir/skills/design/SKILL.md"
  assert_runtime_present 'fix_mode=user_directed' "$runtime_dir/skills/design/SKILL.md"
  assert_runtime_present '仅对 FAIL 视角重审' "$runtime_dir/skills/design/SKILL.md"
  assert_runtime_present 'Team 模式.*发送结构化消息给 Review Lead' "$runtime_dir/skills/design/references/design-reviewer-prompt.md"
  assert_runtime_present 'fallback.*直接写' "$runtime_dir/skills/design/references/design-reviewer-prompt.md"
  assert_runtime_present 'Team 模式.*发送结构化消息给 Review Lead' "$runtime_dir/skills/design/references/design-product-reviewer-prompt.md"
  assert_runtime_present 'fallback.*直接写' "$runtime_dir/skills/design/references/design-product-reviewer-prompt.md"
  assert_runtime_present 'Team 模式.*发送结构化消息给 Review Lead' "$runtime_dir/skills/design/references/design-test-reviewer-prompt.md"
  assert_runtime_present 'fallback.*直接写' "$runtime_dir/skills/design/references/design-test-reviewer-prompt.md"

  assert_runtime_count 3 '^\| Issue ID \| Severity \| 状态 \| 维度 \| 发现 \| 证据 \| 建议承接位置 \|$' "$runtime_dir/skills/product/references/templates/product-cross-review-template.md"
  assert_runtime_count 1 '^## 横向质疑记录$' "$runtime_dir/skills/product/references/templates/product-cross-review-template.md"
  assert_runtime_count 3 '^\| Issue ID \| Severity \| 状态 \| 维度 \| 发现 \| 证据 \| 建议承接位置 \|$' "$runtime_dir/skills/design/references/templates/design-cross-review-template.md"
  assert_runtime_count 1 '^## 横向质疑记录$' "$runtime_dir/skills/design/references/templates/design-cross-review-template.md"
  assert_runtime_present '\[DISPUTED\]' "$runtime_dir/skills/product/references/templates/prd-template.md"
  assert_runtime_present '\[DISPUTED\]' "$runtime_dir/skills/design/references/templates/design-template.md"
done

echo "[PASS] runtime integrity"
