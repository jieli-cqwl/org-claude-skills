#!/usr/bin/env bash
# shellcheck disable=SC2016
# File role: prove standard-chain HARD-GATE sections contain blocking invariants, not execution details.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
TEST_DESIGN_SKILL="$ROOT/shared/skills/test-design/SKILL.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
DEVELOPER_SKILL="$ROOT/shared/skills/developer/SKILL.md"
REVIEW_SKILL="$ROOT/shared/skills/review/SKILL.md"
VERIFY_SKILL="$ROOT/shared/skills/verify/SKILL.md"
QA_SKILL="$ROOT/shared/skills/qa/SKILL.md"
FIX_SKILL="$ROOT/shared/skills/fix/SKILL.md"
CONSISTENCY_AUDIT_SKILL="$ROOT/shared/skills/consistency-audit/SKILL.md"
DELIVERY_OWNER_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  test -f "$1" || fail "missing file: ${1#"$ROOT"/}"
}

assert_present() {
  local needle="$1" file="$2"
  grep -Fq "$needle" "$file" || fail "missing content in ${file#"$ROOT"/}: $needle"
}

assert_absent() {
  local needle="$1" file="$2"
  ! grep -Fq "$needle" "$file" || fail "unexpected content in ${file#"$ROOT"/}: $needle"
}

hard_gate_block() {
  awk '
    /^<HARD-GATE>$/ { in_block = 1; xml_gate = 1; next }
    xml_gate && /^<\/HARD-GATE>$/ { exit }
    /^## HARD-GATE$/ { in_block = 1; next }
    in_block && !xml_gate && /^## / { exit }
    in_block { print }
  ' "$1"
}

assert_hard_gate_terms() {
  local file="$1" label="$2" block term_pattern
  shift 2
  block="$(hard_gate_block "$file")"
  test -n "$block" || fail "missing HARD-GATE block in ${file#"$ROOT"/}"
  for term_pattern in "$@"; do
    grep -Eq "$term_pattern" <<<"$block" || fail "HARD-GATE missing ${label}: $term_pattern"
  done
}

assert_hard_gate_absent() {
  local needle="$1" file="$2" block
  block="$(hard_gate_block "$file")"
  test -n "$block" || fail "missing HARD-GATE block in ${file#"$ROOT"/}"
  ! grep -Fq "$needle" <<<"$block" || fail "HARD-GATE contains execution detail in ${file#"$ROOT"/}: $needle"
}

STANDARD_CHAIN_GATE_SKILLS=(
  "$DIRECTOR_SKILL"
  "$MANAGER_SKILL"
  "$DESIGN_SKILL"
  "$TEST_DESIGN_SKILL"
  "$TECH_LEAD_SKILL"
  "$DEVELOPER_SKILL"
  "$REVIEW_SKILL"
  "$VERIFY_SKILL"
  "$QA_SKILL"
  "$FIX_SKILL"
  "$CONSISTENCY_AUDIT_SKILL"
  "$DELIVERY_OWNER_SKILL"
)

for file in "${STANDARD_CHAIN_GATE_SKILLS[@]}"; do
  assert_file "$file"
  assert_hard_gate_absent 'python3 ' "$file"
  assert_hard_gate_absent 'bash ' "$file"
  assert_hard_gate_absent 'Bash' "$file"
  assert_hard_gate_absent 'references/' "$file"
  assert_hard_gate_absent 'Trigger:' "$file"
  assert_hard_gate_absent 'Read:' "$file"
  assert_hard_gate_absent 'Expect:' "$file"
  assert_hard_gate_absent 'validate_co_creation_ledger.py' "$file"
done

assert_hard_gate_absent 'references/conversation-guide.md' "$DIRECTOR_SKILL"

assert_hard_gate_absent 'preflight_check.sh --arguments' "$DESIGN_SKILL"
assert_hard_gate_absent 'delivery_confirmation.status' "$DESIGN_SKILL"
assert_hard_gate_absent 'issue_ledger' "$DESIGN_SKILL"
assert_hard_gate_absent 'input params' "$DESIGN_SKILL"
assert_hard_gate_absent 'output params' "$DESIGN_SKILL"
assert_hard_gate_absent 'error codes' "$DESIGN_SKILL"
assert_hard_gate_absent 'migration / verification / rollback' "$DESIGN_SKILL"


