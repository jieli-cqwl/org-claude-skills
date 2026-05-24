#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/tools/community/check_test_signal_assertions.py"
CLAUDE_ENTRY="$ROOT/CLAUDE.md"
AGENTS_ENTRY="$ROOT/AGENTS.md"
GLOBAL_RULE_FILE="$ROOT/shared/rules/测试断言边界.md"
MAX_ENTRY_LINES=36

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern: $pattern"
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-assertion-boundary.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

test -f "$CLAUDE_ENTRY" || fail "missing repo entry document: $CLAUDE_ENTRY"
test -f "$AGENTS_ENTRY" || fail "missing repo entry document: $AGENTS_ENTRY"
test ! -e "$GLOBAL_RULE_FILE" || fail "repo-local assertion boundary must not be distributed from shared/rules"
diff <(tail -n +2 "$CLAUDE_ENTRY") <(tail -n +2 "$AGENTS_ENTRY") >/dev/null \
  || fail "CLAUDE.md and AGENTS.md bodies should stay identical"
for entry in "$CLAUDE_ENTRY" "$AGENTS_ENTRY"; do
  line_count="$(wc -l <"$entry" | tr -d ' ')"
  [ "$line_count" -le "$MAX_ENTRY_LINES" ] \
    || fail "$(basename "$entry") should stay concise: $line_count lines > $MAX_ENTRY_LINES"
done
assert_present '^## Testing$' "$CLAUDE_ENTRY"
assert_present '测试断言边界' "$CLAUDE_ENTRY"
assert_present 'tools/community/check_test_signal_assertions\.py' "$CLAUDE_ENTRY"
assert_present 'tests/fixtures/test-assertion-boundary/low-signal-prose-assertions\.baseline' "$CLAUDE_ENTRY"

mkdir -p "$TMP_DIR/bad" "$TMP_DIR/good"

cat >"$TMP_DIR/bad/test-bad-prose.sh" <<'BAD'
#!/usr/bin/env bash
assert_present '^## Beautiful prose heading$' "$ROOT/shared/skills/example/SKILL.md"
assert_absent 'This assertion only freezes the wording of a Markdown skill guide and does not protect a machine contract.' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'The reviewer should provide concise actionable guidance and return an advisory gate conclusion before implementation proceeds.' "$ROOT/shared/agents/example.md"
assert_present 'The SKILL guide MUST preserve this complete prose sentence for API readers even though it is not a machine contract.' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'This assertion freezes owner_stage wording in a complete Markdown sentence and does not protect behavior.' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'The artifact-registry.json paragraph must keep this complete explanatory sentence exactly for readers.' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'The validate_canonical_schema.py sentence should remain exactly as written in this Markdown guide.' "$ROOT/shared/skills/example/SKILL.md"
assert_absent '默认直接执行' "$ROOT/shared/skills/example/SKILL.md"
assert_absent '需要用户可读投影视图时运行' "$ROOT/shared/skills/example/SKILL.md"
assert_present '确认检查点未闭合不得 handoff' "$ROOT/shared/skills/example/SKILL.md"
assert_section_present "$ROOT/shared/skills/example/SKILL.md" "## HARD-GATE" '用户确认检查点未闭合前，不得冻结基线' "example hard-gate prose"
assert_present '^- 执行：`python3 shared/skills/example/scripts/render_projection\.py --feature-dir "docs/\{feature\}"`' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'Owner Self-Check|owner 自检|自检后.*送审' "$ROOT/shared/skills/example/SKILL.md"
BAD

cat >"$TMP_DIR/good/test-good-contract.sh" <<'GOOD'
#!/usr/bin/env bash
assert_present '^name: example$' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'validate_canonical_schema\.py' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'owner_stage' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'sha256:[0-9a-f]{64}' "$ROOT/shared/skills/example/projections/template.md"
assert_present 'render_projection\.py' "$ROOT/shared/skills/example/SKILL.md"
assert_present '--feature-dir' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'agent teams.*三名只读 reviewer.*advisory 结论' "$ROOT/shared/agents/designer.md"
GOOD

if python3 "$CHECKER" --tests-dir "$TMP_DIR/bad" >"$TMP_DIR/bad.out" 2>&1; then
  fail "low-signal Markdown prose assertions should be rejected"
fi
assert_present 'LOW_SIGNAL_PROSE_ASSERTION' "$TMP_DIR/bad.out"
assert_present 'Beautiful prose heading' "$TMP_DIR/bad.out"
assert_present 'wording of a Markdown skill guide' "$TMP_DIR/bad.out"
assert_present 'advisory gate conclusion' "$TMP_DIR/bad.out"
assert_present 'SKILL guide MUST preserve' "$TMP_DIR/bad.out"
assert_present 'owner_stage wording' "$TMP_DIR/bad.out"
assert_present 'artifact-registry.json paragraph' "$TMP_DIR/bad.out"
assert_present 'validate_canonical_schema.py sentence' "$TMP_DIR/bad.out"
assert_present '默认直接执行' "$TMP_DIR/bad.out"
assert_present '需要用户可读投影视图时运行' "$TMP_DIR/bad.out"
assert_present '确认检查点未闭合不得 handoff' "$TMP_DIR/bad.out"
assert_present '用户确认检查点未闭合前' "$TMP_DIR/bad.out"
assert_present 'render_projection' "$TMP_DIR/bad.out"
assert_present 'Owner Self-Check' "$TMP_DIR/bad.out"

python3 "$CHECKER" --tests-dir "$TMP_DIR/good" >/dev/null
python3 "$CHECKER" --repo-root "$ROOT" >/dev/null
(
  cd "$ROOT"
  python3 tools/community/check_test_signal_assertions.py >/dev/null
)

printf '[PASS] test assertion boundary contract\n'
