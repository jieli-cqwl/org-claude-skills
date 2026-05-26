#!/usr/bin/env bash
# Validate design-ready product inputs before architecture co-creation.
set -euo pipefail

usage() {
    cat <<'USAGE'
design/preflight_check.sh — design input preflight

Usage:
  bash shared/skills/design/scripts/preflight_check.sh --phase-dir <docs/feature/phase-N>
  bash shared/skills/design/scripts/preflight_check.sh --arguments <feature-or-phase>

Checks:
  - brief.json exists, is JSON, and has product review + delivery closure
  - phase-prd.json exists, is JSON, and has product review closure
  - units/UNIT-*.json exist, are JSON, and satisfy UNIT shape checks
  - docs/constitution.md is returned when present
USAGE
}

json_payload() {
    jq -nc "$@"
}

fail() {
    local code="$1"
    local owner="$2"
    local reason="$3"
    json_payload \
        --arg status "BLOCKED" \
        --arg failure_code "$code" \
        --arg owner "$owner" \
        --arg reason "$reason" \
        '{status:$status, failure_code:$failure_code, owner:$owner, reason:$reason}'
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PHASE_DIR=""
ARGUMENTS=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --phase-dir)
            [ "$#" -ge 2 ] || fail "MISSING_ARG" "design" "--phase-dir requires a value"
            PHASE_DIR="$2"
            shift 2
            ;;
        --arguments)
            [ "$#" -ge 2 ] || fail "MISSING_ARG" "design" "--arguments requires a value"
            ARGUMENTS="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            fail "UNKNOWN_ARG" "design" "unknown argument: $1"
            ;;
    esac
done

resolve_existing_dir() {
    local raw="$1"
    if [ -d "$raw" ]; then
        (cd "$raw" && pwd)
        return 0
    fi
    if [ -d "$ROOT/$raw" ]; then
        (cd "$ROOT/$raw" && pwd)
        return 0
    fi
    if [ -d "$ROOT/docs/$raw" ]; then
        (cd "$ROOT/docs/$raw" && pwd)
        return 0
    fi
    fail "MISSING_INPUT" "design" "arguments did not resolve to a feature or phase directory: $raw"
}

is_closed_phase() {
    local phase_dir="$1"
    [ -f "$phase_dir/delivery-state.json" ] || return 1
    jq -e '(.current_stage // "") as $stage | $stage == "CLOSED" or $stage == "DONE"' \
        "$phase_dir/delivery-state.json" >/dev/null 2>&1
}

select_phase_dir() {
    local feature_dir="$1"
    local candidates=()
    local phase_id phase_dir

    [ -f "$feature_dir/brief.json" ] || fail "MISSING_INPUT" "product-manager" "feature dir missing brief.json: $feature_dir"
    if jq -e 'type == "object" and (.delivery_plan | type == "array")' "$feature_dir/brief.json" >/dev/null 2>&1; then
        while IFS= read -r phase_id; do
            [ -n "$phase_id" ] || continue
            phase_dir="$feature_dir/$phase_id"
            [ -d "$phase_dir" ] && candidates+=("$phase_dir")
        done < <(jq -r '.delivery_plan[] | .phase_id // empty' "$feature_dir/brief.json")
    fi

    if [ "${#candidates[@]}" -eq 0 ]; then
        shopt -s nullglob
        candidates=("$feature_dir"/phase-*)
        shopt -u nullglob
    fi
    [ "${#candidates[@]}" -gt 0 ] || fail "MISSING_INPUT" "product-manager" "no phase directories found: $feature_dir"

    for phase_dir in "${candidates[@]}"; do
        if ! is_closed_phase "$phase_dir"; then
            (cd "$phase_dir" && pwd)
            return 0
        fi
    done
    (cd "${candidates[0]}" && pwd)
}

if [ -n "$PHASE_DIR" ] && [ -n "$ARGUMENTS" ]; then
    fail "AMBIGUOUS_INPUT" "design" "choose exactly one of --phase-dir or --arguments"
