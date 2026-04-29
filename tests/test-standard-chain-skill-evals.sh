#!/usr/bin/env bash
# 文件职责：验证 standard-chain main skill 均沉淀 skill-creator 风格本地 eval。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHAIN="$ROOT/contracts/standard-chain.yaml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

read_standard_chain_skills() {
  awk '
    /^  - name: / { name=$3 }
    /position: main/ { print name }
  ' "$CHAIN"
}

test -f "$CHAIN" || fail "missing standard-chain contract: $CHAIN"

STANDARD_CHAIN_SKILLS=()
while IFS= read -r skill; do
  STANDARD_CHAIN_SKILLS+=("$skill")
done < <(read_standard_chain_skills)

[ "${#STANDARD_CHAIN_SKILLS[@]}" -eq 10 ] || fail "expected 10 standard-chain main skills, got ${#STANDARD_CHAIN_SKILLS[@]}: ${STANDARD_CHAIN_SKILLS[*]}"

for skill in "${STANDARD_CHAIN_SKILLS[@]}"; do
  eval_file="$ROOT/shared/skills/$skill/evals/evals.json"
  test -f "$eval_file" || fail "missing skill-creator evals for standard-chain skill: $eval_file"

  python3 - "$skill" "$eval_file" <<'PY'
import json
import sys
from pathlib import Path

skill_name = sys.argv[1]
path = Path(sys.argv[2])
root = path.parents[4]
skill_root = path.parents[1]

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    raise SystemExit(f"{path}: invalid JSON: {exc}") from exc

if data.get("skill_name") != skill_name:
    raise SystemExit(f"{path}: skill_name must be {skill_name!r}")

evals = data.get("evals")
if not isinstance(evals, list) or len(evals) < 3:
    raise SystemExit(f"{path}: expected at least 3 eval cases")

seen_ids = set()
for index, case in enumerate(evals, start=1):
    if not isinstance(case, dict):
        raise SystemExit(f"{path}: eval #{index} must be an object")

    case_id = case.get("id")
    if not isinstance(case_id, (int, str)) or (isinstance(case_id, str) and not case_id.strip()):
        raise SystemExit(f"{path}: eval #{index} must have a non-empty string or integer id")
    if case_id in seen_ids:
        raise SystemExit(f"{path}: duplicate eval id {case_id!r}")
    seen_ids.add(case_id)

    for field in ("prompt", "expected_output"):
        value = case.get(field)
        if not isinstance(value, str) or not value.strip():
            raise SystemExit(f"{path}: eval {case_id!r} missing non-empty {field}")

    files = case.get("files")
    if not isinstance(files, list):
        raise SystemExit(f"{path}: eval {case_id!r} files must be a list")
    for file_ref in files:
        if not isinstance(file_ref, str) or not file_ref.strip():
            raise SystemExit(f"{path}: eval {case_id!r} contains an empty file ref")
        if Path(file_ref).is_absolute():
            raise SystemExit(f"{path}: eval {case_id!r} file ref must be relative: {file_ref}")
        candidates = [skill_root / file_ref, root / file_ref]
        if not any(candidate.exists() for candidate in candidates):
            raise SystemExit(f"{path}: eval {case_id!r} file ref does not exist: {file_ref}")

    expectations = case.get("expectations")
    if not isinstance(expectations, list) or not expectations:
        raise SystemExit(f"{path}: eval {case_id!r} expectations must be a non-empty list")
    for expectation in expectations:
        if not isinstance(expectation, str) or not expectation.strip():
            raise SystemExit(f"{path}: eval {case_id!r} contains an empty expectation")
PY
done

python3 - "$ROOT/shared/skills/test-design/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))

required_eval_ids = {
    "product-ambiguity-produces-product-gap",
    "design-gap-data-architecture-blocks-handoff",
    "scope-drift-exclusion-case-blocks",
    "product-design-conflict-produces-trace-conflict",
    "untestable-ac-produces-testability-gap",
    "qa-handoff-browser-required",
    "cross-unit-composition-obligation",
    "special-trigger-source-ref-contract",
    "three-view-reviewer-verdict-contract",
}
actual_eval_ids = {case.get("id") for case in data.get("evals", [])}
missing_eval_ids = sorted(required_eval_ids - actual_eval_ids)
if missing_eval_ids:
    raise SystemExit(f"{path}: missing test-design governance evals {missing_eval_ids}")

required_anchor_terms = {
    "产品是一等真源",
    "typed gap",
    "assertion_target",
    "QA handoff",
    "cross_unit_obligations",
    "browser_required",
    "不执行 QA",
    "special_test_triggers",
    "obligation_id",
    "reviewer_verdicts",
}
anchor_text = "\n".join(anchor.get("anchor", "") for anchor in data.get("preference_anchors", []))
missing_anchor_terms = sorted(term for term in required_anchor_terms if term not in anchor_text)
if missing_anchor_terms:
    raise SystemExit(f"{path}: missing test-design preference anchor terms {missing_anchor_terms}")

expected_dimensions = {
    "role_boundary",
    "product_first_traceability",
    "executable_assertions",
    "typed_gap_detection",
    "browser_required_handoff",
    "cross_unit_composition",
    "special_trigger_coverage",
    "reviewer_verdict_convergence",
}
dimensions = set(data.get("grader_dimensions", []))
missing_dimensions = sorted(expected_dimensions - dimensions)
if missing_dimensions:
    raise SystemExit(f"{path}: missing test-design grader dimensions {missing_dimensions}")

case_by_id = {case.get("id"): case for case in data.get("evals", [])}
field_expectations = {
    "qa-handoff-browser-required": ["obligation_id", "design_source_refs"],
    "cross-unit-composition-obligation": [
        "journey_title",
        "predecessor_case_refs",
        "successor_case_refs",
        "obligation_id",
    ],
    "special-trigger-source-ref-contract": [
        "special_test_triggers",
        "source_ref",
        "handling",
        "test_case_refs",
        "qa_handoff_obligation_refs",
        "gap_refs",
    ],
    "three-view-reviewer-verdict-contract": [
        "reviewer_verdicts",
        "test_quality",
        "product",
        "architecture",
        "review_round",
        "evidence",
    ],
}
for case_id, required_terms in field_expectations.items():
    case = case_by_id.get(case_id)
    text = "\n".join([case.get("expected_output", ""), *case.get("expectations", [])])
    missing_terms = sorted(term for term in required_terms if term not in text)
    if missing_terms:
        raise SystemExit(f"{path}: eval {case_id!r} missing contract terms {missing_terms}")
PY

python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/community"))
from canonical_test_case_rules import assert_test_cases_contract

feature_dir = root / "tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature"
paths = [
    feature_dir / "brief.json",
    feature_dir / "phase-1/phase-prd.json",
    feature_dir / "phase-1/design.json",
    feature_dir / "phase-1/units/UNIT-1.json",
    feature_dir / "phase-1/unit-1/test-cases.json",
]
artifacts = [json.loads(path.read_text(encoding="utf-8")) for path in paths]
assert_test_cases_contract(artifacts[-1], artifacts)
PY

printf '[PASS] standard-chain skill evals contract\n'
