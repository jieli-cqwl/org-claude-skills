#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DIRECTOR_OUTPUT_REFERENCE="$ROOT/shared/skills/product-director/references/output.md"
MANAGER_OUTPUT_REFERENCE="$ROOT/shared/skills/product-manager/references/output.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

extract_section() {
  local file="$1"
  local heading="$2"
  awk -v heading="$heading" '
    $0 == heading { in_section=1; print; next }
    in_section && /^## / && $0 != heading { exit }
    in_section { print }
  ' "$file"
}

assert_output_section_routes_to_reference() {
  local skill_file="$1"
  local reference_path="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/product-output-section.XXXXXX")"
  extract_section "$skill_file" "## 输出" > "$tmp"

  assert_present "$reference_path" "$tmp"
  assert_absent 'docs/\{feature\}/|模板见|brief\.lock\.json|phase-\{N\}/prd\.lock\.json|UNIT-\*\.md|review\.md#|brief\.md#交付确认' "$tmp"

  rm -f "$tmp"
}

test -f "$DIRECTOR_SKILL" || fail "missing director skill: $DIRECTOR_SKILL"
test -f "$MANAGER_SKILL" || fail "missing manager skill: $MANAGER_SKILL"
test -f "$DIRECTOR_OUTPUT_REFERENCE" || fail "missing director output reference: $DIRECTOR_OUTPUT_REFERENCE"
test -f "$MANAGER_OUTPUT_REFERENCE" || fail "missing manager output reference: $MANAGER_OUTPUT_REFERENCE"

assert_output_section_routes_to_reference "$DIRECTOR_SKILL" '`references/output\.md`'
assert_output_section_routes_to_reference "$MANAGER_SKILL" '`references/output\.md`'

assert_present 'docs/\{feature\}/brief\.json' "$DIRECTOR_OUTPUT_REFERENCE"
assert_present 'shared/skills/product-director/templates/brief\.template\.json' "$DIRECTOR_OUTPUT_REFERENCE"
assert_present 'docs/\{feature\}/phase-\{N\}/phase-prd\.json' "$DIRECTOR_OUTPUT_REFERENCE"
assert_present 'shared/skills/product-director/templates/phase-prd\.template\.json' "$DIRECTOR_OUTPUT_REFERENCE"
assert_absent 'brief\.lock\.json|prd\.lock\.json|contracts/product-artifacts\.yaml' "$DIRECTOR_OUTPUT_REFERENCE"
assert_absent 'UNIT-\*\.md|review\.md|交付确认' "$DIRECTOR_OUTPUT_REFERENCE"

assert_present 'docs/\{feature\}/brief\.json' "$MANAGER_OUTPUT_REFERENCE"
assert_present 'docs/\{feature\}/phase-\{N\}/phase-prd\.json' "$MANAGER_OUTPUT_REFERENCE"
assert_present 'docs/\{feature\}/phase-\{N\}/units/UNIT-\*\.json' "$MANAGER_OUTPUT_REFERENCE"
assert_present 'shared/skills/product-manager/templates/unit-definition\.template\.json' "$MANAGER_OUTPUT_REFERENCE"
assert_absent 'docs/\{feature\}/review\.md|docs/\{feature\}/product-manager-review\.md|contracts/product-artifacts\.yaml' "$MANAGER_OUTPUT_REFERENCE"
assert_present '不得改写 Director 锁定字段' "$MANAGER_OUTPUT_REFERENCE"

echo "[PASS] product output reference"
