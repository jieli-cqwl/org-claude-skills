#!/usr/bin/env bash
set -euo pipefail

# File responsibility: replay the feedback/thanks pilot as a standard-chain
# smoke baseline without depending on human-readable projection files.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHASE_DIR="$ROOT/tests/fixtures/standard-chain-pilots/feedback-thanks-pilot/phase-1"
CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"
PROFILES="$ROOT/shared/runtime/replay-profiles.json"
ORACLE="$PHASE_DIR/replay/phase-operational.replay-oracle.json"

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s "$ROOT/tests" \
  -p "test_feedback_thanks_app.py"

python3 - "$ROOT/tests/test_feedback_thanks_app.py" "$PHASE_DIR/unit-1/test-cases.json" "$PHASE_DIR" <<'PY'
import ast
import json
import sys
from pathlib import Path

case_to_method = {
    "TC-T1-1": "test_root_redirects_to_feedback_form",
    "TC-T1-NEG": "test_blank_submission_returns_readable_validation_error",
    "TC-T1-BND": "test_minimum_blank_field_request_fails_closed_without_creating_feedback",
    "TC-LEN-1": "test_oversized_submission_returns_readable_error",
    "TC-LEN-NEG": "test_negative_content_length_is_rejected_before_body_read",
    "TC-LEN-BND": "test_maximum_body_boundary_submission_redirects_to_thanks_page",
    "TC-T2-1": "test_valid_submission_redirects_to_thanks_page",
    "TC-T2-NEG": "test_missing_feedback_id_returns_readable_not_found",
    "TC-T2-BND": "test_thanks_page_escapes_submitted_feedback",
    "TC-OBS-1": "test_invalid_submission_emits_access_log",
    "TC-OBS-NEG": "test_observability_guard_rejects_missing_invalid_submission_log_evidence",
    "TC-OBS-BND": "test_single_invalid_submission_produces_one_auditable_status_trace",
}
source_text = Path(sys.argv[1]).read_text(encoding="utf-8")
test_source = ast.parse(source_text)
test_cases = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))["test_cases"]
phase_dir = Path(sys.argv[3])
methods = {
    item.name
    for node in test_source.body
    if isinstance(node, ast.ClassDef) and node.name == "FeedbackThanksAcceptanceTests"
    for item in node.body
    if isinstance(item, ast.FunctionDef) and item.name.startswith("test_")
}
method_bodies = {
    item.name: ast.get_source_segment(source_text, item) or ""
    for node in test_source.body
    if isinstance(node, ast.ClassDef) and node.name == "FeedbackThanksAcceptanceTests"
    for item in node.body
    if isinstance(item, ast.FunctionDef) and item.name.startswith("test_")
}
case_ids = {case["case_id"] for case in test_cases}
if set(case_to_method) != case_ids:
    raise SystemExit(
        f"feedback pilot test-case mapping drift: missing={sorted(case_ids - set(case_to_method))} extra={sorted(set(case_to_method) - case_ids)}"
    )
missing_methods = sorted(set(case_to_method.values()) - methods)
if missing_methods:
    raise SystemExit(f"feedback pilot mapped unittest methods missing: {missing_methods}")
if len(methods) != len(test_cases):
    raise SystemExit(
        f"feedback pilot declared {len(test_cases)} canonical test cases but has {len(methods)} real unittest methods"
    )
blank_boundary_body = method_bodies[case_to_method["TC-T1-BND"]]
if "name=&message=" not in blank_boundary_body or "submission_count" not in blank_boundary_body:
    raise SystemExit("TC-T1-BND must prove blank-field failure without creating feedback")
expected_result = f"Ran {len(methods)} tests"
evidence_paths = [
    phase_dir / "code-review-result.json",
    phase_dir / "unit-1/tasks/T1/developer-report.json",
    phase_dir / "unit-1/tasks/T2/developer-report.json",
]
for path in evidence_paths:
    text = path.read_text(encoding="utf-8")
    if expected_result not in text:
        raise SystemExit(f"feedback pilot stale test-count evidence: {path}")
    if "Ran 9 tests" in text or "Ran 7 tests" in text:
        raise SystemExit(f"feedback pilot old test-count evidence remains: {path}")
PY

python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG" \
  --enforce-canonical-only

python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG"

python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --profiles "$PROFILES" \
  --oracle "$ORACLE"

printf '[PASS] standard-chain feedback thanks pilot\n'
