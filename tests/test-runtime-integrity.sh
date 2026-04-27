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

assert_runtime_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected runtime pattern in $file: $pattern"
  fi
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
pattern = re.compile(
    r'(?:\{\{RUNTIME_HOME\}\}|\$HOME/\.(?:claude|codex)|~/\.(?:claude|codex))/'
    r'((?:reference|protocols|rules)/[^"\'` )(]+\.md)'
)

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
# Allow local references inside the same skill directory, and sibling skill
# references such as ../qa/projections/qa-report-template.md.
pattern = re.compile(r'(?:\.\./)+[^"\'` )(]+\.md|reference(?:s)?/[^"\'` )(]+\.md')

for ref in sorted(set(pattern.findall(text))):
    print(ref)
PY
}

check_global_refs() {
  local runtime_dir="$1"
  local source_file ref skill_dir source_list ref_list

  source_list="$(mktemp)"
  ref_list="$(mktemp)"
  {
    [ -f "$runtime_dir/CLAUDE.md" ] && printf '%s\n' "$runtime_dir/CLAUDE.md"
    [ -f "$runtime_dir/AGENTS.md" ] && printf '%s\n' "$runtime_dir/AGENTS.md"
    rg --files \
      "$runtime_dir/rules" \
      "$runtime_dir/reference" \
      "$runtime_dir/protocols" \
      "$runtime_dir/skills" \
      "$runtime_dir/agents" \
      -g '*.md' \
      -g 'SKILL.md'
  } | sort >"$source_list"

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
  python3 - "$runtime_dir" <<'PY' || fail "$runtime_dir should not retain ~/.claude runtime references"
import re
import sys
from pathlib import Path

runtime = Path(sys.argv[1])
paths = [
    runtime / "CLAUDE.md",
    runtime / "AGENTS.md",
    runtime / "rules",
]
pattern = re.compile(r'\$HOME/\.claude|~/.claude')
allowed_suffixes = {".md", ".sh", ".json", ".toml", ".yaml"}
violations = []

for base in paths:
    if base.is_file():
        iter_paths = [base]
    else:
        iter_paths = [path for path in base.rglob("*") if path.is_file() and path.suffix in allowed_suffixes]
    for path in iter_paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            if pattern.search(line):
                violations.append(f"{path}:{lineno}:{line.strip()}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY
}

check_no_codex_runtime_refs() {
  local runtime_dir="$1"
  python3 - "$runtime_dir" <<'PY' || fail "$runtime_dir should not retain ~/.codex runtime references"
import re
import sys
from pathlib import Path

runtime = Path(sys.argv[1])
paths = [
    runtime / "CLAUDE.md",
    runtime / "AGENTS.md",
    runtime / "rules",
]
pattern = re.compile(r'\$HOME/\.codex|~/.codex')
allowed_suffixes = {".md", ".sh", ".json", ".toml", ".yaml"}
violations = []

for base in paths:
    if base.is_file():
        iter_paths = [base]
    else:
        iter_paths = [path for path in base.rglob("*") if path.is_file() and path.suffix in allowed_suffixes]
    for path in iter_paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            if pattern.search(line):
                violations.append(f"{path}:{lineno}:{line.strip()}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY
}

check_no_unrendered_placeholders() {
  local runtime_dir="$1"
  python3 - "$runtime_dir" <<'PY' || fail "$runtime_dir should not retain runtime placeholders"
import re
import sys
from pathlib import Path

runtime = Path(sys.argv[1])
paths = [
    runtime / "CLAUDE.md",
    runtime / "AGENTS.md",
    runtime / "rules",
    runtime / "reference",
    runtime / "protocols",
    runtime / "skills",
    runtime / "agents",
    runtime / "hooks",
]
pattern = re.compile(r'\{\{(?:RUNTIME_HOME|ENTRY_DOC|RUNTIME_[A-Z0-9_]+)\}\}')
allowed_suffixes = {".md", ".sh", ".json", ".toml", ".yaml"}
violations = []

for base in paths:
    if base.is_file():
        iter_paths = [base]
    else:
        iter_paths = [path for path in base.rglob("*") if path.is_file() and path.suffix in allowed_suffixes]
    for path in iter_paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            if pattern.search(line):
                violations.append(f"{path}:{lineno}:{line.strip()}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY
}

check_no_bare_runtime_refs() {
  local runtime_dir="$1"
  python3 - "$runtime_dir" <<'PY' || fail "$runtime_dir should not retain bare runtime doc references"
import re
import sys
from pathlib import Path

runtime = Path(sys.argv[1])
paths = [
    runtime / "CLAUDE.md",
    runtime / "AGENTS.md",
    runtime / "rules",
    runtime / "reference",
    runtime / "protocols",
    runtime / "skills",
    runtime / "agents",
]
pattern = re.compile(
    r'\b(?:reference|protocols|rules)/[^"\'` )(]+\.md'
    r'|\bskills/[^"\'` )(]+/references/[^"\'` )(]+\.md'
)
allowed_prefixes = ("$HOME/.claude/", "$HOME/.codex/", ".claude/", ".codex/", "./", "../")
violations = []

for base in paths:
    iter_paths = [base] if base.is_file() else base.rglob("*.md")
    for path in iter_paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            for match in pattern.finditer(line):
                ref = match.group(0)
                try:
                    rel = path.relative_to(runtime / "skills")
                except ValueError:
                    rel = None
                if rel is not None:
                    skill_dir = runtime / "skills" / rel.parts[0]
                    if (skill_dir / ref).is_file():
                        continue
                prefix = line[:match.start()]
                if "docs/archive/" in prefix:
                    continue
                if prefix.endswith(allowed_prefixes):
                    continue
                violations.append(f"{path}:{lineno}:{line.strip()}")
                break

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY
}

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
TOML
mkdir -p "$TMP_HOME/.codex/skills/project-agents-init"
printf 'legacy retired skill\n' > "$TMP_HOME/.codex/skills/project-agents-init/SKILL.md"

env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_runtime_integrity_install.out 2>&1 || {
  cat /tmp/org_runtime_integrity_install.out >&2
  fail "install failed"
}

test -f "$TMP_HOME/.claude/CLAUDE.md" || fail "missing ~/.claude/CLAUDE.md"
test -f "$TMP_HOME/.codex/AGENTS.md" || fail "missing ~/.codex/AGENTS.md"
python3 "$ROOT/tools/community/source_lock_check.py" || fail "source lock invalid"
python3 "$ROOT/tools/community/render_canonical.py" || fail "canonical assets missing"
for validator_tool in \
  normalize_canonical_artifact.py \
  validate_canonical_schema.py \
  validate_canonical_rules.py \
  resolve_evidence_refs.py \
  validate_projection_manifest.py \
  validate_standard_chain_phase.py; do
  test -f "$ROOT/tools/community/$validator_tool" || fail "missing validator tool $validator_tool"
done
python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --help >/dev/null || fail "validator phase tool should be runnable"
test -f "$TMP_HOME/.claude/skills/brainstorming/SKILL.md" || fail "missing small-chain default skill brainstorming"
test -f "$TMP_HOME/.claude/skills/verification-before-completion/SKILL.md" || fail "missing ~/.claude/skills/verification-before-completion/SKILL.md"
test -f "$TMP_HOME/.claude/skills/finishing-a-development-branch/SKILL.md" || fail "missing ~/.claude/skills/finishing-a-development-branch/SKILL.md"
grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/using-superpowers/SKILL.md" || fail "using-superpowers should be manual-only in claude runtime"
test -f "$TMP_HOME/.claude/skills/verify-change/SKILL.md" || fail "missing ~/.claude/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.claude/skills/verify-change/scripts/check_task_plan_consistency.py" || fail "missing ~/.claude/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.claude/skills/archive/SKILL.md" || fail "missing ~/.claude/skills/archive/SKILL.md"
test -f "$TMP_HOME/.claude/skills/code-review-fix/SKILL.md" || fail "missing ~/.claude/skills/code-review-fix/SKILL.md"
test -f "$TMP_HOME/.claude/skills/doc-review-fix/SKILL.md" || fail "missing ~/.claude/skills/doc-review-fix/SKILL.md"
test -f "$TMP_HOME/.claude/skills/docx/SKILL.md" || fail "missing ~/.claude/skills/docx/SKILL.md"
test -f "$TMP_HOME/.claude/skills/skill-creator/SKILL.md" || fail "missing ~/.claude/skills/skill-creator/SKILL.md"
test ! -e "$TMP_HOME/.claude/skills/new-skills" || fail "new-skills should not install into claude runtime"
test -f "$TMP_HOME/.claude/skills/mcp-builder/SKILL.md" || fail "missing ~/.claude/skills/mcp-builder/SKILL.md"
test -f "$TMP_HOME/.claude/skills/feishu-docs/SKILL.md" || fail "missing ~/.claude/skills/feishu-docs/SKILL.md"
test -f "$TMP_HOME/.claude/skills/deep-research/SKILL.md" || fail "missing ~/.claude/skills/deep-research/SKILL.md"
test -f "$TMP_HOME/.claude/skills/find-skills/SKILL.md" || fail "missing ~/.claude/skills/find-skills/SKILL.md"
test -f "$TMP_HOME/.claude/skills/agent-browser/SKILL.md" || fail "missing ~/.claude/skills/agent-browser/SKILL.md"
test -f "$TMP_HOME/.claude/protocols/phase-selection-protocol.md" || fail "missing ~/.claude/protocols/phase-selection-protocol.md"
test ! -f "$TMP_HOME/.claude/reference/phase-selection-protocol.md" || fail "protocol should not remain in ~/.claude/reference"
test -f "$TMP_HOME/.codex/skills/brainstorming/agents/openai.yaml" || fail "missing brainstorming codex adapter"
grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.codex/skills/using-superpowers/SKILL.md" || fail "using-superpowers should be manual-only in codex runtime"
test ! -f "$TMP_HOME/.codex/skills/using-superpowers/agents/openai.yaml" || fail "using-superpowers should be manual-only in codex runtime"
test ! -f "$TMP_HOME/.codex/skills/product-director/agents/openai.yaml" || fail "product-director should be manual-only in codex runtime"
test ! -f "$TMP_HOME/.codex/skills/product-manager/agents/openai.yaml" || fail "product-manager should be manual-only in codex runtime"
for skill in ai-cli-updater skill-harness feishu-docs deep-research algorithmic-art brand-guidelines canvas-design darwin-skill ui-ux-pro-max doc-coauthoring docx internal-comms mcp-builder pdf pptx slack-gif-creator theme-factory web-artifacts-builder xlsx agent-browser; do
  grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/$skill/SKILL.md" || fail "$skill should be manual-only in claude runtime"
  grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.codex/skills/$skill/SKILL.md" || fail "$skill should be manual-only in codex runtime"
  test ! -f "$TMP_HOME/.codex/skills/$skill/agents/openai.yaml" || fail "$skill should be manual-only in codex runtime"
done
test ! -e "$TMP_HOME/.claude/skills/skill-auditor" || fail "skill-auditor should not install into claude runtime"
test ! -e "$TMP_HOME/.codex/skills/skill-auditor" || fail "skill-auditor should not install into codex runtime"
test -f "$TMP_HOME/.claude/skills/webapp-testing/SKILL.md" || fail "missing ~/.claude/skills/webapp-testing/SKILL.md"
if grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/webapp-testing/SKILL.md"; then
  fail "webapp-testing should remain auto-visible in claude runtime"
fi
test -f "$TMP_HOME/.codex/skills/webapp-testing/SKILL.md" || fail "missing ~/.codex/skills/webapp-testing/SKILL.md"
test -f "$TMP_HOME/.codex/skills/webapp-testing/agents/openai.yaml" || fail "webapp-testing should remain auto-visible in codex runtime"
if grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.codex/skills/webapp-testing/SKILL.md"; then
  fail "webapp-testing should remain auto-visible in codex runtime"
fi
test -f "$TMP_HOME/.codex/skills/verification-before-completion/SKILL.md" || fail "missing ~/.codex/skills/verification-before-completion/SKILL.md"
test -f "$TMP_HOME/.codex/skills/feishu-docs/SKILL.md" || fail "missing ~/.codex/skills/feishu-docs/SKILL.md"
test -f "$TMP_HOME/.codex/skills/deep-research/SKILL.md" || fail "missing ~/.codex/skills/deep-research/SKILL.md"
test -f "$TMP_HOME/.codex/skills/finishing-a-development-branch/SKILL.md" || fail "missing ~/.codex/skills/finishing-a-development-branch/SKILL.md"
test -f "$TMP_HOME/.codex/skills/verify-change/SKILL.md" || fail "missing ~/.codex/skills/verify-change/SKILL.md"
test -f "$TMP_HOME/.codex/skills/verify-change/scripts/check_task_plan_consistency.py" || fail "missing ~/.codex/skills/verify-change/scripts/check_task_plan_consistency.py"
test -f "$TMP_HOME/.codex/skills/archive/SKILL.md" || fail "missing ~/.codex/skills/archive/SKILL.md"
test ! -e "$TMP_HOME/.codex/skills/code-review-fix" || fail "codex runtime should not contain claude-only skill code-review-fix"
test ! -e "$TMP_HOME/.codex/skills/doc-review-fix" || fail "codex runtime should not contain claude-only skill doc-review-fix"
test ! -e "$TMP_HOME/.codex/skills/review-fix-loop" || fail "codex runtime should not contain claude-only skill review-fix-loop"
test ! -f "$TMP_HOME/.codex/skills/docx/agents/openai.yaml" || fail "docx should be manual-only in codex runtime"
test -f "$TMP_HOME/.codex/skills/skill-creator/agents/openai.yaml" || fail "missing ~/.codex/skills/skill-creator/agents/openai.yaml"
test ! -e "$TMP_HOME/.codex/skills/new-skills" || fail "new-skills should not install into codex runtime"
test ! -f "$TMP_HOME/.codex/skills/mcp-builder/agents/openai.yaml" || fail "mcp-builder should be manual-only in codex runtime"
test -f "$TMP_HOME/.codex/skills/find-skills/SKILL.md" || fail "missing ~/.codex/skills/find-skills/SKILL.md"
test -f "$TMP_HOME/.codex/skills/agent-browser/SKILL.md" || fail "missing ~/.codex/skills/agent-browser/SKILL.md"
test -f "$TMP_HOME/.codex/skills/find-skills/agents/openai.yaml" || fail "missing ~/.codex/skills/find-skills/agents/openai.yaml"
test ! -f "$TMP_HOME/.codex/skills/agent-browser/agents/openai.yaml" || fail "agent-browser should be manual-only in codex runtime"
test ! -e "$TMP_HOME/.codex/skills/project-agents-init" || fail "codex runtime should not retain retired skill project-agents-init"
test -f "$TMP_HOME/.codex/protocols/phase-selection-protocol.md" || fail "missing ~/.codex/protocols/phase-selection-protocol.md"
test ! -f "$TMP_HOME/.codex/reference/phase-selection-protocol.md" || fail "protocol should not remain in ~/.codex/reference"
test -f "$STATE_ROOT/claude/installed-version" || fail "missing claude state version"
test -f "$STATE_ROOT/codex/installed-version" || fail "missing codex state version"
test ! -e "$TMP_HOME/.claude/skills/codex-doc-review" || fail "claude runtime should not contain retired skill codex-doc-review"
test ! -e "$TMP_HOME/.claude/agents/codex-doc-reviewer.md" || fail "claude runtime should not contain retired agent codex-doc-reviewer.md"
test ! -e "$TMP_HOME/.codex/skills/codex-doc-review" || fail "codex runtime should not contain claude-only skill codex-doc-review"
test ! -e "$TMP_HOME/.codex/agents/codex-doc-reviewer.md" || fail "codex runtime should not contain claude-only agent codex-doc-reviewer.md"
grep -Fq "bash \$HOME/.claude/hooks/block_dangerous.sh" "$TMP_HOME/.claude/settings.json" || fail "missing ~/.claude/settings.json managed hook: block_dangerous"
grep -Fq "bash \$HOME/.claude/hooks/code_quality_check.sh" "$TMP_HOME/.claude/settings.json" || fail "missing ~/.claude/settings.json managed hook: code_quality_check"
grep -Fq "bash \$HOME/.claude/hooks/auto_format.sh" "$TMP_HOME/.claude/settings.json" || fail "missing ~/.claude/settings.json managed hook: auto_format"
grep -Fq "bash \$HOME/.claude/hooks/post_compact.sh" "$TMP_HOME/.claude/settings.json" || fail "missing ~/.claude/settings.json managed hook: post_compact"
grep -Fq "bash \$HOME/.claude/hooks/task_verify.sh" "$TMP_HOME/.claude/settings.json" || fail "missing ~/.claude/settings.json managed hook: task_verify"
test -x "$TMP_HOME/.claude/hooks/block_dangerous.sh" || fail "claude dangerous hook wrapper should be executable"
test -x "$TMP_HOME/.claude/hooks/managed/block_dangerous.sh" || fail "claude managed dangerous hook should be executable"
printf '{}' | bash "$TMP_HOME/.claude/hooks/block_dangerous.sh" >/dev/null 2>&1 || fail "claude dangerous hook wrapper should run without permission errors"
test -x "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" || fail "codex managed dangerous hook should be executable"
printf '{}' | bash "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" >/dev/null 2>&1 || fail "codex managed dangerous hook should run without permission errors"
find "$TMP_HOME/.claude" -maxdepth 1 \( -name '.org-*' -o -name '.org-backups' \) | grep -q . && fail "runtime ~/.claude should not retain .org metadata"
find "$TMP_HOME/.codex" -maxdepth 1 \( -name '.org-*' -o -name '.org-backups' \) | grep -q . && fail "runtime ~/.codex should not retain .org metadata"

check_global_refs "$TMP_HOME/.claude"
check_global_refs "$TMP_HOME/.codex"
check_skill_refs "$TMP_HOME/.claude"
check_skill_refs "$TMP_HOME/.codex"
check_no_claude_runtime_refs "$TMP_HOME/.codex"
check_no_codex_runtime_refs "$TMP_HOME/.claude"
check_no_unrendered_placeholders "$TMP_HOME/.claude"
check_no_unrendered_placeholders "$TMP_HOME/.codex"
check_no_bare_runtime_refs "$TMP_HOME/.claude"
check_no_bare_runtime_refs "$TMP_HOME/.codex"

for runtime_dir in "$TMP_HOME/.claude" "$TMP_HOME/.codex"; do
  entry_file="$runtime_dir/CLAUDE.md"
  [ -f "$entry_file" ] || entry_file="$runtime_dir/AGENTS.md"
  runtime_home="\\\$HOME/\\.codex"
  if [ "$runtime_dir" = "$TMP_HOME/.claude" ]; then
    runtime_home="\\\$HOME/\\.claude"
  fi

  assert_runtime_present '^## Runtime Contract$' "$entry_file"
  assert_runtime_absent '^## 配置导航$' "$entry_file"
  assert_runtime_present '硬约束加载' "$entry_file"
  assert_runtime_present '关键补充不可读' "$entry_file"
  assert_runtime_present "${runtime_home}/rules/铁律\\.md" "$entry_file"
  assert_runtime_present "${runtime_home}/reference/测试规范\\.md" "$entry_file"
  assert_runtime_present "${runtime_home}/reference/代码复用\\.md" "$entry_file"
  assert_runtime_present "${runtime_home}/reference/完成前验证\\.md" "$entry_file"
  assert_runtime_present "${runtime_home}/reference/全栈开发\\.md" "$entry_file"
  assert_runtime_present "${runtime_home}/reference/性能效率\\.md" "$entry_file"
  assert_runtime_present "${runtime_home}/reference/硬编码治理规范\\.md" "$entry_file"
  assert_runtime_present "${runtime_home}/reference/代码质量\\.md" "$entry_file"
  assert_runtime_present '新增实现前判断复用' "$entry_file"
  assert_runtime_present '当前任务已触发且会影响 rules 结论、成功标准或验收口径' "$entry_file"
  assert_runtime_present '用户目标、失败代价、非协商约束和质量属性排序' "$entry_file"
  assert_runtime_present 'I/O 密集使用有界并发' "$entry_file"
  assert_runtime_present '稳定共享语义或公共契约' "$entry_file"
  assert_runtime_present '用户路径、业务不变量' "$entry_file"
  assert_runtime_absent '复用举证与新建门禁' "$entry_file"
  assert_runtime_absent '创建、更新文档' "$entry_file"
  assert_runtime_absent "${runtime_home}/reference/文档规范\\.md" "$entry_file"

  assert_runtime_present '^## Runtime Contract$' "$runtime_dir/rules/铁律.md"
  assert_runtime_present '规则优先级' "$runtime_dir/rules/铁律.md"
  assert_runtime_present '允许为定位根因而进行受控诊断、证据收集和问题复现' "$runtime_dir/rules/铁律.md"
  assert_runtime_absent '测试分层与真实依赖' "$runtime_dir/rules/铁律.md"
  assert_runtime_count 1 "${runtime_home}/reference/测试规范\\.md" "$runtime_dir/rules/铁律.md"
  assert_runtime_count 1 "${runtime_home}/reference/全栈开发\\.md" "$runtime_dir/rules/铁律.md"
  assert_runtime_count 1 "${runtime_home}/reference/完成前验证\\.md" "$runtime_dir/rules/铁律.md"

  assert_runtime_present '^## Runtime Contract$' "$runtime_dir/rules/代码规范.md"
  assert_runtime_absent '代码质量指南' "$runtime_dir/rules/代码规范.md"
  assert_runtime_absent '复用原则补充' "$runtime_dir/rules/代码规范.md"
  assert_runtime_absent '复用举证门禁' "$runtime_dir/rules/代码规范.md"
  assert_runtime_count 1 "${runtime_home}/reference/测试规范\\.md" "$runtime_dir/rules/代码规范.md"
  assert_runtime_count 2 "${runtime_home}/reference/代码质量\\.md" "$runtime_dir/rules/代码规范.md"
  assert_runtime_count 1 "${runtime_home}/reference/硬编码治理规范\\.md" "$runtime_dir/rules/代码规范.md"
  assert_runtime_count 1 "${runtime_home}/reference/性能效率\\.md" "$runtime_dir/rules/代码规范.md"
  assert_runtime_count 1 "${runtime_home}/reference/代码复用\\.md" "$runtime_dir/rules/代码规范.md"

  assert_runtime_present '^## Runtime Contract$' "$runtime_dir/rules/执行纪律.md"
  assert_runtime_present '流程纪律' "$runtime_dir/rules/执行纪律.md"
  assert_runtime_present '确认前不执行' "$runtime_dir/rules/执行纪律.md"
  assert_runtime_present "若运行面提供 \`AskUserQuestion\`，优先使用" "$runtime_dir/rules/执行纪律.md"
  assert_runtime_present '成功标准必须明确达成什么结果' "$runtime_dir/rules/执行纪律.md"
  assert_runtime_present '验证未通过前不得声称完成' "$runtime_dir/rules/执行纪律.md"

  assert_runtime_present '^## Runtime Contract$' "$runtime_dir/rules/文档管理.md"
  assert_runtime_present '文档同步' "$runtime_dir/rules/文档管理.md"
  assert_runtime_absent '文档格式补充' "$runtime_dir/rules/文档管理.md"
  assert_runtime_absent "${runtime_home}/reference/文档规范\\.md" "$runtime_dir/rules/文档管理.md"

  assert_runtime_present 'Phase 1-3 属于铁律允许的受控诊断范围' "$runtime_dir/reference/系统调试.md"
  assert_runtime_present 'Phase 4 仅在根因已确认、修复不改变原目标与验收标准时进入' "$runtime_dir/reference/系统调试.md"
  assert_runtime_present '^## 轻量改动路径$' "$runtime_dir/reference/完成前验证.md"
  assert_runtime_present 'docs-only / script-only / config-only' "$runtime_dir/reference/完成前验证.md"
  assert_runtime_present '不必发明空壳命令' "$runtime_dir/reference/完成前验证.md"

  assert_runtime_present 'Treat "可以交付了" / "ready to ship" as a closeout trigger' "$runtime_dir/skills/verification-before-completion/SKILL.md"
  assert_runtime_present '1\. Small-chain artifacts exist' "$runtime_dir/skills/verification-before-completion/SKILL.md"
  assert_runtime_present 'before any merge, PR, archive' "$runtime_dir/skills/verification-before-completion/SKILL.md"
  assert_runtime_present 'before branch integration or archive' "$runtime_dir/skills/verify-change/SKILL.md"
  assert_runtime_present 'If branch integration or worktree cleanup is still pending' "$runtime_dir/skills/verify-change/SKILL.md"
  assert_runtime_present 'Require verify-change PASS' "$runtime_dir/skills/finishing-a-development-branch/SKILL.md"
  assert_runtime_present 'Archive is only valid after the change is integrated on the target branch' "$runtime_dir/skills/finishing-a-development-branch/SKILL.md"

done

echo "[PASS] runtime integrity"
