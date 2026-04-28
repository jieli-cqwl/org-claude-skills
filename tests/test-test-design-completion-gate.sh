#!/usr/bin/env bash
# Verify the runtime completion gate rejects incomplete test-design artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_FEATURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
CHECK="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

prepare_workspace() {
  local name="$1"
  local workspace="$TMP_DIR/$name"
  mkdir -p "$workspace/docs"
  cp -R "$BASE_FEATURE" "$workspace/docs/sample-feature"
  python3 - "$workspace/docs/sample-feature/phase-1/unit-1/test-cases.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["authoritative_fields"] = [
    "$.test_analysis",
    "$.traceability_matrix",
    "$.ac_coverage_matrix",
    "$.equivalence_matrix",
    "$.test_cases",
    "$.qa_handoff_contract",
    "$.unit_coverage_view",
    "$.design_gap_report",
    "$.cross_unit_obligations",
    "$.special_test_triggers",
    "$.review_conclusion",
    "$.issue_ledger",
]
data["test_analysis"] = {
    "objectives": [
        "prove product acceptance and design verification obligations before implementation"
    ],
    "in_scope": [
        "UNIT-1 acceptance criteria",
        "design verification mapping",
        "QA handoff obligations",
    ],
    "out_of_scope": [
        "release sign-off",
    ],
    "risk_model": [
        {
            "risk_ref": "design.json#risks[0].risk_id",
            "risk_type": "handoff-drift",
            "test_depth": "positive, negative, boundary, and QA handoff coverage",
        }
    ],
    "strategy_by_quality_area": [
        {
            "quality_area": "functional-correctness",
            "strategy": "derive cases from product and architecture design refs",
        }
    ],
    "test_flow": [
        {
            "checkpoint_id": "FLOW-1",
            "source_refs": [
                "brief.json#business_goals[0]",
                "phase-prd.json#exit_conditions[0]",
                "UNIT-1.json#acceptance_criteria[0].ac_id",
                "design.json#verification_mapping[0].manager_vp_ref",
            ],
            "expected_checkpoint": "canonical runtime contracts validate before handoff",
        }
    ],
    "environment_assumptions": [
        "canonical validators run from the repository root",
    ],
    "data_assumptions": [
        "golden phase fixture contains stable product and design refs",
    ],
}
data["traceability_matrix"] = [
    {
        "product_ref": "brief.json#business_goals[0]",
        "unit_ref": "UNIT-1.json#unit_id",
        "ac_ref": "UNIT-1.json#acceptance_criteria[0].ac_id",
        "design_ref": "design.json#verification_mapping[0].manager_vp_ref",
        "test_case_refs": [
            "TC-T1-1",
            "TC-T2-1",
        ],
        "gap_refs": [],
    }
]
for row in data["test_cases"]:
    row.update(
        {
            "product_refs": [
                "UNIT-1.json#acceptance_criteria[0].ac_id",
                "phase-prd.json#exit_conditions[0]",
            ],
            "design_refs": [
                "design.json#verification_mapping[0].manager_vp_ref",
            ],
            "case_type": "positive",
            "priority": "P1",
            "preconditions": [
                "canonical artifacts are present",
            ],
            "test_data": [
                "golden phase fixture",
            ],
            "steps": [
                "run canonical rule validation",
                "inspect the phase validation result",
            ],
            "expected_result": "phase validation passes without unresolved refs",
            "assertion_target": "canonical rule validator exits zero",
            "execution_mode": "non_browser_ok",
            "automation_level": "automatable",
            "evidence_expectation": "validate_canonical_rules.py output",
            "owner_stage": "developer",
        }
    )
data["design_gap_report"] = {
    "status": "NO_GAPS",
    "gaps": [],
}
data["cross_unit_obligations"] = [
    {
        "journey_id": "J-RUNTIME-CONTROL",
        "journey_title": "runtime control validation journey",
        "participant_unit_refs": [
            "UNIT-1.json#unit_id",
        ],
        "local_unit_ref": "UNIT-1.json#unit_id",
        "sequence_index": 0,
        "predecessor_case_refs": [],
        "successor_case_refs": [],
        "handoff_obligation_refs": [
            "QA_A",
        ],
        "composition_status": "COMPOSABLE",
        "gap_refs": [],
    }
]
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$workspace"
}

