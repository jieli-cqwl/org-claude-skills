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

assert_allowed_tools_exact() {
  local file="$1" expected_csv="$2" label="${3:-$file}"
  python3 - "$file" "$expected_csv" "$label" "$ROOT" <<'PY' || fail "allowed-tools mismatch in ${label#"$ROOT"/}: expected $expected_csv"
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected = [item.strip() for item in sys.argv[2].split(",") if item.strip()]
text = path.read_text(encoding="utf-8")
actual = None
for line in text.splitlines():
    if line.startswith("allowed-tools:"):
        actual = [item.strip() for item in line.split(":", 1)[1].split(",") if item.strip()]
        break
if actual is None:
    raise SystemExit("missing allowed-tools")
if sorted(actual) != sorted(expected):
    raise SystemExit(f"actual={actual}, expected={expected}")
PY
}

assert_reference_contract() {
  local file="$1"
  for field in Trigger Read Expect Consume Evidence Sync; do
    assert_present "^>?[[:space:]]*$field:" "$file"
  done
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

assert_test_design_manifest_contract() {
  assert_manifest_contract "$TEST_DESIGN_MANIFEST" "test-design" "tests/test-design-skill-governance-redesign.sh" '$TMPDIR|/tmp'
}

assert_manifest_contract() {
  local manifest_path="$1" owner="$2" proof_fragment="$3" expected_output_root="$4"
  jq -e --arg owner "$owner" --arg proof_fragment "$proof_fragment" --arg expected_output_root "$expected_output_root" '
    .scripts[]
    | select(.path == "scripts/completion_check.sh")
    | .owner == $owner
      and (.allowed_args | index("hook payload via stdin only") != null)
      and (.allowed_args | index("--help") != null)
      and (.allowed_args | index("-h") != null)
      and .timeout_seconds == 15
      and .output_root == $expected_output_root
      and (.failure_state | type == "string" and length > 0)
      and (.verification_command | contains($proof_fragment))
  ' "$manifest_path" >/dev/null || fail "${owner} manifest must define owner, args, timeout, output root, failure state, and proof command"
}

assert_registry_contract() {
  local manifest_path="$1" skill_name="$2"
  python3 - "$manifest_path" "$HOOK_REGISTRY" "$skill_name" <<'PY' || fail "$skill_name registry must mirror manifest owner, handler, args, output root, and failure state"
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
skill_name = sys.argv[3]
scripts = [item for item in manifest["scripts"] if item.get("path") == "scripts/completion_check.sh"]
if len(scripts) != 1:
    raise SystemExit(f"{skill_name} manifest must have exactly one completion_check.sh script")
script = scripts[0]
entries = [item for item in registry["skill_completion_gates"] if item.get("skill") == skill_name]
if len(entries) != 1:
    raise SystemExit(f"{skill_name} registry must have exactly one entry")
entry = entries[0]
required = {"handler_rel", "owner", "allowed_args", "output_root", "failure_state"}
missing = sorted(required - set(entry))
if missing:
    raise SystemExit(f"{skill_name} registry missing keys: {missing}")
if entry["handler_rel"] != f"skills/{skill_name}/{script['path']}":
    raise SystemExit(f"{skill_name} registry and manifest drift on handler_rel")
for field in required - {"handler_rel"}:
    if entry[field] != script[field]:
        raise SystemExit(f"{skill_name} registry and manifest drift on {field}")
if entry.get("timeout_sec") != script.get("timeout_seconds"):
    raise SystemExit(f"{skill_name} registry and manifest drift on timeout")
PY
}

assert_test_design_registry_contract() {
  assert_registry_contract "$TEST_DESIGN_MANIFEST" "test-design"
}

assert_design_manifest_contract() {
  assert_manifest_contract "$DESIGN_MANIFEST" "design" "tests/test-design-skill-governance-redesign.sh" "."
}

assert_design_registry_contract() {
  assert_registry_contract "$DESIGN_MANIFEST" "design"
}

assert_test_design_permission_boundary() {
  assert_allowed_tools_exact "$TEST_DESIGN_SKILL" "Read,Write,Bash,Glob,Grep,TeamCreate,AskUserQuestion"
  assert_present 'TeamCreate 协作团队.*Parallel Review' "$TEST_DESIGN_SKILL"
  assert_present 'reviewer 只读输入工件' "$TEST_DESIGN_SKILL"
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

mutate_test_cases_review_contract() {
  local test_cases_file="$1" mutation="$2"
  python3 - "$test_cases_file" "$mutation" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mutation = sys.argv[2]
payload = json.loads(path.read_text(encoding="utf-8"))
if mutation == "fail_verdict":
    payload["review_conclusion"]["verdict"] = "FAIL"
elif mutation == "missing_convergence":
    payload["review_conclusion"].pop("review_round", None)
    payload["review_conclusion"].pop("convergence_evidence", None)
elif mutation == "warn_without_ledger":
    payload["review_conclusion"]["verdict"] = "WARN"
    payload["issue_ledger"] = []
elif mutation == "missing_triple_coverage":
    payload["ac_coverage_matrix"][0].pop("positive_case_refs", None)
elif mutation == "positive_over_negative_boundary":
    payload["ac_coverage_matrix"][0]["positive_case_refs"] = ["TC-POS-1", "TC-POS-2"]
    payload["ac_coverage_matrix"][0]["negative_case_refs"] = ["TC-NEG-1"]
    payload["ac_coverage_matrix"][0]["boundary_case_refs"] = []
elif mutation == "case_type_mismatch":
    payload["ac_coverage_matrix"][0]["negative_case_refs"] = [
        payload["ac_coverage_matrix"][0]["positive_case_refs"][0]
    ]
elif mutation == "missing_reviewer_verdicts":
    payload["review_conclusion"].pop("reviewer_verdicts", None)
elif mutation == "reviewer_fail_verdict":
    payload["review_conclusion"]["reviewer_verdicts"][0]["verdict"] = "FAIL"
elif mutation == "reviewer_warn_aggregate_mismatch":
    payload["review_conclusion"]["reviewer_verdicts"][0]["verdict"] = "WARN"
elif mutation == "unknown_handoff_obligation":
    payload["cross_unit_obligations"][0]["handoff_obligation_refs"] = [
        "NOT_A_REAL_QA_OBLIGATION"
    ]
elif mutation == "missing_special_trigger":
    payload["special_test_triggers"] = []
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

remove_design_interface_field() {
  local design_file="$1" field="$2"
  python3 - "$design_file" "$field" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
payload = json.loads(path.read_text(encoding="utf-8"))
for item in payload.get("interfaces", []):
    if isinstance(item, dict):
        item.pop(field, None)
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

assert_phase_rejects_bad_test_design_review_contract() {
  local mutation="$1" tmp_dir phase_dir stdout_file stderr_file
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-design-review-phase.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"
  phase_dir="$tmp_dir/docs/sample-feature/phase-1"
  stdout_file="$tmp_dir/phase.stdout"
  stderr_file="$tmp_dir/phase.stderr"

  if ! python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator baseline must pass before test-design review contract probe: $mutation"
  fi

  mutate_test_cases_review_contract "$phase_dir/unit-1/test-cases.json" "$mutation"
  if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator should reject bad test-design review contract: $mutation"
  fi
  rm -rf "$tmp_dir"
}

assert_test_design_gate_rejects_bad_review_contract() {
  local mutation="$1" tmp_dir status
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-design-review-hook.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"

  run_test_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/test-design-hook.status")"
  if [ "$status" != "0" ] || ! jq -e '.decision == "allow"' "$tmp_dir/test-design-hook.stdout" >/dev/null 2>&1; then
    cat "$tmp_dir/test-design-hook.stdout" >&2
    cat "$tmp_dir/test-design-hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "test-design gate baseline must allow before review contract probe: $mutation"
  fi

  mutate_test_cases_review_contract "$tmp_dir/docs/sample-feature/phase-1/unit-1/test-cases.json" "$mutation"
  run_test_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/test-design-hook.status")"
  if [ "$status" = "0" ]; then
    cat "$tmp_dir/test-design-hook.stdout" >&2
    cat "$tmp_dir/test-design-hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "test-design gate should exit non-zero for bad review contract: $mutation"
  fi
  jq -e '.decision == "block"' "$tmp_dir/test-design-hook.stdout" >/dev/null 2>&1 || {
    cat "$tmp_dir/test-design-hook.stdout" >&2
    cat "$tmp_dir/test-design-hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "test-design gate should emit a block decision for bad review contract: $mutation"
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

assert_phase_rejects_missing_interface_field() {
  local field="$1" tmp_dir phase_dir stdout_file stderr_file
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-interface-phase.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"
  phase_dir="$tmp_dir/docs/sample-feature/phase-1"
  stdout_file="$tmp_dir/phase.stdout"
  stderr_file="$tmp_dir/phase.stderr"

  if ! python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator baseline must pass before missing-interface-field probe: $field"
  fi

  remove_design_interface_field "$phase_dir/design.json" "$field"
  if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$phase_dir" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file" >&2
    cat "$stderr_file" >&2
    rm -rf "$tmp_dir"
    fail "phase validator should reject design interface missing field: $field"
  fi
  rm -rf "$tmp_dir"
}

assert_design_gate_rejects_missing_interface_field() {
  local field="$1" tmp_dir status
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/design-interface-hook.XXXXXX")"
  prepare_phase_probe_workspace "$tmp_dir"

  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" != "0" ] || ! jq -e '.decision == "allow"' "$tmp_dir/hook.stdout" >/dev/null 2>&1; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate baseline must allow before missing-interface-field probe: $field"
  fi

  remove_design_interface_field "$tmp_dir/docs/sample-feature/phase-1/design.json" "$field"
  run_design_hook "$tmp_dir"
  status="$(cat "$tmp_dir/hook.status")"
  if [ "$status" = "0" ]; then
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should exit non-zero when interface is missing field: $field"
  fi
  jq -e '.decision == "block"' "$tmp_dir/hook.stdout" >/dev/null 2>&1 || {
    cat "$tmp_dir/hook.stdout" >&2
    cat "$tmp_dir/hook.stderr" >&2
    rm -rf "$tmp_dir"
    fail "design gate should emit a block decision when interface is missing field: $field"
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
DESIGN_MANIFEST="$ROOT/shared/skills/design/scripts/manifest.json"
TEST_DESIGN_MANIFEST="$ROOT/shared/skills/test-design/scripts/manifest.json"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
DEVELOPER_SKILL="$ROOT/shared/skills/developer/SKILL.md"
VERIFY_SKILL="$ROOT/shared/skills/verify/SKILL.md"
DELIVERY_OWNER_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
CONSISTENCY_AUDIT_SKILL="$ROOT/shared/skills/consistency-audit/SKILL.md"
TEST_DESIGN_PROJECTION="$ROOT/shared/skills/test-design/projections/test-cases-template.md"
TEST_DESIGN_METHODOLOGY="$ROOT/shared/skills/test-design/references/methodology.md"
TEST_DESIGN_REVIEWER="$ROOT/shared/skills/test-design/references/testdesign-reviewer-prompt.md"
TEST_DESIGN_PRODUCT_REVIEWER="$ROOT/shared/skills/test-design/references/testdesign-product-reviewer-prompt.md"
TEST_DESIGN_ARCH_REVIEWER="$ROOT/shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md"
TEST_DESIGN_INTEGRATION_METHOD="$ROOT/shared/skills/test-design/references/integration-test-methodology.md"
TEST_DESIGN_CONTRACT_METHOD="$ROOT/shared/skills/test-design/references/contract-test-methodology.md"
TEST_DESIGN_SECURITY_METHOD="$ROOT/shared/skills/test-design/references/security-test-methodology.md"
TEST_DESIGN_PERFORMANCE_METHOD="$ROOT/shared/skills/test-design/references/performance-test-methodology.md"
DESIGN_TEMPLATE="$ROOT/shared/skills/design/templates/design.template.json"
DESIGN_SCHEMA="$ROOT/shared/skills/design/contracts/design.schema.json"
DESIGN_CHECK="$ROOT/shared/skills/design/scripts/completion_check.sh"
TEST_DESIGN_CHECK="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
CANONICAL_RULES="$ROOT/tools/community/validate_canonical_rules.py"
TEST_CASE_SPECIAL_RULES="$ROOT/tools/community/canonical_test_case_special_rules.py"
STANDARD_CHAIN="$ROOT/contracts/standard-chain.yaml"
REGISTRY_TEST="$ROOT/tests/test-standard-chain-foundation-registry.sh"
CLOSURE_TEST="$ROOT/tests/test-standard-chain-closure-contract.sh"
TEST_CASES_TEMPLATE="$ROOT/shared/skills/test-design/templates/test-cases.template.json"
TEST_CASES_SCHEMA="$ROOT/shared/skills/test-design/contracts/test-cases.schema.json"

for file in \
  "$STANDARD" \
  "$DESIGN_SKILL" \
  "$TEST_DESIGN_SKILL" \
  "$DESIGN_MANIFEST" \
  "$TEST_DESIGN_MANIFEST" \
  "$HOOK_REGISTRY" \
  "$TECH_LEAD_SKILL" \
  "$DEVELOPER_SKILL" \
  "$VERIFY_SKILL" \
  "$DELIVERY_OWNER_SKILL" \
  "$CONSISTENCY_AUDIT_SKILL" \
  "$TEST_DESIGN_PROJECTION" \
  "$TEST_DESIGN_METHODOLOGY" \
  "$TEST_DESIGN_REVIEWER" \
  "$TEST_DESIGN_PRODUCT_REVIEWER" \
  "$TEST_DESIGN_ARCH_REVIEWER" \
  "$TEST_DESIGN_INTEGRATION_METHOD" \
  "$TEST_DESIGN_CONTRACT_METHOD" \
  "$TEST_DESIGN_SECURITY_METHOD" \
  "$TEST_DESIGN_PERFORMANCE_METHOD" \
  "$DESIGN_TEMPLATE" \
  "$DESIGN_SCHEMA" \
  "$DESIGN_CHECK" \
  "$TEST_DESIGN_CHECK" \
  "$CANONICAL_RULES" \
  "$TEST_CASE_SPECIAL_RULES" \
  "$STANDARD_CHAIN" \
  "$REGISTRY_TEST" \
  "$CLOSURE_TEST" \
  "$TEST_CASES_TEMPLATE" \
  "$TEST_CASES_SCHEMA"; do
  assert_file "$file"
done

assert_test_design_manifest_contract
assert_test_design_registry_contract
assert_design_manifest_contract
assert_design_registry_contract
assert_test_design_permission_boundary

assert_present '^## Bash 使用边界$' "$TEST_DESIGN_SKILL"
assert_present 'Bash.*只用于只读校验和 fresh proof|只读校验和 fresh proof.*Bash' "$TEST_DESIGN_SKILL"
assert_present '禁止：.*git.*安装依赖.*网络调用.*删除文件' "$TEST_DESIGN_SKILL"
assert_present '\$TMPDIR.*\/tmp' "$TEST_DESIGN_SKILL"
assert_present '500 行 / 5000 tokens|5000 tokens / 500 行' "$STANDARD"
assert_present '250 行.*审视信号|审视信号.*250 行' "$STANDARD"
assert_absent 'Pipeline skill \| <=250 行' "$STANDARD"
assert_present 'Q1.*技术现状与约束' "$DESIGN_SKILL"
assert_present 'Q9.*风险与回应' "$DESIGN_SKILL"
assert_present 'LLM 判断.*Artifact.*工程化验证|工程化验证.*Artifact.*LLM 判断' "$DESIGN_SKILL"
assert_present 'consumer-first|消费者优先' "$DESIGN_SKILL"
assert_present 'Trigger.*Read.*Expect.*Consume.*Evidence.*Sync' "$DESIGN_SKILL"

for field in \
  co_creation_summary \
  constraint_inheritance_confirmation \
  final_confirmation \
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

for interface_field in input_params output_params error_codes; do
  assert_present "\"$interface_field\"" "$DESIGN_TEMPLATE"
  assert_present "\"$interface_field\"" "$DESIGN_SCHEMA"
  assert_phase_rejects_missing_interface_field "$interface_field"
  assert_design_gate_rejects_missing_interface_field "$interface_field"
done

assert_present 'option_analysis.*2\+.*alternative|2\+.*alternative.*option_analysis|option_analysis.*2\+.*方案|2\+.*方案.*option_analysis' "$DESIGN_SKILL"
assert_present 'key_decisions.*最终|最终.*key_decisions|key_decisions.*冻结|冻结.*key_decisions' "$DESIGN_SKILL"
assert_absent 'alternatives in `design\.json\.key_decisions`|方案.*`design\.json\.key_decisions`|`design\.json\.key_decisions`.*方案' "$DESIGN_SKILL"
assert_present 'final_confirmation' "$DESIGN_SKILL"
assert_present 'product_handoff' "$DESIGN_SKILL"
assert_absent '`design\.json\.delivery_confirmation`|design\.json.*delivery_confirmation|delivery_confirmation.*design\.json' "$DESIGN_SKILL"

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

for mutation in \
  fail_verdict \
  missing_convergence \
  warn_without_ledger \
  missing_triple_coverage \
  positive_over_negative_boundary \
  case_type_mismatch \
  missing_reviewer_verdicts \
  reviewer_fail_verdict \
  reviewer_warn_aggregate_mismatch \
  unknown_handoff_obligation \
  missing_special_trigger; do
  assert_phase_rejects_bad_test_design_review_contract "$mutation"
  assert_test_design_gate_rejects_bad_review_contract "$mutation"
done

assert_present '产品是一等真源' "$TEST_DESIGN_SKILL"
assert_present 'test_analysis.*traceability_matrix|traceability_matrix.*test_analysis' "$TEST_DESIGN_SKILL"
assert_present 'PRODUCT_GAP.*DESIGN_GAP.*SCOPE_DRIFT.*TRACE_CONFLICT.*TESTABILITY_GAP.*EQ_GAP' "$TEST_DESIGN_SKILL"
assert_present 'data_architecture.*DESIGN_GAP|DESIGN_GAP.*data_architecture' "$TEST_DESIGN_SKILL"
assert_present 'cross_cutting_concerns.*auth.*error.*log.*config|auth.*error.*log.*config.*cross_cutting_concerns' "$TEST_DESIGN_SKILL"
assert_present 'verification_mapping' "$TEST_DESIGN_SKILL"
assert_present 'manager_vp_ref.*design_source_refs|design_source_refs.*manager_vp_ref' "$TEST_DESIGN_SKILL"
assert_present 'blocking=true' "$TEST_DESIGN_SKILL"
assert_present 'qa_handoff_contract.*cross_unit_obligations|cross_unit_obligations.*qa_handoff_contract' "$TEST_DESIGN_SKILL"
assert_present 'references/methodology\.md.*Trigger:.*Read:.*Expect:.*Consume:.*Evidence:.*Sync:' "$TEST_DESIGN_SKILL"
assert_present 'journey_title.*predecessor_case_refs.*successor_case_refs|successor_case_refs.*predecessor_case_refs.*journey_title' "$TEST_DESIGN_SKILL"
assert_present 'product_refs.*design_refs.*assertion_target|assertion_target.*product_refs.*design_refs' "$TEST_DESIGN_SKILL"
assert_present 'reviewer_verdicts|三视角 Verdict' "$TEST_DESIGN_SKILL"
assert_present 'obligation_id' "$TEST_DESIGN_SKILL"
assert_present 'special_test_triggers.*source_refs|source_refs.*special_test_triggers|special_test_triggers.*source_ref' "$TEST_DESIGN_SKILL"
assert_present 'canonical enum.*人类标签|人类标签.*canonical enum' "$TEST_DESIGN_PROJECTION"
assert_present 'traceability_matrix' "$TEST_DESIGN_PROJECTION"
assert_present 'cross_unit_obligations|跨 UNIT 组合义务' "$TEST_DESIGN_PROJECTION"
assert_present 'reviewer_verdicts' "$TEST_DESIGN_PROJECTION"
assert_present 'design_source_refs' "$TEST_DESIGN_PROJECTION"
assert_present 'predecessor_case_refs.*successor_case_refs|successor_case_refs.*predecessor_case_refs' "$TEST_DESIGN_PROJECTION"
assert_present 'Review Round.*Evidence|Evidence.*Review Round' "$TEST_DESIGN_PROJECTION"
assert_present '"design_source_refs"' "$TEST_CASES_TEMPLATE"
assert_present '"design_source_refs"' "$TEST_CASES_SCHEMA"
assert_present '"obligation_id"' "$TEST_CASES_TEMPLATE"
assert_present '"obligation_id"' "$TEST_CASES_SCHEMA"
assert_present '"reviewer_verdicts"' "$TEST_CASES_TEMPLATE"
assert_present '"reviewer_verdicts"' "$TEST_CASES_SCHEMA"
assert_present '"source_ref"' "$TEST_CASES_TEMPLATE"
assert_present '"source_ref"' "$TEST_CASES_SCHEMA"
for reference_contract in \
  "$TEST_DESIGN_METHODOLOGY" \
  "$TEST_DESIGN_REVIEWER" \
  "$TEST_DESIGN_PRODUCT_REVIEWER" \
  "$TEST_DESIGN_ARCH_REVIEWER" \
  "$TEST_DESIGN_INTEGRATION_METHOD" \
  "$TEST_DESIGN_CONTRACT_METHOD" \
  "$TEST_DESIGN_SECURITY_METHOD" \
  "$TEST_DESIGN_PERFORMANCE_METHOD"; do
  assert_reference_contract "$reference_contract"
done
for specialty_method in \
  "$TEST_DESIGN_INTEGRATION_METHOD" \
  "$TEST_DESIGN_CONTRACT_METHOD" \
  "$TEST_DESIGN_SECURITY_METHOD" \
  "$TEST_DESIGN_PERFORMANCE_METHOD"; do
  assert_absent '步骤 [0-9]+' "$specialty_method"
  assert_absent '步骤 10' "$specialty_method"
  assert_present '专项触发/专项展开规则' "$specialty_method"
done
assert_present 'assert_special_test_triggers' "$TEST_CASE_SPECIAL_RULES"
assert_present 'assert_qa_handoff_obligation_ids' "$TEST_CASE_SPECIAL_RULES"
assert_present 'quality_attributes' "$TEST_CASE_SPECIAL_RULES"
assert_present 'data_architecture' "$TEST_CASE_SPECIAL_RULES"
assert_present 'cross_cutting_concerns' "$TEST_CASE_SPECIAL_RULES"
assert_present 'test_analysis' "$TEST_DESIGN_REVIEWER"
assert_present 'traceability_matrix' "$TEST_DESIGN_REVIEWER"
assert_present 'assertion_target' "$TEST_DESIGN_REVIEWER"
assert_present 'obligation_id.*handoff_obligation_refs|handoff_obligation_refs.*obligation_id' "$TEST_DESIGN_REVIEWER"
assert_present 'Perspective: test_quality' "$TEST_DESIGN_REVIEWER"
assert_present 'Review Round: R<N>' "$TEST_DESIGN_REVIEWER"
assert_present 'Evidence:' "$TEST_DESIGN_REVIEWER"
assert_present 'blocking=true' "$TEST_DESIGN_REVIEWER"
assert_present '产品是一等真源' "$TEST_DESIGN_PRODUCT_REVIEWER"
assert_present 'product_refs' "$TEST_DESIGN_PRODUCT_REVIEWER"
assert_present 'Perspective: product' "$TEST_DESIGN_PRODUCT_REVIEWER"
assert_present 'Review Round: R<N>' "$TEST_DESIGN_PRODUCT_REVIEWER"
assert_present 'Evidence:' "$TEST_DESIGN_PRODUCT_REVIEWER"
assert_present 'SCOPE_DRIFT' "$TEST_DESIGN_PRODUCT_REVIEWER"
assert_present 'design_refs' "$TEST_DESIGN_ARCH_REVIEWER"
assert_present 'Perspective: architecture' "$TEST_DESIGN_ARCH_REVIEWER"
assert_present 'Review Round: R<N>' "$TEST_DESIGN_ARCH_REVIEWER"
assert_present 'Evidence:' "$TEST_DESIGN_ARCH_REVIEWER"
assert_present 'TESTABILITY_GAP' "$TEST_DESIGN_ARCH_REVIEWER"
assert_present 'TRACE_CONFLICT' "$TEST_DESIGN_ARCH_REVIEWER"
assert_present 'unit_coverage.*Task|Task.*unit_coverage' "$TECH_LEAD_SKILL"
assert_present 'impact_scope.*scope_item_id|scope_item_id.*impact_scope' "$TECH_LEAD_SKILL"
assert_present 'planning_constraints.*探索|探索.*planning_constraints' "$TECH_LEAD_SKILL"
assert_present 'traceability_matrix' "$TECH_LEAD_SKILL"
assert_present 'blocking=true' "$TECH_LEAD_SKILL"
assert_present 'execution_basis' "$TECH_LEAD_SKILL"
assert_present 'assertion_target' "$DEVELOPER_SKILL"
assert_present 'evidence_expectation' "$DEVELOPER_SKILL"
assert_present 'design_gap_report' "$DEVELOPER_SKILL"
assert_present 'product_refs' "$VERIFY_SKILL"
assert_present 'design_refs' "$VERIFY_SKILL"
assert_present 'assertion_target' "$VERIFY_SKILL"
assert_present 'qa_handoff_contract' "$DELIVERY_OWNER_SKILL"
assert_present 'cross_unit_obligations' "$DELIVERY_OWNER_SKILL"
assert_present 'blocking=true' "$DELIVERY_OWNER_SKILL"
assert_present 'traceability_matrix' "$CONSISTENCY_AUDIT_SKILL"
assert_present 'typed gap' "$CONSISTENCY_AUDIT_SKILL"

printf '[PASS] design skill governance redesign\n'
