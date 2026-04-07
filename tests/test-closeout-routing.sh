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
  local first_line second_line
  first_line="$(rg -n "$first" "$file" | head -1 | cut -d: -f1)"
  second_line="$(rg -n "$second" "$file" | head -1 | cut -d: -f1)"
  [ -n "$first_line" ] || fail "missing first pattern in ${file#"$ROOT"/}: $first"
  [ -n "$second_line" ] || fail "missing second pattern in ${file#"$ROOT"/}: $second"
  [ "$first_line" -lt "$second_line" ] || fail "unexpected order in ${file#"$ROOT"/}: $first should appear before $second"
}

assert_present '5\. verification-before-completion' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"
assert_present '6\. verify-change' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"
assert_present '7\. finishing-a-development-branch' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"
assert_present '8\. archive' "$ROOT/community/superpowers/skills/using-superpowers/SKILL.md"

assert_present 'Treat "可以交付了" / "ready to ship" as a closeout trigger' "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md"
assert_present '1\. Small-chain artifacts exist' "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md"
assert_order 'verify-change' 'finishing-a-development-branch' "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md"

assert_present 'before branch integration or archive' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'If branch integration or worktree cleanup is still pending' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'finishing-a-development-branch' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"

assert_present 'If `design.md`, `tasks.md`, and `plan.md` exist' "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md"
assert_present 'do not present merge/PR/cleanup options yet' "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md"
assert_present 'Archive is only valid after the change is integrated on the target branch' "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md"

assert_present 'Use superpowers:verification-before-completion' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present '1\. verification-before-completion' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present '2\. verify-change' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present '3\. finishing-a-development-branch' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present '4\. archive' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_order '1\. verification-before-completion' '2\. verify-change' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_order '2\. verify-change' '3\. finishing-a-development-branch' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"

assert_present 'name: verification-before-completion' "$ROOT/contracts/small-chain.yaml"
assert_present 'name: finishing-a-development-branch' "$ROOT/contracts/small-chain.yaml"
assert_present '6\. `verification-before-completion`' "$ROOT/docs/small-chain/README.md"
assert_present '8\. `finishing-a-development-branch`' "$ROOT/docs/small-chain/README.md"
assert_present '`verify-change` 通过后才能进入 `finishing-a-development-branch` 或 `archive`' "$ROOT/docs/small-chain/boundary-contract.md"

echo "[PASS] closeout routing"
