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

# Validate a canonical artifact through the shared schema catalog.
validate_schema() {
    local file="$1"
    local label="$2"
    local fixture_file schema_out

    fixture_file="$(mktemp "${TMPDIR:-/tmp}/design-canonical.XXXXXX")"
    schema_out="$(mktemp "${TMPDIR:-/tmp}/design-canonical-schema.XXXXXX")"
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

# Validate canonical design through the standard-chain phase validator so the
# hook gate cannot drift from duplicate-id and traceability rules.
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

# Validate canonical-only cleanup that JSON Schema cannot safely express while
# templates still carry placeholders.
validate_design_cleanup() {
    local target="$1"

    if jq -e '
        has("candidate_design_json")
        or has("open_warns")
        or has("handoff_summary")
        or has("co_creation_confirmations")
        or has("source_refs")
    ' "$target" >/dev/null 2>&1; then
        add_failure "design.json contains S8 candidate package fields that must not be canonical: $target"
    fi

    if jq -e 'any(..; type == "string" and test("<[^>]+>"))' "$target" >/dev/null 2>&1; then
        add_failure "design.json contains unresolved placeholder strings: $target"
    fi
}

validate_review_digest() {
    local target="$1"
    local digest_out

    digest_out="$(mktemp "${TMPDIR:-/tmp}/design-review-digest.XXXXXX")"
    if ! python3 "$SCRIPT_DIR/review_digest.py" --check "$target" >"$digest_out" 2>&1; then
        add_failure "design.json review_closure candidate digest does not match reviewed candidate"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$digest_out")
    fi
    rm -f "$digest_out"
}

# Validate Product Manager handoff closure before accepting a design artifact.
validate_product_handoff() {
    local design_file="$1"
    local phase_dir feature_dir closure_out

    phase_dir="$(cd "$(dirname "$design_file")" && pwd)"
    feature_dir="$(cd "$phase_dir/.." && pwd)"
    closure_out="$(mktemp "${TMPDIR:-/tmp}/design-product-handoff.XXXXXX")"

    if ! python3 "$RUNTIME_ROOT/tools/community/validate_product_closure.py" \
        --artifact "$feature_dir/brief.json" \
        --require-review \
        --require-delivery >"$closure_out" 2>&1; then
        add_failure "brief.json product handoff closure is not ready for design"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$closure_out")
    fi

    if ! python3 "$RUNTIME_ROOT/tools/community/validate_product_closure.py" \
        --artifact "$phase_dir/phase-prd.json" \
        --require-review >"$closure_out" 2>&1; then
        add_failure "phase-prd.json product handoff closure is not ready for design"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$closure_out")
    fi

    rm -f "$closure_out"
}

# Validate design semantics that JSON Schema cannot express.
validate_design_semantics() {
    local target="$1"

    if ! jq -e '
        def non_empty_string: type == "string" and length > 0;
        def non_empty_array: type == "array" and length > 0;
        def frozen_key_decision:
            type == "object"
            and (.decision_id | non_empty_string)
            and (.summary | non_empty_string)
            and (.decision_state == "已冻结")
            and (.verdict | non_empty_string)
            and (.option_ref | non_empty_string)
            and (.fact_refs | non_empty_array)
            and (.user_confirmation | non_empty_string);
        def option_candidate:
            type == "object"
            and (.option_id | non_empty_string)
            and (.decision_ref | non_empty_string)
            and (.summary | non_empty_string)
            and (.tradeoff | non_empty_string)
            and (.verdict | non_empty_string)
            and (.fact_refs | non_empty_array);
        . as $root
        | (.key_decisions | non_empty_array)
        and (.option_analysis | non_empty_array)
        and all(.option_analysis[]; option_candidate)
        and (. as $root | all($root.key_decisions[];
            . as $decision
            | frozen_key_decision
            and ([ $root.option_analysis[] | select(.decision_ref == $decision.decision_id) ] | length >= 2)
            and ([ $root.option_analysis[] | select(.decision_ref == $decision.decision_id) | .option_id ] | index($decision.option_ref))
        ))
        and (.co_creation_summary | non_empty_array)
        and (([.co_creation_summary[].stage_id] | unique) | (index("S3") and index("S4") and index("S5") and index("S6") and index("S7") and index("S8")))
        and all(.co_creation_summary[]; (.stage_name | non_empty_string) and (.question_or_focus | non_empty_string) and (.user_response_summary | non_empty_string) and (.decision_refs | non_empty_array))
        and (.constraint_inheritance_confirmation.status == "confirmed")
        and (.constraint_inheritance_confirmation.confirmed_at | non_empty_string)
        and (.constraint_inheritance_confirmation.source_refs | type == "array")
        and all(.constraint_inheritance_confirmation.source_refs[]; type == "string" and length > 0)
        and (.constraint_inheritance_confirmation.inherited_constraints | type == "array")
        and all(.constraint_inheritance_confirmation.inherited_constraints[]; type == "string" and length > 0)
        and (.constraint_inheritance_confirmation.rejected_constraints | type == "array")
        and all(.constraint_inheritance_confirmation.rejected_constraints[]; type == "string" and length > 0)
        and (.constraint_inheritance_confirmation.confirmation_summary | non_empty_string)
        and (.review_closure.candidate_digest | type == "string" and test("^sha256:[0-9a-f]{64}$"))
        and (.review_closure.reviewed_at | non_empty_string)
        and (.review_closure.reviewers | type == "array" and length >= 3)
        and (([.review_closure.reviewers[].reviewer] | unique) | (index("architecture") and index("product") and index("test")))
        and all(.review_closure.reviewers[]; ((.verdict == "PASS") or (.verdict == "WARN")) and (.finding_refs | type == "array") and (.reviewed_candidate_digest == $root.review_closure.candidate_digest))
        and (.review_closure.resolved_failures | type == "array")
        and all(.review_closure.resolved_failures[]; (.finding_id | non_empty_string) and (.evidence_ref | non_empty_string))
        and (.review_closure.warn_followups | type == "array")
        and all(.review_closure.warn_followups[]; (.finding_id | non_empty_string) and (.summary | non_empty_string) and ((.target == "design.json#planning_constraints") or (.target == "design.json#risk_response") or (.target == "design.json#verification_mapping") or (.target == "design.json#product_handoff")))
        and (
            ([.review_closure.reviewers[] | select(.verdict == "WARN") | .finding_refs[]] | unique) as $warn_findings
            | ([.review_closure.warn_followups[].finding_id] | unique) as $followups
            | all($warn_findings[]; . as $id | $followups | index($id))
        )
        and (.final_confirmation.status == "confirmed")
        and (.final_confirmation.confirmed_by | non_empty_string)
        and (.final_confirmation.confirmed_at | non_empty_string)
        and (.final_confirmation.summary | non_empty_string)
        and (.final_confirmation.accepted_refs | non_empty_array)
        and (.modules | non_empty_array)
        and (.data_architecture.summary | non_empty_string)
        and (.data_architecture.storage_decisions | non_empty_array)
        and (.data_architecture.data_flows | non_empty_array)
        and (.data_architecture.consistency_strategy | non_empty_string)
        and (.cross_cutting_concerns | type == "array")
        and (([.cross_cutting_concerns[].concern] | unique) | (index("auth") and index("error") and index("log") and index("config")))
        and all(.cross_cutting_concerns[]; (.decision | non_empty_string) and (.owner | non_empty_string) and (.verification_refs | non_empty_array))
        and (.verification_mapping | non_empty_array)
        and all(.verification_mapping[]; (.manager_vp_ref | non_empty_string) and (.design_validation | non_empty_string) and (.test_obligation | non_empty_string) and (.evidence_ref | non_empty_string))
        and (
            [.verification_mapping[].evidence_ref] as $verification_refs
            | all((.quality_attributes // [])[]; all((.verification_refs // [])[]; . as $ref | $verification_refs | index($ref)))
            and all((.cross_cutting_concerns // [])[]; all((.verification_refs // [])[]; . as $ref | $verification_refs | index($ref)))
            and all((.impact_scope // [])[]; all((.verification_refs // [])[]; . as $ref | $verification_refs | index($ref)))
            and all((.risk_response // [])[]; all((.verification_refs // [])[]; . as $ref | $verification_refs | index($ref)))
        )
        and (.unit_coverage | non_empty_array)
        and all(.unit_coverage[]; (.unit_id | non_empty_string) and (.ac_refs | non_empty_array) and (.design_refs | non_empty_array))
        and (.impact_scope | non_empty_array)
        and all(.impact_scope[]; (.scope_item_id | non_empty_string) and (.affected_modules | non_empty_array) and (.impact | non_empty_string) and (.verification_refs | non_empty_array))
        and (.planning_constraints | non_empty_array)
        and all(.planning_constraints[]; (.constraint_id | non_empty_string) and (.constraint_type | non_empty_string) and (.description | non_empty_string) and (.owner | non_empty_string))
        and (.product_handoff.status == "READY")
        and (.product_handoff.accepted_refs | non_empty_array)
        and (.product_handoff.open_failures | type == "array" and length == 0)
        and (.risks | non_empty_array)
        and (.risk_response | non_empty_array)
        and (([.risks[].risk_id] - [.risk_response[].risk_id]) | length == 0)
        and all(.risk_response[]; (.architecture_response | non_empty_string) and (((.verification_refs // []) | length > 0) or (.escalation_path | non_empty_string)))
    ' "$target" >/dev/null 2>&1; then
        add_failure "design.json missing key decision contract, Q1-Q9 semantic closure, cross-cutting coverage, verification mapping, product handoff, or risk response: $target"
    fi
}

# Validate traceability refs against sibling canonical product artifacts.
validate_design_references() {
    local target="$1"
    local phase_dir feature_dir ref_out

    phase_dir="$(cd "$(dirname "$target")" && pwd)"
    feature_dir="$(cd "$phase_dir/.." && pwd)"
    ref_out="$(mktemp "${TMPDIR:-/tmp}/design-reference-check.XXXXXX")"

    if ! python3 - "$target" "$feature_dir/brief.json" "$phase_dir/phase-prd.json" "$phase_dir/units" >"$ref_out" 2>&1 <<'PY'
import json
import re
import sys
from pathlib import Path

design_path = Path(sys.argv[1])
brief_path = Path(sys.argv[2])
phase_prd_path = Path(sys.argv[3])
units_dir = Path(sys.argv[4])

manager_ref_re = re.compile(r"^(phase-prd)\.([A-Za-z_][A-Za-z0-9_]*)\[(\d+)\]$")
handoff_ref_re = re.compile(r"^(brief\.json|phase-prd\.json)#(.+)$")


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def require_list(value, path):
    if not isinstance(value, list) or not value:
        raise ValueError(f"{path} must be a non-empty array")
    return value


def anchor_exists(document, anchor):
    if anchor.startswith("/"):
        current = document
        for raw_part in anchor.strip("/").split("/"):
            part = raw_part.replace("~1", "/").replace("~0", "~")
            if isinstance(current, dict) and part in current:
                current = current[part]
            elif isinstance(current, list) and part.isdigit() and int(part) < len(current):
                current = current[int(part)]
            else:
                return False
        return True
    field = anchor.split(".", 1)[0].split("[", 1)[0]
    return field in document


def assert_manager_ref(ref, phase_prd, path):
    if not isinstance(ref, str):
        raise ValueError(f"{path} must be a string")
    match = manager_ref_re.match(ref)
    if not match:
        raise ValueError(f"unsupported manager ref: {ref}")
    _artifact_name, field, raw_index = match.groups()
    values = phase_prd.get(field)
    if not isinstance(values, list) or int(raw_index) >= len(values):
        raise ValueError(f"manager ref does not resolve: {ref}")


def assert_handoff_ref(ref, documents, path):
    if not isinstance(ref, str):
        raise ValueError(f"{path} must be a string")
    match = handoff_ref_re.match(ref)
    if not match:
        raise ValueError(f"unsupported handoff ref: {ref}")
    document_name, anchor = match.groups()
    if document_name not in documents or not anchor_exists(documents[document_name], anchor):
        raise ValueError(f"handoff ref does not resolve: {ref}")


def assert_design_ref(ref, design, path):
    if not isinstance(ref, str):
        raise ValueError(f"{path} must be a string")
    if not ref.startswith("design.json#"):
        raise ValueError(f"{path} must target design.json: {ref}")
    if not anchor_exists(design, ref.removeprefix("design.json#")):
        raise ValueError(f"design ref does not resolve: {ref}")


design = load_json(design_path)
brief = load_json(brief_path)
phase_prd = load_json(phase_prd_path)
units = [load_json(path) for path in sorted(units_dir.glob("UNIT-*.json"))]
unit_map = {
    unit["unit_id"]: {
        row.get("ac_id")
        for row in unit.get("acceptance_criteria", [])
        if isinstance(row, dict) and isinstance(row.get("ac_id"), str)
    }
    for unit in units
    if isinstance(unit.get("unit_id"), str)
}
expected_units = set(phase_prd.get("unit_index", []))
missing_units = sorted(expected_units - set(unit_map))
if missing_units:
    raise ValueError(f"missing unit definitions: {missing_units}")

module_ids = {
    row.get("module_id")
    for row in design.get("modules", [])
    if isinstance(row, dict) and isinstance(row.get("module_id"), str)
}
interface_ids = {
    row.get("interface_id")
    for row in design.get("interfaces", [])
    if isinstance(row, dict) and isinstance(row.get("interface_id"), str)
}
design_refs = module_ids | interface_ids

for index, mapping in enumerate(require_list(design.get("verification_mapping"), "verification_mapping")):
    assert_manager_ref(mapping.get("manager_vp_ref"), phase_prd, f"verification_mapping[{index}].manager_vp_ref")

for index, row in enumerate(require_list(design.get("unit_coverage"), "unit_coverage")):
    unit_id = row.get("unit_id")
    if unit_id not in unit_map:
        raise ValueError(f"unit_coverage references unknown unit: {unit_id}")
    unknown_acs = sorted(set(require_list(row.get("ac_refs"), f"unit_coverage[{index}].ac_refs")) - unit_map[unit_id])
    if unknown_acs:
        raise ValueError(f"unit_coverage references unknown ACs for {unit_id}: {unknown_acs}")
    unknown_design_refs = sorted(set(require_list(row.get("design_refs"), f"unit_coverage[{index}].design_refs")) - design_refs)
    if unknown_design_refs:
        raise ValueError(f"unit_coverage references unknown design refs: {unknown_design_refs}")

for index, row in enumerate(require_list(design.get("impact_scope"), "impact_scope")):
    unknown_modules = sorted(set(require_list(row.get("affected_modules"), f"impact_scope[{index}].affected_modules")) - module_ids)
    if unknown_modules:
        raise ValueError(f"impact_scope references unknown modules: {unknown_modules}")

documents = {"brief.json": brief, "phase-prd.json": phase_prd}
for index, ref in enumerate(require_list(design.get("product_handoff", {}).get("accepted_refs"), "product_handoff.accepted_refs")):
    assert_handoff_ref(ref, documents, f"product_handoff.accepted_refs[{index}]")

for index, option in enumerate(require_list(design.get("option_analysis"), "option_analysis")):
    for ref_index, ref in enumerate(require_list(option.get("fact_refs"), f"option_analysis[{index}].fact_refs")):
        assert_design_ref(ref, design, f"option_analysis[{index}].fact_refs[{ref_index}]")

for index, decision in enumerate(require_list(design.get("key_decisions"), "key_decisions")):
    for ref_index, ref in enumerate(require_list(decision.get("fact_refs"), f"key_decisions[{index}].fact_refs")):
        assert_design_ref(ref, design, f"key_decisions[{index}].fact_refs[{ref_index}]")

for index, row in enumerate(require_list(design.get("co_creation_summary"), "co_creation_summary")):
    for ref_index, ref in enumerate(require_list(row.get("decision_refs"), f"co_creation_summary[{index}].decision_refs")):
        assert_design_ref(ref, design, f"co_creation_summary[{index}].decision_refs[{ref_index}]")

for ref_index, ref in enumerate(require_list(design.get("final_confirmation", {}).get("accepted_refs"), "final_confirmation.accepted_refs")):
    assert_design_ref(ref, design, f"final_confirmation.accepted_refs[{ref_index}]")
PY
    then
        add_failure "design.json traceability refs do not resolve: $target"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$ref_out")
    fi
    rm -f "$ref_out"
}

# Validate the design-specific required semantic fields.
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

    validate_product_handoff "$target"
    validate_schema "$target" "design.json"
    validate_phase_contract "$target"
    validate_design_cleanup "$target"
    validate_design_semantics "$target"
    validate_review_digest "$target"
    validate_design_references "$target"
    if ! jq -e '
        ((.input_analysis // "") | type == "string" and length > 0)
        and (.key_decisions | type == "array" and length > 0)
        and all(.key_decisions[];
            ((.decision_id // "") | type == "string" and length > 0)
            and ((.summary // "") | type == "string" and length > 0)
            and (.decision_state == "已冻结")
            and ((.verdict // "") | type == "string" and length > 0)
            and ((.option_ref // "") | type == "string" and length > 0)
            and (.fact_refs | type == "array" and length > 0)
            and all(.fact_refs[]; type == "string" and length > 0)
            and ((.user_confirmation // "") | type == "string" and length > 0)
        )
        and (.option_analysis | type == "array" and length >= 2)
        and all(.option_analysis[]; ((.option_id // "") | type == "string" and length > 0) and ((.decision_ref // "") | type == "string" and length > 0) and ((.summary // "") | type == "string" and length > 0) and ((.tradeoff // "") | type == "string" and length > 0) and ((.verdict // "") | type == "string" and length > 0) and (.fact_refs | type == "array" and length > 0) and all(.fact_refs[]; type == "string" and length > 0))
        and (. as $root | all($root.key_decisions[];
            . as $decision
            | ([ $root.option_analysis[] | select(.decision_ref == $decision.decision_id) ] | length >= 2)
            and ([ $root.option_analysis[] | select(.decision_ref == $decision.decision_id) | .option_id ] | index($decision.option_ref))
        ))
        and (.runtime_facts | type == "array" and length > 0)
        and all(.runtime_facts[]; (type == "string") and (test("evidence=")) and (test("observed_at=")))
        and (.interfaces | type == "array" and length > 0)
        and all(.interfaces[];
            ((.interface_id // "") | type == "string" and length > 0)
            and ((.owner // "") | type == "string" and length > 0)
            and ((.contract_summary // "") | type == "string" and length > 0)
            and (.error_modes | type == "array" and length > 0)
            and (.input_params | type == "array" and length > 0)
            and all(.input_params[]; (.name | type == "string" and length > 0) and (.type | type == "string" and length > 0) and (.required | type == "boolean") and (.validation | type == "string" and length > 0) and (.description | type == "string" and length > 0))
            and (.output_params | type == "array" and length > 0)
            and all(.output_params[]; (.name | type == "string" and length > 0) and (.type | type == "string" and length > 0) and (.description | type == "string" and length > 0))
            and (.error_codes | type == "array" and length > 0)
            and all(.error_codes[]; (.code | type == "string" and length > 0) and (.condition | type == "string" and length > 0) and (.user_message | type == "string" and length > 0))
        )
        and (.interface_boundary | type == "array" and length > 0)
        and (.quality_attributes | type == "array" and length > 0)
        and all(.quality_attributes[];
            ((.attribute // "") | type == "string" and length > 0)
            and ((.priority // "") | type == "string" and length > 0)
            and (.key_scenarios | type == "array" and length > 0)
            and all(.key_scenarios[]; type == "string" and length > 0)
            and (.target_metrics | type == "array" and length > 0)
            and all(.target_metrics[]; type == "string" and length > 0)
            and (.tradeoff_points | type == "array" and length > 0)
            and all(.tradeoff_points[]; type == "string" and length > 0)
            and (.verification_refs | type == "array" and length > 0)
            and all(.verification_refs[]; type == "string" and length > 0)
        )
        and (.migration_plan | type == "array" and length > 0)
        and (.verification_plan | type == "array" and length > 0)
        and (.rollback_plan | type == "array" and length > 0)
    ' "$target" >/dev/null 2>&1; then
        add_failure "design.json missing canonical key decisions, alternatives, runtime facts, interfaces, migration, verification, rollback, or quality fields: $target"
    fi
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
