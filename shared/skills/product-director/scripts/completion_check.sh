#!/usr/bin/env bash
# Product Director result gate: validates Director-owned result payloads only.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
product-director/completion_check.sh — Director result baseline gate
Execution: PostToolUse(Edit|Write) or skill-local Stop
Input: stdin JSON (cwd, session_id, transcript_path, optional tool_input.file_path)
Output: stdout JSON decision + stderr diagnostics
USAGE
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_LIB="$(cd "$SCRIPT_DIR/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
hook_init

RUNTIME_ROOT="$(resolve_runtime_root "$SCRIPT_DIR")"

# Resolve the feature root from Director result artifact paths in the hook context.
resolve_director_feature_dir() {
    local pattern feature_count target_path

    pattern='docs/[^/"[:space:]*{}]+/(brief\.json|phase-[0-9]+/phase-prd\.json)'
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

# Director completion is valid only after its co-creation ledger is finalized.
validate_director_ledger_finalized() {
    local ledger_file="$FEATURE_DIR/product-director-ledger.json"
    local ledger_out

    ledger_out="$(mktemp "${TMPDIR:-/tmp}/director-ledger.XXXXXX")"
    if ! python3 "$RUNTIME_ROOT/tools/community/validate_co_creation_ledger.py" \
        --artifact "$ledger_file" \
        --producer product-director \
        --require-finalized >"$ledger_out" 2>&1; then
        add_failure "product-director-ledger.json finalized validation failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$ledger_out")
    fi
    rm -f "$ledger_out"
}

# Result payload validation is the deterministic boundary for Director artifacts.
validate_director_result_payload() {
    local artifact_file="$1"
    local label="$2"
    local result_out

    if [ ! -f "$artifact_file" ]; then
        add_failure "Director result artifact not found: $label"
        return 0
    fi

    result_out="$(mktemp "${TMPDIR:-/tmp}/director-result.XXXXXX")"
    if ! python3 - "$artifact_file" "$label" >"$result_out" 2>&1 <<'PY'; then
import json
import sys
from pathlib import Path
from typing import Any

path = Path(sys.argv[1])
label = sys.argv[2]
payload = json.loads(path.read_text(encoding="utf-8"))

BRIEF_KEYS = {
    "root_problem",
    "user_profile",
    "business_goals",
    "appetite",
    "scope_boundaries",
    "non_goals",
    "feasibility_constraints",
    "risks_and_unknowns",
    "decision_rationale",
    "delivery_plan",
}
PHASE_KEYS = {"phase_goal", "entry_conditions", "exit_conditions"}
RUNTIME_OR_DOWNSTREAM_FIELDS = {
    "artifact_type",
    "artifact_id",
    "schema_version",
    "producer",
    "produced_at",
    "chain_version",
    "chain_registry_digest",
    "authority_scope",
    "authoritative_fields",
    "director_confirmation",
    "locked_fields",
    "locked_field_digest",
    "unit_index",
    "unit_priority_order",
    "acceptance_criteria",
    "design_decisions",
    "non_functional_requirements",
    "business_flows",
    "user_paths",
    "rule_mappings",
    "semantic_draft",
    "business_semantics_draft",
    "semantics_gaps",
    "design_decision_candidates",
    "review_conclusion",
    "issue_ledger",
    "delivery_confirmation",
}


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def require_non_empty_list(errors: list[str], key: str) -> None:
    value = payload.get(key)
    if not isinstance(value, list) or not value:
        errors.append(f"{label}.{key} must be a non-empty array")


errors: list[str] = []
if not isinstance(payload, dict):
    errors.append(f"{label} must be a JSON object")
else:
    required = BRIEF_KEYS if label == "brief.json" else PHASE_KEYS
    actual = set(payload.keys())
    missing = sorted(required - actual)
    extra = sorted(actual - required)
    polluted = sorted(actual & RUNTIME_OR_DOWNSTREAM_FIELDS)
    if missing:
        errors.append(f"{label} missing Director result fields: {', '.join(missing)}")
    if extra:
        errors.append(
            f"{label} contains fields outside Director result payload: {', '.join(extra)}"
        )
    if polluted:
        errors.append(
            f"{label} contains runtime or downstream fields: {', '.join(polluted)}"
        )

    if label == "brief.json":
        if not isinstance(payload.get("root_problem"), str) or not payload["root_problem"].strip():
            errors.append("brief.json.root_problem must be a non-empty string")
        if not isinstance(payload.get("appetite"), dict) or not payload["appetite"]:
            errors.append("brief.json.appetite must be a non-empty object")
        for key in (
            "user_profile",
            "business_goals",
            "scope_boundaries",
            "non_goals",
            "feasibility_constraints",
            "risks_and_unknowns",
            "decision_rationale",
            "delivery_plan",
        ):
            require_non_empty_list(errors, key)
        for index, phase in enumerate(as_list(payload.get("delivery_plan")), start=1):
            if not isinstance(phase, dict):
                errors.append(f"brief.json.delivery_plan[{index}] must be an object")
                continue
            phase_keys = set(phase.keys())
            expected_phase_keys = {"phase_id", "goal", "iteration_timebox_days"}
            if phase_keys != expected_phase_keys:
                errors.append(
                    "brief.json.delivery_plan"
                    f"[{index}] keys must be phase_id, goal, iteration_timebox_days"
                )
            days = phase.get("iteration_timebox_days")
            if not isinstance(days, int) or days < 1 or days > 14:
                errors.append(
                    f"brief.json.delivery_plan[{index}].iteration_timebox_days must be 1-14"
                )

    if label == "phase-prd.json":
        if not isinstance(payload.get("phase_goal"), str) or not payload["phase_goal"].strip():
            errors.append("phase-prd.json.phase_goal must be a non-empty string")
        for key in ("entry_conditions", "exit_conditions"):
            require_non_empty_list(errors, key)
            if any(not isinstance(item, str) or not item.strip() for item in as_list(payload.get(key))):
                errors.append(f"phase-prd.json.{key} must contain non-empty strings")

if errors:
    for error in errors:
        print(error)
    sys.exit(1)
PY
        add_failure "$label Director result payload validation failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < "$result_out"
    fi
    rm -f "$result_out"
}

