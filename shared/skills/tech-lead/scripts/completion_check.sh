#!/usr/bin/env bash
# Tech Lead canonical gate: validates the active standard-chain phase plan/tasks set.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
tech-lead/completion_check.sh — canonical phase tasks gate
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

# Validate required phase inputs before delegating semantic checks to the phase validator.
validate_phase_inputs() {
    local phase_dir="$1"
    local preflight preflight_output

    preflight="$SCRIPT_DIR/planning_preflight.py"
    preflight_output="$(mktemp "${TMPDIR:-/tmp}/tech-lead-preflight.XXXXXX")"
    if [ ! -f "$preflight" ]; then
        add_failure "tech-lead planning preflight not found: $preflight"
        rm -f "$preflight_output"
        return 0
    fi
    if ! python3 "$preflight" --phase-dir "$phase_dir" --require-tasks >"$preflight_output" 2>&1; then
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < "$preflight_output"
        add_failure "tech-lead planning preflight failed: $phase_dir"
    fi
    rm -f "$preflight_output"
}

# Run the canonical standard-chain phase validator with canonical-only enforcement.
run_phase_validator() {
    local phase_dir="$1"
    local validator gate_output

    validator="$RUNTIME_ROOT/tools/community/validate_standard_chain_phase.py"
    gate_output="$(mktemp "${TMPDIR:-/tmp}/tech-lead-canonical.XXXXXX")"
    if [ ! -f "$validator" ]; then
        add_failure "standard-chain phase validator not found: $validator"
        rm -f "$gate_output"
        return 0
    fi
    if ! python3 "$validator" --phase-dir "$phase_dir" --enforce-canonical-only >"$gate_output" 2>&1; then
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < "$gate_output"
        add_failure "canonical phase validation failed: $phase_dir"
    fi
    rm -f "$gate_output"
}

# Run the canonical tech-lead gate or allow non-tech-lead hook events.
run_gate() {
    local target phase_dir

    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/tasks\.json' 'tasks.json'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "Canonical tech-lead gate failed" ""
        fi
        if is_stop_dispatch_context; then
            add_failure "tasks.json path not found in hook context"
            output_failures "Canonical tech-lead gate failed" ""
        fi
        if { [ "${TOOL_NAME:-}" = "Write" ] || [ "${TOOL_NAME:-}" = "Edit" ]; } && [ -z "${TOOL_FILE_PATH:-}" ]; then
            add_failure "hook payload missing tool_input.file_path"
            output_failures "Canonical tech-lead gate failed" ""
        fi
        emit_decision_json "allow" "canonical tech-lead gate not targeted"
        return 0
    fi

    phase_dir=$(dirname "$target")
    validate_phase_inputs "$phase_dir"
    run_phase_validator "$phase_dir"
    output_failures "Canonical tech-lead gate failed" "$phase_dir"
    emit_decision_json "allow" "canonical phase plan/tasks validated"
}

run_gate
