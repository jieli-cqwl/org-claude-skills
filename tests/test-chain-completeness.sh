#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHAIN="$ROOT/contracts/small-chain.yaml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CHAIN" ] || fail "missing contracts/small-chain.yaml"

for skill in using-superpowers brainstorming writing-plans using-git-worktrees subagent-driven-development verification-before-completion verify-change finishing-a-development-branch archive; do
  grep -Fq "name: $skill" "$CHAIN" || fail "chain contract missing skill: $skill"
done

for path in \
  "$ROOT/community/superpowers/skills/brainstorming/SKILL.md" \
  "$ROOT/community/superpowers/skills/writing-plans/SKILL.md" \
  "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md" \
  "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md" \
  "$ROOT/community/superpowers/skills/verify-change/SKILL.md" \
  "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md" \
  "$ROOT/community/superpowers/skills/archive/SKILL.md" \
  "$ROOT/docs/small-chain/README.md" \
  "$ROOT/docs/small-chain/boundary-contract.md"; do
  [ -f "$path" ] || fail "small-chain completeness missing file: ${path#"$ROOT"/}"
done

echo "[PASS] chain completeness"
