#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/tools/community/check_test_signal_assertions.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern: $pattern"
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-signal-governance.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bad" "$TMP_DIR/good"

cat >"$TMP_DIR/bad/test-bad-prose.sh" <<'BAD'
#!/usr/bin/env bash
assert_present '^## Beautiful prose heading$' "$ROOT/shared/skills/example/SKILL.md"
assert_absent 'This assertion only freezes the wording of a Markdown skill guide and does not protect a machine contract.' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'The reviewer should provide concise actionable guidance and return an advisory gate conclusion before implementation proceeds.' "$ROOT/shared/agents/example.md"
assert_present 'The SKILL guide MUST preserve this complete prose sentence for API readers even though it is not a machine contract.' "$ROOT/shared/skills/example/SKILL.md"
BAD

cat >"$TMP_DIR/good/test-good-contract.sh" <<'GOOD'
#!/usr/bin/env bash
assert_present '^name: example$' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'validate_canonical_schema\.py' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/example/SKILL.md"
assert_present 'owner_stage' "$ROOT/shared/skills/example/references/guide.md"
assert_present 'sha256:[0-9a-f]{64}' "$ROOT/shared/skills/example/projections/template.md"
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

python3 "$CHECKER" --tests-dir "$TMP_DIR/good" >/dev/null
python3 "$CHECKER" --repo-root "$ROOT" >/dev/null
(
  cd "$ROOT"
  python3 tools/community/check_test_signal_assertions.py >/dev/null
)

printf '[PASS] test signal governance contract\n'
