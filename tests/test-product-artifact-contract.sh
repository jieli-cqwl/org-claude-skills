#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONTRACT="$ROOT/contracts/product-artifacts.yaml"
DIRECTOR_CHECK="$ROOT/shared/skills/product-director/scripts/completion_check.sh"
MANAGER_CHECK="$ROOT/shared/skills/product-manager/scripts/completion_check.sh"
DIRECTOR_FINAL_ARTIFACTS_REFERENCE="$ROOT/shared/skills/product-director/references/final-artifacts.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
DESIGN_CHECK="$ROOT/shared/skills/design/scripts/completion_check.sh"
ROLE_CONTRACT_TEST="$ROOT/tests/test-product-role-split-contract.sh"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Eq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern '$pattern' in $file"
  fi
}

assert_file "$CONTRACT"
assert_present '^product_artifacts:' "$CONTRACT"
assert_present 'brief_result:' "$CONTRACT"
assert_present 'phase_result:' "$CONTRACT"
assert_present 'product_manager_review_contract:' "$CONTRACT"
assert_absent '^[[:space:]]*review_contract:' "$CONTRACT"
assert_present '业务背景与根问题' "$CONTRACT"
assert_present '目标与成功标准' "$CONTRACT"
assert_present '交付计划' "$CONTRACT"
assert_present '阶段目标' "$CONTRACT"
assert_present '入口与出口条件' "$CONTRACT"
assert_absent '产品总监确认|功能需求（UNIT 索引）' "$CONTRACT"
assert_present '最终结论' "$CONTRACT"
assert_present '未决阻断' "$CONTRACT"

assert_present 'Director result baseline gate' "$DIRECTOR_CHECK"
assert_absent 'validate_canonical_schema\.py|validate_product_closure\.py' "$DIRECTOR_CHECK"
assert_present 'validate_canonical_schema\.py' "$MANAGER_CHECK"
assert_present '只按模板写结果 payload' "$DIRECTOR_FINAL_ARTIFACTS_REFERENCE"
assert_absent 'producer.*`product`|director_confirmation|locked_field_digest|chain_registry_digest' "$DIRECTOR_FINAL_ARTIFACTS_REFERENCE"
assert_present '"producer"[[:space:]]*:[[:space:]]*"product"' "$ROOT/shared/skills/product-manager/templates/brief.template.json"
assert_present 'validate_product_closure\.py' "$MANAGER_CHECK"
assert_present 'validate_product_closure\.py' "$DESIGN_CHECK"
assert_present 'require-delivery' "$DESIGN_CHECK"
assert_present 'delivery_confirmation\.status=confirmed' "$DESIGN_SKILL"
assert_present 'issue_ledger' "$DESIGN_SKILL"
assert_absent 'REQUIRED_BRIEF_LOCK_HEADINGS=\(' "$MANAGER_CHECK"
assert_absent 'REQUIRED_PRD_LOCK_HEADINGS=\(' "$MANAGER_CHECK"
assert_absent '"业务背景与根问题"[[:space:]]+"目标与成功标准"' "$MANAGER_CHECK"

python3 - "$ROOT" <<'PY'
import ast
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])


