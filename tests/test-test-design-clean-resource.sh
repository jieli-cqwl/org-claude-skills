#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/test-design"
HISTORY_DIR="$ROOT/shared/skills/test-design-h"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: ${1#"$ROOT"/}"
}

json_has_key() {
  local file="$1" key="$2"
  python3 - "$file" "$key" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if sys.argv[2] not in payload:
    raise SystemExit(1)
PY
}

assert_file "$SKILL_DIR/SKILL.md"
assert_file "$SKILL_DIR/references/methodology.md"
assert_file "$SKILL_DIR/references/test-obligation-shaping.md"
assert_file "$SKILL_DIR/references/specialty-test-design.md"
assert_file "$SKILL_DIR/references/testdesign-reviewer-prompt.md"
assert_file "$SKILL_DIR/references/testdesign-product-reviewer-prompt.md"
assert_file "$SKILL_DIR/references/testdesign-arch-reviewer-prompt.md"
assert_file "$SKILL_DIR/scripts/preflight_check.sh"
assert_file "$SKILL_DIR/scripts/completion_check.sh"
assert_file "$SKILL_DIR/contracts/test-cases.schema.json"
assert_file "$SKILL_DIR/templates/test-cases.template.json"
assert_file "$SKILL_DIR/projections/test-cases-template.md"

for removed in \
  integration-test-methodology.md \
  contract-test-methodology.md \
  security-test-methodology.md \
  performance-test-methodology.md; do
  [ ! -e "$SKILL_DIR/references/$removed" ] || fail "old specialty reference still exists: $removed"
done

[ ! -e "$HISTORY_DIR" ] || fail "historical test-design-h should be deleted"

json_has_key "$SKILL_DIR/templates/test-cases.template.json" "test_analysis" \
  || fail "template must define test_analysis"
json_has_key "$SKILL_DIR/templates/test-cases.template.json" "traceability_matrix" \
  || fail "template must define traceability_matrix"
json_has_key "$SKILL_DIR/templates/test-cases.template.json" "qa_handoff_contract" \
  || fail "template must define qa_handoff_contract"
json_has_key "$SKILL_DIR/templates/test-cases.template.json" "review_conclusion" \
  || fail "template must define review_conclusion"
json_has_key "$SKILL_DIR/contracts/test-cases.schema.json" "allOf" \
  || fail "schema must define allOf"
printf '[PASS] test-design clean resource\n'
