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
elif mutation == "unresolved-ref":
    data["test_cases"][0]["product_refs"] = [
        "UNIT-1.json#acceptance_criteria[99].ac_id"
    ]
elif mutation == "invalid-cross-unit":
    data["cross_unit_obligations"][0]["composition_status"] = "UNKNOWN"
elif mutation == "coverage-type-mismatch":
    data["ac_coverage_matrix"][0]["negative_case_refs"] = [
        data["ac_coverage_matrix"][0]["positive_case_refs"][0]
    ]
elif mutation == "missing-reviewer-verdicts":
    data["review_conclusion"].pop("reviewer_verdicts", None)
elif mutation == "reviewer-fail-verdict":
    data["review_conclusion"]["reviewer_verdicts"][0]["verdict"] = "FAIL"
elif mutation == "reviewer-warn-aggregate-mismatch":
    data["review_conclusion"]["reviewer_verdicts"][0]["verdict"] = "WARN"
elif mutation == "review-digest-mismatch":
    data["review_conclusion"]["reviewed_test_cases_digest"] = "sha256:" + "0" * 64
    for reviewer in data["review_conclusion"]["reviewer_verdicts"]:
        reviewer["reviewed_test_cases_digest"] = "sha256:" + "1" * 64
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
assert_block coverage-type-mismatch 'negative_case_refs|negative cases|canonical'
assert_block missing-reviewer-verdicts 'reviewer_verdicts|canonical'
assert_block reviewer-fail-verdict 'reviewer_verdicts|FAIL|canonical'
assert_block reviewer-warn-aggregate-mismatch 'WARN verdicts require aggregate WARN|canonical'
assert_block review-digest-mismatch 'reviewed_test_cases_digest|digest|canonical'
assert_block unknown-handoff-obligation 'handoff_obligation_refs|unknown refs|canonical'
assert_block missing-special-trigger 'special_test_triggers source refs|canonical'
assert_block orphan-test-case 'traceability_matrix must reference every test_cases|canonical'

printf '[PASS] test-design completion gate\n'
