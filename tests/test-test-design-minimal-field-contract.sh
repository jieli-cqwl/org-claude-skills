#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" <<'PY' || fail "test-design minimal field contract drift"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
schema = json.loads(
    (root / "shared/skills/test-design/contracts/test-cases.schema.json").read_text(encoding="utf-8")
)
props = schema["allOf"][1]["properties"]
top_level = schema["allOf"][1]
failures: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


handoff = props["qa_handoff_contract"]["items"]
for field in ("test_obligation", "trigger_source", "skip_rule", "evidence_expectation"):
    require(field not in handoff["required"], f"qa_handoff_contract must not require {field}")
    require(field not in handoff["properties"], f"qa_handoff_contract must not define {field}")
require(
    {"obligation_type", "trigger_refs", "skip_policy", "evidence_contract_ref"} <= set(handoff["required"]),
    "qa_handoff_contract must require typed obligation, trigger, skip, and evidence fields",
)

analysis = props["test_analysis"]
for field in ("objectives", "in_scope", "out_of_scope", "environment_assumptions", "data_assumptions"):
    require(field not in analysis["required"], f"test_analysis must not require {field}")
    require(field not in analysis["properties"], f"test_analysis must not define {field}")
require(
    set(analysis["required"]) == {"risk_model", "strategy_by_quality_area", "test_flow"},
    "test_analysis must require only structured risk, quality, and flow fields",
)
require(
    set(analysis["properties"]) == {"risk_model", "strategy_by_quality_area", "test_flow"},
    "test_analysis must define only structured risk, quality, and flow fields",
)

gap = props["design_gap_report"]["properties"]["gaps"]["items"]
require("next_action" not in gap["required"], "design_gap_report gaps must not require next_action")
require("next_action" not in gap["properties"], "design_gap_report gaps must not define next_action")
require(
    {"required_artifact_ref", "decision_needed"} <= set(gap["required"]),
    "design_gap_report gaps must require required_artifact_ref and decision_needed",
)

trigger = props["special_test_triggers"]["items"]
require("condition" not in trigger["required"], "special_test_triggers must not require condition")
require("condition" not in trigger["properties"], "special_test_triggers must not define condition")
require(
    {"trigger_rule", "threshold_ref"} <= set(trigger["required"]),
    "special_test_triggers must require trigger_rule and threshold_ref",
)

review = props["review_conclusion"]
require("summary" not in review["required"], "review_conclusion must not require summary")
require("summary" not in review["properties"], "review_conclusion must not define summary")
require("closure_status" in review["required"], "review_conclusion must require closure_status")

reviewer = review["properties"]["reviewer_verdicts"]["items"]
require("evidence" not in reviewer["required"], "reviewer_verdicts must not require evidence prose")
require("evidence" not in reviewer["properties"], "reviewer_verdicts must not define evidence prose")
require("evidence_refs" in reviewer["required"], "reviewer_verdicts must require evidence_refs")

convergence = review["properties"]["convergence_evidence"]["items"]
require("evidence" not in convergence["required"], "convergence_evidence must not require evidence prose")
require("evidence" not in convergence["properties"], "convergence_evidence must not define evidence prose")
require("evidence_refs" in convergence["required"], "convergence_evidence must require evidence_refs")

issue = props["issue_ledger"]["items"]
for field in ("evidence", "handling_record"):
    require(field not in issue.get("required", []), f"issue_ledger must not require {field}")
    require(field not in issue.get("properties", {}), f"issue_ledger must not define {field}")
require(
    {"evidence_refs", "handling_action"} <= set(issue.get("required", [])),
    "issue_ledger must require evidence_refs and handling_action",
)

for field in ("equivalence_matrix", "unit_coverage_view"):
    require(field not in props, f"test-cases schema must not define derived field {field}")
    require(
        field not in schema["allOf"][1]["required"],
        f"test-cases schema must not require derived field {field}",
    )
denylisted_top_level = set()
for rule in top_level.get("not", {}).get("anyOf", []):
    required = rule.get("required")
    if isinstance(required, list) and len(required) == 1:
        denylisted_top_level.add(required[0])
