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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_ROOT="$(resolve_runtime_root "$SCRIPT_DIR")"

# Validate redesigned test-cases.json against product, UNIT, and design sources.
validate_test_cases_contract() {
    local target="$1"
    local contract_out

    contract_out="$(mktemp "${TMPDIR:-/tmp}/test-design-contract.XXXXXX")"

    if ! python3 - "$target" "$RUNTIME_ROOT" >"$contract_out" 2>&1 <<'PY'
import json
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1]).resolve()
runtime_root = Path(sys.argv[2]).resolve()
sys.path.insert(0, str(runtime_root / "tools/community"))

from canonical_test_case_rules import assert_test_cases_contract


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


phase_dir = test_cases_path.parent.parent
feature_dir = phase_dir.parent
artifact_paths = [
    feature_dir / "brief.json",
    phase_dir / "phase-prd.json",
    phase_dir / "design.json",
    *sorted((phase_dir / "units").glob("UNIT-*.json")),
    test_cases_path,
]
missing = [str(path) for path in artifact_paths if not path.is_file()]
if missing:
    raise ValueError(f"supporting artifacts not found: {missing}")

artifacts = [load_json(path) for path in artifact_paths]
assert_test_cases_contract(artifacts[-1], artifacts)
PY
    then
        add_failure "test-cases.json canonical semantic validation failed: $target"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,5p' "$contract_out")
    fi
    rm -f "$contract_out"
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
        (.test_analysis | type == "object")
        and (.traceability_matrix | type == "array" and length > 0)
        and (.ac_coverage_matrix | type == "array" and length > 0)
        and all(.ac_coverage_matrix[]; (.positive_case_refs | type == "array" and length > 0)
            and (.negative_case_refs | type == "array" and length > 0)
            and (.boundary_case_refs | type == "array" and length > 0)
            and (((.negative_case_refs | length) + (.boundary_case_refs | length)) >= (.positive_case_refs | length)))
        and (.equivalence_matrix | type == "array" and length > 0)
        and (.test_cases | type == "array" and length > 0)
        and all(.test_cases[]; (.product_refs | type == "array" and length > 0)
            and (.design_refs | type == "array" and length > 0)
            and ((.case_type // "") | IN("positive", "negative", "boundary", "exclusion", "specialty"))
            and ((.expected_result // "") | type == "string" and length > 0)
            and ((.assertion_target // "") | type == "string" and length > 0)
            and ((.evidence_expectation // "") | type == "string" and length > 0))
        and (.qa_handoff_contract | type == "array" and length > 0)
        and all(.qa_handoff_contract[]; (.test_obligation // "" | type == "string" and length > 0)
            and (.trigger_source // "" | type == "string" and length > 0)
            and ((.qa_stage // "") | IN("QA_A", "QA_B", "QA_C", "QA_D", "NFR"))
            and (.requiredness // "" | type == "string" and length > 0)
            and (.execution_mode // "" | IN("browser_required", "non_browser_ok"))
            and (.skip_rule // "" | type == "string" and length > 0)
            and (.evidence_expectation // "" | type == "string" and length > 0)
            and (.design_source_refs | type == "array" and length > 0))
        and (["QA_A", "QA_B", "QA_C", "QA_D"] - ([.qa_handoff_contract[].qa_stage] | unique) | length == 0)
        and (.unit_coverage_view | type == "array" and length > 0)
        and (.design_gap_report | type == "object")
        and ((.design_gap_report.status // "") | IN("NO_GAPS", "HAS_GAPS"))
        and (.design_gap_report.gaps | type == "array")
        and all(.design_gap_report.gaps[]?; (.gap_id // "" | type == "string" and length > 0)
            and ((.gap_type // "") | IN("PRODUCT_GAP", "DESIGN_GAP", "SCOPE_DRIFT", "TRACE_CONFLICT", "TESTABILITY_GAP", "EQ_GAP"))
            and (.blocking_refs | type == "array" and length > 0)
            and (.owner // "" | type == "string" and length > 0)
            and (.next_action // "" | type == "string" and length > 0)
            and (.blocking | type == "boolean"))
        and (.cross_unit_obligations | type == "array")
        and all(.cross_unit_obligations[]?; (.journey_id // "" | type == "string" and length > 0)
            and (.participant_unit_refs | type == "array" and length > 0)
            and (.local_unit_ref // "" | type == "string" and length > 0)
            and (.sequence_index | type == "number")
            and (.composition_status // "" | IN("COMPOSABLE", "BLOCKED_GAP")))
        and (.special_test_triggers | type == "array")
        and (.review_conclusion | type == "object")
        and ((.review_conclusion.verdict // "") | IN("PASS", "WARN"))
        and ((.review_conclusion.summary // "") | type == "string" and length > 0)
        and ((.review_conclusion.review_round // "") | test("^R[0-9]+$"))
        and (.review_conclusion.convergence_evidence | type == "array" and length > 0)
        and all(.review_conclusion.convergence_evidence[]; (.round // "" | test("^R[0-9]+$"))
            and (.result // "" | IN("PASS", "WARN", "FAIL"))
            and (.fail_count | type == "number")
            and (.control_action // "" | IN("CONTINUE", "CONFIRMATION", "ASK_USER", "BLOCKED", "COMPLETE"))
            and (.evidence // "" | type == "string" and length > 0))
        and (.issue_ledger | type == "array")
        and ((.review_conclusion.verdict != "WARN") or (.issue_ledger | length > 0))
        and all(.issue_ledger[]; (.issue_id // "" | type == "string" and length > 0)
            and (.status // "" | IN("CLOSED", "DEFERRED"))
            and (.review_round // "" | test("^R[0-9]+$"))
            and (.evidence // "" | type == "string" and length > 0)
            and (.handling_record // "" | type == "string" and length > 0))
    ' "$target" >/dev/null 2>&1; then
        add_failure "test-cases.json missing redesigned canonical test analysis, executable cases, QA handoff, typed gaps, cross-UNIT obligations, review convergence, or issue ledger fields: $target"
    fi

    if jq -e 'any(.design_gap_report.gaps[]?; .blocking == true)' "$target" >/dev/null 2>&1; then
        add_failure "test-cases.json has blocking test-design gaps; owner and next_action must be resolved before tech-lead handoff: $target"
    fi

    phase_dir=$(dirname "$(dirname "$target")")
    if [ ! -f "$phase_dir/design.json" ]; then
        add_failure "design.json not found: $phase_dir/design.json"
    elif ! jq -e . "$phase_dir/design.json" >/dev/null 2>&1; then
        add_failure "design.json is not valid JSON: $phase_dir/design.json"
    else
        validate_test_cases_contract "$target"
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