fi
if [ -n "$ARGUMENTS" ]; then
    RESOLVED_ARGUMENTS_DIR="$(resolve_existing_dir "$ARGUMENTS")"
    if [[ "$(basename "$RESOLVED_ARGUMENTS_DIR")" =~ ^phase-[0-9]+$ ]]; then
        PHASE_DIR="$RESOLVED_ARGUMENTS_DIR"
    else
        PHASE_DIR="$(select_phase_dir "$RESOLVED_ARGUMENTS_DIR")"
    fi
fi

[ -n "$PHASE_DIR" ] || fail "MISSING_ARG" "design" "--phase-dir or --arguments is required"
[ -d "$PHASE_DIR" ] || fail "MISSING_INPUT" "product-manager" "phase-dir not found: $PHASE_DIR"

PHASE_DIR_ABS="$(cd "$PHASE_DIR" && pwd)"
FEATURE_DIR="$(cd "$PHASE_DIR_ABS/.." && pwd)"
CONSTITUTION="$ROOT/docs/constitution.md"
CONSTITUTION_REF=""
BRIEF="$FEATURE_DIR/brief.json"
PHASE_PRD="$PHASE_DIR_ABS/phase-prd.json"
UNITS_DIR="$PHASE_DIR_ABS/units"

require_json_object() {
    local path="$1"
    local label="$2"
    [ -f "$path" ] || fail "MISSING_INPUT" "product-manager" "missing $label: $path"
    if ! jq -e 'type == "object"' "$path" >/dev/null 2>&1; then
        fail "SCHEMA_FAILURE" "product-manager" "$label must be a JSON object: $path"
    fi
}

run_closure_check() {
    local label="$1"
    shift
    local output
    output="$(mktemp "${TMPDIR:-/tmp}/design-preflight.XXXXXX")"
    if ! python3 "$ROOT/tools/community/validate_product_closure.py" "$@" >"$output" 2>&1; then
        local reason
        reason="$(sed -n '1,3p' "$output" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
        rm -f "$output"
        fail "UPSTREAM_NOT_READY" "product-manager" "$label is not ready for design: $reason"
    fi
    rm -f "$output"
}

require_json_object "$BRIEF" "brief.json"
require_json_object "$PHASE_PRD" "phase-prd.json"
[ -d "$UNITS_DIR" ] || fail "MISSING_INPUT" "product-manager" "units directory not found: $UNITS_DIR"

shopt -s nullglob
UNIT_FILES=("$UNITS_DIR"/UNIT-*.json)
shopt -u nullglob
[ "${#UNIT_FILES[@]}" -gt 0 ] || fail "MISSING_INPUT" "product-manager" "no UNIT-*.json files found: $UNITS_DIR"

for unit_file in "${UNIT_FILES[@]}"; do
    require_json_object "$unit_file" "UNIT artifact"
done

run_closure_check "brief.json" --artifact "$BRIEF" --require-review --require-delivery
run_closure_check "phase-prd.json" --artifact "$PHASE_PRD" --require-review
for unit_file in "${UNIT_FILES[@]}"; do
    run_closure_check "$(basename "$unit_file")" --artifact "$unit_file"
done

UNIT_REFS=()
for unit_file in "${UNIT_FILES[@]}"; do
    UNIT_REFS+=("${unit_file#"$ROOT"/}")
done
UNITS_JSON="$(printf '%s\n' "${UNIT_REFS[@]}" | jq -R . | jq -s .)"
[ -f "$CONSTITUTION" ] && CONSTITUTION_REF="${CONSTITUTION#"$ROOT"/}"

json_payload \
    --arg status "PASS" \
    --arg phase_dir "${PHASE_DIR_ABS#"$ROOT"/}" \
    --arg constitution "$CONSTITUTION_REF" \
    --arg brief "${BRIEF#"$ROOT"/}" \
    --arg phase_prd "${PHASE_PRD#"$ROOT"/}" \
    --argjson units "$UNITS_JSON" \
    '{status:$status, phase_dir:$phase_dir, constitution:(if $constitution | length > 0 then $constitution else null end), brief:$brief, phase_prd:$phase_prd, units:$units, unit_count:($units | length)}'
