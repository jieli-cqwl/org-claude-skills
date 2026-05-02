#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
SKILL="$ROOT/SKILL.md"

[ -f "$SKILL" ]

for term in '流程合规输出合同' '前置条件' '主动探索' 'Trigger:' 'Read:' 'Expect:' 'Consume:' 'Evidence:' 'Sync:' '引用者：'; do
  if find "$ROOT" -name '*.md' -type f -exec grep -HnF "$term" {} +; then
    printf '[FAIL] stale noise term survived: %s\n' "$term" >&2
    exit 1
  fi
done

grep -Fq 'TDD' "$SKILL"
grep -Fq '自测' "$SKILL"
grep -Fq '复杂自审时读取 `references/implementation-review.md`' "$SKILL"

printf '[PASS] noisy implementation noise regression\n'
