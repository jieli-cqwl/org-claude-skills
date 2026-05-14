#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [ -f "$path" ] || fail "missing file: $path"
}

assert_regex() {
  local pattern="$1"
  local path="$2"
  grep -Eq "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

CODE_SKILL="$ROOT/claude/skills/code-review-fix/SKILL.md"
DOC_SKILL="$ROOT/claude/skills/doc-review-fix/SKILL.md"
DECEPTION_DOC="$ROOT/claude/skills/doc-review-fix/references/deception-patterns.md"
SCENARIOS="$ROOT/tests/test-review-fix-redesign-scenarios.sh"

assert_file_exists "$CODE_SKILL"
assert_file_exists "$DOC_SKILL"
assert_file_exists "$DECEPTION_DOC"
assert_file_exists "$SCENARIOS"

assert_regex '^name: code-review-fix$' "$CODE_SKILL"
assert_regex '^allowed-tools: .*AskUserQuestion' "$CODE_SKILL"
assert_regex '^allowed-tools: .*Bash' "$CODE_SKILL"
assert_regex '^name: doc-review-fix$' "$DOC_SKILL"
assert_regex '^allowed-tools: .*AskUserQuestion' "$DOC_SKILL"
assert_regex '^allowed-tools: .*Bash' "$DOC_SKILL"

bash "$SCENARIOS"

printf 'PASS\n'
