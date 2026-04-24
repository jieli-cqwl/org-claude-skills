#!/usr/bin/env bash
# Test Design canonical gate: validates standard-chain test-cases.json and its design dependency.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
test-design/completion_check.sh — canonical test design artifact gate
Execution: PostToolUse(Edit|Write) or skill-local Stop
Input: stdin JSON (cwd, session_id, transcript_path, optional tool_input.file_path)
Output: stdout JSON decision + stderr diagnostics
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
hook_init

# Validate design_source_refs against sibling design.json.
validate_design_source_refs() {
    local target="$1"
    local phase_dir design_file ref_out

    phase_dir=$(dirname "$(dirname "$target")")
    design_file="$phase_dir/design.json"
    ref_out="$(mktemp "${TMPDIR:-/tmp}/test-design-source-refs.XXXXXX")"

    if ! python3 - "$target" "$design_file" >"$ref_out" 2>&1 <<'PY'
import json
import re
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1])
design_path = Path(sys.argv[2])
design_ref_re = re.compile(r"^design\.json#(.+)$")


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def require_list(value, path):
    if not isinstance(value, list) or not value:
        raise ValueError(f"{path} must be a non-empty array")
    return value


def resolve_dotted_path(document, anchor):
    current = document
    for raw_part in anchor.split("."):
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)(?:\[(\d+)\])?", raw_part)
        if not match:
            raise ValueError(f"unsupported design source ref anchor: {anchor}")
        field, raw_index = match.groups()
        if not isinstance(current, dict) or field not in current:
            raise ValueError(f"design source ref does not resolve: {anchor}")
        current = current[field]
        if raw_index is None:
            continue
        if not isinstance(current, list):
            raise ValueError(f"design source ref field is not an array: {anchor}")
        index = int(raw_index)
        if index >= len(current):
            raise ValueError(f"design source ref index out of range: {anchor}")
        current = current[index]
    return current


def assert_design_ref(ref, design, path):
    if not isinstance(ref, str):
        raise ValueError(f"{path} must be a string")
    match = design_ref_re.match(ref)
    if not match:
        raise ValueError(f"unsupported design source ref: {ref}")
    resolve_dotted_path(design, match.group(1))
    return ref


test_cases = load_json(test_cases_path)
design = load_json(design_path)
expected_manager_refs = {
    f"design.json#verification_mapping[{index}].manager_vp_ref"
    for index, _row in enumerate(require_list(design.get("verification_mapping"), "design.verification_mapping"))
}
actual_refs = set()
for index, row in enumerate(require_list(test_cases.get("qa_handoff_contract"), "qa_handoff_contract")):
    if not isinstance(row, dict):
        raise ValueError(f"qa_handoff_contract[{index}] must be an object")
    refs = require_list(row.get("design_source_refs"), f"qa_handoff_contract[{index}].design_source_refs")
    for ref_index, ref in enumerate(refs):
        actual_refs.add(assert_design_ref(ref, design, f"qa_handoff_contract[{index}].design_source_refs[{ref_index}]"))
missing = sorted(expected_manager_refs - actual_refs)
if missing:
    raise ValueError(f"design_source_refs missing manager refs: {missing}")
PY
    then
        add_failure "test-cases.json design_source_refs do not resolve: $target"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$ref_out")
    fi
    rm -f "$ref_out"
}

# Validate test-cases.json fields that downstream QA consumes.
validate_test_cases() {
    local target="$1"
    local phase_dir

    if [ ! -f "$target" ]; then
        add_failure "test-cases.json not found: $target"
        output_failures "Canonical test-design gate failed" "$target"
    fi
    if ! jq -e . "$target" >/dev/null 2>&1; then
        add_failure "test-cases.json is not valid JSON: $target"
        output_failures "Canonical test-design gate failed" "$target"
    fi
    if ! jq -e '
        (.ac_coverage_matrix | type == "array" and length > 0)
        and (.equivalence_matrix | type == "array" and length > 0)
	        and (.test_cases | type == "array" and length > 0)
	        and (.qa_handoff_contract | type == "array" and length > 0)
        and all(.qa_handoff_contract[]; (.test_obligation // "" | type == "string" and length > 0)
            and (.trigger_source // "" | type == "string" and length > 0)
            and (.qa_stage // "" | type == "string" and length > 0)
            and (.requiredness // "" | type == "string" and length > 0)
            and (.execution_mode // "" | IN("browser_required", "non_browser_ok"))
	            and (.skip_rule // "" | type == "string" and length > 0)
	            and (.evidence_expectation // "" | type == "string" and length > 0)
            and (.design_source_refs | type == "array" and length > 0))
	        and (["QA_A", "QA_B", "QA_C", "QA_D"] - ([.qa_handoff_contract[].qa_stage] | unique) | length == 0)
	        and (.unit_coverage_view | type == "array" and length > 0)
	        and (.design_gap_report | type == "object")
	        and ((.design_gap_report.status // "") | IN("NO_GAPS", "HAS_GAPS"))
	        and (.special_test_triggers | type == "array")
	        and (.review_conclusion | type == "object")
        and ((.review_conclusion.verdict // "") | type == "string" and length > 0)
        and ((.review_conclusion.summary // "") | type == "string" and length > 0)
        and (.issue_ledger | type == "array")
    ' "$target" >/dev/null 2>&1; then
	        add_failure "test-cases.json missing canonical QA_A-D handoff, coverage, design gap, trigger, review, or issue ledger fields: $target"
	    fi

    phase_dir=$(dirname "$(dirname "$target")")
    if [ ! -f "$phase_dir/design.json" ]; then
        add_failure "design.json not found: $phase_dir/design.json"
    elif ! jq -e . "$phase_dir/design.json" >/dev/null 2>&1; then
        add_failure "design.json is not valid JSON: $phase_dir/design.json"
    else
        validate_design_source_refs "$target"
    fi
}

# Run the canonical test-design gate or allow non-test-design hook events.
run_gate() {
    local target

    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/unit-[0-9]+/test-cases\.json' 'test-cases.json'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "Canonical test-design gate failed" ""
        fi
        if is_stop_dispatch_context; then
            add_failure "test-cases.json path not found in hook context"
            output_failures "Canonical test-design gate failed" ""
        fi
        emit_decision_json "allow" "canonical test-design gate not targeted"
        return 0
    fi

    validate_test_cases "$target"
    output_failures "Canonical test-design gate failed" "$target"
    emit_decision_json "allow" "canonical test-design artifact validated"
}

run_gate
