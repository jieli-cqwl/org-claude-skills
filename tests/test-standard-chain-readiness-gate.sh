#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-foundation/cutover"
PHASE_DIR="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
SCRIPT="$ROOT/tools/community/validate_standard_chain_readiness.py"
PHASE_VALIDATOR="$ROOT/tools/community/validate_standard_chain_phase.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SCRIPT" ] || fail "missing readiness gate script"
[ -f "$PHASE_VALIDATOR" ] || fail "missing standard-chain phase validator"

python3 "$SCRIPT" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/dev/null \
  || fail "golden pilot should satisfy canonical readiness"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - \
  "$ROOT/shared/runtime/standard-chain-catalog.json" \
  "$TMP_DIR/catalog-missing-target-change.json" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
catalog = json.loads(source_path.read_text(encoding="utf-8"))
catalog["artifacts"].pop("target-change", None)
target_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$PHASE_VALIDATOR" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$TMP_DIR/catalog-missing-target-change.json" >/tmp/t6_catalog_missing_target_change.out 2>&1; then
  cat /tmp/t6_catalog_missing_target_change.out >&2
  fail "phase validator should reject catalog when target-change artifact is missing"
fi
grep -Eq 'target-change' /tmp/t6_catalog_missing_target_change.out \
  || fail "missing target-change catalog failure should name target-change"

python3 - "$SCRIPT" <<'PY'
import importlib.util
import subprocess
import sys
from pathlib import Path

