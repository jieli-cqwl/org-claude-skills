#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
CASES="$ROOT/tests/fixtures/standard-chain-harness/capability-eval/cases.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CASES" ] || fail "missing harness capability eval cases fixture"
jq -e '
  def required_ids:
    [
      "HC-GATE-001",
      "HC-GATE-002",
      "HC-HANDOFF-001",
      "HC-HANDOFF-002",
      "HC-EVIDENCE-001",
      "HC-CORRECTION-001"
    ];
  def dimension_whitelist:
    [
      "task_specification",
      "context_selection",
      "tool_access",
      "project_memory",
      "task_state",
      "observability",
      "failure_attribution",
      "verification",
      "permissions",
      "entropy_auditing",
      "intervention_recording"
    ];
  def owner_whitelist:
    ["skill", "reference", "schema", "script", "test", "human"];
  def class_whitelist:
    ["guarding", "handoff", "evidence", "correction"];
  def status_whitelist:
    ["covered", "planned"];
  def non_empty_strings:
    type == "array" and length > 0 and all(.[]; type == "string" and length > 0);

  .schema_version == "0.1.0"
  and .chain_version == "standard-chain/v1"
  and (has("source_report_ref") | not)
  and (.cases | type == "array" and length == 6)
  and ([.cases[].id] | sort == (required_ids | sort))
  and (([.cases[].id] | unique | length) == (.cases | length))
  and all(.cases[]; .capability_class as $class | class_whitelist | index($class) != null)
  and all(.cases[]; .automation_status as $status | status_whitelist | index($status) != null)
  and all(.cases[]; .dimension_refs | non_empty_strings)
  and all(.cases[]; all(.dimension_refs[]; . as $dimension | dimension_whitelist | index($dimension) != null))
  and all(.cases[]; .input_refs | non_empty_strings)
  and all(.cases[]; .pass_signals | non_empty_strings)
  and all(.cases[]; .fail_signals | non_empty_strings)
  and all(.cases[]; .owner_action as $owner | owner_whitelist | index($owner) != null)
  and all(.cases[] | select(.automation_status == "covered"); .current_gate_refs | non_empty_strings)
  and all(.cases[] | select(.automation_status == "planned"); .future_fixture_refs | non_empty_strings)
  and any(.cases[]; .id == "HC-GATE-002" and .automation_status == "covered" and (.current_gate_refs | index("tests/test-standard-chain-episode-package.sh") != null))
  and any(.cases[]; .id == "HC-HANDOFF-002" and .automation_status == "covered" and (.current_gate_refs | index("tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json") != null))
  and any(.cases[]; .id == "HC-EVIDENCE-001" and .automation_status == "covered" and (.current_gate_refs | index("tests/test-standard-chain-episode-package.sh") != null))
  and any(.cases[]; .id == "HC-CORRECTION-001" and .automation_status == "planned")
' "$CASES" >/dev/null || fail "capability eval cases fixture should expose the P2 harness test matrix"

while IFS= read -r path_ref; do
  [ -e "$ROOT/$path_ref" ] || fail "capability eval path ref does not exist: $path_ref"
done < <(
  jq -r '
    .cases[]
    | (.input_refs[]?, .current_gate_refs[]?, .future_fixture_refs[]?)
    | select(startswith("tests/") or startswith("tools/") or startswith("docs/") or startswith("contracts/") or startswith("shared/"))
  ' "$CASES" | sort -u
)

printf '[PASS] standard-chain harness capability eval\n'
