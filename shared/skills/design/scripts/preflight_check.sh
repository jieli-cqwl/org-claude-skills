#!/usr/bin/env bash
# Validate design-ready product inputs before architecture co-creation.
set -euo pipefail

usage() {
    cat <<'USAGE'
design/preflight_check.sh — design input preflight

Usage:
  bash shared/skills/design/scripts/preflight_check.sh --phase-dir <docs/feature/phase-N>

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

PHASE_DIR=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --phase-dir)
            [ "$#" -ge 2 ] || fail "MISSING_ARG" "design" "--phase-dir requires a value"
            PHASE_DIR="$2"
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

[ -n "$PHASE_DIR" ] || fail "MISSING_ARG" "design" "--phase-dir is required"
[ -d "$PHASE_DIR" ] || fail "MISSING_INPUT" "product-manager" "phase-dir not found: $PHASE_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
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
