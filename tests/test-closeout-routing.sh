#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_order() {
  local first="$1"
  local second="$2"
  local file="$3"
  local first_lines second_lines last_first earliest_second
  first_lines="$(rg -n "$first" "$file" | cut -d: -f1)"
  second_lines="$(rg -n "$second" "$file" | cut -d: -f1)"
  [ -n "$first_lines" ] || fail "missing first pattern in ${file#"$ROOT"/}: $first"
  [ -n "$second_lines" ] || fail "missing second pattern in ${file#"$ROOT"/}: $second"
  last_first="$(printf '%s\n' "$first_lines" | tail -1)"
  earliest_second="$(printf '%s\n' "$second_lines" | head -1)"
  [ "$last_first" -lt "$earliest_second" ] || fail "unexpected order in ${file#"$ROOT"/}: $first should always appear before $second"
}

assert_present 'verification-before-completion' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"
assert_present 'requesting-code-review' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"
assert_present 'verify-change' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"
assert_present 'finishing-a-development-branch' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"
assert_present 'archive' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"

assert_present 'Treat "可以交付了" / "ready to ship" as a closeout trigger' "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md"
assert_present '1\. Small-chain artifacts exist' "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md"

assert_present 'before branch integration or archive' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'execution-route.json' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'parallel-execution-report.json' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'code-review-result.json' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'Code Review Evidence Gate' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'If branch integration or worktree cleanup is still pending' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'finishing-a-development-branch' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"

assert_present "If \`design.md\`, \`tasks.md\`, and \`plan.md\` exist" "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md"
assert_present 'do not present merge/PR/cleanup options yet' "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md"
assert_present 'Archive is only valid after the change is integrated on the target branch' "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md"

assert_present 'Use superpowers:verification-before-completion' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present 'decision=serial' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present 'verification-before-completion' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present 'verify-change' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present 'finishing-a-development-branch' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present 'archive' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"

assert_present 'name: verification-before-completion' "$ROOT/contracts/small-chain.yaml"
assert_present 'name: requesting-code-review' "$ROOT/contracts/small-chain.yaml"
assert_present 'parallel-execution-report' "$ROOT/contracts/small-chain.yaml"
assert_present 'code-review-result.json' "$ROOT/contracts/small-chain.yaml"
assert_present 'name: finishing-a-development-branch' "$ROOT/contracts/small-chain.yaml"
assert_present '^closeout_policy:$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^  required_sequence:$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^    - verification-before-completion$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^    - requesting-code-review$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^    - verify-change$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^    - finishing-a-development-branch$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^    - archive$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^  verify_change_required_before:$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^  code_review_required_before:$' "$ROOT/contracts/superpowers-boundary.yaml"
assert_present '^  archive_requires: integrated_on_target_branch$' "$ROOT/contracts/superpowers-boundary.yaml"

echo "[PASS] closeout routing"
