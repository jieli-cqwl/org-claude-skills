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

if failures:
    raise SystemExit("\n".join(failures))
PY

echo "[PASS] design minimal field contract"
