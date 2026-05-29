#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" <<'PY' || fail "design minimal field contract drift"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
schema = json.loads(
    (root / "shared/skills/design/contracts/design.schema.json").read_text(encoding="utf-8")
)
props = schema["allOf"][1]["properties"]
failures: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def item(name: str) -> dict:
    return props[name]["items"]


decision = item("key_decisions")
for field in ("summary", "verdict", "user_confirmation"):
    require(field not in decision["required"], f"key_decisions must not require {field} prose")
    require(field not in decision["properties"], f"key_decisions must not define {field} prose")
require(
    {"decision_id", "decision_state", "option_ref", "fact_refs"} <= set(decision["required"]),
    "key_decisions must require structural decision fields",
)
require(
    decision.get("additionalProperties") is False,
    "key_decisions must reject undeclared prose fields",
)

co_creation = item("co_creation_summary")
for field in ("stage_name", "question_or_focus", "user_response_summary"):
    require(field not in co_creation["required"], f"co_creation_summary must not require {field}")
    require(field not in co_creation["properties"], f"co_creation_summary must not define {field}")
require(
    {"stage_id", "confirmation_status", "decision_refs", "evidence_refs"} <= set(co_creation["required"]),
    "co_creation_summary must require stage_id, confirmation_status, decision_refs, evidence_refs",
)

option = item("option_analysis")
for field in ("summary", "tradeoff", "verdict"):
    require(field not in option["required"], f"option_analysis must not require {field}")
    require(field not in option["properties"], f"option_analysis must not define {field}")
require(
    {"option_id", "decision_ref", "decision_status", "evaluation", "fact_refs"} <= set(option["required"]),
    "option_analysis must require typed decision_status and evaluation",
)

interface = item("interfaces")
require("contract_summary" not in interface["required"], "interfaces must not require contract_summary")
require("contract_summary" not in interface["properties"], "interfaces must not define contract_summary")
behavior = interface["properties"]["boundary_behaviors"]["items"]
for field in ("scenario", "expected_behavior"):
    require(field not in behavior["required"], f"boundary_behaviors must not require {field}")
    require(field not in behavior["properties"], f"boundary_behaviors must not define {field}")
require(
    {"behavior_type", "trigger_ref", "expected_outcome", "verification_ref"} <= set(behavior["required"]),
    "boundary_behaviors must require typed behavior fields",
)

quality = item("quality_attributes")
for field in ("key_scenarios", "tradeoff_points"):
    require(field not in quality["required"], f"quality_attributes must not require {field}")
    require(field not in quality["properties"], f"quality_attributes must not define {field}")
require(
    {"attribute", "priority", "scenario_refs", "target_metrics", "verification_refs"} <= set(quality["required"]),
    "quality_attributes must require scenario_refs and typed target_metrics",
)
metric = quality["properties"]["target_metrics"]["items"]
require(
    {"metric_id", "metric_name", "threshold", "unit"} <= set(metric.get("required", [])),
    "quality_attributes.target_metrics must be typed metric objects",
)

concern = item("cross_cutting_concerns")
require("decision" not in concern["required"], "cross_cutting_concerns must not require decision prose")
require("decision" not in concern["properties"], "cross_cutting_concerns must not define decision prose")
require("decision_ref" in concern["required"], "cross_cutting_concerns must require decision_ref")

impact = item("impact_scope")
require("impact" not in impact["required"], "impact_scope must not require impact prose")
require("impact" not in impact["properties"], "impact_scope must not define impact prose")
require(
    {"impact_type", "required_action"} <= set(impact["required"]),
    "impact_scope must require impact_type and required_action",
)

constraint = item("planning_constraints")
require("description" not in constraint["required"], "planning_constraints must not require description prose")
require("description" not in constraint["properties"], "planning_constraints must not define description prose")
require(
    {"constraint_rule", "enforcement_type"} <= set(constraint["required"]),
    "planning_constraints must require constraint_rule and enforcement_type",
)

risk = item("risks")
require("description" not in risk["required"], "risks must not require description prose")
require("description" not in risk["properties"], "risks must not define description prose")
require("risk_type" in risk["required"], "risks must require risk_type")

response = item("risk_response")
require("architecture_response" not in response["required"], "risk_response must not require architecture_response prose")
require("architecture_response" not in response["properties"], "risk_response must not define architecture_response prose")
require("response_type" in response["required"], "risk_response must require response_type")

data_architecture = props["data_architecture"]
require("summary" not in data_architecture["required"], "data_architecture must not require summary prose")
require("summary" not in data_architecture["properties"], "data_architecture must not define summary prose")

final_confirmation = props["final_confirmation"]
require("summary" not in final_confirmation["required"], "final_confirmation must not require summary prose")
require("summary" not in final_confirmation["properties"], "final_confirmation must not define summary prose")