assert_hard_gate_absent 'full traceability' "$TECH_LEAD_SKILL"
assert_hard_gate_absent 'DESIGN_OK verdict AND complete coverage matrix' "$TECH_LEAD_SKILL"
assert_hard_gate_absent 'real_dependency_note' "$TECH_LEAD_SKILL"
assert_hard_gate_absent 'evidence_target' "$TECH_LEAD_SKILL"
assert_hard_gate_absent 'mock_boundary_note' "$TECH_LEAD_SKILL"

assert_hard_gate_absent 'environment_or_build' "$QA_SKILL"
assert_hard_gate_absent 'release_recommendation' "$QA_SKILL"

assert_hard_gate_absent 'Allowed values:' "$FIX_SKILL"

assert_hard_gate_absent 'task_packet_check.sh' "$DELIVERY_OWNER_SKILL"
assert_hard_gate_absent 'current_gap / progress_signal' "$DELIVERY_OWNER_SKILL"
assert_hard_gate_absent 'next_owner' "$DELIVERY_OWNER_SKILL"

python3 - "$ROOT/shared/skills/tech-lead/contracts/tasks.schema.json" <<'PY'
import json
import sys
from pathlib import Path

schema = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
properties = schema["allOf"][1]["properties"]
task_required = set(properties["tasks"]["items"]["required"])
required_task_fields = {
    "scope_item_refs",
    "test_refs",
    "acceptance_targets",
    "evidence_target",
}
missing = sorted(required_task_fields - task_required)
if missing:
    raise SystemExit(f"tech-lead task contract missing hard-gate fields: {missing}")
PY
python3 - "$ROOT/shared/skills/fix/contracts/fix-result.schema.json" <<'PY'
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

schema = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
issue_schema = schema["allOf"][1]["properties"]["issues"]["items"]
if "failure_class" not in issue_schema["required"]:
    raise SystemExit("fix-result issues must require failure_class")
if "FIXABLE" not in issue_schema["properties"]["failure_class"]["enum"]:
    raise SystemExit("fix-result failure_class must define FIXABLE")

base_issue = {
    "issue_id": "FIX-1",
    "failure_class": "REQUIREMENT_AMBIGUITY",
    "diagnosis_evidence": ["Observed conflicting acceptance statements", "Decision owner has not resolved them"],
    "fix_summary": "No code change while the requirement remains unresolved",
    "impact_files": [],
}
validator = Draft202012Validator(issue_schema)

unresolved = {**base_issue, "diagnosis_status": "UNRESOLVED"}
validator.validate(unresolved)

unresolved_with_fake_root = {**unresolved, "root_cause_ref": "src/example.py:1"}
if not list(validator.iter_errors(unresolved_with_fake_root)):
    raise SystemExit("UNRESOLVED issue must not fabricate root_cause_ref")

confirmed_without_root = {**base_issue, "diagnosis_status": "CONFIRMED"}
if not list(validator.iter_errors(confirmed_without_root)):
    raise SystemExit("CONFIRMED issue must require root_cause_ref")

confirmed = {**confirmed_without_root, "root_cause_ref": "requirements/checkout.md#AC-2"}
validator.validate(confirmed)
PY

assert_present 'python3 tools/community/validate_co_creation_ledger.py --artifact "docs/{feature}/product-director-ledger.json" --producer product-director --require-finalized' "$DIRECTOR_SKILL"
assert_absent 'design-ledger.json' "$DESIGN_SKILL"
assert_present 'bash shared/skills/design/scripts/preflight_check.sh --arguments "$ARGUMENTS"' "$DESIGN_SKILL"
assert_present 'task_packet_check.sh --packet "$TASK_PACKET_JSON_PATH"' "$DELIVERY_OWNER_SKILL"

printf '[PASS] standard-chain hard-gate boundary contract\n'
