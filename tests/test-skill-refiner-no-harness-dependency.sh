#!/usr/bin/env bash
# File role: prove skill-refiner SOP has no skill-harness or reviewer-layer dependency.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REFINER="$ROOT/shared/skills/skill-refiner/SKILL.md"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_noisy_implementation_result.sh"
EXAMPLE="$ROOT/shared/skills/skill-refiner/references/examples/developer-optimization-case.md"
OLD_EXAMPLE="$ROOT/shared/skills/skill-refiner/references/developer-optimization-case.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#"$ROOT"/}: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in ${file#"$ROOT"/}: $needle"
  fi
}

test -f "$REFINER" || fail "missing skill-refiner SKILL.md"
test -f "$VALIDATOR" || fail "missing noisy fixture validator"
test -f "$EXAMPLE" || fail "missing developer success example"
test ! -e "$OLD_EXAMPLE" || fail "old developer optimization case path must be removed"

assert_present 'references/examples/developer-optimization-case.md' "$REFINER"
assert_present 'Developer 优化成功示例' "$EXAMPLE"
assert_present '## 成功形态' "$EXAMPLE"
assert_present '## 主 agent 评审要点' "$EXAMPLE"

assert_absent 'skill-harness' "$REFINER"
assert_absent 'check_skill_package_quality.py' "$REFINER"
assert_absent 'check_skill_body_quality.py' "$REFINER"
assert_absent 'check_skill_harness' "$REFINER"
assert_absent 'references/reviewers/' "$REFINER"
assert_absent '## Sub Agent 审查队列' "$REFINER"
assert_absent 'discover_refinement_candidates.py' "$REFINER"
assert_absent '边界：' "$REFINER"

assert_absent 'skill-harness' "$VALIDATOR"
assert_absent 'check_skill_package_quality.py' "$VALIDATOR"
assert_absent 'check_skill_body_quality.py' "$VALIDATOR"
assert_absent 'check_skill_harness' "$VALIDATOR"

printf '[PASS] skill-refiner no harness dependency\n'
