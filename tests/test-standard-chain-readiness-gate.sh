#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-foundation/cutover"
PHASE_DIR="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
SCRIPT="$ROOT/tools/community/validate_standard_chain_readiness.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SCRIPT" ] || fail "missing readiness gate script"

python3 "$SCRIPT" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/dev/null \
  || fail "golden pilot should satisfy canonical readiness"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/sample-feature"
rm -f "$TMP_DIR/sample-feature/brief.json"
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/sample-feature/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_brief.out 2>&1; then
  cat /tmp/t6_missing_brief.out >&2
  fail "readiness gate should reject phase when feature brief.json is missing"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-delivery-confirmation"
python3 - "$TMP_DIR/missing-delivery-confirmation/brief.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
payload = json.loads(brief_path.read_text(encoding="utf-8"))
payload.pop("delivery_confirmation", None)
brief_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-delivery-confirmation/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_delivery_confirmation.out 2>&1; then
  cat /tmp/t6_missing_delivery_confirmation.out >&2
  fail "readiness gate should reject feature brief when delivery_confirmation is missing"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/empty-delivery-plan"
python3 - "$TMP_DIR/empty-delivery-plan/brief.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
payload = json.loads(brief_path.read_text(encoding="utf-8"))
payload["delivery_plan"] = []
brief_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/empty-delivery-plan/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_empty_delivery_plan.out 2>&1; then
  cat /tmp/t6_empty_delivery_plan.out >&2
  fail "readiness gate should reject feature brief when delivery_plan is empty"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-review-conclusion"
python3 - "$TMP_DIR/missing-review-conclusion/brief.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
payload = json.loads(brief_path.read_text(encoding="utf-8"))
payload.pop("review_conclusion", None)
brief_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-review-conclusion/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_review_conclusion.out 2>&1; then
  cat /tmp/t6_missing_review_conclusion.out >&2
  fail "readiness gate should reject feature brief when review_conclusion is missing"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-review"
rm -f "$TMP_DIR/missing-review/phase-1/code-review-result.json"
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-review/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_review.out 2>&1; then
  cat /tmp/t6_missing_review.out >&2
  fail "readiness gate should reject phase when code-review-result.json is missing"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-developer-report"
rm -f "$TMP_DIR/missing-developer-report/phase-1/unit-1/tasks/T1/developer-report.json"
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-developer-report/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_developer_report.out 2>&1; then
  cat /tmp/t6_missing_developer_report.out >&2
  fail "readiness gate should reject phase when developer-report.json is missing"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-task-runtime"
python3 - "$TMP_DIR/missing-task-runtime/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
payload["tasks"].append({
    "task_id": "T3",
    "task_title": "missing runtime evidence",
    "phase_ref": "artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal",
    "unit_refs": [],
    "scope_item_refs": [],
    "design_refs": [],
    "test_refs": [],
    "depends_on": [],
    "shared_files": [],
    "batch": 2,
    "acceptance_targets": ["coverage"],
})
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-task-runtime/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_task_runtime.out 2>&1; then
  cat /tmp/t6_missing_task_runtime.out >&2
  fail "readiness gate should reject tasks.json entries without developer-report/verify-result coverage"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/inactive-code-review"
python3 - "$TMP_DIR/inactive-code-review/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
entry = payload["revisions"][-1]["entries"][-1]
entry["lifecycle_state"] = "QUARANTINED"
entry["active_for_consumption"] = False
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/inactive-code-review/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_inactive_code_review.out 2>&1; then
  cat /tmp/t6_inactive_code_review.out >&2
  fail "readiness gate should reject inactive code-review-result registry entry"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/invalid-test-cases"
printf '{\"artifact_type\":\"test-cases\"}\n' > "$TMP_DIR/invalid-test-cases/phase-1/unit-1/test-cases.json"
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/invalid-test-cases/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_invalid_test_cases.out 2>&1; then
  cat /tmp/t6_invalid_test_cases.out >&2
  fail "readiness gate should reject invalid unit test-cases.json"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/empty-qa-handoff-contract"
python3 - "$TMP_DIR/empty-qa-handoff-contract/phase-1/unit-1/test-cases.json" <<'PY'
import json
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1])
payload = json.loads(test_cases_path.read_text(encoding="utf-8"))
payload["qa_handoff_contract"] = []
test_cases_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/empty-qa-handoff-contract/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_empty_qa_handoff_contract.out 2>&1; then
  cat /tmp/t6_empty_qa_handoff_contract.out >&2
  fail "readiness gate should reject test-cases.json when qa_handoff_contract is empty"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-qa-ruled-out"
python3 - "$TMP_DIR/missing-qa-ruled-out/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
payload = json.loads(qa_path.read_text(encoding="utf-8"))
payload.pop("ruled_out_issues", None)
qa_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-qa-ruled-out/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_qa_ruled_out.out 2>&1; then
  cat /tmp/t6_missing_qa_ruled_out.out >&2
  fail "readiness gate should reject qa-result.json when ruled_out_issues is missing"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/empty-qa-ruled-out"
python3 - "$TMP_DIR/empty-qa-ruled-out/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
payload = json.loads(qa_path.read_text(encoding="utf-8"))
payload["ruled_out_issues"] = []
qa_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/empty-qa-ruled-out/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_empty_qa_ruled_out.out 2>&1; then
  cat /tmp/t6_empty_qa_ruled_out.out >&2
  fail "readiness gate should reject qa-result.json when ruled_out_issues is empty"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/browser-required-without-evidence"
