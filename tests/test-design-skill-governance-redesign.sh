#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: ${1#"$ROOT"/}"
}

assert_present() {
  local pattern="$1" file="$2" label="${3:-$2}"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${label#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2" label="${3:-$2}"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in ${label#"$ROOT"/}: $pattern"
  fi
}

assert_standard_chain_design_key_field() {
  local field="$1"
  python3 - "$STANDARD_CHAIN" "$field" "$ROOT" <<'PY' || fail "missing design key_fields entry in ${STANDARD_CHAIN#"$ROOT"/}: $field"
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
root = Path(sys.argv[3])
sys.path.insert(0, str(root / "tools/community"))
from runtime_yaml import load_yaml

standard_chain = load_yaml(path)
for step in standard_chain.get("chain", []):
    if step.get("name") != "design":
        continue
    for output in step.get("outputs", []):
        if output.get("artifact") == "phase-{N}/design.json" and field in output.get("key_fields", []):
            raise SystemExit(0)
raise SystemExit(1)
PY
}

assert_registry_design_required_field() {
  local field="$1"
  python3 - "$REGISTRY_TEST" "$field" <<'PY' || fail "missing design REQUIRED_SCHEMA_FIELDS entry in ${REGISTRY_TEST#"$ROOT"/}: $field"
import ast
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
text = path.read_text(encoding="utf-8")
for match in re.finditer(r"<<'PY'[^\n]*\n(.*?)\nPY", text, re.S):
    module = ast.parse(match.group(1))
    for node in ast.walk(module):
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(target, ast.Name) and target.id == "REQUIRED_SCHEMA_FIELDS" for target in node.targets):
            continue
        value = ast.literal_eval(node.value)
        if field in value.get("design", set()):
            raise SystemExit(0)
raise SystemExit(1)
PY
}

assert_closure_design_required_field() {
  local field="$1"
  python3 - "$CLOSURE_TEST" "$field" <<'PY' || fail "missing design required-field assertion in ${CLOSURE_TEST#"$ROOT"/}: $field"
import ast
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
text = path.read_text(encoding="utf-8")
for match in re.finditer(r"<<'PY'[^\n]*\n(.*?)\nPY", text, re.S):
    module = ast.parse(match.group(1))
    for node in ast.walk(module):
        if not isinstance(node, ast.For):
            continue
        messages = [
            child.value
            for child in ast.walk(node)
            if isinstance(child, ast.Constant) and isinstance(child.value, str)
        ]
        if not any("design schema must require" in message for message in messages):
            continue
        values = ast.literal_eval(node.iter)
        if field in values:
            raise SystemExit(0)
raise SystemExit(1)
PY
}

run_design_hook() {
  local workspace="$1"
  local transcript_path="$workspace/transcript.log"
  local payload status

  printf '%s\n' "docs/sample-feature/phase-1/design.json" > "$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "design-governance-redesign" \
    --arg tp "$transcript_path" \
    --arg fp "docs/sample-feature/phase-1/design.json" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"
  if (cd "$workspace" && bash "$DESIGN_CHECK" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$workspace/hook.status"
}

run_test_design_hook() {
  local workspace="$1"
  local transcript_path="$workspace/transcript-test-design.log"
  local payload status

  printf '%s\n' "docs/sample-feature/phase-1/unit-1/test-cases.json" > "$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "design-governance-redesign" \
    --arg tp "$transcript_path" \
    --arg fp "docs/sample-feature/phase-1/unit-1/test-cases.json" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"
  if (cd "$workspace" && bash "$TEST_DESIGN_CHECK" <<<"$payload") >"$workspace/test-design-hook.stdout" 2>"$workspace/test-design-hook.stderr"; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$workspace/test-design-hook.status"
}

prepare_phase_probe_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$workspace/docs/sample-feature"
}

