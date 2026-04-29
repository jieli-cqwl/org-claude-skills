#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  printf 'usage: %s <refined-noisy-implementation-skill-dir>\n' "$0" >&2
  exit 2
fi

case "$TARGET" in
  /*) TARGET_DIR="$TARGET" ;;
  *) TARGET_DIR="$ROOT/$TARGET" ;;
esac

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
  if rg -n --fixed-strings "$term" "$TARGET_DIR" -g '*.md' >/tmp/skill-refiner-noisy-match.out 2>&1; then
    cat /tmp/skill-refiner-noisy-match.out >&2
    fail "noise term still present: $term"
  fi
done

rg -n --fixed-strings 'TDD' "$SKILL" >/dev/null || fail "refined SKILL.md must keep implementation practice language"
rg -n --fixed-strings '自测' "$SKILL" >/dev/null || fail "refined SKILL.md must require self-testing evidence"
rg -n --fixed-strings '按需读取 `references/implementation-review.md`' "$SKILL" >/dev/null || fail "reference must be progressively disclosed"

bash "$TEST_SCRIPT" "$TARGET_DIR"
python3 "$ROOT/shared/skills/skill-harness/scripts/check_skill_package_quality.py" "$TARGET_DIR" >/tmp/skill-refiner-package-quality.out
jq -e '.status == "static_pass" and .finding_count == 0' /tmp/skill-refiner-package-quality.out >/dev/null

printf '[PASS] noisy implementation fixture refined output\n'
