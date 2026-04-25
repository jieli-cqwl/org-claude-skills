#!/usr/bin/env bash
# File responsibility: validate the Skill Harness runtime entry and reference routes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/skill-harness"
SKILL_FILE="$SKILL_DIR/SKILL.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SKILL_FILE" ] || fail "missing skill-harness SKILL.md"
grep -Fq 'name: skill-harness' "$SKILL_FILE" || fail "frontmatter name must be skill-harness"
grep -Fq 'user-invocable: true' "$SKILL_FILE" || fail "frontmatter must expose user-invocable skill"
grep -Fq 'allowed-tools: Read, Glob, Grep, Bash' "$SKILL_FILE" || fail "allowed tools must stay read-first"
grep -Fq 'LLM can propose transitions; engineering must authorize transitions' "$SKILL_FILE" || fail "missing core transition principle"
grep -Fq 'Default output: structured Markdown findings' "$SKILL_FILE" || fail "default audit output must be Markdown"
grep -Fq 'JSON upgrade gate' "$SKILL_FILE" || fail "missing JSON upgrade gate"
grep -Fq 'legacy_baseline_label' "$SKILL_FILE" || fail "missing legacy baseline label boundary"
grep -Fq '{{RUNTIME_HOME}}/reference/Skill质量标准.md' "$SKILL_FILE" || fail "missing MVP standard route"
grep -Fq 'references/json-upgrade-gate.md' "$SKILL_FILE" || fail "missing JSON reference route"
grep -Fq 'references/darwin-candidate-contract.md' "$SKILL_FILE" || fail "missing Darwin reference route"
grep -Fq 'references/content-order-contract.md' "$SKILL_FILE" || fail "missing content order route"
grep -Fq 'references/runtime-noise-contract.md' "$SKILL_FILE" || fail "missing runtime noise route"

printf '[PASS] skill-harness contract\n'
