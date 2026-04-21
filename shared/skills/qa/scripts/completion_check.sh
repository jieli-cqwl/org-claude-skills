#!/usr/bin/env bash
# QA canonical gate: validates qa-result.json as the standard-chain QA fact source.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
qa/completion_check.sh — canonical QA result gate
Execution: skill-local Stop or PostToolUse(Edit|Write)
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

# Validate one canonical artifact through the shared schema catalog.
validate_schema() {
    local file="$1"
    local label="$2"
    local fixture_file schema_out

    fixture_file="$(mktemp "${TMPDIR:-/tmp}/qa-canonical.XXXXXX")"
    schema_out="$(mktemp "${TMPDIR:-/tmp}/qa-canonical-schema.XXXXXX")"
    python3 - "$file" "$fixture_file" <<'PY'
import json
import sys
from pathlib import Path

artifact_path = Path(sys.argv[1])
fixture_path = Path(sys.argv[2])
payload = json.loads(artifact_path.read_text(encoding="utf-8"))
fixture_path.write_text(json.dumps({"artifacts": [payload]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

    if ! python3 "$RUNTIME_ROOT/tools/community/validate_canonical_schema.py" --fixture "$fixture_file" >"$schema_out" 2>&1; then
        add_failure "$label canonical schema validation failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$schema_out")
    fi
    rm -f "$fixture_file" "$schema_out"
}

# Browser-required QA must cite real browser-native evidence.
browser_evidence_is_valid() {
    local file="$1"
    jq -e '
        ((.browser_tool // "") | test("playwright|browser|chrom(e|ium)|firefox|webkit|safari|puppeteer|cypress|selenium|devtools"; "i"))
        and ((.entry_url // "") | test("^https?://[^\\s]+$"))
        and (.browser_evidence | type == "array" and length > 0)
        and any(.browser_evidence[]; test("playwright|browser|screenshot|screen recording|video|trace|dom|locator|click|page|navigation|console|network"; "i"))
        and all(.browser_evidence[]; (test("curl|wget|httpie|grpcurl|postman|api response|axios|requests|fetch\\("; "i") | not) or test("playwright|browser|page|screenshot|trace|video"; "i"))
    ' "$file" >/dev/null 2>&1
}

# Detect whether any QA handoff contract in this phase requires browser-native evidence.
phase_requires_browser_evidence() {
    local phase_dir="$1"
    local test_cases

    while IFS= read -r test_cases; do
        [ -n "$test_cases" ] || continue
        if jq -e '
            (.qa_handoff_contract | type == "array")
            and any(.qa_handoff_contract[]; (.qa_stage // "") == "QA_B" and (.execution_mode // "") == "browser_required")
        ' "$test_cases" >/dev/null 2>&1; then
            return 0
        fi
    done < <(find "$phase_dir" -type f -path '*/unit-*/test-cases.json' 2>/dev/null | sort || true)
    return 1
}

# Validate QA-owned canonical result fields.
validate_qa_result() {
    local target="$1"
    local phase_dir

    if [ ! -f "$target" ]; then
        add_failure "qa-result.json not found: $target"
        output_failures "Canonical QA gate failed" "$target"
    fi
    if ! jq -e . "$target" >/dev/null 2>&1; then
        add_failure "qa-result.json is not valid JSON: $target"
        output_failures "Canonical QA gate failed" "$target"
    fi

    phase_dir=$(dirname "$target")
    validate_schema "$target" "qa-result.json"
    if ! jq -e '
        .baseline_plan_version_ref
        and .baseline_tasks_version_ref
        and .active_plan_version_ref
        and .active_tasks_version_ref
        and .current_stage
        and .gate_result
        and .release_recommendation
        and (.residual_risk | type == "array")
        and has("uncovered_boundary")
        and has("conditional_release_basis")
        and has("not_executed_reason")
        and (.ruled_out_issues | type == "array" and length >= 2)
        and (.issue_ledger | type == "array")
    ' "$target" >/dev/null 2>&1; then
        add_failure "qa-result.json missing baseline refs, active refs, gate result, release recommendation, risk fields, ruled_out_issues, or issue_ledger: $target"
    fi
    if ! jq -e '
        if .gate_result == "FAIL" then
            (.issue_ledger | type == "array" and length > 0)
            and all(.issue_ledger[]; .severity and .priority and .impact_scope and .user_impact and .environment_or_build and .regression_flag and .temporary_workaround and .owner_hint and .expected_behavior and .actual_behavior and .reproduction)
        else
            true
        end
    ' "$target" >/dev/null 2>&1; then
        add_failure "qa-result.json gate_result=FAIL requires complete triage issue_ledger: $target"
    fi
    if phase_requires_browser_evidence "$phase_dir" && ! browser_evidence_is_valid "$target"; then
        add_failure "qa-result.json requires browser_tool, entry_url, and browser-native evidence for browser_required QA: $target"
    fi
}

# Run the canonical QA gate or allow non-QA hook events.
run_gate() {
    local target

    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/qa-result\.json' 'qa-result.json'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "Canonical QA gate failed" ""
        fi
        if is_stop_dispatch_context; then
            add_failure "qa-result.json path not found in hook context"
            output_failures "Canonical QA gate failed" ""
        fi
        emit_decision_json "allow" "canonical QA gate not targeted"
        return 0
    fi

    validate_qa_result "$target"
    output_failures "Canonical QA gate failed" "$target"
    emit_decision_json "allow" "canonical QA result validated"
}

run_gate
