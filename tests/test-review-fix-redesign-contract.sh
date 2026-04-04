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

assert_contains() {
  local needle="$1"
  local path="$2"
  grep -Fq "$needle" "$path" || fail "missing content in $path: $needle"
}

assert_regex() {
  local pattern="$1"
  local path="$2"
  grep -Eq "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

assert_count() {
  local expected="$1"
  local pattern="$2"
  local path="$3"
  local actual
  actual="$(grep -Ec "$pattern" "$path")"
  [ "$actual" = "$expected" ] || fail "unexpected match count in $path for $pattern: expected $expected, got $actual"
}

CODE_SKILL="$ROOT/claude/skills/code-review-fix/SKILL.md"
DOC_SKILL="$ROOT/claude/skills/doc-review-fix/SKILL.md"
DECEPTION_DOC="$ROOT/claude/skills/doc-review-fix/references/deception-patterns.md"

assert_file_exists "$CODE_SKILL"
assert_file_exists "$DOC_SKILL"
assert_file_exists "$DECEPTION_DOC"

assert_regex '^allowed-tools: .*AskUserQuestion' "$CODE_SKILL"
assert_regex '^allowed-tools: .*AskUserQuestion' "$DOC_SKILL"

assert_contains 'AskUserQuestion' "$CODE_SKILL"
assert_contains 'baseline_ref' "$CODE_SKILL"
assert_contains 'staged_stash_ref' "$CODE_SKILL"
assert_contains 'staged changes 时先执行' "$CODE_SKILL"
assert_contains 'git stash push --keep-index' "$CODE_SKILL"
assert_contains 'git stash pop' "$CODE_SKILL"
assert_contains '禁止静默切换' "$CODE_SKILL"
assert_contains 'codex:adversarial-review' "$CODE_SKILL"
assert_contains '300 秒' "$CODE_SKILL"
assert_contains 'verdict' "$CODE_SKILL"
assert_contains 'approve' "$CODE_SKILL"
assert_contains 'needs-attention' "$CODE_SKILL"
assert_contains 'findings' "$CODE_SKILL"
assert_contains 'review-output.schema.json' "$CODE_SKILL"
assert_contains '"file": "文件相对路径"' "$CODE_SKILL"
assert_contains '"line_start": 42' "$CODE_SKILL"
assert_contains '"confidence": 0.85' "$CODE_SKILL"
assert_contains '只修复' "$CODE_SKILL"
assert_contains 'high' "$CODE_SKILL"
assert_contains 'stage + commit' "$CODE_SKILL"
assert_contains '轮次标识' "$CODE_SKILL"
assert_contains '达到最大轮次（5）' "$CODE_SKILL"
assert_contains '连续 2 轮 high+ findings 数量不减少' "$CODE_SKILL"
assert_contains 'skipped:unlocatable' "$CODE_SKILL"
assert_contains '.review-fix-raw-output.json' "$CODE_SKILL"
assert_contains 'stash_ref' "$CODE_SKILL"
assert_contains '验证命令' "$CODE_SKILL"
assert_contains '跳过的 findings' "$CODE_SKILL"
assert_contains 'residual findings' "$CODE_SKILL"

assert_contains '连续两轮零 findings' "$DOC_SKILL"
assert_contains '需用户介入' "$DOC_SKILL"
assert_contains 'codex exec --json' "$DOC_SKILL"
assert_contains 'staged changes 时先执行' "$DOC_SKILL"
assert_contains '300 秒' "$DOC_SKILL"
assert_contains 'verdict' "$DOC_SKILL"
assert_contains 'findings 数组' "$DOC_SKILL"
assert_contains '动态发现' "$DOC_SKILL"
assert_contains '动态维度' "$DOC_SKILL"
assert_contains 'deception-patterns.md' "$DOC_SKILL"
assert_contains 'file + line_start + severity' "$DOC_SKILL"
assert_contains '±5 行内' "$DOC_SKILL"
assert_contains 'line_start' "$DOC_SKILL"
assert_contains 'line_start' "$DOC_SKILL"
assert_contains '连续两轮 verdict == approve' "$DOC_SKILL"
assert_contains 'findings 都为 0' "$DOC_SKILL"
assert_contains 'stage + commit' "$DOC_SKILL"
assert_contains '轮次标识' "$DOC_SKILL"
assert_contains '达到最大轮次（5）' "$DOC_SKILL"
assert_contains '连续 2 轮 findings 数量不减少' "$DOC_SKILL"
assert_contains 'baseline_ref' "$DOC_SKILL"
assert_contains '各轮评审维度' "$DOC_SKILL"
assert_contains 'DECEPTION findings' "$DOC_SKILL"
assert_contains 'git reset --soft <baseline_ref>' "$DOC_SKILL"
assert_contains 'residual findings' "$DOC_SKILL"

assert_contains 'DECEPTION' "$DECEPTION_DOC"
assert_count 12 '^\\| DECEPTION-' "$DECEPTION_DOC"

printf 'PASS\n'
