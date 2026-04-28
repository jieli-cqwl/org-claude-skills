#!/usr/bin/env bash
# Verify semantic validation for redesigned test-design canonical artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_FEATURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
VALIDATOR="$ROOT/tools/community/validate_canonical_rules.py"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

make_phase() {
  local name="$1"
  local feature_dir="$TMP_DIR/$name"
  mkdir -p "$feature_dir"
  cp -R "$BASE_FEATURE"/. "$feature_dir"/
  python3 - "$feature_dir/phase-1/unit-1/test-cases.json" <<'PY'
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
  printf '%s\n' "$feature_dir/phase-1"
}

mutate_test_cases() {
  local phase_dir="$1"
  local mutation="$2"
  python3 - "$phase_dir/unit-1/test-cases.json" "$mutation" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mutation = sys.argv[2]
data = json.loads(path.read_text(encoding="utf-8"))

if mutation == "unresolved-product-ref":
    data["test_cases"][0]["product_refs"] = [
        "UNIT-1.json#acceptance_criteria[99].ac_id"
    ]
elif mutation == "unresolved-analysis-ref":
    data["test_analysis"]["risk_model"][0]["risk_ref"] = (
        "brief.json#risks_and_unknowns[99].item"
    )
elif mutation == "shallow-case":
    del data["test_cases"][0]["expected_result"]
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
elif mutation == "invalid-cross-unit":
    data["cross_unit_obligations"][0]["composition_status"] = "UNKNOWN"
else:
    raise SystemExit(f"unknown mutation: {mutation}")

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

assert_pass() {
  local name="$1"
  local phase_dir="$2"
  python3 "$VALIDATOR" --phase-dir "$phase_dir" >/tmp/test_design_rules_"$name".out 2>&1 || {
    cat /tmp/test_design_rules_"$name".out >&2
    fail "$name should pass canonical rule validation"
  }
}

assert_fail() {
  local name="$1"
  local phase_dir="$2"
  local expected="$3"
  if python3 "$VALIDATOR" --phase-dir "$phase_dir" >/tmp/test_design_rules_"$name".out 2>&1; then
    cat /tmp/test_design_rules_"$name".out >&2
    fail "$name should fail canonical rule validation"
  fi
  grep -Eq "$expected" /tmp/test_design_rules_"$name".out || {
    cat /tmp/test_design_rules_"$name".out >&2
    fail "$name failure should mention: $expected"
  }
}

valid_phase="$(make_phase valid)"
assert_pass valid "$valid_phase"

for mutation in \
  unresolved-product-ref \
  unresolved-analysis-ref \
  shallow-case \
  unknown-gap-type \
  blocking-gap \
  invalid-cross-unit; do
  phase_dir="$(make_phase "$mutation")"
  mutate_test_cases "$phase_dir" "$mutation"
  case "$mutation" in
    unresolved-product-ref) expected='product_refs|source ref|does not resolve' ;;
    unresolved-analysis-ref) expected='risk_ref|source ref|does not resolve' ;;
    shallow-case) expected='expected_result' ;;
    unknown-gap-type) expected='gap_type|UNKNOWN_GAP' ;;
    blocking-gap) expected='blocking gap|blocking=true' ;;
    invalid-cross-unit) expected='composition_status|UNKNOWN' ;;
  esac
  assert_fail "$mutation" "$phase_dir" "$expected"
done

printf '[PASS] test-design canonical rules\n'
