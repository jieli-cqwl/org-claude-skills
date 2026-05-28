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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/failed-code-review"
python3 - "$TMP_DIR/failed-code-review/phase-1/code-review-result.json" <<'PY'
import json
import sys
from pathlib import Path

review_path = Path(sys.argv[1])
payload = json.loads(review_path.read_text(encoding="utf-8"))
payload["gate_result"] = "FAIL"
payload["review_conclusion"] = "REQUEST_CHANGES"
payload["review_a"] = "REVIEW_A_ISSUE"
payload["dimension_verdicts"]["contract_correctness"] = "ISSUE"
payload["findings"] = [{
    "finding_id": "REV-FAIL-001",
    "severity": "S1",
    "summary": "blocking review issue",
    "file_path": "tools/community/validate_standard_chain_readiness.py",
    "line_number": 18,
    "confidence": 95,
    "verification_status": "VERIFIED",
}]
review_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/failed-code-review/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_failed_code_review.out 2>&1; then
  cat /tmp/t6_failed_code_review.out >&2
  fail "readiness gate should reject code-review-result failure semantics at closeout"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/code-review-blocking-finding"
python3 - "$TMP_DIR/code-review-blocking-finding/phase-1/code-review-result.json" <<'PY'
import json
import sys
from pathlib import Path

review_path = Path(sys.argv[1])
payload = json.loads(review_path.read_text(encoding="utf-8"))
payload["findings"] = [{
    "finding_id": "REV-BLOCK-001",
    "severity": "S1",
    "summary": "verified blocking review issue",
    "file_path": "tools/community/validate_readiness_contract.py",
    "line_number": 216,
    "confidence": 95,
    "verification_status": "Verified",
}]
review_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/code-review-blocking-finding/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_code_review_blocking_finding.out 2>&1; then
  cat /tmp/t6_code_review_blocking_finding.out >&2
  fail "readiness gate should reject verified S0/S1/S2 code-review findings at closeout"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-brief-active-entry"
python3 - "$TMP_DIR/missing-brief-active-entry/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
payload["revisions"][-1]["entries"] = [
    entry
    for entry in payload["revisions"][-1]["entries"]
    if entry["artifact_type"] != "brief"
]
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-brief-active-entry/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_brief_active_entry.out 2>&1; then
  cat /tmp/t6_missing_brief_active_entry.out >&2
  fail "readiness gate should reject missing active registry entry for feature brief"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/ghost-active-registry-entry"
python3 - \
  "$TMP_DIR/ghost-active-registry-entry/phase-1/artifact-registry.json" \
  "$TMP_DIR/ghost-active-registry-entry/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

registry = json.loads(registry_path.read_text(encoding="utf-8"))
ghost = {
    "artifact_type": "qa-result",
    "artifact_id": "ghost-feature.phase-1.qa",
    "revision": "v1",
    "artifact_path": "ghost-qa-result.json",
    "lifecycle_state": "FINALIZED",
    "active_for_consumption": True,
}
registry["revisions"][-1]["entries"].append(ghost)
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["artifact-registry"]["active_entry_tuples"].append([
    ghost["artifact_type"],
    ghost["artifact_id"],
    ghost["revision"],
    ghost["artifact_path"],
    ghost["lifecycle_state"],
    ghost["active_for_consumption"],
])
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/ghost-active-registry-entry/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_ghost_active_registry_entry.out 2>&1; then
  cat /tmp/t6_ghost_active_registry_entry.out >&2
  fail "readiness gate should reject active registry entries that are not part of the validated delivery artifact set"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/bad-code-review-active-path"
python3 - "$TMP_DIR/bad-code-review-active-path/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
entry = next(
    item
    for item in payload["revisions"][-1]["entries"]
    if item["artifact_type"] == "code-review-result"
)
entry["artifact_path"] = "missing-code-review-result.json"
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/bad-code-review-active-path/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_bad_code_review_active_path.out 2>&1; then
  cat /tmp/t6_bad_code_review_active_path.out >&2
  fail "readiness gate should reject active registry entry whose artifact_path does not resolve to the validated artifact"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/bad-brief-active-version"
python3 - \
  "$TMP_DIR/bad-brief-active-version/phase-1/artifact-registry.json" \
  "$TMP_DIR/bad-brief-active-version/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])
