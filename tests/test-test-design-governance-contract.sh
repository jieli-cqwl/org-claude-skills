#!/usr/bin/env bash
# Verify the strengthened test-design schema/template contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
TEMPLATE="$ROOT/shared/skills/test-design/templates/test-cases.template.json"

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
qa_handoff_required='.allOf[1].properties.qa_handoff_contract.items.required'
special_trigger_required='.allOf[1].properties.special_test_triggers.items.required'
reviewer_verdict_required='.allOf[1].properties.review_conclusion.properties.reviewer_verdicts.items.required'

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
for field in obligation_id trigger_source evidence_expectation design_source_refs; do
  assert_jq "$qa_handoff_required | index(\"$field\") != null" "$SCHEMA"
  assert_jq '.qa_handoff_contract[0] | has("'$field'")' "$TEMPLATE"
done

for field in journey_id journey_title participant_unit_refs local_unit_ref sequence_index predecessor_case_refs successor_case_refs handoff_obligation_refs composition_status gap_refs; do
  assert_jq '.allOf[1].properties.cross_unit_obligations.items.required | index("'$field'") != null' "$SCHEMA"
done
assert_jq '.allOf[1].properties.cross_unit_obligations.items.properties.composition_status.enum == ["COMPOSABLE","BLOCKED_GAP"]' "$SCHEMA"
assert_jq '.cross_unit_obligations[0].handoff_obligation_refs[0] == .qa_handoff_contract[0].obligation_id' "$TEMPLATE"

for field in trigger_id trigger_type source_ref condition qa_stage handling; do
  assert_jq "$special_trigger_required | index(\"$field\") != null" "$SCHEMA"
  assert_jq '.special_test_triggers[0] | has("'$field'")' "$TEMPLATE"
done
for handling in TEST_CASE QA_HANDOFF TYPED_GAP; do
  assert_jq '.allOf[1].properties.special_test_triggers.items.properties.handling.enum | index("'$handling'") != null' "$SCHEMA"
done
for trigger_type in quality_attribute data_architecture cross_cutting_concern; do
  assert_jq '.allOf[1].properties.special_test_triggers.items.properties.trigger_type.enum | index("'$trigger_type'") != null' "$SCHEMA"
done
for field in test_case_refs qa_handoff_obligation_refs gap_refs; do
  assert_jq '.allOf[1].properties.special_test_triggers.items.properties | has("'$field'")' "$SCHEMA"
done
assert_jq '.special_test_triggers[0].source_ref | startswith("design.json#")' "$TEMPLATE"
assert_jq 'any(.special_test_triggers[]; .handling == "TEST_CASE" and (.test_case_refs | length > 0)) or any(.test_cases[]; .case_type == "specialty")' "$TEMPLATE"
assert_jq '. as $root | any($root.special_test_triggers[]; .handling == "QA_HANDOFF" and .qa_handoff_obligation_refs[0] == $root.qa_handoff_contract[0].obligation_id)' "$TEMPLATE"
assert_jq '. as $root | any($root.special_test_triggers[]; .handling == "TYPED_GAP" and (.gap_refs | length > 0) and (.gap_refs as $refs | any($root.design_gap_report.gaps[]; .gap_id as $gap_id | ($refs | index($gap_id)) != null)))' "$TEMPLATE"

assert_jq '.allOf[1].properties.review_conclusion.required | index("reviewer_verdicts") != null' "$SCHEMA"
for field in perspective verdict issue_count review_round evidence; do
  assert_jq "$reviewer_verdict_required | index(\"$field\") != null" "$SCHEMA"
done
assert_jq '(.review_conclusion.reviewer_verdicts | length) >= 3' "$TEMPLATE"
assert_jq '[.review_conclusion.reviewer_verdicts[].perspective] | index("test_quality") != null and index("product") != null and index("architecture") != null' "$TEMPLATE"

assert_jq '.ac_coverage_matrix[0].positive_case_refs[0] as $ref | any(.test_cases[]; .case_id == $ref and .case_type == "positive")' "$TEMPLATE"
assert_jq '.ac_coverage_matrix[0].negative_case_refs[0] as $ref | any(.test_cases[]; .case_id == $ref and .case_type == "negative")' "$TEMPLATE"
assert_jq '.ac_coverage_matrix[0].boundary_case_refs[0] as $ref | any(.test_cases[]; .case_id == $ref and .case_type == "boundary")' "$TEMPLATE"

printf '[PASS] test-design governance contract\n'