inheritance = props["constraint_inheritance_confirmation"]
require(
    "confirmation_summary" not in inheritance["required"],
    "constraint_inheritance_confirmation must not require confirmation_summary prose",
)
require(
    "confirmation_summary" not in inheritance["properties"],
    "constraint_inheritance_confirmation must not define confirmation_summary prose",
)

warn_followup = props["review_closure"]["properties"]["warn_followups"]["items"]
require(
    "summary" not in warn_followup["required"],
    "review_closure.warn_followups must not require summary prose",
)
require(
    "summary" not in warn_followup["properties"],
    "review_closure.warn_followups must not define summary prose",
)

verification = item("verification_mapping")
for field in ("design_validation", "test_obligation"):
    require(field not in verification["required"], f"verification_mapping must not require {field}")
    require(field not in verification["properties"], f"verification_mapping must not define {field}")
require(
    set(verification["required"]) == {"manager_vp_ref", "evidence_ref"},
    "verification_mapping must require only manager_vp_ref and evidence_ref",
)
require(
    set(verification["properties"]) == {"manager_vp_ref", "evidence_ref"},
    "verification_mapping must define only manager_vp_ref and evidence_ref",
)
require(
    verification.get("additionalProperties") is False,
    "verification_mapping must reject undeclared fields",
)

template = json.loads(
    (root / "shared/skills/design/templates/design.template.json").read_text(encoding="utf-8")
)
for index, row in enumerate(template.get("key_decisions", [])):
    for field in ("summary", "verdict", "user_confirmation"):
        require(field not in row, f"design template key_decisions[{index}] must not include {field}")
require("summary" not in template.get("data_architecture", {}), "design template data_architecture must not include summary")
require("summary" not in template.get("final_confirmation", {}), "design template final_confirmation must not include summary")
require(
    "confirmation_summary" not in template.get("constraint_inheritance_confirmation", {}),
    "design template constraint_inheritance_confirmation must not include confirmation_summary",
)
for index, row in enumerate(template.get("verification_mapping", [])):
    for field in ("design_validation", "test_obligation"):
        require(field not in row, f"design template verification_mapping[{index}] must not include {field}")

for source_root in (
    root / "shared/skills/design",
    root / "tests/fixtures/standard-chain-foundation",
    root / "tests/fixtures/standard-chain-pilots",
):
    for path in sorted(source_root.rglob("design.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        for index, row in enumerate(payload.get("key_decisions", [])):
            for field in ("summary", "verdict", "user_confirmation"):
                require(
                    field not in row,
                    f"{path.relative_to(root)} key_decisions[{index}] must not include {field}",
                )
        require(
            "summary" not in payload.get("data_architecture", {}),
            f"{path.relative_to(root)} data_architecture must not include summary",
        )
        require(
            "summary" not in payload.get("final_confirmation", {}),
            f"{path.relative_to(root)} final_confirmation must not include summary",
        )
        require(
            "confirmation_summary" not in payload.get("constraint_inheritance_confirmation", {}),
            f"{path.relative_to(root)} constraint_inheritance_confirmation must not include confirmation_summary",
        )
        for index, row in enumerate(
            payload.get("review_closure", {}).get("warn_followups", [])
        ):
            require(
                "summary" not in row,
                f"{path.relative_to(root)} review_closure.warn_followups[{index}] must not include summary",
            )
        for index, row in enumerate(payload.get("verification_mapping", [])):
            for field in ("design_validation", "test_obligation"):
                require(
                    field not in row,
                    f"{path.relative_to(root)} verification_mapping[{index}] must not include {field}",
                )

for path in (
    root / "tools/community/canonical_design_trace_rules.py",
    root / "tools/community/canonical_design_errors.py",
    root / "tools/community/canonical_design_rules.py",
    root / "tools/community/canonical_design_confirmation_rules.py",
    root / "tools/eval/scripts/validate_stage2_design_materials_builder.py",
    root / "shared/skills/design/references/canonical-ref-cheatsheet.md",
    root / "shared/skills/design/scripts/render_projection.py",
):
    text = path.read_text(encoding="utf-8")
    for field in ("design_validation", "test_obligation"):
        require(field not in text, f"{path.relative_to(root)} must not mention removed design field {field}")
    for field in (
        "data_architecture.summary",
        "final_confirmation.summary",
        "constraint_inheritance_confirmation.confirmation_summary",
        'decision.get("summary")',
    ):
        require(field not in text, f"{path.relative_to(root)} must not mention removed design summary field {field}")

if failures:
    raise SystemExit("\n".join(failures))
PY

echo "[PASS] design minimal field contract"
