#!/usr/bin/env bash
# Canonical test-design completion gate.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
test-design/completion_check.sh — canonical test-cases gate
Execution: PostToolUse(Edit|Write) or Stop
Input: stdin JSON hook payload
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

validate_phase_contract() {
    local target="$1"
    local phase_dir
    local out

    phase_dir="$(dirname "$(dirname "$target")")"
    out="$(mktemp "${TMPDIR:-/tmp}/test-design-gate.XXXXXX")"

    if ! python3 "$RUNTIME_ROOT/tools/community/validate_canonical_schema.py" --phase-dir "$phase_dir" >"$out" 2>&1; then
        add_failure "test-cases.json schema validation failed: $target"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,6p' "$out")
    fi

    if ! python3 "$RUNTIME_ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$phase_dir" >"$out" 2>&1; then
        add_failure "test-cases.json semantic validation failed: $target"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,6p' "$out")
    fi

    rm -f "$out"
}

run_gate() {
    local target

    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/unit-[0-9]+/test-cases\.json' 'test-cases.json'
    target="$HOOK_MATCHED_PATH"

    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "test-design completion gate failed" ""
        fi
        if is_stop_dispatch_context; then
            add_failure "test-cases.json path not found in hook context"
            output_failures "test-design completion gate failed" ""
        fi
        emit_decision_json "allow" "test-design gate not targeted"
        return 0
    fi

    if [ ! -f "$target" ]; then
        add_failure "test-cases.json not found: $target"
        output_failures "test-design completion gate failed" "$target"
    fi

    validate_phase_contract "$target"
    output_failures "test-design completion gate failed" "$target"
    emit_decision_json "allow" "test-cases.json validated"
}

run_gate
