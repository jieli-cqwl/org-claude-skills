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

if failures:
    raise SystemExit("\n".join(failures))
PY

echo "[PASS] test-design minimal field contract"