mutate_test_cases() {
  local workspace="$1"
  local mutation="$2"
  python3 - "$workspace/docs/sample-feature/phase-1/unit-1/test-cases.json" "$mutation" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mutation = sys.argv[2]
data = json.loads(path.read_text(encoding="utf-8"))

if mutation == "missing-analysis":
    data.pop("test_analysis", None)
elif mutation == "missing-product-refs":
    data["test_cases"][0].pop("product_refs", None)
elif mutation == "missing-assertion":
    data["test_cases"][0].pop("assertion_target", None)
elif mutation == "bad-qa-stage":
    data["qa_handoff_contract"][0]["qa_stage"] = "QA_X"
elif mutation == "unknown-gap-type":
    data["design_gap_report"] = {
        "status": "HAS_GAPS",
        "gaps": [
            {
                "gap_id": "GAP-1",
                "gap_type": "UNKNOWN_GAP",
                "blocking_refs": [
                    "UNIT-1.json#acceptance_criteria[0].ac_id"
                ],
                "owner": "product-manager",
                "next_action": "clarify acceptance criteria",
                "blocking": False,
            }
        ],
    }
elif mutation == "blocking-gap":
    data["design_gap_report"] = {
        "status": "HAS_GAPS",
        "gaps": [
            {
                "gap_id": "GAP-1",
                "gap_type": "PRODUCT_GAP",
                "blocking_refs": [
                    "UNIT-1.json#acceptance_criteria[0].ac_id"
                ],
                "owner": "product-manager",
                "next_action": "clarify acceptance criteria",
                "blocking": True,
            }
        ],
    }
elif mutation == "unresolved-ref":
    data["test_cases"][0]["product_refs"] = [
        "UNIT-1.json#acceptance_criteria[99].ac_id"
    ]
elif mutation == "invalid-cross-unit":
    data["cross_unit_obligations"][0]["composition_status"] = "UNKNOWN"
else:
    raise SystemExit(f"unknown mutation: {mutation}")

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

run_hook() {
  local workspace="$1"
  local transcript_path="$workspace/transcript.log"
  local payload

  printf '%s\n' "docs/sample-feature/phase-1/unit-1/test-cases.json" > "$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "test-design-completion-$RANDOM" \
    --arg tp "$transcript_path" \
    --arg fp "docs/sample-feature/phase-1/unit-1/test-cases.json" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"
  if (cd "$workspace" && bash "$CHECK" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    printf '0\n' > "$workspace/hook.status"
  else
    printf '%s\n' "$?" > "$workspace/hook.status"
  fi
}

assert_allow() {
  local workspace="$1"
  run_hook "$workspace"
  if [ "$(cat "$workspace/hook.status")" != "0" ] \
    || ! jq -e '.decision == "allow"' "$workspace/hook.stdout" >/dev/null 2>&1; then
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "completion gate should allow valid test-cases.json"
  fi
}

assert_block() {
  local mutation="$1"
  local expected="$2"
  local workspace

  workspace="$(prepare_workspace "$mutation")"
  mutate_test_cases "$workspace" "$mutation"
  run_hook "$workspace"
  if [ "$(cat "$workspace/hook.status")" = "0" ]; then
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "completion gate should block: $mutation"
  fi
  jq -e '.decision == "block"' "$workspace/hook.stdout" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "completion gate should emit block decision: $mutation"
  }
  grep -Eq "$expected" "$workspace/hook.stdout" "$workspace/hook.stderr" || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "completion gate block should mention $expected for $mutation"
  }
}

assert_allow "$(prepare_workspace valid)"

assert_block missing-analysis 'test_analysis|canonical'
assert_block missing-product-refs 'product_refs|canonical'
assert_block missing-assertion 'assertion_target|canonical'
assert_block bad-qa-stage 'qa_stage|QA_X|canonical'
assert_block unknown-gap-type 'gap_type|UNKNOWN_GAP|canonical'
assert_block blocking-gap 'blocking test-design gaps|blocking=true'
assert_block unresolved-ref 'source ref|does not resolve|canonical'
assert_block invalid-cross-unit 'composition_status|UNKNOWN|canonical'

printf '[PASS] test-design completion gate\n'
