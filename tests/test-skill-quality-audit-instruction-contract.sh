#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="$ROOT/shared/skills/skill-quality-audit/references/instruction-contract.md"
GOOD="$ROOT/shared/skills/skill-quality-audit/evals/fixtures/target-skills/good-skill/SKILL.md"
UNCLEAR="$ROOT/shared/skills/skill-quality-audit/evals/fixtures/target-skills/unclear-instruction-skill/SKILL.md"
MODIFIER="$ROOT/shared/skills/skill-quality-audit/evals/fixtures/target-skills/modifier-skill/SKILL.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$REF" ] || fail "missing instruction-contract.md"

[ -f "$GOOD" ] || fail "missing good target fixture"
[ -f "$UNCLEAR" ] || fail "missing unclear target fixture"
[ -f "$MODIFIER" ] || fail "missing modifier target fixture"

grep -Fq "Handle related files when needed." "$UNCLEAR" \
  || fail "unclear fixture must include broad object and hidden condition"
grep -Eq 'allowed-tools:.*(Write|Edit)' "$MODIFIER" \
  || fail "modifier fixture must demonstrate target modification risk"

printf '[PASS] skill-quality-audit instruction contract\n'

