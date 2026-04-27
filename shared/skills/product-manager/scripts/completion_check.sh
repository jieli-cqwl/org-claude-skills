#!/usr/bin/env bash
# Product Manager canonical gate: validates PRD/UNIT closure in standard-chain JSON artifacts.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
product-manager/completion_check.sh — Manager canonical PRD/UNIT closure gate
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
    export SC_COMPLETION_ROLE="${SC_COMPLETION_ROLE:-product-manager}"
    exec "$SCRIPT_DIR/../../product-director/scripts/completion_payload_adapter.sh" <<<"$INPUT"
fi

# Resolve feature root from canonical product artifact references.
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

# Validate one canonical product artifact through the shared schema catalog.
validate_canonical_schema() {
    local artifact_file="$1"
    local label="$2"
    local fixture_file schema_out

    if [ ! -f "$artifact_file" ]; then
        add_failure "canonical product artifact not found: $label"
        return 0
    fi

    fixture_file="$(mktemp "${TMPDIR:-/tmp}/manager-canonical.XXXXXX")"
    schema_out="$(mktemp "${TMPDIR:-/tmp}/manager-canonical-schema.XXXXXX")"
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

# Product Manager consumes Director sign-off and must not silently proceed without it.
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

# Product Manager closure lives in canonical review_conclusion/issue_ledger and optional delivery_confirmation.
validate_manager_closure() {
    local artifact_file="$1"
    local label="$2"
    local delivery_flag="${3:-}"
    local closure_out fields

    closure_out="$(mktemp "${TMPDIR:-/tmp}/manager-closure.XXXXXX")"
    fields="review_conclusion / issue_ledger"
    [ -n "$delivery_flag" ] && fields="$fields / delivery_confirmation"
    if ! python3 "$RUNTIME_ROOT/tools/community/validate_product_closure.py" \
        --artifact "$artifact_file" \
        --require-review \
        ${delivery_flag:+"$delivery_flag"} >"$closure_out" 2>&1; then
        add_failure "$label $fields is not closed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$closure_out")
    fi
    rm -f "$closure_out"
}

# UNIT artifacts do not carry review_conclusion; their PM-owned WHAT-layer
# semantics are enforced by the shared closure validator without review flags.
validate_unit_semantics() {
    local artifact_file="$1"
    local label="$2"
    local closure_out

    closure_out="$(mktemp "${TMPDIR:-/tmp}/manager-unit-closure.XXXXXX")"
    if ! python3 "$RUNTIME_ROOT/tools/community/validate_product_closure.py" \
        --artifact "$artifact_file" >"$closure_out" 2>&1; then
        add_failure "$label PM-owned semantic fields are not closed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$closure_out")
    fi
    rm -f "$closure_out"
}

# Validate canonical artifact shape and block retired aliases.
validate_product_artifact() {
    local artifact_file="$1"
    local label="$2"

    validate_canonical_schema "$artifact_file" "$label"
    [ -f "$artifact_file" ] || return 0
    if [ "$label" = "brief.json" ] && jq -e 'has("non_functional_req")' "$artifact_file" >/dev/null 2>&1; then
        add_failure "$label contains retired alias non_functional_req"
    fi
    case "$label" in
        brief.json|phase-prd.json)
            validate_director_confirmation "$artifact_file" "$label"
            ;;
    esac
}

# Validate all phase PRDs and their Manager-owned review closure.
validate_phase_prds() {
    local phase_files phase_file

    phase_files=$(find "$FEATURE_DIR" -path "$FEATURE_DIR/phase-*/phase-prd.json" -type f | sort)
    if [ -z "$phase_files" ]; then
        add_failure "canonical product artifact not found: phase-prd.json"
        return 0
    fi

    while IFS= read -r phase_file; do
        [ -n "$phase_file" ] || continue
        validate_product_artifact "$phase_file" "phase-prd.json"
        validate_manager_closure "$phase_file" "phase-prd.json"
    done <<< "$phase_files"
}

# Validate all UNIT canonical artifacts created by Product Manager.
validate_units() {
    local unit_files unit_file

    unit_files=$(find "$FEATURE_DIR" -path "$FEATURE_DIR/phase-*/units/UNIT-*.json" -type f | sort)
    if [ -z "$unit_files" ]; then
        add_failure "canonical product artifact not found: UNIT-*.json"
        return 0
    fi

    while IFS= read -r unit_file; do
        [ -n "$unit_file" ] || continue
        validate_product_artifact "$unit_file" "UNIT.json"
        validate_unit_semantics "$unit_file" "UNIT.json"
    done <<< "$unit_files"
}

# Validate Manager handoff artifacts for the current feature.
run_canonical_manager_gate() {
    resolve_canonical_feature_dir
    if [ -z "$FEATURE_DIR" ]; then
        add_failure "canonical product feature root not found"
        output_failures "Product Manager canonical closure gate failed" ""
    fi

    validate_product_artifact "$FEATURE_DIR/brief.json" "brief.json"
    validate_manager_closure "$FEATURE_DIR/brief.json" "brief.json" "--require-delivery"
    validate_phase_prds
    validate_units
    output_failures "Product Manager canonical closure gate failed" "$FEATURE_DIR"
    emit_decision_json "allow" "manager canonical product closure validated"
}

run_canonical_manager_gate