# Director gate also checks observable content quality signals, not only JSON shape.
validate_director_content_quality() {
    local phase_file="$1"
    local quality_out

    [ -f "$FEATURE_DIR/brief.json" ] && [ -f "$phase_file" ] || return 0

    quality_out="$(mktemp "${TMPDIR:-/tmp}/director-content-quality.XXXXXX")"
    if ! python3 "$SCRIPT_DIR/evaluate_content_quality.py" \
        --brief "$FEATURE_DIR/brief.json" \
        --phase-prd "$phase_file" \
        --ledger "$FEATURE_DIR/product-director-ledger.json" \
        --min-score 12 >"$quality_out" 2>&1; then
        add_failure "product-director content quality validation failed: ${phase_file#"$FEATURE_DIR/"}"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < "$quality_out"
    fi
    rm -f "$quality_out"
}

validate_director_artifact() {
    local artifact_file="$1"
    local label="$2"

    validate_director_result_payload "$artifact_file" "$label"
    if [ "$label" = "brief.json" ] && jq -e 'has("non_functional_req")' "$artifact_file" >/dev/null 2>&1; then
        add_failure "$label contains retired alias non_functional_req"
    fi
}

run_director_result_gate() {
    local phase_files

    resolve_director_feature_dir
    if [ -z "$FEATURE_DIR" ]; then
        add_failure "Director result feature root not found"
        output_failures "Director result baseline gate failed" ""
    fi

    validate_director_ledger_finalized
    validate_director_artifact "$FEATURE_DIR/brief.json" "brief.json"

    phase_files=$(find "$FEATURE_DIR" -path "$FEATURE_DIR/phase-*/phase-prd.json" -type f | sort)
    if [ -z "$phase_files" ]; then
        add_failure "Director result artifact not found: phase-prd.json"
    else
        while IFS= read -r phase_file; do
            if [ -n "$phase_file" ]; then
                validate_director_artifact "$phase_file" "phase-prd.json"
                validate_director_content_quality "$phase_file"
            fi
        done <<< "$phase_files"
    fi

    output_failures "Director result baseline gate failed" "$FEATURE_DIR"
    emit_decision_json "allow" "director result baseline validated"
}

run_director_result_gate