python3 - \
  "$TMP_DIR/browser-required-without-evidence/phase-1/unit-1/test-cases.json" \
  "$TMP_DIR/browser-required-without-evidence/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1])
qa_path = Path(sys.argv[2])

test_cases = json.loads(test_cases_path.read_text(encoding="utf-8"))
for row in test_cases.get("qa_handoff_contract", []):
    row["execution_mode"] = "browser_required"
test_cases_path.write_text(json.dumps(test_cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

qa_result = json.loads(qa_path.read_text(encoding="utf-8"))
qa_result.pop("browser_tool", None)
qa_result.pop("entry_url", None)
qa_result.pop("browser_evidence", None)
qa_path.write_text(json.dumps(qa_result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/browser-required-without-evidence/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_browser_required_without_evidence.out 2>&1; then
  cat /tmp/t6_browser_required_without_evidence.out >&2
  fail "readiness gate should reject browser_required QA obligations without browser evidence"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/browser-required-api-only"
python3 - \
  "$TMP_DIR/browser-required-api-only/phase-1/unit-1/test-cases.json" \
  "$TMP_DIR/browser-required-api-only/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1])
qa_path = Path(sys.argv[2])

test_cases = json.loads(test_cases_path.read_text(encoding="utf-8"))
for row in test_cases.get("qa_handoff_contract", []):
    row["execution_mode"] = "browser_required"
test_cases_path.write_text(json.dumps(test_cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

qa_result = json.loads(qa_path.read_text(encoding="utf-8"))
qa_result["browser_tool"] = "curl"
qa_result["entry_url"] = "http://127.0.0.1:3000/login"
qa_result["browser_evidence"] = ["curl output attached"]
qa_path.write_text(json.dumps(qa_result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/browser-required-api-only/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_browser_required_api_only.out 2>&1; then
  cat /tmp/t6_browser_required_api_only.out >&2
  fail "readiness gate should reject browser_required QA obligations backed by api-only evidence"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/fail-triage-incomplete"
python3 - \
  "$TMP_DIR/fail-triage-incomplete/phase-1/qa-result.json" \
  "$TMP_DIR/fail-triage-incomplete/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

qa_payload = json.loads(qa_path.read_text(encoding="utf-8"))
qa_payload["gate_result"] = "FAIL"
qa_payload["issue_ledger"] = [{}]
qa_path.write_text(json.dumps(qa_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle_payload = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle_payload["artifacts"]["qa-result"]["gate_result"] = "FAIL"
oracle_path.write_text(json.dumps(oracle_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/fail-triage-incomplete/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_fail_triage_incomplete.out 2>&1; then
  cat /tmp/t6_fail_triage_incomplete.out >&2
  fail "readiness gate should reject FAIL qa-result.json when issue_ledger triage is incomplete"
fi

cp "$ROOT/shared/runtime/standard-chain-catalog.json" "$TMP_DIR/bad-catalog.json"
python3 - "$TMP_DIR/bad-catalog.json" <<'PY'
import json
import sys
from pathlib import Path

catalog_path = Path(sys.argv[1])
payload = json.loads(catalog_path.read_text(encoding="utf-8"))
payload["artifacts"]["brief"]["default_path"] = "docs/{feature}/brief.md"
catalog_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$TMP_DIR/bad-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_bad_catalog.out 2>&1; then
  cat /tmp/t6_bad_catalog.out >&2
  fail "readiness gate should reject catalog drift"
fi

python3 "$SCRIPT" \
  --fixture "$FIXTURE_ROOT/failed-cutover.json" \
  --expect-freeze-quarantine >/dev/null \
  || fail "failed cutover fixture should satisfy freeze + quarantine contract"

cp "$FIXTURE_ROOT/failed-cutover.json" "$TMP_DIR/missing-cutover-greens.json"
python3 - "$TMP_DIR/missing-cutover-greens.json" <<'PY'
import json
import sys
from pathlib import Path

fixture_path = Path(sys.argv[1])
payload = json.loads(fixture_path.read_text(encoding="utf-8"))
payload.pop("validator_green", None)
payload.pop("replay_green", None)
fixture_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --fixture "$TMP_DIR/missing-cutover-greens.json" \
  --expect-freeze-quarantine >/tmp/t6_missing_cutover_greens.out 2>&1; then
  cat /tmp/t6_missing_cutover_greens.out >&2
  fail "readiness gate should reject fixture when validator/replay green is missing"
fi

if python3 "$SCRIPT" --fixture "$FIXTURE_ROOT/illegal-rollback.json" >/tmp/t6_illegal_rollback.out 2>&1; then
  cat /tmp/t6_illegal_rollback.out >&2
  fail "readiness gate should reject illegal rollback"
fi

if python3 "$SCRIPT" --fixture "$FIXTURE_ROOT/mixed-mode.json" >/tmp/t6_mixed_mode.out 2>&1; then
  cat /tmp/t6_mixed_mode.out >&2
  fail "readiness gate should reject mixed mode fixture"
fi

if python3 "$SCRIPT" --fixture "$FIXTURE_ROOT/missing-green.json" >/tmp/t6_missing_green.out 2>&1; then
  cat /tmp/t6_missing_green.out >&2
  fail "readiness gate should reject missing validator green"
fi

echo "[PASS] standard chain readiness gate"