for field in ("test_obligations", "equivalence_matrix", "unit_coverage_view", "acceptance_summary"):
    require(
        field in denylisted_top_level,
        f"test-cases schema must explicitly reject removed top-level field {field}",
    )

coverage = props["ac_coverage_matrix"]["items"]
require("covers" not in coverage["required"], "ac_coverage_matrix must not require covers prose")
require("covers" not in coverage["properties"], "ac_coverage_matrix must not define covers prose")

cross_unit = props["cross_unit_obligations"]["items"]
require("journey_title" not in cross_unit["required"], "cross_unit_obligations must not require journey_title prose")
require("journey_title" not in cross_unit["properties"], "cross_unit_obligations must not define journey_title prose")

template = json.loads(
    (root / "shared/skills/test-design/templates/test-cases.template.json").read_text(encoding="utf-8")
)
template_analysis = template.get("test_analysis", {})
for field in ("objectives", "in_scope", "out_of_scope", "environment_assumptions", "data_assumptions"):
    require(field not in template_analysis, f"test-cases template test_analysis must not include {field}")
for field in ("equivalence_matrix", "unit_coverage_view"):
    require(field not in template, f"test-cases template must not include derived field {field}")
    require(f"$.{field}" not in template.get("authoritative_fields", []), f"test-cases template authoritative_fields must not include {field}")
for index, row in enumerate(template.get("ac_coverage_matrix", [])):
    require("covers" not in row, f"test-cases template ac_coverage_matrix[{index}] must not include covers")
for index, row in enumerate(template.get("cross_unit_obligations", [])):
    require("journey_title" not in row, f"test-cases template cross_unit_obligations[{index}] must not include journey_title")
for index, row in enumerate(template.get("traceability_matrix", [])):
    require(
        "acceptance_summary" not in row.get("product_ref", ""),
        f"test-cases template traceability_matrix[{index}].product_ref must not point at removed acceptance_summary",
    )

for source_root in (
    root / "tests/fixtures/standard-chain-foundation",
    root / "tests/fixtures/standard-chain-pilots",
    root / "tests/fixtures/developer-runtime-layering",
):
    for path in sorted(source_root.rglob("test-cases.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        analysis_payload = payload.get("test_analysis", {})
        for field in ("objectives", "in_scope", "out_of_scope", "environment_assumptions", "data_assumptions"):
            require(
                field not in analysis_payload,
                f"{path.relative_to(root)} test_analysis must not include {field}",
            )
        for field in ("equivalence_matrix", "unit_coverage_view"):
            require(field not in payload, f"{path.relative_to(root)} must not include derived field {field}")
        for index, row in enumerate(payload.get("ac_coverage_matrix", [])):
            require("covers" not in row, f"{path.relative_to(root)} ac_coverage_matrix[{index}] must not include covers")
        for index, row in enumerate(payload.get("cross_unit_obligations", [])):
            require("journey_title" not in row, f"{path.relative_to(root)} cross_unit_obligations[{index}] must not include journey_title")
        for index, row in enumerate(payload.get("traceability_matrix", [])):
            require(
                "acceptance_summary" not in row.get("product_ref", ""),
                f"{path.relative_to(root)} traceability_matrix[{index}].product_ref must not point at removed acceptance_summary",
            )

for path in (
    root / "tools/community/canonical_test_case_semantic_rules.py",
    root / "shared/skills/test-design/projections/test-cases-template.md",
    root / "contracts/standard-chain.yaml",
    root / "contracts/standard-chain-field-consumption.yaml",
    root / "tools/eval/scripts/validate_stage2_test_design_materials.py",
):
    text = path.read_text(encoding="utf-8")
    for field in (
        "test_analysis.objectives",
        "test_analysis.in_scope",
        "test_analysis.out_of_scope",
        "test_analysis.environment_assumptions",
        "test_analysis.data_assumptions",
        "equivalence_matrix",
        "unit_coverage_view",
        "journey_title",
        "acceptance_summary",
    ):
        require(field not in text, f"{path.relative_to(root)} must not mention removed field {field}")

if failures:
    raise SystemExit("\n".join(failures))
PY

echo "[PASS] test-design minimal field contract"
