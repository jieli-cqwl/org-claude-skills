#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

CASES="$ROOT/tests/fixtures/standard-chain-harness/interaction-eval/cases.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CASES" ] || fail "missing standard-chain interaction eval cases fixture"
jq -e '
  def required_ids:
    [
      "SC-INT-PD-001",
      "SC-INT-PD-002",
      "SC-INT-PD-003",
      "SC-INT-PD-004",
      "SC-INT-PD-005",
      "SC-INT-PD-006",
      "SC-INT-PM-001",
      "SC-INT-DES-001",
      "SC-INT-TD-001",
      "SC-INT-TL-001",
      "SC-INT-DO-001",
      "SC-INT-DEV-001",
      "SC-INT-REV-001",
      "SC-INT-VER-001",
      "SC-INT-QA-001"
    ];
  def required_roles:
    ["product-director", "product-manager", "design", "test-design", "tech-lead", "developer", "review", "verify", "qa", "delivery-owner"];
  def dimension_whitelist:
    [
      "fact_sufficiency",
      "user_correction",
      "candidate_vs_confirmed_state",
      "stage_backtracking",
      "role_boundary",
      "scope_control",
      "downstream_handoff",
      "evidence_freshness",
      "process_lightness",
      "eval_validity"
    ];
  def status_whitelist:
    ["planned", "covered"];
  def owner_whitelist:
    ["skill", "reference", "schema", "script", "test", "human"];
  def non_empty_strings:
    type == "array" and length > 0 and all(.[]; type == "string" and length > 0);
  . as $root
  | .schema_version == "0.1.0"
  and .chain_version == "standard-chain/v1"
  and (has("source_report_ref") | not)
  and (.cases | type == "array" and length == 15)
  and ([.cases[].id] | sort == (required_ids | sort))
  and (([.cases[].id] | unique | length) == (.cases | length))
  and all(required_roles[]; . as $role | any($root.cases[]; .roles | index($role) != null))
  and all(.cases[]; .roles | non_empty_strings)
  and all(.cases[]; .interaction_turns | type == "array" and length >= 2)
  and all(.cases[]; .dimension_refs | non_empty_strings)
  and all(.cases[]; all(.dimension_refs[]; . as $dimension | dimension_whitelist | index($dimension) != null))
  and all(.cases[]; .failure_mode | type == "string" and length > 0)
  and all(.cases[]; .expected_behavior | type == "string" and length > 0)
  and all(.cases[]; .forbidden_behavior | type == "string" and length > 0)
  and all(.cases[]; .observable_signals | non_empty_strings)
  and all(.cases[]; .regression_targets | non_empty_strings)
  and all(.cases[]; (.evidence_eval_ids? // []) | all(.[]; type == "string" and length > 0))
  and all(.cases[];
    if .automation_status == "covered" and any(.evidence_refs[]?; endswith("summary.json"))
    then (.evidence_eval_ids? | non_empty_strings)
    else true
    end
  )
  and all(.cases[]; .automation_status as $status | status_whitelist | index($status) != null)
  and all(.cases[]; .automation_status == "covered")
  and all(.cases[]; .owner_action as $owner | owner_whitelist | index($owner) != null)
  and any(.cases[]; .id == "SC-INT-PD-002" and (.dimension_refs | index("user_correction") != null) and (.dimension_refs | index("stage_backtracking") != null))
  and any(.cases[]; .id == "SC-INT-DO-001" and (.dimension_refs | index("evidence_freshness") != null))
  and any(.cases[]; .id == "SC-INT-QA-001" and (.dimension_refs | index("evidence_freshness") != null))
  and any(.cases[]; .id == "SC-INT-PD-003" and (.dimension_refs | index("process_lightness") != null))
  and any(.cases[]; .id == "SC-INT-PD-005" and (.evidence_eval_ids // []) == ["success-gap-stays-in-success-stage", "target-metrics-gap-blocks-direct-recommendation"])
  and any(.cases[]; .id == "SC-INT-PD-006" and (.evidence_eval_ids // []) == ["fully-closed-facts-asks-confirmation"])
' "$CASES" >/dev/null || fail "interaction eval cases fixture should cover multi-turn role behavior"

while IFS= read -r path_ref; do
  [ -e "$ROOT/$path_ref" ] || fail "interaction eval path ref does not exist: $path_ref"
done < <(
  jq -r '
    .cases[]
    | (.regression_targets[]?, .evidence_refs[]?)
    | select(startswith("tests/") or startswith("tools/") or startswith("docs/") or startswith("contracts/") or startswith("shared/"))
  ' "$CASES" | sort -u
)

python3 - "$ROOT" "$CASES" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
cases_path = Path(sys.argv[2])
data = json.loads(cases_path.read_text(encoding="utf-8"))

for case in data["cases"]:
    if case["automation_status"] != "covered":
        continue
    evidence_eval_ids = case.get("evidence_eval_ids", [])
    passing_summaries = []
    matching_summaries = []
    for ref in case.get("evidence_refs", []):
        if not ref.endswith("summary.json"):
            continue
        summary_path = root / ref
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        status = summary.get("summary", {})
        anchor_failed = sum(
            run.get("anchor_failed", 0)
            for run in summary.get("runs", [])
            if isinstance(run, dict)
        )
        if (
            status.get("infra_failures") == 0
            and status.get("failed_expectations") == 0
            and status.get("pass_rate") == 1.0
            and anchor_failed == 0
        ):
            passing_summaries.append(ref)
            runs_by_eval_id = {
                run.get("eval_id"): run
                for run in summary.get("runs", [])
                if isinstance(run, dict)
            }
            all_target_runs_pass = True
            for eval_id in evidence_eval_ids:
                run = runs_by_eval_id.get(eval_id)
                if not run:
                    all_target_runs_pass = False
                    break
                if (
                    run.get("status") != "graded"
                    or run.get("failed") != 0
                    or run.get("pass_rate") != 1.0
                    or run.get("anchor_failed", 0) != 0
                    or run.get("anchor_total", 0) <= 0
                ):
                    all_target_runs_pass = False
                    break
            if all_target_runs_pass:
                matching_summaries.append(ref)
    if not passing_summaries:
        raise SystemExit(
            f"covered interaction case {case['id']} must reference at least one passing summary.json"
        )
    if evidence_eval_ids and not matching_summaries:
        joined = ", ".join(evidence_eval_ids)
        raise SystemExit(
            f"covered interaction case {case['id']} must reference a passing summary.json with eval ids: {joined}"
        )
PY

printf '[PASS] standard-chain interaction eval\n'
