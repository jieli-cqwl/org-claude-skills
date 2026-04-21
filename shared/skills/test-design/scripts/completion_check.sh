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
            and (.evidence_expectation // "" | type == "string" and length > 0))
        and (.review_conclusion | type == "object")
        and ((.review_conclusion.verdict // "") | type == "string" and length > 0)
        and ((.review_conclusion.summary // "") | type == "string" and length > 0)
        and (.issue_ledger | type == "array")
    ' "$target" >/dev/null 2>&1; then
        add_failure "test-cases.json missing canonical QA handoff, coverage, review, or issue ledger fields: $target"
    fi

    phase_dir=$(dirname "$(dirname "$target")")
    if [ ! -f "$phase_dir/design.json" ]; then
        add_failure "design.json not found: $phase_dir/design.json"
    elif ! jq -e . "$phase_dir/design.json" >/dev/null 2>&1; then
        add_failure "design.json is not valid JSON: $phase_dir/design.json"
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