script_path = sys.argv[1]
sys.path.insert(0, str(Path(script_path).parent))
spec = importlib.util.spec_from_file_location("readiness", script_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
completed = subprocess.CompletedProcess(
    args=["validator"],
    returncode=1,
    stdout='prefix\n{"status":"BLOCKED","owner":"delivery-owner","reason":"semantic stale evidence","recovery_condition":"rerun","signoff_allowed":false}\n',
    stderr="",
)
reason = module.extract_subprocess_failure_reason(completed, "phase validator")
if reason != "semantic stale evidence":
    raise SystemExit(f"nested validator reason should be semantic, got: {reason}")
PY

expect_block_contract() {
  local label="$1"
  local output_file="$2"
  shift 2
  if "$@" >"$output_file" 2>&1; then
    cat "$output_file" >&2
    fail "$label should block readiness"
  fi
  python3 - "$output_file" "$label" <<'PY'
import json
import sys
from pathlib import Path

output_path = Path(sys.argv[1])
label = sys.argv[2]
text = output_path.read_text(encoding="utf-8").strip()
try:
    payload = json.loads(text)
except json.JSONDecodeError as exc:
    raise SystemExit(f"{label} must emit a JSON block contract, got: {text[:240]}") from exc

required = {"status", "owner", "reason", "recovery_condition", "signoff_allowed"}
missing = sorted(required - set(payload))
if missing:
    raise SystemExit(f"{label} block contract missing keys: {', '.join(missing)}")
if payload["status"] != "BLOCKED":
    raise SystemExit(f"{label} status must be BLOCKED")
if payload["signoff_allowed"] is not False:
    raise SystemExit(f"{label} signoff_allowed must be false")
for key in ("owner", "reason", "recovery_condition"):
    if not isinstance(payload.get(key), str) or not payload[key].strip():
        raise SystemExit(f"{label} block contract {key} must be a non-empty string")
PY
}

expect_block_contract_reason() {
  local label="$1"
  local reason_fragment="$2"
  local output_file="$3"
  shift 3
  expect_block_contract "$label" "$output_file" "$@"
  python3 - "$output_file" "$label" "$reason_fragment" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
label = sys.argv[2]
reason_fragment = sys.argv[3]
if reason_fragment not in payload.get("reason", ""):
    raise SystemExit(f"{label} reason must contain {reason_fragment!r}, got: {payload.get('reason', '')}")
PY
}
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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/task-proving-command-drift"
python3 - "$TMP_DIR/task-proving-command-drift/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
payload["tasks"][0]["proving_command"] = "bash tests/not-run-by-developer-report.sh"
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "task proving_command drift" \
  "task T1 proving_command must match developer-report fresh_proof" \
  /tmp/t6_task_proving_command_drift.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/task-proving-command-drift/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/task-evidence-target-drift"
python3 - "$TMP_DIR/task-evidence-target-drift/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
payload["tasks"][0]["evidence_target"] = "developer-report.json#task-T999.fresh_proof"
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "task evidence_target drift" \
  "task T1 evidence_target must resolve to developer-report fresh_proof" \
  /tmp/t6_task_evidence_target_drift.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/task-evidence-target-drift/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

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

cp -R "$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot" "$TMP_DIR/tasks-missing-brief-ac-coverage"
python3 - "$TMP_DIR/tasks-missing-brief-ac-coverage/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
missing_ref = "artifact://brief/login-homepage-pilot.brief@v1#ac-005"
for task in payload["tasks"]:
    task["scope_item_refs"] = [
        ref for ref in task.get("scope_item_refs", []) if ref != missing_ref
    ]
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "tasks missing upstream brief acceptance criterion coverage" \
  "tasks scope_item_refs must cover brief acceptance_criteria" \
  /tmp/t6_tasks_missing_brief_ac_coverage.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/tasks-missing-brief-ac-coverage/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot" "$TMP_DIR/test-design-missing-brief-ac-coverage"
python3 - \
  "$TMP_DIR/test-design-missing-brief-ac-coverage/phase-1/unit-1/test-cases.json" \
  "$TMP_DIR/test-design-missing-brief-ac-coverage/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1])
tasks_path = Path(sys.argv[2])
test_cases = json.loads(test_cases_path.read_text(encoding="utf-8"))
test_cases["ac_coverage_matrix"] = [
    row for row in test_cases["ac_coverage_matrix"] if row.get("ac_id") != "AC-T2-1"
]
test_cases["traceability_matrix"] = [
    row
    for row in test_cases["traceability_matrix"]
    if row.get("ac_ref") != "UNIT-1.json#acceptance_criteria[1].ac_id"
]
test_cases_path.write_text(json.dumps(test_cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

tasks = json.loads(tasks_path.read_text(encoding="utf-8"))
for task in tasks["tasks"]:
    task["test_refs"] = [
        ref
        for ref in task.get("test_refs", [])
        if not ref.endswith("#AC-T2-1") and not ref.endswith("#traceability_matrix:2")
    ]
tasks_path.write_text(json.dumps(tasks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "test-design missing upstream brief acceptance criterion coverage" \
  "brief acceptance_criteria must map through UNIT and test-design coverage" \
  /tmp/t6_test_design_missing_brief_ac_coverage.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/test-design-missing-brief-ac-coverage/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/missing-design-obligation-refs"
python3 - "$TMP_DIR/missing-design-obligation-refs/phase-1/unit-1/test-cases.json" <<'PY'
import json
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1])
payload = json.loads(test_cases_path.read_text(encoding="utf-8"))
for row in payload["qa_handoff_contract"]:
        row["design_source_refs"] = [
            ref
            for ref in row.get("design_source_refs", [])
            if not (
                ref.startswith("design.json#key_decisions[")
                or ref.startswith("design.json#interfaces[")
            )
        ]
test_cases_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/missing-design-obligation-refs/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_design_obligation_refs.out 2>&1; then
  cat /tmp/t6_missing_design_obligation_refs.out >&2
  fail "readiness gate should reject test-cases.json when design key decisions or interfaces are not traceable"
fi

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/plan-missing-test-design-obligations"
python3 - "$TMP_DIR/plan-missing-test-design-obligations/phase-1/plan.json" <<'PY'
import json
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
payload = json.loads(plan_path.read_text(encoding="utf-8"))
payload["obligation_source_refs"] = []
plan_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "plan missing test-design obligation refs" \
  "plan obligation_source_refs must consume required test-design obligations" \
  /tmp/t6_plan_missing_test_design_obligations.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/plan-missing-test-design-obligations/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/tasks-missing-test-design-obligations"
python3 - "$TMP_DIR/tasks-missing-test-design-obligations/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
for task in payload["tasks"]:
    task["test_refs"] = [
        ref for ref in task.get("test_refs", [])
        if "qa_handoff_contract:" not in ref and "cross_unit_obligations:" not in ref
    ]
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "tasks missing test-design obligation refs" \
  "tasks test_refs must consume required test-design obligations" \
  /tmp/t6_tasks_missing_test_design_obligations.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/tasks-missing-test-design-obligations/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/tasks-missing-ac-coverage-refs"
python3 - "$TMP_DIR/tasks-missing-ac-coverage-refs/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
for task in payload["tasks"]:
    task["test_refs"] = [
        ref for ref in task.get("test_refs", [])
        if "#AC-" not in ref
    ]
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "tasks missing ac coverage refs" \
  "brief acceptance_criteria must map through UNIT and task test_refs" \
  /tmp/t6_tasks_missing_ac_coverage_refs.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/tasks-missing-ac-coverage-refs/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/tasks-missing-traceability-refs"
python3 - "$TMP_DIR/tasks-missing-traceability-refs/phase-1/tasks.json" <<'PY'
import json
import sys
from pathlib import Path

tasks_path = Path(sys.argv[1])
payload = json.loads(tasks_path.read_text(encoding="utf-8"))
for task in payload["tasks"]:
    task["test_refs"] = [
        ref for ref in task.get("test_refs", [])
        if "#traceability_matrix:" not in ref
    ]
tasks_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "tasks missing traceability refs" \
  "brief acceptance_criteria must map through UNIT and task test_refs" \
  /tmp/t6_tasks_missing_traceability_refs.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/tasks-missing-traceability-refs/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/qa-route-without-owner"
python3 - "$TMP_DIR/qa-route-without-owner/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
qa_payload = json.loads(qa_path.read_text(encoding="utf-8"))
qa_payload["gate_result"] = "PASS"
qa_payload["release_recommendation"] = "DEFER"
qa_path.write_text(json.dumps(qa_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$PHASE_VALIDATOR" \
  --phase-dir "$TMP_DIR/qa-route-without-owner/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" >/tmp/t6_qa_route_without_owner.out 2>&1; then
  cat /tmp/t6_qa_route_without_owner.out >&2
  fail "phase validator should reject non-release QA route without delivery-owner route fields"
fi
grep -Eq 'QA route matrix' /tmp/t6_qa_route_without_owner.out \
  || fail "QA route failure should name the QA route matrix"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/qa-route-with-owner"
python3 - \
  "$TMP_DIR/qa-route-with-owner/phase-1/qa-result.json" \
  "$TMP_DIR/qa-route-with-owner/phase-1/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
delivery_path = Path(sys.argv[2])

qa_payload = json.loads(qa_path.read_text(encoding="utf-8"))
qa_payload["gate_result"] = "PASS"
qa_payload["release_recommendation"] = "DEFER"
qa_path.write_text(json.dumps(qa_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

delivery_payload = json.loads(delivery_path.read_text(encoding="utf-8"))
delivery_payload["current_stage"] = "BLOCKED"
delivery_payload["status"] = "BLOCKED"
delivery_payload["control_action"] = "REQUEST_DECISION"
delivery_payload["blocker_id"] = "QA-ROUTE-001"
delivery_payload["blocker_owner"] = "delivery-owner"
delivery_payload["blocker_basis_refs"] = [
    "artifact://qa-result/sample-feature.phase-1.qa@v1#release"
]
delivery_payload["resume_stage"] = "SIGNOFF_PENDING"
delivery_payload["next_action"] = "resolve QA release route before signoff"
delivery_payload["resume_condition"] = "qa-result release_recommendation is ALLOW or user decision records accepted route"
for field in [
    "$.blocker_id",
    "$.blocker_owner",
    "$.blocker_basis_refs",
    "$.resume_stage",
    "$.next_action",
    "$.resume_condition",
]:
    if field not in delivery_payload["authoritative_fields"]:
        delivery_payload["authoritative_fields"].append(field)
delivery_path.write_text(json.dumps(delivery_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$PHASE_VALIDATOR" \
  --phase-dir "$TMP_DIR/qa-route-with-owner/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" >/dev/null \
  || fail "phase validator should accept non-release QA route when delivery-owner route fields are present"
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/qa-route-with-owner/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_qa_route_readiness.out 2>&1; then
  cat /tmp/t6_qa_route_readiness.out >&2
  fail "readiness gate should reject non-release QA route even when delivery-owner recorded the route"
fi
grep -Eq 'QA route matrix' /tmp/t6_qa_route_readiness.out \
  || fail "readiness QA route failure should name the QA route matrix"

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
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/duplicate-goal-closure/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_duplicate_goal_closure.out 2>&1; then
  cat /tmp/t6_duplicate_goal_closure.out >&2
  fail "readiness gate should reject signoff goal_closure that duplicates another goal while omitting a required business goal"
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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/accept-risk-pending-status"
python3 - \
  "$TMP_DIR/accept-risk-pending-status/phase-1/user-decision.json" \
  "$TMP_DIR/accept-risk-pending-status/phase-1/evidence/authority-proof.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

decision_path = Path(sys.argv[1])
proof_path = Path(sys.argv[2])

decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision["decision"] = "ACCEPT_RISK"
decision["business_risk_acceptance_status"] = "PENDING"
digest_payload = dict(decision)
digest_payload.pop("decision_payload_digest", None)
decision["decision_payload_digest"] = "sha256:" + hashlib.sha256(
    json.dumps(digest_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
decision_path.write_text(json.dumps(decision, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["decision_payload_digest"] = decision["decision_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "accept risk pending status" \
  "waiver_type requires business_risk_acceptance_status=ACCEPTED" \
  /tmp/t6_accept_risk_pending_status.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/accept-risk-pending-status/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/allow-pending-risk-status"
python3 - \
  "$TMP_DIR/allow-pending-risk-status/phase-1/signoff-package.json" \
  "$TMP_DIR/allow-pending-risk-status/phase-1/user-decision.json" \
  "$TMP_DIR/allow-pending-risk-status/phase-1/evidence/authority-proof.json" \
  "$TMP_DIR/allow-pending-risk-status/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
decision_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
oracle_path = Path(sys.argv[4])

signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["release_recommendation"] = "ALLOW"
signoff["business_risk_acceptance_status"] = "PENDING"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision["business_risk_acceptance_status"] = "PENDING"
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
oracle["artifacts"]["signoff-package"]["release_recommendation"] = "ALLOW"
oracle["artifacts"]["user-decision"]["decision_payload_digest"] = decision["decision_payload_digest"]
oracle["artifacts"]["user-decision"]["business_risk_acceptance_status"] = "PENDING"
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "allow pending risk status" \
  "business_risk_acceptance_status" \
  /tmp/t6_allow_pending_risk_status.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/allow-pending-risk-status/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/conditional-allow-without-waiver"
python3 - "$TMP_DIR/conditional-allow-without-waiver/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["waiver_entries"] = []
for row in signoff.get("goal_closure", []):
    if row.get("result") == "PARTIAL":
        row["result"] = "MET"
        row.pop("remaining_gap_text", None)
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "conditional allow without waiver" \
  "CONDITIONAL_ALLOW requires waiver_entries" \
  /tmp/t6_conditional_allow_without_waiver.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/conditional-allow-without-waiver/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/signoff-release-block"
python3 - \
  "$TMP_DIR/signoff-release-block/phase-1/signoff-package.json" \
  "$TMP_DIR/signoff-release-block/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
oracle_path = Path(sys.argv[2])

signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["release_recommendation"] = "BLOCK"
signoff["active_blocker"] = "remaining release blocker"
signoff["blocker_owner"] = "delivery-owner"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["signoff-package"]["release_recommendation"] = "BLOCK"
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "signoff release recommendation block" \
  "signoff-package release_recommendation" \
  /tmp/t6_signoff_release_block.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/signoff-release-block/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/expired-risk-waiver"
python3 - "$TMP_DIR/expired-risk-waiver/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["waiver_entries"][0]["expires_at"] = "2026-04-14T03:38:59Z"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "expired risk waiver" \
  "waiver_entries[1].expires_at" \
  /tmp/t6_expired_risk_waiver.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/expired-risk-waiver/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/signoff-runtime-evidence-anchor-drift"
python3 - "$TMP_DIR/signoff-runtime-evidence-anchor-drift/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
for row in signoff["runtime_evidence_matrix"]:
    if row.get("artifact_type") == "qa-result":
        row["artifact_ref"] = "artifact://qa-result/sample-feature.phase-1.qa@v1#gate-result"
        break
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "signoff runtime evidence unsupported anchor" \
  "unsupported artifact_ref anchor" \
  /tmp/t6_signoff_runtime_evidence_anchor_drift.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/signoff-runtime-evidence-anchor-drift/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/active-fix-result-missing-signoff-row"
python3 - \
  "$ROOT/shared/skills/fix/templates/fix-result.template.json" \
  "$TMP_DIR/active-fix-result-missing-signoff-row/phase-1/fix-result.json" \
  "$TMP_DIR/active-fix-result-missing-signoff-row/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
fix_path = Path(sys.argv[2])
registry_path = Path(sys.argv[3])
fix_result = json.loads(template_path.read_text(encoding="utf-8"))
fix_result["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
fix_path.write_text(json.dumps(fix_result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

registry = json.loads(registry_path.read_text(encoding="utf-8"))
registry["revisions"][-1]["entries"].append({
    "scope_ref": "artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal",
    "artifact_id": fix_result["artifact_id"],
    "artifact_type": "fix-result",
    "version": "v1",
    "artifact_path": "fix-result.json",
    "lifecycle_state": "FINALIZED",
    "active_for_consumption": True,
    "produced_by": "fix",
    "restore_basis_refs": [],
})
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "active fix-result missing signoff runtime evidence row" \
  "missing active runtime evidence" \
  /tmp/t6_active_fix_result_missing_signoff_row.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/active-fix-result-missing-signoff-row/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-stale-active-fix-result"
python3 - \
  "$ROOT/shared/skills/fix/templates/fix-result.template.json" \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-stale-active-fix-result/phase-1/fix-result.json" \
  "$TMP_DIR/target-change-stale-active-fix-result/phase-1/artifact-registry.json" \
  "$TMP_DIR/target-change-stale-active-fix-result/phase-1/signoff-package.json" \
  "$TMP_DIR/target-change-stale-active-fix-result/phase-1/target-change.json" \
  "$TMP_DIR/target-change-stale-active-fix-result/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

fix_template_path = Path(sys.argv[1])
target_template_path = Path(sys.argv[2])
fix_path = Path(sys.argv[3])
registry_path = Path(sys.argv[4])
signoff_path = Path(sys.argv[5])
target_path = Path(sys.argv[6])
proof_path = Path(sys.argv[7])
root = Path(sys.argv[8])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

active_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"

fix_result = json.loads(fix_template_path.read_text(encoding="utf-8"))
fix_result["produced_at"] = "2026-04-13T23:00:00Z"
fix_result["active_tasks_version_ref"] = active_tasks_ref
fix_path.write_text(json.dumps(fix_result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

registry = json.loads(registry_path.read_text(encoding="utf-8"))
registry["revisions"][-1]["entries"].append({
    "scope_ref": "artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal",
    "artifact_id": fix_result["artifact_id"],
    "artifact_type": "fix-result",
    "version": "v1",
    "artifact_path": "fix-result.json",
    "lifecycle_state": "FINALIZED",
    "active_for_consumption": True,
    "produced_by": "fix",
    "restore_basis_refs": [],
})
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["runtime_evidence_matrix"].append({
    "artifact_type": "fix-result",
    "artifact_ref": "artifact://fix-result/sample-feature.phase-1.fix@v1#completion-status",
    "producer": "fix",
    "status": "FIXED",
    "freshness_basis_ref": active_tasks_ref,
    "active_registry_proof": {
        "registry_ref": "artifact://artifact-registry/sample-feature.phase-1.artifact-registry@rev-4#active-entry:fix-result:sample-feature.phase-1.fix",
        "lifecycle_state": "FINALIZED",
        "active_for_consumption": True,
    },
    "stale_superseded_check": "CURRENT",
})
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

target = json.loads(target_template_path.read_text(encoding="utf-8"))
target["affected_refs"] = ["artifact://brief/sample-feature.brief@v1#ac-001"]
target["invalidates_refs"] = [old_tasks_ref]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change stale active fix-result freshness" \
  "target-change required_fresh_proof_after_rebaseline must include active runtime evidence artifacts: fix-result" \
  /tmp/t6_target_change_stale_active_fix_result.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-stale-active-fix-result/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

python3 - \
  "$TMP_DIR/target-change-stale-active-fix-result/phase-1/target-change.json" \
  "$TMP_DIR/target-change-stale-active-fix-result/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

target_path = Path(sys.argv[1])
proof_path = Path(sys.argv[2])
root = Path(sys.argv[3])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

target = json.loads(target_path.read_text(encoding="utf-8"))
target["required_fresh_proof_after_rebaseline"].append("fix-result")
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change stale active fix-result timestamp" \
  "target-change required fresh proof artifact is not newer than target-change" \
  /tmp/t6_target_change_stale_active_fix_result_timestamp.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-stale-active-fix-result/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

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

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/developer-report-without-active-entry"
python3 - "$TMP_DIR/developer-report-without-active-entry/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
payload["revisions"][-1]["entries"] = [
    entry
    for entry in payload["revisions"][-1]["entries"]
    if not (
        entry.get("artifact_type") == "developer-report"
        and entry.get("artifact_id") == "sample-feature.phase-1.unit-1.task-T1.developer-report"
    )
]
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract \
  "developer-report exists without active registry entry" \
  /tmp/t6_developer_report_without_active_entry.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/developer-report-without-active-entry/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/verify-result-wrong-active-task"
python3 - "$TMP_DIR/verify-result-wrong-active-task/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
entry = next(
    item
    for item in payload["revisions"][-1]["entries"]
    if item.get("artifact_type") == "verify-result"
    and item.get("artifact_id") == "sample-feature.phase-1.unit-1.task-T1.verify-result"
)
entry["scope_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T2"
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract \
  "verify-result active entry points to wrong task" \
  /tmp/t6_verify_result_wrong_active_task.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/verify-result-wrong-active-task/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/code-review-active-tasks-drift"
python3 - "$TMP_DIR/code-review-active-tasks-drift/phase-1/code-review-result.json" <<'PY'
import json
import sys
from pathlib import Path

review_path = Path(sys.argv[1])
payload = json.loads(review_path.read_text(encoding="utf-8"))
payload["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
review_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract \
  "code-review-result active_tasks_version_ref drift" \
  /tmp/t6_code_review_active_tasks_drift.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/code-review-active-tasks-drift/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/browser-required-without-evidence"
python3 - \
  "$TMP_DIR/browser-required-without-evidence/phase-1/unit-1/test-cases.json" \
  "$TMP_DIR/browser-required-without-evidence/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

test_cases_path = Path(sys.argv[1])
qa_result_path = Path(sys.argv[2])
test_cases = json.loads(test_cases_path.read_text(encoding="utf-8"))
for row in test_cases["qa_handoff_contract"]:
    if row.get("qa_stage") == "QA_B":
        row["execution_mode"] = "browser_required"
        break
test_cases_path.write_text(json.dumps(test_cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

qa_result = json.loads(qa_result_path.read_text(encoding="utf-8"))
qa_result.pop("browser_tool", None)
qa_result.pop("entry_url", None)
qa_result.pop("browser_evidence", None)
qa_result_path.write_text(json.dumps(qa_result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract \
  "browser-required QA lacks browser evidence" \
  /tmp/t6_browser_required_without_evidence.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/browser-required-without-evidence/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/consistency-owner-action-unconsumed"
python3 - \
  "$TMP_DIR/consistency-owner-action-unconsumed/phase-1/consistency-audit-result.json" \
  "$TMP_DIR/consistency-owner-action-unconsumed/phase-1/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

audit_path = Path(sys.argv[1])
state_path = Path(sys.argv[2])
audit = json.loads(audit_path.read_text(encoding="utf-8"))
audit["required_owner_action"] = ["ACTION-REBASELINE-001"]
audit_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
state = json.loads(state_path.read_text(encoding="utf-8"))
state["owner_action_consumption"] = []
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract \
  "consistency owner action is not consumed" \
  /tmp/t6_consistency_owner_action_unconsumed.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/consistency-owner-action-unconsumed/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/delivered-without-commit-result"
python3 - "$TMP_DIR/delivered-without-commit-result/phase-1/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
payload = json.loads(state_path.read_text(encoding="utf-8"))
payload["status"] = "DELIVERED"
payload["commit_state"] = "NOT_READY"
payload.pop("commit_result_ref", None)
payload.pop("equivalent_delivery_result_ref", None)
state_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "DELIVERED without commit or equivalent result" \
  "DELIVERED requires commit_result_ref or equivalent_delivery_result_ref" \
  /tmp/t6_delivered_without_commit_result.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/delivered-without-commit-result/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/ready-for-commit-without-handoff"
python3 - "$TMP_DIR/ready-for-commit-without-handoff/phase-1/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
payload = json.loads(state_path.read_text(encoding="utf-8"))
payload["status"] = "READY_FOR_COMMIT"
payload["commit_state"] = "NOT_READY"
payload.pop("commit_handoff_ref", None)
state_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "READY_FOR_COMMIT without commit handoff" \
  "READY_FOR_COMMIT requires commit_state=HANDOFF_PREPARED and commit_handoff_ref" \
  /tmp/t6_ready_for_commit_without_handoff.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/ready-for-commit-without-handoff/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-stale-signoff-evidence"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-stale-signoff-evidence/phase-1/target-change.json" \
  "$TMP_DIR/target-change-stale-signoff-evidence/phase-1/signoff-package.json" \
  "$TMP_DIR/target-change-stale-signoff-evidence/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
signoff_path = Path(sys.argv[3])
proof_path = Path(sys.argv[4])
root = Path(sys.argv[5])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest
target = json.loads(template_path.read_text(encoding="utf-8"))
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
target["baseline_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target["active_tasks_version_ref"] = signoff["active_tasks_version_ref"]
target["superseded_evidence_refs"] = [signoff["runtime_evidence_matrix"][0]["artifact_ref"]]
target["invalidates_refs"] = [
    "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry",
    signoff["runtime_evidence_matrix"][0]["artifact_ref"],
]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change superseded evidence remains in signoff matrix" \
  "target-change superseded evidence remains in signoff-package.runtime_evidence_matrix" \
  /tmp/t6_target_change_stale_signoff_evidence.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-stale-signoff-evidence/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-empty-invalidations"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-empty-invalidations/phase-1/target-change.json" \
  "$TMP_DIR/target-change-empty-invalidations/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
signoff_path = Path(sys.argv[3])
target = json.loads(template_path.read_text(encoding="utf-8"))
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
target["baseline_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target["active_tasks_version_ref"] = signoff["active_tasks_version_ref"]
for field in ("affected_refs", "invalidates_refs", "superseded_evidence_refs", "authority_proof_refs", "decision_basis_refs"):
    target[field] = []
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change empty invalidation refs" \
  "target-change affected_refs must be non-empty" \
  /tmp/t6_target_change_empty_invalidations.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-empty-invalidations/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-stale-task-baseline"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-stale-task-baseline/phase-1/target-change.json" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
target = json.loads(source_path.read_text(encoding="utf-8"))
target["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change stale task baseline" \
  "target-change active_tasks_version_ref must match delivery-state active_tasks_version_ref" \
  /tmp/t6_target_change_stale_task_baseline.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-stale-task-baseline/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-baseline-not-invalidated"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-baseline-not-invalidated/phase-1/target-change.json" \
  "$TMP_DIR/target-change-baseline-not-invalidated/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

active_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
target = json.loads(template_path.read_text(encoding="utf-8"))
target["baseline_tasks_version_ref"] = active_tasks_ref
target["active_tasks_version_ref"] = active_tasks_ref
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change baseline points at active tasks" \
  "target-change baseline_tasks_version_ref must point to the invalidated prior tasks baseline" \
  /tmp/t6_target_change_baseline_not_invalidated.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-baseline-not-invalidated/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-unresolved-invalidation-ref"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-unresolved-invalidation-ref/phase-1/target-change.json" \
  "$TMP_DIR/target-change-unresolved-invalidation-ref/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target = json.loads(template_path.read_text(encoding="utf-8"))
target["invalidates_refs"] = [
    old_tasks_ref,
    "artifact://verify-result/sample-feature.phase-1.unit-1.task-T999.verify-result@v1#verify-root",
]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change unresolved invalidation ref" \
  "target-change invalidates_refs[2] does not resolve to registry or known evidence" \
  /tmp/t6_target_change_unresolved_invalidation_ref.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-unresolved-invalidation-ref/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-unresolved-invalidation-anchor"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-unresolved-invalidation-anchor/phase-1/target-change.json" \
  "$TMP_DIR/target-change-unresolved-invalidation-anchor/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target = json.loads(template_path.read_text(encoding="utf-8"))
target["invalidates_refs"] = [
    old_tasks_ref,
    old_tasks_ref.replace("#task-registry", "#not-task-registry"),
]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change unresolved invalidation anchor" \
  "target-change invalidates_refs[2] does not resolve to registry or known evidence" \
  /tmp/t6_target_change_unresolved_invalidation_anchor.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-unresolved-invalidation-anchor/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-registered-self-ref"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-registered-self-ref/phase-1/target-change.json" \
  "$TMP_DIR/target-change-registered-self-ref/phase-1/artifact-registry.json" \
  "$TMP_DIR/target-change-registered-self-ref/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
registry_path = Path(sys.argv[3])
proof_path = Path(sys.argv[4])
root = Path(sys.argv[5])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
bogus_ref = "artifact://verify-result/sample-feature.phase-1.unit-1.task-T999.verify-result@v1#verify-root"
target = json.loads(template_path.read_text(encoding="utf-8"))
target["invalidates_refs"] = [old_tasks_ref, bogus_ref]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
registry = json.loads(registry_path.read_text(encoding="utf-8"))
active_revision = next(
    revision
    for revision in registry["revisions"]
    if revision["revision_id"] == registry["active_revision_id"]
)
active_revision["entries"].append(
    {
        "scope_ref": "artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal",
        "artifact_id": "sample-feature.phase-1.target-change",
        "artifact_type": "target-change",
        "version": "v1",
        "artifact_path": "target-change.json",
        "lifecycle_state": "FINALIZED",
        "active_for_consumption": True,
        "produced_by": "delivery-owner",
        "restore_basis_refs": [],
    }
)
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change registered self ref cannot authorize bogus invalidation" \
  "target-change invalidates_refs[2] does not resolve to registry or known evidence" \
  /tmp/t6_target_change_registered_self_ref.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-registered-self-ref/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-signoff-extra-ref-echo"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-signoff-extra-ref-echo/phase-1/target-change.json" \
  "$TMP_DIR/target-change-signoff-extra-ref-echo/phase-1/signoff-package.json" \
  "$TMP_DIR/target-change-signoff-extra-ref-echo/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
signoff_path = Path(sys.argv[3])
proof_path = Path(sys.argv[4])
root = Path(sys.argv[5])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
bogus_ref = "artifact://verify-result/sample-feature.phase-1.unit-1.task-T999.verify-result@v1#verify-root"
target = json.loads(template_path.read_text(encoding="utf-8"))
target["invalidates_refs"] = [old_tasks_ref, bogus_ref]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["unvalidated_ref_echo"] = bogus_ref
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change signoff extra field cannot authorize bogus invalidation" \
  "target-change invalidates_refs[2] does not resolve to registry or known evidence" \
  /tmp/t6_target_change_signoff_extra_ref_echo.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-signoff-extra-ref-echo/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-missing-authority-proof"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-missing-authority-proof/phase-1/target-change.json" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
target = json.loads(source_path.read_text(encoding="utf-8"))
target["authority_proof_refs"] = [
    "artifact://evidence/sample-feature.phase-1.authority-proof@ev-missing#proof-root"
]
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change missing authority proof" \
  "target-change authority proof not found" \
  /tmp/t6_target_change_missing_authority_proof.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-missing-authority-proof/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-unknown-change-source"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-unknown-change-source/phase-1/target-change.json" \
  "$TMP_DIR/target-change-unknown-change-source/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

target = json.loads(template_path.read_text(encoding="utf-8"))
target["change_source"] = "manual-override"
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change unknown change source" \
  "target-change change_source must be authenticated-target-change" \
  /tmp/t6_target_change_unknown_change_source.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-unknown-change-source/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-payload-tamper"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-payload-tamper/phase-1/target-change.json" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
target = json.loads(template_path.read_text(encoding="utf-8"))
target["affected_refs"] = ["artifact://brief/sample-feature.brief@v1#ac-999"]
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change payload tamper without digest refresh" \
  "target-change target_change_payload_digest does not match payload" \
  /tmp/t6_target_change_payload_tamper.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-payload-tamper/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-missing-runtime-fresh-proof"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-missing-runtime-fresh-proof/phase-1/target-change.json" \
  "$TMP_DIR/target-change-missing-runtime-fresh-proof/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

target = json.loads(template_path.read_text(encoding="utf-8"))
old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target["invalidates_refs"] = [old_tasks_ref]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["required_fresh_proof_after_rebaseline"] = [
    item
    for item in target["required_fresh_proof_after_rebaseline"]
    if item != "qa-result"
]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change missing runtime fresh proof type" \
  "target-change required_fresh_proof_after_rebaseline must include active runtime evidence artifacts" \
  /tmp/t6_target_change_missing_runtime_fresh_proof.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-missing-runtime-fresh-proof/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-authority-digest-mismatch"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-authority-digest-mismatch/phase-1/target-change.json" \
  "$TMP_DIR/target-change-authority-digest-mismatch/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest
target = json.loads(template_path.read_text(encoding="utf-8"))
old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target["invalidates_refs"] = [old_tasks_ref]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = "sha256:" + "0" * 64
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change authority proof digest mismatch" \
  "target-change authority_proof_refs[1] target_change_payload_digest does not match target-change" \
  /tmp/t6_target_change_authority_digest_mismatch.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-authority-digest-mismatch/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-fresh-proof-equal-to-change"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-fresh-proof-equal-to-change/phase-1/target-change.json" \
  "$TMP_DIR/target-change-fresh-proof-equal-to-change/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest

target = json.loads(template_path.read_text(encoding="utf-8"))
old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target["produced_at"] = "2026-04-14T00:00:00Z"
target["invalidates_refs"] = [old_tasks_ref]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change fresh proof equal to target-change" \
  "target-change required fresh proof artifact is not newer than target-change" \
  /tmp/t6_target_change_fresh_proof_equal_to_change.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-fresh-proof-equal-to-change/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-fresh-proof-older-than-change"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-fresh-proof-older-than-change/phase-1/target-change.json" \
  "$TMP_DIR/target-change-fresh-proof-older-than-change/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest
target = json.loads(template_path.read_text(encoding="utf-8"))
old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target["produced_at"] = "2026-04-30T00:00:00Z"
target["invalidates_refs"] = [old_tasks_ref]
target["superseded_evidence_refs"] = [old_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["verified_until"] = "2026-05-01T00:00:00Z"
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change fresh proof older than target-change" \
  "target-change required fresh proof artifact is not newer than target-change" \
  /tmp/t6_target_change_fresh_proof_older_than_change.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-fresh-proof-older-than-change/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/code-review-evidence-integrity-finding"
python3 - "$TMP_DIR/code-review-evidence-integrity-finding/phase-1/code-review-result.json" <<'PY'
import json
import sys
from pathlib import Path

review_path = Path(sys.argv[1])
payload = json.loads(review_path.read_text(encoding="utf-8"))
payload["evidence_integrity"]["applicability"] = "applicable"
payload["evidence_integrity"]["trigger_refs"] = [
    "artifact://code-review-result/sample-feature.phase-1.review@v1#manual-negative"
]
payload["evidence_integrity"]["checks"][0]["status"] = "FINDING"
review_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "code-review evidence integrity finding" \
  "code-review-result evidence_integrity contains blocking status" \
  /tmp/t6_code_review_evidence_integrity_finding.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/code-review-evidence-integrity-finding/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/code-review-evidence-integrity-not-applicable"
python3 - "$TMP_DIR/code-review-evidence-integrity-not-applicable/phase-1/code-review-result.json" <<'PY'
import json
import sys
from pathlib import Path

review_path = Path(sys.argv[1])
payload = json.loads(review_path.read_text(encoding="utf-8"))
payload["evidence_integrity"]["applicability"] = "applicable"
payload["evidence_integrity"]["trigger_refs"] = [
    "artifact://code-review-result/sample-feature.phase-1.review@v1#manual-negative"
]
payload["evidence_integrity"]["checks"][0]["status"] = "NOT_APPLICABLE"
review_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "code-review evidence integrity applicable NOT_APPLICABLE" \
  "applicable checks must not be NOT_APPLICABLE" \
  /tmp/t6_code_review_evidence_integrity_not_applicable.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/code-review-evidence-integrity-not-applicable/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/qa-active-tasks-drift-with-synced-signoff"
python3 - \
  "$TMP_DIR/qa-active-tasks-drift-with-synced-signoff/phase-1/qa-result.json" \
  "$TMP_DIR/qa-active-tasks-drift-with-synced-signoff/phase-1/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
signoff_path = Path(sys.argv[2])
old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
qa = json.loads(qa_path.read_text(encoding="utf-8"))
qa["active_tasks_version_ref"] = old_tasks_ref
qa_path.write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
for row in signoff["runtime_evidence_matrix"]:
    if row.get("artifact_type") == "qa-result":
        row["freshness_basis_ref"] = old_tasks_ref
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "qa-result active tasks drift hidden by signoff matrix" \
  "runtime evidence active_tasks_version_ref must match active delivery-state tasks ref" \
  /tmp/t6_qa_active_tasks_drift_with_synced_signoff.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/qa-active-tasks-drift-with-synced-signoff/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/target-change-invalidates-active-tasks"
python3 - \
  "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" \
  "$TMP_DIR/target-change-invalidates-active-tasks/phase-1/target-change.json" \
  "$TMP_DIR/target-change-invalidates-active-tasks/phase-1/evidence/authority-proof.json" \
  "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
root = Path(sys.argv[4])
sys.path.insert(0, str(root / "tools/community"))
from write_user_decision import canonical_digest
active_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
old_tasks_ref = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
target = json.loads(template_path.read_text(encoding="utf-8"))
target["baseline_tasks_version_ref"] = old_tasks_ref
target["active_tasks_version_ref"] = active_tasks_ref
target["affected_refs"] = [active_tasks_ref]
target["invalidates_refs"] = [old_tasks_ref, active_tasks_ref]
target["superseded_evidence_refs"] = [old_tasks_ref, active_tasks_ref]
target["target_change_payload_digest"] = canonical_digest(target)
target_path.write_text(json.dumps(target, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
proof = json.loads(proof_path.read_text(encoding="utf-8"))
proof["target_change_payload_digest"] = target["target_change_payload_digest"]
proof_path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "target-change invalidates active tasks freshness basis" \
  "target-change superseded evidence remains in signoff-package.runtime_evidence_matrix" \
  /tmp/t6_target_change_invalidates_active_tasks.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/target-change-invalidates-active-tasks/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/artifact-registry-active-not-latest"
python3 - "$TMP_DIR/artifact-registry-active-not-latest/phase-1/artifact-registry.json" <<'PY'
import copy
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
shadow = copy.deepcopy(payload["revisions"][-1])
shadow["revision_id"] = "rev-shadow"
shadow["parent_revision_id"] = payload["revisions"][-1]["revision_id"]
payload["revisions"].append(shadow)
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "artifact registry active revision not latest" \
  "active_revision_id must point to last revision" \
  /tmp/t6_artifact_registry_active_not_latest.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/artifact-registry-active-not-latest/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/signoff-package-pending-status"
python3 - \
  "$TMP_DIR/signoff-package-pending-status/phase-1/signoff-package.json" \
  "$TMP_DIR/signoff-package-pending-status/phase-1/user-decision.json" \
  "$TMP_DIR/signoff-package-pending-status/phase-1/evidence/authority-proof.json" \
  "$TMP_DIR/signoff-package-pending-status/phase-1/replay/phase-operational.replay-oracle.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

signoff_path = Path(sys.argv[1])
decision_path = Path(sys.argv[2])
proof_path = Path(sys.argv[3])
oracle_path = Path(sys.argv[4])

signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["sign_off_status"] = "PENDING"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

decision = json.loads(decision_path.read_text(encoding="utf-8"))
decision["decision"] = "ACCEPT_RISK"
decision["sign_off_status"] = "SIGNED_OFF"
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
oracle["artifacts"]["user-decision"]["sign_off_status"] = "SIGNED_OFF"
oracle["artifacts"]["user-decision"]["decision_payload_digest"] = decision["decision_payload_digest"]
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_block_contract_reason \
  "signoff package pending status" \
  "signoff-package sign_off_status must be SIGNED_OFF" \
  /tmp/t6_signoff_package_pending_status.out \
  python3 "$SCRIPT" \
    --phase-dir "$TMP_DIR/signoff-package-pending-status/phase-1" \
    --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
    --profiles "$ROOT/shared/runtime/replay-profiles.json"

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