mutate_test_cases_design_source_ref() {
  local test_cases_file="$1" mutation="$2"
  python3 - "$test_cases_file" "$mutation" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mutation = sys.argv[2]
payload = json.loads(path.read_text(encoding="utf-8"))
if mutation == "missing":
    payload["qa_handoff_contract"][0].pop("design_source_refs", None)
elif mutation == "bad":
    payload["qa_handoff_contract"][0]["design_source_refs"] = ["design.json#not-real"]
else:
    raise SystemExit(f"unknown mutation: {mutation}")
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

remove_design_field() {
  local design_file="$1" field="$2"
  python3 - "$design_file" "$field" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
payload = json.loads(path.read_text(encoding="utf-8"))
payload.pop(field, None)
payload["authoritative_fields"] = [
    item for item in payload.get("authoritative_fields", []) if item != f"$.{field}"
]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

remove_cross_cutting_concern() {
  local design_file="$1" concern="$2"
  python3 - "$design_file" "$concern" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
concern = sys.argv[2]
payload = json.loads(path.read_text(encoding="utf-8"))
payload["cross_cutting_concerns"] = [
    row for row in payload.get("cross_cutting_concerns", [])
    if row.get("concern") != concern
]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

mutate_design_reference() {
  local design_file="$1" mutation="$2"
  python3 - "$design_file" "$mutation" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mutation = sys.argv[2]
payload = json.loads(path.read_text(encoding="utf-8"))
if mutation == "manager_vp_ref":
    payload["verification_mapping"][0]["manager_vp_ref"] = "phase-prd.exit_conditions[999]"
elif mutation == "unit_id":
    payload["unit_coverage"][0]["unit_id"] = "UNIT-999"
elif mutation == "design_ref":
    payload["unit_coverage"][0]["design_refs"][0] = "MOD-DOES-NOT-EXIST"
elif mutation == "affected_module":
    payload["impact_scope"][0]["affected_modules"][0] = "MOD-DOES-NOT-EXIST"
elif mutation == "accepted_ref":
    payload["product_handoff"]["accepted_refs"] = [
        "brief.json#not-real",
        "phase-prd.json#not-real",
    ]
else:
    raise SystemExit(f"unknown mutation: {mutation}")
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

assert_phase_rejects_bad_test_design_source_ref() {
  local mutation="$1" tmp_dir phase_dir stdout_file stderr_file
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-design-source-phase.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"
  phase_dir="$tmp_dir/docs/sample-feature/phase-1"
  stdout_file="$tmp_dir/phase.stdout"
  stderr_file="$tmp_dir/phase.stderr"

  if ! python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator baseline must pass before test-design source ref probe: $mutation"
  fi

  mutate_test_cases_design_source_ref "$phase_dir/unit-1/test-cases.json" "$mutation"
  if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator should reject bad test-design source ref: $mutation"
  fi
  rm -rf "$tmp_dir"
}

assert_test_design_gate_rejects_bad_source_ref() {
  local mutation="$1" tmp_dir status
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-design-source-hook.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"

  run_test_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/test-design-hook.status")"
  if [ "$status" != "0" ] || ! jq -e '.decision == "allow"' "$tmp_dir/test-design-hook.stdout" >/dev/null 2>&1; then
    cat "$tmp_dir/test-design-hook.stdout" >&2
    cat "$tmp_dir/test-design-hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "test-design gate baseline must allow before source ref probe: $mutation"
  fi

  mutate_test_cases_design_source_ref "$tmp_dir/docs/sample-feature/phase-1/unit-1/test-cases.json" "$mutation"
  run_test_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/test-design-hook.status")"
  if [ "$status" = "0" ]; then
    cat "$tmp_dir/test-design-hook.stdout" >&2
    cat "$tmp_dir/test-design-hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "test-design gate should exit non-zero for bad source ref: $mutation"
  fi
  jq -e '.decision == "block"' "$tmp_dir/test-design-hook.stdout" >/dev/null 2>&1 || {
    cat "$tmp_dir/test-design-hook.stdout" >&2
    cat "$tmp_dir/test-design-hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "test-design gate should emit a block decision for bad source ref: $mutation"
  }
  rm -rf "$tmp_dir"
}

assert_phase_rejects_missing_design_field() {
  local field="$1" tmp_dir phase_dir stdout_file stderr_file
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-governance-phase.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"
  phase_dir="$tmp_dir/docs/sample-feature/phase-1"
  stdout_file="$tmp_dir/phase.stdout"
  stderr_file="$tmp_dir/phase.stderr"

  if ! python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator baseline must pass before missing-field probe: $field"
  fi

  remove_design_field "$phase_dir/design.json" "$field"
  if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator should reject design missing field: $field"
  fi
  rm -rf "$tmp_dir"
}

assert_phase_rejects_bad_design_reference() {
  local mutation="$1" tmp_dir phase_dir stdout_file stderr_file
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-governance-ref.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"
  phase_dir="$tmp_dir/docs/sample-feature/phase-1"
  stdout_file="$tmp_dir/phase.stdout"
  stderr_file="$tmp_dir/phase.stderr"

  if ! python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator baseline must pass before bad-reference probe: $mutation"
  fi

  mutate_design_reference "$phase_dir/design.json" "$mutation"
  if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator should reject bad design reference: $mutation"
  fi
  rm -rf "$tmp_dir"
}

assert_design_gate_rejects_missing_field() {
  local field="$1" tmp_dir status
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-governance-hook.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"

  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" != "0" ] || ! jq -e '.decision == "allow"' "$tmp_dir/hook.stdout" >/dev/null 2>&1; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate baseline must allow before missing-field probe: $field"
  fi

  remove_design_field "$tmp_dir/docs/sample-feature/phase-1/design.json" "$field"
  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" = "0" ]; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should exit non-zero when design is missing field: $field"
  fi
  jq -e '.decision == "block"' "$tmp_dir/hook.stdout" >/dev/null 2>&1 || {
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should emit a block decision when design is missing field: $field"
  }
  rm -rf "$tmp_dir"
}

assert_design_gate_rejects_bad_design_reference() {
  local mutation="$1" tmp_dir status
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-governance-hook-ref.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"

  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" != "0" ] || ! jq -e '.decision == "allow"' "$tmp_dir/hook.stdout" >/dev/null 2>&1; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate baseline must allow before bad-reference probe: $mutation"
  fi

  mutate_design_reference "$tmp_dir/docs/sample-feature/phase-1/design.json" "$mutation"
  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" = "0" ]; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should exit non-zero for bad design reference: $mutation"
  fi
  jq -e '.decision == "block"' "$tmp_dir/hook.stdout" >/dev/null 2>&1 || {
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should emit a block decision for bad design reference: $mutation"
  }
  rm -rf "$tmp_dir"
}

assert_design_gate_rejects_missing_concern() {
  local concern="$1" tmp_dir status
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-governance-hook-concern.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"

  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" != "0" ] || ! jq -e '.decision == "allow"' "$tmp_dir/hook.stdout" >/dev/null 2>&1; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate baseline must allow before missing-concern probe: $concern"
  fi

  remove_cross_cutting_concern "$tmp_dir/docs/sample-feature/phase-1/design.json" "$concern"
  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" = "0" ]; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should exit non-zero when design is missing cross-cutting concern: $concern"
  fi
  jq -e '.decision == "block"' "$tmp_dir/hook.stdout" >/dev/null 2>&1 || {
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should emit a block decision when design is missing cross-cutting concern: $concern"
  }
  rm -rf "$tmp_dir"
}

assert_phase_rejects_missing_concern() {
  local concern="$1" tmp_dir phase_dir stdout_file stderr_file
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-governance-concern.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"
  phase_dir="$tmp_dir/docs/sample-feature/phase-1"
  stdout_file="$tmp_dir/phase.stdout"
  stderr_file="$tmp_dir/phase.stderr"

  if ! python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator baseline must pass before missing-concern probe: $concern"
  fi

  remove_cross_cutting_concern "$phase_dir/design.json" "$concern"
  if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator should reject design missing cross-cutting concern: $concern"
  fi
  rm -rf "$tmp_dir"
}

STANDARD="$ROOT/shared/reference/Skill质量标准.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
TEST_DESIGN_SKILL="$ROOT/shared/skills/test-design/SKILL.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
DESIGN_TEMPLATE="$ROOT/contracts/canonical/templates/planning/design.template.json"
DESIGN_SCHEMA="$ROOT/contracts/canonical/schemas/planning/design.schema.json"
DESIGN_CHECK="$ROOT/shared/skills/design/scripts/completion_check.sh"
TEST_DESIGN_CHECK="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
CANONICAL_RULES="$ROOT/tools/community/validate_canonical_rules.py"
STANDARD_CHAIN="$ROOT/contracts/standard-chain.yaml"
REGISTRY_TEST="$ROOT/tests/test-standard-chain-foundation-registry.sh"
CLOSURE_TEST="$ROOT/tests/test-standard-chain-closure-contract.sh"
TEST_CASES_TEMPLATE="$ROOT/contracts/canonical/templates/planning/test-cases.template.json"
TEST_CASES_SCHEMA="$ROOT/contracts/canonical/schemas/planning/test-cases.schema.json"

for file in \
  "$STANDARD" \
  "$DESIGN_SKILL" \
  "$TEST_DESIGN_SKILL" \
  "$TECH_LEAD_SKILL" \
  "$DESIGN_TEMPLATE" \
  "$DESIGN_SCHEMA" \
  "$DESIGN_CHECK" \
  "$TEST_DESIGN_CHECK" \
  "$CANONICAL_RULES" \
  "$STANDARD_CHAIN" \
  "$REGISTRY_TEST" \
  "$CLOSURE_TEST" \
  "$TEST_CASES_TEMPLATE" \
  "$TEST_CASES_SCHEMA"; do
  assert_file "$file"
done

assert_present '500 行 / 5000 tokens|5000 tokens / 500 行' "$STANDARD"
assert_present '250 行.*审视信号|审视信号.*250 行' "$STANDARD"
assert_absent 'Pipeline skill \| <=250 行' "$STANDARD"
assert_present 'Q1.*技术现状与约束' "$DESIGN_SKILL"
assert_present 'Q9.*风险与回应' "$DESIGN_SKILL"
assert_present 'LLM 判断.*Artifact.*工程化验证|工程化验证.*Artifact.*LLM 判断' "$DESIGN_SKILL"
assert_present 'consumer-first|消费者优先' "$DESIGN_SKILL"
assert_present 'Trigger.*Read.*Expect.*Consume.*Evidence.*Sync' "$DESIGN_SKILL"

for field in \
  modules \
  data_architecture \
  cross_cutting_concerns \
  verification_mapping \
  unit_coverage \
  impact_scope \
  planning_constraints \
  product_handoff \
  risks \
  risk_response; do
  assert_present "\"$field\"" "$DESIGN_TEMPLATE"
  assert_present "\"$field\"" "$DESIGN_SCHEMA"
  assert_standard_chain_design_key_field "$field"
  assert_registry_design_required_field "$field"
  assert_closure_design_required_field "$field"
  assert_phase_rejects_missing_design_field "$field"
  assert_design_gate_rejects_missing_field "$field"
done

for concern in auth error log config; do
  assert_phase_rejects_missing_concern "$concern"
  assert_design_gate_rejects_missing_concern "$concern"
done

for mutation in manager_vp_ref unit_id design_ref affected_module accepted_ref; do
  assert_phase_rejects_bad_design_reference "$mutation"
  assert_design_gate_rejects_bad_design_reference "$mutation"
done

for mutation in missing bad; do
  assert_phase_rejects_bad_test_design_source_ref "$mutation"
  assert_test_design_gate_rejects_bad_source_ref "$mutation"
done

assert_present 'data_architecture.*DESIGN-GAP|DESIGN-GAP.*data_architecture' "$TEST_DESIGN_SKILL"
assert_present 'cross_cutting_concerns.*auth.*error.*log.*config|auth.*error.*log.*config.*cross_cutting_concerns' "$TEST_DESIGN_SKILL"
assert_present 'verification_mapping' "$TEST_DESIGN_SKILL"
assert_present 'manager_vp_ref.*design_source_refs|design_source_refs.*manager_vp_ref' "$TEST_DESIGN_SKILL"
assert_present '"design_source_refs"' "$TEST_CASES_TEMPLATE"
assert_present '"design_source_refs"' "$TEST_CASES_SCHEMA"
assert_present 'unit_coverage.*Task|Task.*unit_coverage' "$TECH_LEAD_SKILL"
assert_present 'impact_scope.*scope_item_id|scope_item_id.*impact_scope' "$TECH_LEAD_SKILL"
assert_present 'planning_constraints.*探索|探索.*planning_constraints' "$TECH_LEAD_SKILL"

printf '[PASS] design skill governance redesign\n'
