#!/usr/bin/env bash
# Verify the strengthened test-design schema/template contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$ROOT/contracts/canonical/schemas/planning/test-cases.schema.json"
TEMPLATE="$ROOT/contracts/canonical/templates/planning/test-cases.template.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_json() {
  local file="$1"
  jq empty "$file" >/dev/null 2>&1 || fail "invalid JSON: ${file#"$ROOT"/}"
}

assert_jq() {
  local expr="$1"
  local file="$2"
  jq -e "$expr" "$file" >/dev/null || fail "missing contract in ${file#"$ROOT"/}: $expr"
}

assert_json "$SCHEMA"
assert_json "$TEMPLATE"

schema_props='.allOf[1].properties'
schema_required='.allOf[1].required'
test_case_required='.allOf[1].properties.test_cases.items.required'
gap_required='.allOf[1].properties.design_gap_report.properties.gaps.items.required'

assert_jq '.allOf[1]."$defs".sourceRef.pattern | test("brief\\\\.json") and test("phase-prd\\\\.json") and test("UNIT-") and test("design\\\\.json")' "$SCHEMA"
assert_jq '.allOf[1]."$defs".gapType.enum == ["PRODUCT_GAP","DESIGN_GAP","SCOPE_DRIFT","TRACE_CONFLICT","TESTABILITY_GAP","EQ_GAP"]' "$SCHEMA"

for field in test_analysis traceability_matrix cross_unit_obligations; do
  assert_jq "$schema_props | has(\"$field\")" "$SCHEMA"
  assert_jq "$schema_required | index(\"$field\") != null" "$SCHEMA"
  assert_jq '.authoritative_fields | index("$.'$field'") != null' "$TEMPLATE"
done

for field in objectives in_scope out_of_scope risk_model strategy_by_quality_area test_flow environment_assumptions data_assumptions; do
  assert_jq '.allOf[1].properties.test_analysis.required | index("'$field'") != null' "$SCHEMA"
  assert_jq '.test_analysis | has("'$field'")' "$TEMPLATE"
done

for field in product_refs design_refs case_type priority preconditions test_data steps expected_result assertion_target execution_mode automation_level evidence_expectation owner_stage; do
  assert_jq "$test_case_required | index(\"$field\") != null" "$SCHEMA"
  assert_jq '.test_cases[0] | has("'$field'")' "$TEMPLATE"
done

for value in positive negative boundary exclusion specialty; do
  assert_jq '.allOf[1].properties.test_cases.items.properties.case_type.enum | index("'$value'") != null' "$SCHEMA"
done

for field in gap_id gap_type blocking_refs owner next_action blocking; do
  assert_jq "$gap_required | index(\"$field\") != null" "$SCHEMA"
done

assert_jq '.design_gap_report.gaps | type == "array"' "$TEMPLATE"

assert_jq '.allOf[1].properties.qa_handoff_contract.items.properties.qa_stage.enum == ["QA_A","QA_B","QA_C","QA_D","NFR"]' "$SCHEMA"
assert_jq '.allOf[1].properties.qa_handoff_contract.items.required | index("trigger_source") != null and index("evidence_expectation") != null' "$SCHEMA"

for field in journey_id journey_title participant_unit_refs local_unit_ref sequence_index predecessor_case_refs successor_case_refs handoff_obligation_refs composition_status gap_refs; do
  assert_jq '.allOf[1].properties.cross_unit_obligations.items.required | index("'$field'") != null' "$SCHEMA"
done
assert_jq '.allOf[1].properties.cross_unit_obligations.items.properties.composition_status.enum == ["COMPOSABLE","BLOCKED_GAP"]' "$SCHEMA"

printf '[PASS] test-design governance contract\n'
