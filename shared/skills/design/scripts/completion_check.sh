#!/usr/bin/env bash
# Design canonical gate: validates the frozen standard-chain design.json artifact.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
design/completion_check.sh — canonical design artifact gate
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

# Validate canonical design through the standard-chain phase validator so the
# hook gate cannot drift from schema, rule, traceability, or projection rules.
validate_phase_contract() {
    local design_file="$1"
    local phase_dir phase_out

    phase_dir="$(cd "$(dirname "$design_file")" && pwd)"
    phase_out="$(mktemp "${TMPDIR:-/tmp}/design-phase-contract.XXXXXX")"
    if ! python3 "$RUNTIME_ROOT/tools/community/validate_standard_chain_phase.py" \
        --phase-dir "$phase_dir" >"$phase_out" 2>&1; then
        add_failure "standard-chain phase validator failed for design.json"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$phase_out")
    fi
    rm -f "$phase_out"
}

validate_product_closure_check() {
    local label="$1"
    shift
    local closure_out

    closure_out="$(mktemp "${TMPDIR:-/tmp}/design-product-closure.XXXXXX")"
    if ! python3 "$RUNTIME_ROOT/tools/community/validate_product_closure.py" "$@" >"$closure_out" 2>&1; then
        add_failure "$label is not ready for design"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$closure_out")
    fi
    rm -f "$closure_out"
}

validate_product_inputs() {
    local design_file="$1"
    local phase_dir feature_dir units_dir brief_file phase_prd_file
    local -a unit_files

    phase_dir="$(cd "$(dirname "$design_file")" && pwd)"
    feature_dir="$(cd "$phase_dir/.." && pwd)"
    units_dir="$phase_dir/units"
    brief_file="$feature_dir/brief.json"
    phase_prd_file="$phase_dir/phase-prd.json"

    validate_product_closure_check "brief.json" --artifact "$brief_file" --require-review --require-delivery
    validate_product_closure_check "phase-prd.json" --artifact "$phase_prd_file" --require-review

    shopt -s nullglob
    unit_files=("$units_dir"/UNIT-*.json)
    shopt -u nullglob
    if [ "${#unit_files[@]}" -eq 0 ]; then
        add_failure "no UNIT-*.json files found for design input: $units_dir"
        return 0
    fi
    for unit_file in "${unit_files[@]}"; do
        validate_product_closure_check "$(basename "$unit_file")" --artifact "$unit_file"
    done
}

# Validate design.unit_coverage completeness vs phase UNITs, modules.unit_refs
# truthfulness, and verification_refs resolution. The canonical phase validator
# already covers schema/rule/trace at the artifact level; this mechanical check
# adds cross-file invariants (every phase UNIT must appear in design coverage;
# modules.unit_refs must not reference ghost UNITs) that the phase validator
# does not enforce, so drift cannot leak past the hook even if the LLM forgets
# to run the script manually.
validate_reference_integrity() {
    local design_file="$1"
    local phase_dir integrity_out

    phase_dir="$(cd "$(dirname "$design_file")" && pwd)"
    integrity_out="$(mktemp "${TMPDIR:-/tmp}/design-reference-integrity.XXXXXX")"
    if ! python3 "$SCRIPT_DIR/check_design_reference_integrity.py" \
        --phase-dir "$phase_dir" >"$integrity_out" 2>&1; then
        add_failure "design.json reference integrity check failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,5p' "$integrity_out")
    fi
    rm -f "$integrity_out"
}

validate_architect_contract() {
    local design_file="$1"
    local contract_out

    contract_out="$(mktemp "${TMPDIR:-/tmp}/design-architect-contract.XXXXXX")"
    if ! python3 "$SCRIPT_DIR/validate_design_architect_contract.py" \
        --design "$design_file" >"$contract_out" 2>&1; then
        add_failure "design.json architect contract check failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,5p' "$contract_out")
    fi
    rm -f "$contract_out"
}

validate_review_digest() {
    local target="$1"
    local digest_out

    digest_out="$(mktemp "${TMPDIR:-/tmp}/design-review-digest.XXXXXX")"
    if ! python3 "$SCRIPT_DIR/review_digest.py" --check "$target" >"$digest_out" 2>&1; then
        add_failure "design.json review_closure reviewed design digest does not match the reviewed artifact"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$digest_out")
    fi
    rm -f "$digest_out"
}

validate_no_review_wrapper_fields() {
    local target="$1"
    local leaked_fields

    leaked_fields="$(jq -r '
        ["candidate_design_json", "review_payload_json", "open_warns", "handoff_summary", "co_creation_confirmations", "source_refs"] as $forbidden
        | [keys[] | select(. as $key | $forbidden | index($key))]
        | join(", ")
    ' "$target")"
    if [ -n "$leaked_fields" ]; then
        add_failure "design.json contains review wrapper fields: $leaked_fields"
        output_failures "Canonical design gate failed" "$target"
    fi
}

validate_co_creation_stages() {
    local target="$1"
    local missing_stages

    missing_stages="$(jq -r '
        [
            "stakeholders-and-concerns",
            "architecture-significant-requirements",
            "current-state-evidence",
            "complexity-model",
            "decision-discovery",
            "option-tradeoff",
            "design-synthesis"
        ] as $required
        | (.co_creation_summary | if type == "array" then . else [] end) as $rows
        | ($rows | map(select(type == "object") | .stage_id) | unique) as $seen
        | [$required[] as $stage | select(($seen | index($stage)) == null) | $stage]
        | join(", ")
    ' "$target")"
    if [ -n "$missing_stages" ]; then
        add_failure "design.json missing required co-creation stages: $missing_stages"
        output_failures "Canonical design gate failed" "$target"
    fi
}

# Validate the design artifact by delegating deterministic contracts to
# canonical validators and keeping this hook focused on routing.
validate_design_artifact() {
    local target="$1"

    if [ ! -f "$target" ]; then
        add_failure "design.json not found: $target"
        output_failures "Canonical design gate failed" "$target"
    fi
    if ! jq -e . "$target" >/dev/null 2>&1; then
        add_failure "design.json is not valid JSON: $target"
        output_failures "Canonical design gate failed" "$target"
    fi

    validate_no_review_wrapper_fields "$target"
    validate_co_creation_stages "$target"
    validate_product_inputs "$target"
    validate_phase_contract "$target"
    validate_reference_integrity "$target"
    validate_architect_contract "$target"
    validate_review_digest "$target"
}

# Run the canonical design gate or allow non-design hook events.
run_gate() {
    local target

    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/design\.json' 'design.json'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "Canonical design gate failed" ""
        fi
        if is_stop_dispatch_context; then
            add_failure "design.json path not found in hook context"
            output_failures "Canonical design gate failed" ""
        fi
        emit_decision_json "allow" "canonical design gate not targeted"
        return 0
    fi

    validate_design_artifact "$target"
    output_failures "Canonical design gate failed" "$target"
    emit_decision_json "allow" "canonical design artifact validated"
}

run_gate