def load_json(path: str) -> dict:
    return json.loads((root / path).read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def require_schema_fields(schema: dict, fields: list[str], label: str) -> None:
    body = schema["allOf"][1]
    props = body["properties"]
    required = set(body["required"])
    missing_props = sorted(set(fields) - set(props))
    missing_required = sorted(set(fields) - required)
    require(not missing_props, f"{label} schema missing properties: {missing_props}")
    require(not missing_required, f"{label} schema missing required fields: {missing_required}")


def require_schema_properties(schema: dict, fields: list[str], label: str) -> None:
    body = schema["allOf"][1]
    props = body["properties"]
    missing_props = sorted(set(fields) - set(props))
    require(not missing_props, f"{label} schema missing properties: {missing_props}")


def require_conditional_manager_phase_fields(schema: dict, fields: list[str]) -> None:
    body_required = set(schema["allOf"][1].get("required", []))
    for rule in schema.get("allOf", []):
        if set(rule.get("if", {}).get("required", [])) != {"review_conclusion"}:
            continue
        required = set(rule.get("then", {}).get("required", []))
        missing = sorted(set(fields) - required - body_required)
        require(not missing, f"phase-prd schema missing Manager-finalized required fields: {missing}")
        unit_index = rule.get("then", {}).get("properties", {}).get("unit_index", {})
        require(unit_index.get("minItems") == 1, "phase-prd schema must require non-empty unit_index after Manager review")
        return
    raise SystemExit("phase-prd schema missing Manager-finalized review_conclusion conditional")


def require_authoritative_fields(template: dict, fields: list[str], label: str) -> None:
    authoritative = set(template["authoritative_fields"])
    missing = sorted(f"$.{field}" for field in fields if f"$.{field}" not in authoritative)
    require(not missing, f"{label} template missing authoritative_fields: {missing}")


def require_delivery_plan_timebox(schema: dict, template: dict, label: str) -> None:
    delivery_item = schema["allOf"][1]["properties"]["delivery_plan"]["items"]
    require("iteration_timebox_days" in delivery_item["required"], f"{label} delivery_plan must require iteration_timebox_days")
    timebox = delivery_item["properties"].get("iteration_timebox_days", {})
    require(timebox.get("type") == "integer", f"{label} iteration_timebox_days must be an integer")
    require(timebox.get("maximum") == 14, f"{label} iteration_timebox_days must cap each Phase at 14 days")
    for index, item in enumerate(template.get("delivery_plan", []), start=1):
        require(item.get("iteration_timebox_days") == 14, f"{label} template delivery_plan[{index}] must carry a 14-day timebox")


def require_exact_template_fields(template: dict, fields: list[str], label: str) -> None:
    actual = set(template)
    expected = set(fields)
    require(actual == expected, f"{label} template fields drift: extra={sorted(actual - expected)} missing={sorted(expected - actual)}")


director_brief_fields = [
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
]
phase_prd_manager_fields = [
    "evidence_sources",
    "as_is_flows",
    "to_be_flows",
    "business_process_graphs",
    "feature_inventory",
    "module_capability_matrix",
    "entry_scene_inventory",
    "business_objects",
    "state_transitions",
    "role_permission_matrix",
    "risk_ledger",
    "coverage_matrix",
    "technical_evidence_requirements",
    "release_readiness",
    "business_flows",
    "user_paths",
    "rule_mappings",
    "unit_index",
    "unit_priority_order",
    "design_decision_candidates",
]
phase_prd_director_fields = [
    "phase_goal",
    "entry_conditions",
    "exit_conditions",
]
unit_manager_fields = [
    "trigger",
    "core_behavior",
    "observable_result",
    "feature_refs",
    "flow_refs",
    "risk_refs",
    "rule_refs",
    "integration_context",
    "acceptance_criteria",
    "verification_plan",
    "design_decision_candidates",
]

brief_schema = load_json("shared/skills/product-manager/contracts/brief.schema.json")
phase_schema = load_json("shared/skills/product-manager/contracts/phase-prd.schema.json")
unit_schema = load_json("shared/skills/product-manager/contracts/unit-definition.schema.json")
director_brief_template = load_json("shared/skills/product-director/templates/brief.template.json")
director_phase_template = load_json("shared/skills/product-director/templates/phase-prd.template.json")
manager_phase_template = load_json("shared/skills/product-manager/templates/phase-prd.template.json")
unit_template = load_json("shared/skills/product-manager/templates/unit-definition.template.json")

require_schema_fields(brief_schema, director_brief_fields, "brief")
require_exact_template_fields(director_brief_template, director_brief_fields, "director brief")
require_delivery_plan_timebox(brief_schema, director_brief_template, "director brief")
require_exact_template_fields(director_phase_template, phase_prd_director_fields, "director phase-prd")

require_schema_properties(phase_schema, phase_prd_manager_fields, "phase-prd")
require_conditional_manager_phase_fields(phase_schema, phase_prd_manager_fields)
require_authoritative_fields(manager_phase_template, phase_prd_manager_fields, "manager phase-prd")

require_schema_fields(unit_schema, unit_manager_fields, "unit-definition")
require_authoritative_fields(unit_template, unit_manager_fields, "unit-definition")
ac_items = unit_schema["allOf"][1]["properties"]["acceptance_criteria"]["items"]
require(ac_items.get("type") == "object", "unit acceptance_criteria must be structured objects")
for field in ["ac_id", "description", "example_input", "expected_result", "boundary_case", "failure_mode"]:
    require(field in ac_items.get("required", []), f"unit acceptance_criteria item must require {field}")
evidence_types = set(
    phase_schema["allOf"][1]["properties"]["evidence_sources"]["items"]["properties"]["source_type"]["enum"]
)
for source_type in ["screen_recording", "api_request_response", "data_before_after", "audit_log", "test_record"]:
    require(source_type in evidence_types, f"phase-prd evidence_sources.source_type missing {source_type}")
verification_items = unit_schema["allOf"][1]["properties"]["verification_plan"]["items"]
require("evidence_types" in verification_items.get("required", []), "unit verification_plan item must require evidence_types")
require(
    verification_items["properties"]["evidence_types"]["items"]["enum"] == sorted(evidence_types),
    "unit verification_plan evidence_types enum must match phase evidence source types",
)

standard_chain = (root / "contracts/standard-chain.yaml").read_text(encoding="utf-8")
for field in director_brief_fields:
    require(field in standard_chain, f"standard-chain contract missing Director brief field: {field}")
for field in phase_prd_director_fields:
    require(field in standard_chain, f"standard-chain contract missing Director phase field: {field}")
for field in phase_prd_manager_fields:
    require(field in standard_chain, f"standard-chain contract missing Manager phase field: {field}")
for field in unit_manager_fields:
    require(field in standard_chain, f"standard-chain contract missing Manager UNIT field: {field}")
PY

assert_present 'test-product-artifact-contract.sh' "$ROLE_CONTRACT_TEST"

echo "[PASS] product artifact contract"
