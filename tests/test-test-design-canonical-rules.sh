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
                "required_artifact_ref": "phase-prd.json#exit_conditions[0]",
                "decision_needed": False,
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
                "required_artifact_ref": "phase-prd.json#exit_conditions[0]",
                "decision_needed": True,
                "blocking": True,
            }
        ],
    }
elif mutation == "invalid-cross-unit":
    data["cross_unit_obligations"][0]["composition_status"] = "UNKNOWN"
elif mutation == "coverage-type-mismatch":
    data["ac_coverage_matrix"][0]["negative_case_refs"] = [
        data["ac_coverage_matrix"][0]["positive_case_refs"][0]
    ]
elif mutation == "unknown-ac-coverage-id":
    data["ac_coverage_matrix"][0]["ac_id"] = "AC-DOES-NOT-EXIST"
elif mutation == "missing-reviewer-verdicts":
    data["review_conclusion"].pop("reviewer_verdicts", None)
elif mutation == "reviewer-fail-verdict":
    data["review_conclusion"]["reviewer_verdicts"][0]["verdict"] = "FAIL"
elif mutation == "reviewer-warn-aggregate-mismatch":
    data["review_conclusion"]["reviewer_verdicts"][0]["verdict"] = "WARN"
elif mutation == "unknown-handoff-obligation":
    data["cross_unit_obligations"][0]["handoff_obligation_refs"] = [
        "NOT_A_REAL_QA_OBLIGATION"
    ]
elif mutation == "missing-special-trigger":
    data["special_test_triggers"] = []
elif mutation == "orphan-test-case":
    orphan_id = data["traceability_matrix"][0]["test_case_refs"].pop()
    assert orphan_id in {case["case_id"] for case in data["test_cases"]}
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
  invalid-cross-unit \
  coverage-type-mismatch \
  unknown-ac-coverage-id \
  missing-reviewer-verdicts \
  reviewer-fail-verdict \
  reviewer-warn-aggregate-mismatch \
  unknown-handoff-obligation \
  missing-special-trigger \
  orphan-test-case; do
  phase_dir="$(make_phase "$mutation")"
  mutate_test_cases "$phase_dir" "$mutation"
  case "$mutation" in
    unresolved-product-ref) expected='product_refs|source ref|does not resolve' ;;
    unresolved-analysis-ref) expected='risk_ref|source ref|does not resolve' ;;
    shallow-case) expected='expected_result' ;;
    unknown-gap-type) expected='gap_type|UNKNOWN_GAP' ;;
    blocking-gap) expected='blocking gap|blocking=true' ;;
    invalid-cross-unit) expected='composition_status|UNKNOWN' ;;
    coverage-type-mismatch) expected='negative_case_refs|negative cases' ;;
    unknown-ac-coverage-id) expected='ac_coverage_matrix.*ac_id|unknown' ;;
    missing-reviewer-verdicts) expected='reviewer_verdicts' ;;
    reviewer-fail-verdict) expected='reviewer_verdicts.*FAIL|unresolved FAIL' ;;
    reviewer-warn-aggregate-mismatch) expected='WARN verdicts require aggregate WARN' ;;
    unknown-handoff-obligation) expected='handoff_obligation_refs|unknown refs' ;;
    missing-special-trigger) expected='special_test_triggers source refs' ;;
    orphan-test-case) expected='traceability_matrix must reference every test_cases' ;;
  esac
  assert_fail "$mutation" "$phase_dir" "$expected"
done

printf '[PASS] test-design canonical rules\n'
