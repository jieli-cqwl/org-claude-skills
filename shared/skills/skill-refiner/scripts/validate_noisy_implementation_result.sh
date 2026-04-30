#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  printf 'usage: %s <refined-noisy-implementation-skill-dir>\n' "$0" >&2
  exit 2
fi

resolve_target_dir() {
  local raw="$1"
  local suffix

  case "$raw" in
    /*)
      printf '%s\n' "$raw"
      return 0
      ;;
    shared/skills/skill-refiner/*)
      suffix="${raw#shared/skills/skill-refiner/}"
      printf '%s/%s\n' "$SKILL_ROOT" "$suffix"
      return 0
      ;;
  esac

  if [ -e "$raw" ]; then
    (cd "$raw" && pwd)
    return 0
  fi

  if [ -e "$SKILL_ROOT/$raw" ]; then
    (cd "$SKILL_ROOT/$raw" && pwd)
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$raw"
}

TARGET_DIR="$(resolve_target_dir "$TARGET")"

SKILL="$TARGET_DIR/SKILL.md"
REFERENCE="$TARGET_DIR/references/implementation-review.md"
TEST_SCRIPT="$TARGET_DIR/tests/noise-regression.test.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SKILL" ] || fail "missing SKILL.md: $SKILL"
[ -f "$REFERENCE" ] || fail "missing implementation review reference: $REFERENCE"
[ -f "$TEST_SCRIPT" ] || fail "missing noise regression test: $TEST_SCRIPT"

if [ -e "$TARGET_DIR/references/old-methodology.md" ]; then
  fail "old-methodology.md must not survive in refined output"
fi

for term in \
  '流程合规输出合同' \
  '前置条件' \
  '主动探索' \
  '如果 registry 不存在，继续' \
  'Trigger:' \
  'Read:' \
  'Expect:' \
  'Consume:' \
  'Evidence:' \
  'Sync:' \
  '引用者：'
do
  match_out="$(mktemp)"
  set +e
  rg -n --fixed-strings "$term" "$TARGET_DIR" -g '*.md' >"$match_out" 2>&1
  rg_status=$?
  set -e
  if [ "$rg_status" -eq 0 ]; then
    cat "$match_out" >&2
    rm -f "$match_out"
    fail "noise term still present: $term"
  fi
  if [ "$rg_status" -ne 1 ]; then
    cat "$match_out" >&2
    rm -f "$match_out"
    fail "noise scan failed for term: $term"
  fi
  rm -f "$match_out"
done

rg -n --fixed-strings 'TDD' "$SKILL" >/dev/null || fail "refined SKILL.md must keep implementation practice language"
rg -n --fixed-strings '自测' "$SKILL" >/dev/null || fail "refined SKILL.md must require self-testing evidence"
rg -n --fixed-strings '按需读取 `references/implementation-review.md`' "$SKILL" >/dev/null || fail "reference must be progressively disclosed"
rg -n '^description: .+Use when .+' "$SKILL" >/dev/null || fail "SKILL.md must keep a routable description"
rg -n --fixed-strings 'allowed-tools: Read, Write, Edit, Bash, Glob, Grep' "$SKILL" >/dev/null || fail "implementation skill tools must remain explicit"
rg -n --fixed-strings '## HARD-GATE' "$SKILL" >/dev/null || fail "SKILL.md must keep hard gates"
rg -n --fixed-strings '## 流程' "$SKILL" >/dev/null || fail "SKILL.md must keep implementation flow"
rg -n --fixed-strings '## 输出' "$SKILL" >/dev/null || fail "SKILL.md must keep output contract"

bash "$TEST_SCRIPT" "$TARGET_DIR"

printf '[PASS] noisy implementation fixture refined output\n'
