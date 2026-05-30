#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/tools/community/check_test_signal_assertions.py"
CLAUDE_ENTRY="$ROOT/CLAUDE.md"
AGENTS_ENTRY="$ROOT/AGENTS.md"
GLOBAL_RULE_FILE="$ROOT/shared/rules/测试断言边界.md"
MAX_AGENTS_LINES=36

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern: $pattern"
}

assert_any_present() {
  local file="$1"
  shift
  local pattern
  for pattern in "$@"; do
    grep -Eq "$pattern" "$file" && return 0
  done
  return 1
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-assertion-boundary.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

test -f "$CLAUDE_ENTRY" || fail "missing repo entry document: $CLAUDE_ENTRY"
test -f "$AGENTS_ENTRY" || fail "missing repo entry document: $AGENTS_ENTRY"
test ! -e "$GLOBAL_RULE_FILE" || fail "repo-local assertion boundary must not be distributed from shared/rules"
line_count="$(wc -l <"$AGENTS_ENTRY" | tr -d ' ')"
[ "$line_count" -le "$MAX_AGENTS_LINES" ] \
  || fail "AGENTS.md should stay concise: $line_count lines > $MAX_AGENTS_LINES"
assert_present '测试断言边界' "$AGENTS_ENTRY"
assert_present 'tools/community/check_test_signal_assertions\.py' "$AGENTS_ENTRY"
if grep -Eq 'low-signal-prose-assertions\.baseline' "$AGENTS_ENTRY"; then
  fail "AGENTS.md must not document a low-signal assertion baseline"
fi

mkdir -p "$TMP_DIR/bad" "$TMP_DIR/good" "$TMP_DIR/repo/tools" "$TMP_DIR/repo/tests"

cat >"$TMP_DIR/bad/test-bad-prose.sh" <<'BAD'
#!/usr/bin/env bash
RULE="$ROOT/shared/rules/example.md"
REFERENCE="$ROOT/shared/reference/example.md"
assert_present '^## Beautiful prose heading$' "$ROOT/shared/skills/example/SKILL.md"
assert_present '^# 完成前验证$' "$RULE"
assert_absent 'This assertion only freezes the wording of a Markdown skill guide and does not protect a machine contract.' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'The reviewer should provide concise actionable guidance and return an advisory gate conclusion before implementation proceeds.' "$ROOT/shared/agents/example.md"
assert_present 'The reference guide should preserve this complete prose sentence even though it is not a machine contract.' "$REFERENCE"
assert_present 'The SKILL guide MUST preserve this complete prose sentence for API readers even though it is not a machine contract.' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'This assertion freezes owner_stage wording in a complete Markdown sentence and does not protect behavior.' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'The artifact-registry.json paragraph must keep this complete explanatory sentence exactly for readers.' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'The validate_canonical_schema.py sentence should remain exactly as written in this Markdown guide.' "$ROOT/shared/skills/example/SKILL.md"
assert_absent '默认直接执行' "$ROOT/shared/skills/example/SKILL.md"
assert_present '答案层' "$ROOT/shared/skills/example/references/guide.md"
assert_absent '需要用户可读投影视图时运行' "$ROOT/shared/skills/example/SKILL.md"
assert_present '确认检查点未闭合不得 handoff' "$ROOT/shared/skills/example/SKILL.md"
assert_section_present "$ROOT/shared/skills/example/SKILL.md" "## HARD-GATE" '用户确认检查点未闭合前，不得冻结基线' "example hard-gate prose"
assert_present '^- 执行：`python3 shared/skills/example/scripts/render_projection\.py --feature-dir "docs/\{feature\}"`' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'Owner Self-Check|owner 自检|自检后.*送审' "$ROOT/shared/skills/example/SKILL.md"
assert_any_present "$ROOT/shared/skills/example/SKILL.md" '输出沿着探索、选项、推荐、确认推进' '继续执行 Checklist 的下一步'
grep -Eq '用户是决策方' "$ROOT/shared/skills/example/SKILL.md"
rg -n '交付视角 review' "$ROOT/shared/skills/example/SKILL.md" >/dev/null
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
path = root / "shared" / "rules" / "example.md"
text = path.read_text(encoding="utf-8")
required_sections = ["失败处理", "验收证据"]
for section in required_sections:
    if f"## {section}" not in text:
        raise SystemExit(section)
if text.startswith("# 完成前验证\n"):
    pass
if "目标内失败必须修根因；目标外失败只报告" in text:
    pass
if "红灯" not in text:
    pass
PY
BAD

cat >"$TMP_DIR/repo/tools/check-prose.sh" <<'TOOLBAD'
#!/usr/bin/env bash
assert_present '工具目录也不能锁正文措辞' "$ROOT/shared/skills/example/SKILL.md"
TOOLBAD

cat >"$TMP_DIR/good/test-good-contract.sh" <<'GOOD'
#!/usr/bin/env bash
assert_present '^name: example$' "$ROOT/shared/skills/example/SKILL.md"
assert_present '^allowed-tools: Read, Write, Bash(python3 shared/skills/example/scripts/check.py:\*)$' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'validate_canonical_schema\.py' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'owner_stage' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'sha256:[0-9a-f]{64}' "$ROOT/shared/skills/example/projections/template.md"
assert_present 'render_projection\.py' "$ROOT/shared/skills/example/SKILL.md"
assert_present '--feature-dir' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'docs/reports--security/[YYYY-MM-DD]_安全扫描报告.md' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'python3 tools/community/validate_co_creation_ledger.py --artifact "docs/{feature}/product-director-ledger.json" --producer product-director --require-finalized' "$ROOT/shared/skills/example/SKILL.md"
GOOD

if python3 "$CHECKER" --tests-dir "$TMP_DIR/bad" >"$TMP_DIR/bad.out" 2>&1; then
  fail "low-signal Markdown prose assertions should be rejected"
fi
assert_present 'LOW_SIGNAL_PROSE_ASSERTION' "$TMP_DIR/bad.out"
assert_present 'Beautiful prose heading' "$TMP_DIR/bad.out"
assert_present '完成前验证' "$TMP_DIR/bad.out"
assert_present 'wording of a Markdown skill guide' "$TMP_DIR/bad.out"
assert_present 'advisory gate conclusion' "$TMP_DIR/bad.out"
assert_present 'reference guide should preserve' "$TMP_DIR/bad.out"
assert_present 'SKILL guide MUST preserve' "$TMP_DIR/bad.out"
assert_present '默认直接执行' "$TMP_DIR/bad.out"
assert_present '答案层' "$TMP_DIR/bad.out"
assert_present '需要用户可读投影视图时运行' "$TMP_DIR/bad.out"
assert_present '确认检查点未闭合不得 handoff' "$TMP_DIR/bad.out"
assert_present '用户确认检查点未闭合前' "$TMP_DIR/bad.out"
assert_present 'Owner Self-Check' "$TMP_DIR/bad.out"
assert_present '输出沿着探索' "$TMP_DIR/bad.out"
assert_present '继续执行 Checklist' "$TMP_DIR/bad.out"
assert_present '用户是决策方' "$TMP_DIR/bad.out"
assert_present '交付视角 review' "$TMP_DIR/bad.out"
assert_present '目标内失败必须修根因' "$TMP_DIR/bad.out"

python3 "$CHECKER" --tests-dir "$TMP_DIR/good" >/dev/null
if python3 "$CHECKER" --repo-root "$TMP_DIR/repo" >"$TMP_DIR/tools.out" 2>&1; then
  fail "default repo scan should include tools/ low-signal assertions"
fi
assert_present '工具目录也不能锁正文措辞' "$TMP_DIR/tools.out"
python3 "$CHECKER" --repo-root "$ROOT" >/dev/null
(
  cd "$ROOT"
  python3 tools/community/check_test_signal_assertions.py >/dev/null
)

printf '[PASS] test assertion boundary contract\n'