registry = json.loads(registry_path.read_text(encoding="utf-8"))
entry = next(item for item in registry["revisions"][-1]["entries"] if item["artifact_type"] == "brief")
entry["version"] = "v999"
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["artifact-registry"]["active_entry_tuples"] = [
    [entry["artifact_type"], entry["artifact_id"], entry["version"], entry["artifact_path"], entry["lifecycle_state"], entry["active_for_consumption"]]
    for entry in registry["revisions"][-1]["entries"]
    if entry.get("active_for_consumption")
]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/bad-brief-active-version/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_bad_brief_active_version.out 2>&1; then
  cat /tmp/t6_bad_brief_active_version.out >&2
  fail "readiness gate should reject active registry version drift"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/bad-code-review-active-scope"
python3 - "$TMP_DIR/bad-code-review-active-scope/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
registry = json.loads(registry_path.read_text(encoding="utf-8"))
entry = next(item for item in registry["revisions"][-1]["entries"] if item["artifact_type"] == "code-review-result")
entry["scope_ref"] = "artifact://phase-prd/other-feature.phase-9.prd@v1#phase-goal"
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/bad-code-review-active-scope/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_bad_code_review_active_scope.out 2>&1; then
  cat /tmp/t6_bad_code_review_active_scope.out >&2
  fail "readiness gate should reject active registry scope_ref drift"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/projection-section-drift"
python3 - \
  "$TMP_DIR/projection-section-drift/phase-1/views/phase-operational.projection-manifest.json" \
  "$TMP_DIR/projection-section-drift/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
section = manifest["section_source_map"]["phase-summary"]
section["json_pointers"] = ["$.status"]
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["projection-manifest"]["section_source_map"] = manifest["section_source_map"]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/projection-section-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_projection_section_drift.out 2>&1; then
  cat /tmp/t6_projection_section_drift.out >&2
  fail "readiness gate should reject projection section_source_map drift from configured view"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/projection-feature-drift"
python3 - \
  "$TMP_DIR/projection-feature-drift/phase-1/views/phase-operational.projection-manifest.json" \
  "$TMP_DIR/projection-feature-drift/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["source_artifact_refs"] = [
    ref.replace("sample-feature", "other-feature")
    for ref in manifest["source_artifact_refs"]
]
for section in manifest["section_source_map"].values():
    section["source_artifact_refs"] = [
        ref.replace("sample-feature", "other-feature")
        for ref in section["source_artifact_refs"]
    ]
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["projection-manifest"]["source_artifact_refs"] = manifest["source_artifact_refs"]
oracle["artifacts"]["projection-manifest"]["section_source_map"] = manifest["section_source_map"]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/projection-feature-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_projection_feature_drift.out 2>&1; then
  cat /tmp/t6_projection_feature_drift.out >&2
  fail "readiness gate should reject projection refs that drift to another feature"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/pending-director-fail-review"
python3 - \
  "$TMP_DIR/pending-director-fail-review/brief.json" \
  "$TMP_DIR/pending-director-fail-review/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
phase_prd_path = Path(sys.argv[2])

brief = json.loads(brief_path.read_text(encoding="utf-8"))
brief["director_confirmation"]["status"] = "pending"
brief["review_conclusion"]["verdict"] = "FAIL"
brief["issue_ledger"] = [{"issue_id": "P-1", "severity": "P1", "status": "OPEN"}]
brief_path.write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

