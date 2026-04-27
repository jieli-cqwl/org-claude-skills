#!/usr/bin/env bash
# Product Director canonical gate: validates Director-owned standard-chain artifacts only.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
product-director/completion_check.sh — Director canonical baseline gate
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

if printf '%s' "$INPUT" | jq -e 'has("standard_chain") or has("inputs") or has("arguments") or has("active_targets")' >/dev/null 2>&1; then
    export SC_COMPLETION_ROLE="${SC_COMPLETION_ROLE:-product-director}"
    exec "$SCRIPT_DIR/../../product-director/scripts/completion_payload_adapter.sh" <<<"$INPUT"
fi

# Resolve the feature root from canonical product artifact paths in the hook context.
resolve_canonical_feature_dir() {
    local pattern feature_count target_path

    pattern='docs/[^/"[:space:]*{}]+/(brief\.json|phase-[0-9]+/(phase-prd\.json|units/UNIT-[0-9]+\.json))'
    resolve_feature_dir "docs/*/brief.json" "$pattern" "brief.json"

    feature_count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
    if { [ -z "$FEATURE_DIR" ] || [ "$feature_count" != "1" ]; } && [ -n "${TOOL_FILE_PATH:-}" ]; then
        target_path=$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^(docs/[^/]+)/.*#\1#p')
        if [ -n "$target_path" ] && [ -d "$target_path" ]; then
            # shellcheck disable=SC2034  # common.sh output_failures consumes the global failure buffer.
            FAILURES=""
            FEATURE_DIR="$target_path"
            FEATURE_CANDIDATES="$target_path"
        fi
    fi
}

# Validate one canonical artifact by wrapping it in the shared schema fixture format.
validate_canonical_schema() {
    local artifact_file="$1"
    local label="$2"
    local fixture_file schema_out

    if [ ! -f "$artifact_file" ]; then
        add_failure "canonical product artifact not found: $label"
        return 0
    fi

    fixture_file="$(mktemp "${TMPDIR:-/tmp}/director-canonical.XXXXXX")"
    schema_out="$(mktemp "${TMPDIR:-/tmp}/director-canonical-schema.XXXXXX")"
    python3 - "$artifact_file" "$fixture_file" <<'PY'
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

# Director artifacts must carry explicit sign-off metadata before handoff.
validate_director_confirmation() {
    local artifact_file="$1"
    local label="$2"

    if ! jq -e '
        (.director_confirmation | type == "object")
        and ((.director_confirmation.status // "" | ascii_downcase) as $status | (["passed", "pass", "confirmed", "approved", "已通过", "通过", "确认"] | index($status)) != null)
        and ((.director_confirmation.confirmed_at // "") | type == "string")
        and ((.director_confirmation.confirmed_at // "") | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"))
    ' "$artifact_file" >/dev/null 2>&1; then
        add_failure "$label director_confirmation.status/confirmed_at is not closed"
    fi
}

# Director baseline must contain a locked-field snapshot accepted by the product closure validator.
validate_director_lock() {
    local artifact_file="$1"
    local label="$2"
    local closure_out

    closure_out="$(mktemp "${TMPDIR:-/tmp}/director-lock.XXXXXX")"
    if ! python3 "$RUNTIME_ROOT/tools/community/validate_product_closure.py" --artifact "$artifact_file" >"$closure_out" 2>&1; then
        add_failure "$label director locked_fields snapshot failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$closure_out")
    fi
    rm -f "$closure_out"
}

# Director owns baseline framing only; Manager-owned fields are rejected at this gate.
validate_director_boundary() {
    local artifact_file="$1"
    local label="$2"

    case "$label" in
        brief.json)
            if jq -e '
                has("acceptance_criteria")
                or has("design_decisions")
                or has("non_functional_requirements")
                or has("review_conclusion")
                or has("issue_ledger")
                or has("delivery_confirmation")
            ' "$artifact_file" >/dev/null 2>&1; then
                add_failure "$label contains Manager-owned fields"
            fi
            ;;
        phase-prd.json)
            if jq -e '
                has("review_conclusion")
                or has("issue_ledger")
                or has("business_flows")
                or has("user_paths")
                or has("rule_mappings")
                or has("design_decision_candidates")
                or (((.unit_index // []) | length) > 0)
            ' "$artifact_file" >/dev/null 2>&1; then
                add_failure "$label contains Manager-owned closure, business semantics, design decisions, or non-empty unit_index"
            fi
            ;;
    esac
}

# Validate one Director-owned product artifact with schema, sign-off, lock, and ownership checks.
validate_director_artifact() {
    local artifact_file="$1"
    local label="$2"

    validate_canonical_schema "$artifact_file" "$label"
    [ -f "$artifact_file" ] || return 0
    validate_director_confirmation "$artifact_file" "$label"
    validate_director_lock "$artifact_file" "$label"
    validate_director_boundary "$artifact_file" "$label"
    if [ "$label" = "brief.json" ] && jq -e 'has("non_functional_req")' "$artifact_file" >/dev/null 2>&1; then
        add_failure "$label contains retired alias non_functional_req"
    fi
}

# Validate the complete Director handoff set for the current feature.
run_canonical_director_gate() {
    local phase_files

    resolve_canonical_feature_dir
    if [ -z "$FEATURE_DIR" ]; then
        add_failure "canonical product feature root not found"
        output_failures "Director canonical baseline gate failed" ""
    fi

    validate_director_artifact "$FEATURE_DIR/brief.json" "brief.json"

    phase_files=$(find "$FEATURE_DIR" -path "$FEATURE_DIR/phase-*/phase-prd.json" -type f | sort)
    if [ -z "$phase_files" ]; then
        add_failure "canonical product artifact not found: phase-prd.json"
    else
        while IFS= read -r phase_file; do
            [ -n "$phase_file" ] && validate_director_artifact "$phase_file" "phase-prd.json"
        done <<< "$phase_files"
    fi

    output_failures "Director canonical baseline gate failed" "$FEATURE_DIR"
    emit_decision_json "allow" "director canonical baseline validated"
}

run_canonical_director_gate
