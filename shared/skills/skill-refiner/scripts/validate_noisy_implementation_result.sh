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

scan_fixed_markdown() {
  python3 - "$TARGET_DIR" "$1" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
term = sys.argv[2]
found = False

try:
    for path in root.rglob("*.md"):
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            lines = path.read_text(errors="replace").splitlines()
        for line_number, line in enumerate(lines, 1):
            if term in line:
                print(f"{path}:{line_number}:{line}")
                found = True
except Exception as error:
    print(error, file=sys.stderr)
    raise SystemExit(2)

raise SystemExit(0 if found else 1)
PY
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
  scan_fixed_markdown "$term" >"$match_out" 2>&1
  scan_status=$?
  set -e
  if [ "$scan_status" -eq 0 ]; then
    cat "$match_out" >&2
    rm -f "$match_out"
    fail "noise term still present: $term"
  fi
  if [ "$scan_status" -ne 1 ]; then
    cat "$match_out" >&2
    rm -f "$match_out"
    fail "noise scan failed for term: $term"
  fi
  rm -f "$match_out"
done

grep -Fq 'TDD' "$SKILL" || fail "refined SKILL.md must keep implementation practice language"
grep -Fq '自测' "$SKILL" || fail "refined SKILL.md must require self-testing evidence"
grep -Fq '复杂自审时读取 `references/implementation-review.md`' "$SKILL" || fail "reference must be routed from the self-review step"
grep -Eq '^description: .+Use when .+' "$SKILL" || fail "SKILL.md must keep a routable description"
grep -Fq 'allowed-tools: Read, Write, Edit, Bash, Glob, Grep' "$SKILL" || fail "implementation skill tools must remain explicit"
grep -Fq '## HARD-GATE' "$SKILL" || fail "SKILL.md must keep hard gates"
grep -Fq '## 流程' "$SKILL" || fail "SKILL.md must keep implementation flow"
grep -Fq '## 输出' "$SKILL" || fail "SKILL.md must keep output contract"

bash "$TEST_SCRIPT" "$TARGET_DIR"

printf '[PASS] noisy implementation fixture refined output\n'