phase_prd = json.loads(phase_prd_path.read_text(encoding="utf-8"))
phase_prd["director_confirmation"]["status"] = "pending"
phase_prd["review_conclusion"] = {"verdict": "FAIL", "summary": "phase review failed"}
phase_prd["issue_ledger"] = [{"issue_id": "P-2", "severity": "P1", "status": "OPEN"}]
phase_prd_path.write_text(json.dumps(phase_prd, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/pending-director-fail-review/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_pending_director_fail_review.out 2>&1; then
  cat /tmp/t6_pending_director_fail_review.out >&2
  fail "readiness gate should reject unconfirmed Director and unresolved product review"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/phase-prd-missing-review"
python3 - "$TMP_DIR/phase-prd-missing-review/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

phase_prd_path = Path(sys.argv[1])
phase_prd = json.loads(phase_prd_path.read_text(encoding="utf-8"))
phase_prd.pop("review_conclusion", None)
phase_prd.pop("issue_ledger", None)
phase_prd_path.write_text(json.dumps(phase_prd, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/phase-prd-missing-review/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_phase_prd_missing_review.out 2>&1; then
  cat /tmp/t6_phase_prd_missing_review.out >&2
  fail "readiness gate should reject phase-prd without Manager review closure fields"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/warn-without-issue-ledger"
python3 - \
  "$TMP_DIR/warn-without-issue-ledger/brief.json" \
  "$TMP_DIR/warn-without-issue-ledger/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["review_conclusion"]["verdict"] = "WARN"
    payload["issue_ledger"] = []
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/warn-without-issue-ledger/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_warn_without_issue_ledger.out 2>&1; then
  cat /tmp/t6_warn_without_issue_ledger.out >&2
  fail "readiness gate should reject product WARN review conclusions without issue_ledger entries"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/warn-with-hollow-issue-ledger"
python3 - \
  "$TMP_DIR/warn-with-hollow-issue-ledger/brief.json" \
  "$TMP_DIR/warn-with-hollow-issue-ledger/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["review_conclusion"]["verdict"] = "WARN"
    payload["issue_ledger"] = [{"issue_id": "P-3", "status": "DEFERRED"}]
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/warn-with-hollow-issue-ledger/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_warn_with_hollow_issue_ledger.out 2>&1; then
  cat /tmp/t6_warn_with_hollow_issue_ledger.out >&2
  fail "readiness gate should reject product WARN issue_ledger entries without evidence and handoff fields"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/warn-with-placeholder-issue-ledger"
python3 - \
  "$TMP_DIR/warn-with-placeholder-issue-ledger/brief.json" \
  "$TMP_DIR/warn-with-placeholder-issue-ledger/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["review_conclusion"] = {"verdict": "WARN", "summary": "TBD"}
    payload["issue_ledger"] = [{
        "issue_id": "P-4",
        "status": "DEFERRED",
        "severity": "TBD",
        "dimension": "TBD",
        "finding": "TBD",
        "evidence": "TBD",
        "handoff_target": "TBD",
    }]
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/warn-with-placeholder-issue-ledger/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_warn_with_placeholder_issue_ledger.out 2>&1; then
  cat /tmp/t6_warn_with_placeholder_issue_ledger.out >&2
  fail "readiness gate should reject product WARN issue_ledger placeholder fields"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/final-phase-empty-unit-index"
python3 - "$TMP_DIR/final-phase-empty-unit-index/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

phase_prd_path = Path(sys.argv[1])
phase_prd = json.loads(phase_prd_path.read_text(encoding="utf-8"))
phase_prd["unit_index"] = []
phase_prd_path.write_text(json.dumps(phase_prd, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/final-phase-empty-unit-index/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_final_phase_empty_unit_index.out 2>&1; then
  cat /tmp/t6_final_phase_empty_unit_index.out >&2
  fail "readiness gate should reject final phase-prd when Manager handoff leaves unit_index empty"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/final-phase-ghost-unit-index"
python3 - "$TMP_DIR/final-phase-ghost-unit-index/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

phase_prd_path = Path(sys.argv[1])
phase_prd = json.loads(phase_prd_path.read_text(encoding="utf-8"))
phase_prd["unit_index"] = ["UNIT-99"]
phase_prd_path.write_text(json.dumps(phase_prd, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/final-phase-ghost-unit-index/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_final_phase_ghost_unit_index.out 2>&1; then
  cat /tmp/t6_final_phase_ghost_unit_index.out >&2
  fail "readiness gate should reject phase-prd unit_index entries without matching UNIT artifacts"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/director-lock-drift"
python3 - \
  "$TMP_DIR/director-lock-drift/brief.json" \
  "$TMP_DIR/director-lock-drift/phase-1/phase-prd.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

def lock_digest(payload, fields):
    locked = {field: payload.get(field) for field in fields}
    raw = json.dumps(locked, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()

brief_path = Path(sys.argv[1])
phase_prd_path = Path(sys.argv[2])

brief = json.loads(brief_path.read_text(encoding="utf-8"))
brief["root_problem"] = "mutated after Director confirmation"
brief["director_confirmation"]["locked_field_digest"] = lock_digest(
    brief,
    ["root_problem", "business_goals", "scope_boundaries", "delivery_plan"],
)
brief_path.write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

phase_prd = json.loads(phase_prd_path.read_text(encoding="utf-8"))
phase_prd["phase_goal"] = "mutated after Director confirmation"
phase_prd["director_confirmation"]["locked_field_digest"] = lock_digest(
    phase_prd,
    ["phase_goal", "entry_conditions", "exit_conditions"],
)
phase_prd_path.write_text(json.dumps(phase_prd, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/director-lock-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_director_lock_drift.out 2>&1; then
  cat /tmp/t6_director_lock_drift.out >&2
  fail "readiness gate should reject Director-owned field drift after director_confirmation lock"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/director-lock-co-mutated"
python3 - \
  "$TMP_DIR/director-lock-co-mutated/brief.json" \
  "$TMP_DIR/director-lock-co-mutated/phase-1/phase-prd.json" \
  "$TMP_DIR/director-lock-co-mutated/phase-1/artifact-registry.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

def snapshot_digest(snapshot):
    raw = json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()

brief_path = Path(sys.argv[1])
phase_prd_path = Path(sys.argv[2])
registry_path = Path(sys.argv[3])

brief = json.loads(brief_path.read_text(encoding="utf-8"))
brief["root_problem"] = "co-mutated after Director confirmation"
brief["director_confirmation"]["locked_fields"]["root_problem"] = brief["root_problem"]
brief["director_confirmation"]["locked_field_digest"] = snapshot_digest(brief["director_confirmation"]["locked_fields"])
brief_path.write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

phase_prd = json.loads(phase_prd_path.read_text(encoding="utf-8"))
phase_prd["phase_goal"] = "co-mutated after Director confirmation"
phase_prd["director_confirmation"]["locked_fields"]["phase_goal"] = phase_prd["phase_goal"]
phase_prd["director_confirmation"]["locked_field_digest"] = snapshot_digest(phase_prd["director_confirmation"]["locked_fields"])
phase_prd_path.write_text(json.dumps(phase_prd, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

registry = json.loads(registry_path.read_text(encoding="utf-8"))
for revision in registry["revisions"]:
    for entry in revision["entries"]:
        if entry.get("artifact_type") == "brief":
            entry["director_lock_digest"] = brief["director_confirmation"]["locked_field_digest"]
        if entry.get("artifact_type") == "phase-prd":
            entry["director_lock_digest"] = phase_prd["director_confirmation"]["locked_field_digest"]
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/director-lock-co-mutated/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_director_lock_co_mutated.out 2>&1; then
  cat /tmp/t6_director_lock_co_mutated.out >&2
  fail "readiness gate should reject co-mutated Director fields, locked_fields, and registry lock digest without a fresh user decision"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/director-lock-missing-user-decision-digest"
python3 - \
  "$TMP_DIR/director-lock-missing-user-decision-digest/phase-1/user-decision.json" \
  "$TMP_DIR/director-lock-missing-user-decision-digest/phase-1/evidence/authority-proof.json" <<'PY'
import copy
import hashlib
import json
import sys
from pathlib import Path

decision_path = Path(sys.argv[1])
proof_path = Path(sys.argv[2])
decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision.pop("director_lock_digests", None)
digest_payload = copy.deepcopy(decision)
digest_payload.pop("decision_payload_digest", None)
decision["decision_payload_digest"] = "sha256:" + hashlib.sha256(
    json.dumps(digest_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
decision_path.write_text(json.dumps(decision, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["decision_payload_digest"] = decision["decision_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/director-lock-missing-user-decision-digest/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_director_lock_missing_user_decision_digest.out 2>&1; then
  cat /tmp/t6_director_lock_missing_user_decision_digest.out >&2
  fail "readiness gate should require user-decision to anchor product director lock digests"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/director-lock-missing-registry-digest"
python3 - "$TMP_DIR/director-lock-missing-registry-digest/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
registry = json.loads(registry_path.read_text(encoding="utf-8"))
for revision in registry["revisions"]:
    for entry in revision["entries"]:
        if entry.get("artifact_type") in {"brief", "phase-prd"}:
            entry.pop("director_lock_digest", None)
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/director-lock-missing-registry-digest/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_director_lock_missing_registry_digest.out 2>&1; then
  cat /tmp/t6_director_lock_missing_registry_digest.out >&2
  fail "readiness gate should require active registry entries to carry product director lock digests"
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
    "design_refs": ["artifact://design/sample-feature.phase-1.design@v1#key-decisions"],
    "test_refs": ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-1"],
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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/duplicate-task-id"
python3 - "$TMP_DIR/duplicate-task-id/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
payload["tasks"].append(dict(payload["tasks"][0]))
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/duplicate-task-id/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_duplicate_task_id.out 2>&1; then
  cat /tmp/t6_duplicate_task_id.out >&2
  fail "readiness gate should reject duplicate tasks.json task_id entries"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/delivery-state-missing-task"
python3 - "$TMP_DIR/delivery-state-missing-task/phase-1/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
payload = json.loads(state_path.read_text(encoding="utf-8"))
payload["tasks"] = [
    row for row in payload.get("tasks", [])
    if row.get("task_id") != "T2"
]
state_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/delivery-state-missing-task/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_delivery_state_missing_task.out 2>&1; then
  cat /tmp/t6_delivery_state_missing_task.out >&2
  fail "readiness gate should reject delivery-state tasks that omit tasks.json task ids"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/delivery-state-duplicate-task"
python3 - "$TMP_DIR/delivery-state-duplicate-task/phase-1/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
payload = json.loads(state_path.read_text(encoding="utf-8"))
payload["tasks"].append(dict(payload["tasks"][0]))
state_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/delivery-state-duplicate-task/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_delivery_state_duplicate_task.out 2>&1; then
  cat /tmp/t6_delivery_state_duplicate_task.out >&2
  fail "readiness gate should reject duplicate delivery-state task rows"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/inactive-code-review"
python3 - "$TMP_DIR/inactive-code-review/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
entry = next(
    item
    for item in payload["revisions"][-1]["entries"]
    if item["artifact_type"] == "code-review-result"
)
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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/inactive-task-verify"
python3 - "$TMP_DIR/inactive-task-verify/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
entry = next(
    item
    for item in payload["revisions"][-1]["entries"]
    if item["artifact_type"] == "verify-result" and item["artifact_path"] == "unit-1/tasks/T2/verify-result.json"
)
entry["lifecycle_state"] = "SUPERSEDED"
entry["active_for_consumption"] = False
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/inactive-task-verify/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_inactive_task_verify.out 2>&1; then
  cat /tmp/t6_inactive_task_verify.out >&2
  fail "readiness gate should reject inactive task-level verify-result registry entry"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/task-runtime-identity-drift"
cp \
  "$TMP_DIR/task-runtime-identity-drift/phase-1/unit-1/tasks/T1/developer-report.json" \
  "$TMP_DIR/task-runtime-identity-drift/phase-1/unit-1/tasks/T2/developer-report.json"
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/task-runtime-identity-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_task_runtime_identity_drift.out 2>&1; then
  cat /tmp/t6_task_runtime_identity_drift.out >&2
  fail "readiness gate should reject task runtime artifacts copied across task identities"
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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-qa-obligation-results"
python3 - "$TMP_DIR/missing-qa-obligation-results/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
payload = json.loads(qa_path.read_text(encoding="utf-8"))
payload.pop("obligation_results", None)
qa_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-qa-obligation-results/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_qa_obligation_results.out 2>&1; then
  cat /tmp/t6_missing_qa_obligation_results.out >&2
  fail "readiness gate should reject qa-result.json when obligation_results is missing"
fi
grep -Eq 'obligation_results' /tmp/t6_missing_qa_obligation_results.out \
  || fail "missing obligation_results failure should name obligation_results"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/partial-qa-obligation-results"
python3 - "$TMP_DIR/partial-qa-obligation-results/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
payload = json.loads(qa_path.read_text(encoding="utf-8"))
payload["obligation_results"] = [
    row for row in payload.get("obligation_results", [])
    if row.get("obligation_id") == "QHO-STATIC-CONTRACT"
]
qa_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/partial-qa-obligation-results/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_partial_qa_obligation_results.out 2>&1; then
  cat /tmp/t6_partial_qa_obligation_results.out >&2
  fail "readiness gate should reject qa-result.json when qa_handoff_contract obligations are not all covered"
fi
grep -Eq 'QHO-RUNTIME-REPLAY' /tmp/t6_partial_qa_obligation_results.out \
  || fail "partial obligation_results failure should name an uncovered obligation"

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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/fail-triage-bad-issue-id"
python3 - \
  "$TMP_DIR/fail-triage-bad-issue-id/phase-1/qa-result.json" \
  "$TMP_DIR/fail-triage-bad-issue-id/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

qa_payload = json.loads(qa_path.read_text(encoding="utf-8"))
qa_payload["gate_result"] = "FAIL"
qa_payload["issue_ledger"] = [{
    "issue_id": "BUG-1",
    "severity": "S2",
    "priority": "P1",
    "impact_scope": "核心旅程",
    "user_impact": "用户无法完成 QA 验收路径",
    "environment_or_build": "local-test",
    "regression_flag": "yes",
    "temporary_workaround": "none",
    "owner_hint": "qa",
    "expected_behavior": "QA issue has stable id",
    "actual_behavior": "QA issue has invalid id",
    "reproduction": "python validate_standard_chain_readiness.py",
}]
qa_path.write_text(json.dumps(qa_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle_payload = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle_payload["artifacts"]["qa-result"]["gate_result"] = "FAIL"
oracle_path.write_text(json.dumps(oracle_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/fail-triage-bad-issue-id/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_fail_triage_bad_issue_id.out 2>&1; then
  cat /tmp/t6_fail_triage_bad_issue_id.out >&2
  fail "readiness gate should reject FAIL qa-result.json when issue_id is not QAR-XXX"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/authority-proof-mismatch"
python3 - \
  "$TMP_DIR/authority-proof-mismatch/phase-1/user-decision.json" \
  "$TMP_DIR/authority-proof-mismatch/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

decision_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision["actor_id"] = "attacker"
decision_path.write_text(json.dumps(decision, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["user-decision"]["decision_payload_digest"] = decision["decision_payload_digest"]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/authority-proof-mismatch/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_authority_proof_mismatch.out 2>&1; then
  cat /tmp/t6_authority_proof_mismatch.out >&2
  fail "readiness gate should reject user-decision when authority proof does not bind the actor"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/decision-digest-field-drift"
python3 - \
  "$TMP_DIR/decision-digest-field-drift/phase-1/user-decision.json" \
  "$TMP_DIR/decision-digest-field-drift/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

decision_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision["decision_payload_digest"] = "sha256:" + ("0" * 64)
decision_path.write_text(json.dumps(decision, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["user-decision"]["decision_payload_digest"] = decision["decision_payload_digest"]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/decision-digest-field-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_decision_digest_field_drift.out 2>&1; then
  cat /tmp/t6_decision_digest_field_drift.out >&2
  fail "readiness gate should reject user-decision when decision_payload_digest drifts from the canonical payload digest"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/unresolved-authority-proof-ref"
python3 - \
  "$TMP_DIR/unresolved-authority-proof-ref/phase-1/user-decision.json" \
  "$TMP_DIR/unresolved-authority-proof-ref/phase-1/evidence/authority-proof.json" \
  "$TMP_DIR/unresolved-authority-proof-ref/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

decision_path = Path(sys.argv[1])
proof_path = Path(sys.argv[2])
oracle_path = Path(sys.argv[3])

decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision["authority_proof_refs"].append(
    "artifact://authority-proof/sample-feature.phase-1.user-decision@missing#decision-proof"
)
digest_payload = dict(decision)
digest_payload.pop("decision_payload_digest", None)
decision["decision_payload_digest"] = "sha256:" + hashlib.sha256(
    json.dumps(digest_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
decision_path.write_text(json.dumps(decision, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["decision_payload_digest"] = decision["decision_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["user-decision"]["decision_payload_digest"] = decision["decision_payload_digest"]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/unresolved-authority-proof-ref/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_unresolved_authority_proof_ref.out 2>&1; then
  cat /tmp/t6_unresolved_authority_proof_ref.out >&2
  fail "readiness gate should reject every unresolved user-decision authority_proof_ref"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/empty-goal-closure"
python3 - \
  "$TMP_DIR/empty-goal-closure/phase-1/signoff-package.json" \
  "$TMP_DIR/empty-goal-closure/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["goal_closure"] = []
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["signoff-package"]["goal_closure[].result"] = []
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/empty-goal-closure/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_empty_goal_closure.out 2>&1; then
  cat /tmp/t6_empty_goal_closure.out >&2
  fail "readiness gate should reject empty signoff goal_closure even when replay oracle is self-consistent"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/duplicate-goal-closure"
python3 - "$TMP_DIR/duplicate-goal-closure/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["goal_closure"][0]["goal_ref"] = "artifact://brief/sample-feature.brief@v1#goal-002"
signoff["goal_closure"][0]["goal_source_ref"] = "artifact://brief/sample-feature.brief@v1#goal-002"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/duplicate-goal-closure/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_duplicate_goal_closure.out 2>&1; then
  cat /tmp/t6_duplicate_goal_closure.out >&2
  fail "readiness gate should reject signoff goal_closure that duplicates another goal while omitting a required business goal"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/signoff-goal-ref-drift"
python3 - \
  "$TMP_DIR/signoff-goal-ref-drift/phase-1/signoff-package.json" \
  "$TMP_DIR/signoff-goal-ref-drift/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["goal_closure"][0]["goal_ref"] = "artifact://brief/sample-feature.brief@v1#goal-002"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["signoff-package"]["goal_closure[].result"] = [
    row["result"] for row in signoff["goal_closure"]
]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/signoff-goal-ref-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_signoff_goal_ref_drift.out 2>&1; then
  cat /tmp/t6_signoff_goal_ref_drift.out >&2
  fail "readiness gate should reject signoff goal_ref drift from goal_source_ref"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/signoff-extra-goal-closure"
python3 - \
  "$TMP_DIR/signoff-extra-goal-closure/phase-1/signoff-package.json" \
  "$TMP_DIR/signoff-extra-goal-closure/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
extra = dict(signoff["goal_closure"][0])
extra["goal_ref"] = "artifact://brief/sample-feature.brief@v1#goal-extra"
extra["goal_source_ref"] = "artifact://brief/sample-feature.brief@v1#goal-extra"
signoff["goal_closure"].append(extra)
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["signoff-package"]["goal_closure[].result"] = [
    row["result"] for row in signoff["goal_closure"]
]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/signoff-extra-goal-closure/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_signoff_extra_goal_closure.out 2>&1; then
  cat /tmp/t6_signoff_extra_goal_closure.out >&2
  fail "readiness gate should reject signoff goal_closure rows beyond the required upstream goal set"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-phase-goal-closure"
python3 - "$TMP_DIR/missing-phase-goal-closure/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["goal_closure"][1]["goal_ref"] = "artifact://brief/sample-feature.brief@v1#goal-999"
signoff["goal_closure"][1]["goal_source_ref"] = "artifact://brief/sample-feature.brief@v1#goal-999"
signoff["waiver_entries"][0]["scope_refs"] = ["artifact://brief/sample-feature.brief@v1#goal-999"]
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-phase-goal-closure/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_phase_goal_closure.out 2>&1; then
  cat /tmp/t6_missing_phase_goal_closure.out >&2
  fail "readiness gate should reject signoff goal_closure that omits phase-prd phase_goal"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/waiver-scope-drift"
python3 - "$TMP_DIR/waiver-scope-drift/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["waiver_entries"][0]["scope_refs"] = ["artifact://brief/sample-feature.brief@v1#goal-999"]
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/waiver-scope-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_waiver_scope_drift.out 2>&1; then
  cat /tmp/t6_waiver_scope_drift.out >&2
  fail "readiness gate should reject waiver scope_refs that do not bind to closed upstream goals"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/signoff-ref-anchor-drift"
python3 - "$TMP_DIR/signoff-ref-anchor-drift/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["goal_closure"][0]["execution_basis_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#missing-execution"
signoff["goal_closure"][0]["evidence_ref"] = "artifact://qa-result/sample-feature.phase-1.qa@v1#missing-evidence"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/signoff-ref-anchor-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_signoff_ref_anchor_drift.out 2>&1; then
  cat /tmp/t6_signoff_ref_anchor_drift.out >&2
  fail "readiness gate should reject signoff execution_basis_ref/evidence_ref anchors that do not resolve"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/signoff-missing-runtime-evidence-type"
python3 - "$TMP_DIR/signoff-missing-runtime-evidence-type/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["runtime_evidence_matrix"] = [
    {
        "artifact_type": "developer-report",
        "artifact_ref": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#runtime-status",
        "producer": "developer",
        "status": "VERIFIED",
        "freshness_basis_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
        "active_registry_proof": {
            "registry_ref": "artifact://artifact-registry/sample-feature.phase-1.artifact-registry@rev-4#active-entry:developer-report:sample-feature.phase-1.unit-1.task-T1.developer-report",
            "lifecycle_state": "FINALIZED",
            "active_for_consumption": True,
        },
        "stale_superseded_check": "CURRENT",
    },
    {
        "artifact_type": "verify-result",
        "artifact_ref": "artifact://verify-result/sample-feature.phase-1.unit-1.task-T1.verify-result@v1#gate-result",
        "producer": "verify",
        "status": "PASS",
        "freshness_basis_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
        "active_registry_proof": {
            "registry_ref": "artifact://artifact-registry/sample-feature.phase-1.artifact-registry@rev-4#active-entry:verify-result:sample-feature.phase-1.unit-1.task-T1.verify-result",
            "lifecycle_state": "FINALIZED",
            "active_for_consumption": True,
        },
        "stale_superseded_check": "CURRENT",
    },
    {
        "artifact_type": "qa-result",
        "artifact_ref": "artifact://qa-result/sample-feature.phase-1.qa@v1#obligation_results",
        "producer": "qa",
        "status": "PASS",
        "freshness_basis_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
        "active_registry_proof": {
            "registry_ref": "artifact://artifact-registry/sample-feature.phase-1.artifact-registry@rev-4#active-entry:qa-result:sample-feature.phase-1.qa",
            "lifecycle_state": "FINALIZED",
            "active_for_consumption": True,
        },
        "stale_superseded_check": "CURRENT",
    },
    {
        "artifact_type": "consistency-audit-result",
        "artifact_ref": "artifact://consistency-audit-result/sample-feature.phase-1.consistency-audit@v1#audit-root",
        "producer": "consistency-audit",
        "status": "CLOSED",
        "freshness_basis_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
        "active_registry_proof": {
            "registry_ref": "artifact://artifact-registry/sample-feature.phase-1.artifact-registry@rev-4#active-entry:consistency-audit-result:sample-feature.phase-1.consistency-audit",
            "lifecycle_state": "FINALIZED",
            "active_for_consumption": True,
        },
        "stale_superseded_check": "CURRENT",
    },
]
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/signoff-missing-runtime-evidence-type/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_signoff_missing_runtime_evidence_type.out 2>&1; then
  cat /tmp/t6_signoff_missing_runtime_evidence_type.out >&2
  fail "readiness gate should reject signoff runtime_evidence_matrix missing code-review-result coverage"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/developer-runtime-status-drift"
python3 - "$TMP_DIR/developer-runtime-status-drift/phase-1/unit-1/tasks/T1/developer-report.json" <<'PY'
import json
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
report = json.loads(report_path.read_text(encoding="utf-8"))
report["runtime_status"] = "IN_PROGRESS"
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/developer-runtime-status-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_developer_runtime_status_drift.out 2>&1; then
  cat /tmp/t6_developer_runtime_status_drift.out >&2
  fail "readiness gate should reject developer-report runtime_status that is not VERIFIED at closeout"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/verify-result-failure-drift"
python3 - "$TMP_DIR/verify-result-failure-drift/phase-1/unit-1/tasks/T1/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["gate_result"] = "FAIL"
payload["phase_verdicts"]["spec_review"]["status"] = "SPEC_ISSUE"
payload["phase_verdicts"]["phase2a"]["status"] = "2A_ISSUE"
payload["phase_verdicts"]["phase2b"]["status"] = "2B_ISSUE"
payload["phase_verdicts"]["phase2c"]["status"] = "2C_ISSUE"
payload["ac_verification"][0]["status"] = "ISSUE"
payload["goal_closure"][0]["result"] = "NOT_MET"
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/verify-result-failure-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_verify_result_failure_drift.out 2>&1; then
  cat /tmp/t6_verify_result_failure_drift.out >&2
  fail "readiness gate should reject verify-result failure semantics at closeout"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/verify-empty-goal-closure"
python3 - "$TMP_DIR/verify-empty-goal-closure/phase-1/unit-1/tasks/T1/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["goal_closure"] = []
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/verify-empty-goal-closure/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_verify_empty_goal_closure.out 2>&1; then
  cat /tmp/t6_verify_empty_goal_closure.out >&2
  fail "readiness gate should reject verify-result with empty goal_closure"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/verify-unresolved-goal-ref"
python3 - "$TMP_DIR/verify-unresolved-goal-ref/phase-1/unit-1/tasks/T1/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["goal_closure"][0]["goal_ref"] = "artifact://brief/sample-feature.brief@v1#goal-999"
payload["goal_closure"][0]["result"] = "MET"
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/verify-unresolved-goal-ref/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_verify_unresolved_goal_ref.out 2>&1; then
  cat /tmp/t6_verify_unresolved_goal_ref.out >&2
  fail "readiness gate should reject verify-result goal_ref that does not resolve to an upstream goal"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/verify-na-only-goal"
python3 - "$TMP_DIR/verify-na-only-goal/phase-1/unit-1/tasks/T1/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["goal_closure"][0]["result"] = "N_A"
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/verify-na-only-goal/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_verify_na_only_goal.out 2>&1; then
  cat /tmp/t6_verify_na_only_goal.out >&2
  fail "readiness gate should reject PASS verify-result whose goal_closure has no MET row"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/verify-developer-report-ref-drift"
python3 - "$TMP_DIR/verify-developer-report-ref-drift/phase-1/unit-1/tasks/T1/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["developer_report_ref"] = "artifact://developer-report/sample-feature.phase-1.unit-1.task-T2.developer-report@v1#tdd-evidence-index"
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/verify-developer-report-ref-drift/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_verify_developer_report_ref_drift.out 2>&1; then
  cat /tmp/t6_verify_developer_report_ref_drift.out >&2
  fail "readiness gate should reject verify-result developer_report_ref that points to another task"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/approve-without-signoff"
python3 - \
  "$TMP_DIR/approve-without-signoff/phase-1/user-decision.json" \
  "$TMP_DIR/approve-without-signoff/phase-1/evidence/authority-proof.json" \
  "$TMP_DIR/approve-without-signoff/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

decision_path = Path(sys.argv[1])
proof_path = Path(sys.argv[2])
oracle_path = Path(sys.argv[3])

decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision["decision"] = "APPROVE"
decision["sign_off_status"] = "PENDING"
digest_payload = dict(decision)
digest_payload.pop("decision_payload_digest", None)
decision["decision_payload_digest"] = "sha256:" + hashlib.sha256(
    json.dumps(digest_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
decision_path.write_text(json.dumps(decision, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["decision_payload_digest"] = decision["decision_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["user-decision"]["sign_off_status"] = "PENDING"
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/approve-without-signoff/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_approve_without_signoff.out 2>&1; then
  cat /tmp/t6_approve_without_signoff.out >&2
  fail "readiness gate should reject APPROVE user-decision without signed-off status"
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
