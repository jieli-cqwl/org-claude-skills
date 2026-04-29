#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
SKILL="$ROOT/SKILL.md"

[ -f "$SKILL" ]

for term in '流程合规输出合同' '前置条件' '主动探索' 'Trigger:' 'Read:' 'Expect:' 'Consume:' 'Evidence:' 'Sync:' '引用者：'; do
  if rg -n --fixed-strings "$term" "$ROOT" -g '*.md'; then
    printf '[FAIL] stale noise term survived: %s\n' "$term" >&2
    exit 1
  fi
done

rg -n --fixed-strings 'TDD' "$SKILL" >/dev/null
rg -n --fixed-strings '自测' "$SKILL" >/dev/null
rg -n --fixed-strings '按需读取 `references/implementation-review.md`' "$SKILL" >/dev/null

printf '[PASS] noisy implementation noise regression\n'
