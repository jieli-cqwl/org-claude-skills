#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHAIN="$ROOT/contracts/small-chain.yaml"
STANDARD_CHAIN="$ROOT/contracts/skill-chain.yaml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CHAIN" ] || fail "missing contracts/small-chain.yaml"
[ -f "$STANDARD_CHAIN" ] || fail "missing contracts/skill-chain.yaml"

for skill in using-superpowers brainstorming writing-plans using-git-worktrees subagent-driven-development verification-before-completion verify-change finishing-a-development-branch archive; do
  grep -Fq "name: $skill" "$CHAIN" || fail "chain contract missing skill: $skill"
done

grep -Fq 'phase_delivery_owner: delivery-owner' "$STANDARD_CHAIN" || fail "standard chain missing delivery-owner authority"
grep -Fq 'qa_report_producer: qa' "$STANDARD_CHAIN" || fail "standard chain missing qa report producer"
grep -Fq 'plan_version' "$STANDARD_CHAIN" || fail "standard chain missing plan_version key field"

delivery_owner_block="$(awk '
  /- name: delivery-owner/ { in_block=1 }
  in_block { print }
  /- name: developer/ { if (in_block) exit }
' "$STANDARD_CHAIN")"
printf '%s\n' "$delivery_owner_block" | grep -Fq 'phase-{N}/qa-report.md' || fail "delivery-owner block missing qa-report required input"

for path in \
  "$ROOT/community/superpowers/skills/brainstorming/SKILL.md" \
  "$ROOT/community/superpowers/skills/writing-plans/SKILL.md" \
  "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md" \
  "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md" \
  "$ROOT/community/superpowers/skills/verify-change/SKILL.md" \
  "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md" \
  "$ROOT/community/superpowers/skills/archive/SKILL.md" \
  "$ROOT/contracts/superpowers-boundary.yaml"; do
  [ -f "$path" ] || fail "small-chain completeness missing file: ${path#"$ROOT"/}"
done

echo "[PASS] chain completeness"
