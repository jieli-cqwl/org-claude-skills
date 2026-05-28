#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-foundation"
NEGATIVE_ROOT="$FIXTURE_ROOT/negative"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

prepare_phase_dir() {
  local scenario_file="$1"
  local phase_dir="$2"
  mkdir -p "$phase_dir"
  cp "$scenario_file" "$phase_dir/scenario.json"
  python3 - "$scenario_file" "$phase_dir" <<'PY'
import json
import sys
from pathlib import Path

scenario = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
phase_dir = Path(sys.argv[2])
for rel_path, content in scenario.get("files", {}).items():
    target = phase_dir / rel_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
PY
}

for path in \
  "$NEGATIVE_ROOT/missing-anchor.json" \
  "$NEGATIVE_ROOT/illegal-transition.json" \
  "$NEGATIVE_ROOT/mixed-version.json" \
  "$NEGATIVE_ROOT/stale-evidence.json" \
  "$NEGATIVE_ROOT/authority-mismatch.json" \
  "$NEGATIVE_ROOT/closure-break.json"; do
  [ -f "$path" ] || fail "missing negative fixture: ${path#"$ROOT"/}"
done

for tool in \
  "$ROOT/tools/community/normalize_canonical_artifact.py" \
  "$ROOT/tools/community/validate_canonical_schema.py" \
  "$ROOT/tools/community/validate_canonical_rules.py" \
  "$ROOT/tools/community/resolve_evidence_refs.py" \
  "$ROOT/tools/community/validate_projection_manifest.py" \
  "$ROOT/tools/community/validate_standard_chain_phase.py"; do
  [ -f "$tool" ] || fail "missing validator tool: ${tool#"$ROOT"/}"
done

python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
template = json.loads(
    (root / "shared/skills/delivery-owner/templates/artifact-registry.template.json").read_text(encoding="utf-8")
)
schema = json.loads(
    (root / "shared/skills/delivery-owner/contracts/artifact-registry.schema.json").read_text(encoding="utf-8")
)
active_revision_id = template["active_revision_id"]
active_revision = next(
    revision
    for revision in template["revisions"]
    if revision["revision_id"] == active_revision_id
)
active_types = {
    entry["artifact_type"]
    for entry in active_revision["entries"]
    if entry.get("active_for_consumption") is True
}
required_runtime_types = {
    "developer-report",
    "verify-result",
    "code-review-result",
    "qa-result",
    "consistency-audit-result",
}
missing = sorted(required_runtime_types - active_types)
if missing:
    raise SystemExit(f"artifact registry template missing active runtime artifact types: {missing}")

policy = template.get("runtime_artifact_policy", {})
if policy.get("active_uniqueness") != "one_active_entry_per_scope_artifact_type":
    raise SystemExit("artifact registry template must declare active runtime uniqueness policy")
if set(policy.get("required_runtime_artifacts", [])) != required_runtime_types:
    raise SystemExit("artifact registry template must declare required runtime artifact types")

props = schema["allOf"][1]["properties"]
if "runtime_artifact_policy" not in props:
    raise SystemExit("artifact registry schema must define runtime_artifact_policy")
PY

positive_scenario="$TMP_DIR/positive-scenario.json"
python3 - "$ROOT" "$positive_scenario" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
target = Path(sys.argv[2])

delivery_state = json.loads(
    (root / "tests/fixtures/standard-chain-foundation/runtime/baseline/delivery-state.json").read_text(encoding="utf-8")
)
tasks = json.loads(
    (root / "tests/fixtures/standard-chain-foundation/runtime/baseline/tasks.json").read_text(encoding="utf-8")
)
qa_result = json.loads(
    (root / "shared/skills/qa/templates/qa-result.template.json").read_text(encoding="utf-8")
)
projection_manifest = json.loads(
    (
        root
        / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/views/phase-operational.projection-manifest.json"
    ).read_text(encoding="utf-8")
)
rendered_html = "<html><body><section id='phase-summary'>summary</section></body></html>\n"
projection_manifest["rendered_content_digest"] = "sha256:" + hashlib.sha256(rendered_html.encode("utf-8")).hexdigest()

scenario = {
    "artifacts": [
        delivery_state,
        tasks,
        qa_result,
        projection_manifest,
    ],
    "tasks_registry": tasks,
    "transition": {
        "current_stage": "TASK_EXECUTION",
        "next_stage": "TASK_VERIFICATION",
    },
    "upstream_closure": {
        "goals": [
            "artifact://brief/sample-feature.brief@v1#goal-001",
        ],
        "goal_closure": [
            {
                "source_ref": "artifact://brief/sample-feature.brief@v1#goal-001",
                "result": "MET",
            }
        ],
        "constraints": [
            "artifact://phase-prd/sample-feature.phase-1.prd@v1#constraint-001",
        ],
        "constraint_source_refs": [
            "artifact://phase-prd/sample-feature.phase-1.prd@v1#constraint-001",
        ],
        "constraint_na": [],
        "obligations": [
            "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#handoff-001",
        ],
        "obligation_source_refs": [
            "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#handoff-001",
        ],
        "gate_rows": [
            "artifact://qa-result/sample-feature.phase-1.qa@v1#gate-001",
        ],
        "gate_consumption": [
            "artifact://qa-result/sample-feature.phase-1.qa@v1#gate-001",
        ],
    },
    "evidence_records": [
        {
            "evidence_id": "ev-positive",
            "type": "browser-trace",
            "producer": "qa",
            "created_at": "2026-04-14T00:00:00Z",
            "observed_at": "2026-04-14T00:05:00Z",
            "relation_type": "proves",
            "ref_target": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#plan-version",
            "artifact_path": "evidence/browser-trace.json",
            "target_path": "targets/plan.txt",
            "anchor": "plan-version",
            "consumer_produced_at": "2026-04-14T01:00:00Z",
            "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#plan-version",
        }
    ],
    "projection": {
        "manifest_artifact_id": projection_manifest["artifact_id"],
        "rendered_artifact_path": "rendered/phase-operational.html",
        "available_source_refs": projection_manifest["source_artifact_refs"],
    },
    "files": {
        "targets/plan.txt": "plan-version\nscope-freeze\n",
        "rendered/phase-operational.html": rendered_html,
    },
}
target.write_text(json.dumps(scenario, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

positive_phase_dir="$TMP_DIR/positive-phase"
prepare_phase_dir "$positive_scenario" "$positive_phase_dir"
golden_phase_dir="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"

qa_missing_task_verify_dir="$TMP_DIR/qa-missing-task-verify/sample-feature"
mkdir -p "$TMP_DIR/qa-missing-task-verify"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$qa_missing_task_verify_dir"
rm -f "$qa_missing_task_verify_dir/phase-1/unit-1/tasks/T2/verify-result.json"
if python3 "$ROOT/shared/skills/qa/scripts/preflight_check.py" \
  --phase-dir "$qa_missing_task_verify_dir/phase-1" >"$TMP_DIR/qa-missing-task-verify.out"; then
  cat "$TMP_DIR/qa-missing-task-verify.out" >&2
  fail "qa preflight should reject when any frozen task lacks current verify-result PASS"
fi
python3 - "$TMP_DIR/qa-missing-task-verify.out" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] in {"MISSING_INPUT", "VERIFIER_NOT_PASS"}
assert any("T2" in item or "verify-result" in item for item in payload["missing_inputs"])
PY

qa_inactive_task_verify_dir="$TMP_DIR/qa-inactive-task-verify/sample-feature"
mkdir -p "$TMP_DIR/qa-inactive-task-verify"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$qa_inactive_task_verify_dir"
python3 - "$qa_inactive_task_verify_dir/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
active_revision_id = payload["active_revision_id"]
for revision in payload["revisions"]:
    if revision["revision_id"] != active_revision_id:
        continue
    for entry in revision["entries"]:
        if (
            entry.get("artifact_type") == "verify-result"
            and entry.get("artifact_path") == "unit-1/tasks/T2/verify-result.json"
        ):
            entry["active_for_consumption"] = False
registry_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/shared/skills/qa/scripts/preflight_check.py" \
  --phase-dir "$qa_inactive_task_verify_dir/phase-1" >"$TMP_DIR/qa-inactive-task-verify.out"; then
  cat "$TMP_DIR/qa-inactive-task-verify.out" >&2
  fail "qa preflight should reject filesystem verify-result without active registry binding"
fi
python3 - "$TMP_DIR/qa-inactive-task-verify.out" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "MISSING_INPUT"
assert any("T2" in item and "verify-result" in item for item in payload["missing_inputs"])
PY

qa_stale_task_verify_dir="$TMP_DIR/qa-stale-task-verify/sample-feature"
mkdir -p "$TMP_DIR/qa-stale-task-verify"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$qa_stale_task_verify_dir"
python3 - "$qa_stale_task_verify_dir/phase-1/unit-1/tasks/T2/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["baseline_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/shared/skills/qa/scripts/preflight_check.py" \
  --phase-dir "$qa_stale_task_verify_dir/phase-1" >"$TMP_DIR/qa-stale-task-verify.out"; then
  cat "$TMP_DIR/qa-stale-task-verify.out" >&2
  fail "qa preflight should reject stale verify-result task version refs"
fi
python3 - "$TMP_DIR/qa-stale-task-verify.out" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "VERIFIER_NOT_PASS"
assert any("T2" in item and "verify-result" in item for item in payload["missing_inputs"])
PY

qa_spec_ok_gate_dir="$TMP_DIR/qa-spec-ok-gate/sample-feature"
mkdir -p "$TMP_DIR/qa-spec-ok-gate"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$qa_spec_ok_gate_dir"
python3 - "$qa_spec_ok_gate_dir/phase-1/unit-1/tasks/T2/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["gate_result"] = "SPEC_OK"
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/shared/skills/qa/scripts/preflight_check.py" \
  --phase-dir "$qa_spec_ok_gate_dir/phase-1" >"$TMP_DIR/qa-spec-ok-gate.out"; then
  cat "$TMP_DIR/qa-spec-ok-gate.out" >&2
  fail "qa preflight should reject final verify-result gate_result=SPEC_OK"
fi
python3 - "$TMP_DIR/qa-spec-ok-gate.out" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "VERIFIER_NOT_PASS"
assert any("T2" in item and "verify-result" in item for item in payload["missing_inputs"])
PY

verify_schema_spec_ok_dir="$TMP_DIR/verify-schema-spec-ok"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$verify_schema_spec_ok_dir"
python3 - "$verify_schema_spec_ok_dir/phase-1/unit-1/tasks/T1/verify-result.json" <<'PY'
import json
import sys
from pathlib import Path

verify_path = Path(sys.argv[1])
payload = json.loads(verify_path.read_text(encoding="utf-8"))
payload["gate_result"] = "SPEC_OK"
verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" \
  --phase-dir "$verify_schema_spec_ok_dir/phase-1" >"$TMP_DIR/verify-schema-spec-ok.out" 2>&1; then
  cat "$TMP_DIR/verify-schema-spec-ok.out" >&2
  fail "schema validator should reject final verify-result gate_result=SPEC_OK"
fi

normalized_output="$TMP_DIR/normalized.json"
python3 "$ROOT/tools/community/normalize_canonical_artifact.py" \
  --fixture "$positive_scenario" >"$normalized_output" || fail "normalizer should pass"

python3 "$ROOT/tools/community/validate_canonical_schema.py" \
  --phase-dir "$positive_phase_dir" >/dev/null || fail "schema validator should pass"

bad_delivery_stage="$TMP_DIR/bad-delivery-stage.json"
python3 - "$positive_scenario" "$bad_delivery_stage" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "delivery-state":
        artifact["current_stage"] = "READY_FOR_COMMIT"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_delivery_stage" >/tmp/t3_bad_delivery_stage.out 2>&1; then
  cat /tmp/t3_bad_delivery_stage.out >&2
  fail "schema validator should reject delivery-state current_stage outside shared-core vocabulary"
fi

bad_delivery_action="$TMP_DIR/bad-delivery-action.json"
python3 - "$positive_scenario" "$bad_delivery_action" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "delivery-state":
        artifact["control_action"] = "DISPATCH_READY"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_delivery_action" >/tmp/t3_bad_delivery_action.out 2>&1; then
  cat /tmp/t3_bad_delivery_action.out >&2
  fail "schema validator should reject delivery-state control_action outside shared-core vocabulary"
fi

blocked_missing_recovery="$TMP_DIR/blocked-missing-recovery.json"
python3 - "$positive_scenario" "$blocked_missing_recovery" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "delivery-state":
        artifact["current_stage"] = "BLOCKED"
        artifact["status"] = "BLOCKED"
        artifact["control_action"] = "BLOCK"
        for key in (
            "blocker_id",
            "blocker_owner",
            "blocker_basis_refs",
            "resume_stage",
            "next_action",
            "resume_condition",
        ):
            artifact.pop(key, None)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$blocked_missing_recovery" >/tmp/t3_blocked_missing_recovery.out 2>&1; then
  cat /tmp/t3_blocked_missing_recovery.out >&2
  fail "schema validator should reject blocked delivery-state without recovery fields"
fi

bad_progress_owner_changed="$TMP_DIR/bad-progress-owner-changed.json"
python3 - "$positive_scenario" "$bad_progress_owner_changed" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "delivery-state":
        artifact["progress_signal"] = "owner_changed"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_progress_owner_changed" >/tmp/t3_bad_progress_owner_changed.out 2>&1; then
  cat /tmp/t3_bad_progress_owner_changed.out >&2
  fail "schema validator should reject delivery-state progress_signal=owner_changed"
fi

bad_progress_new_evidence="$TMP_DIR/bad-progress-new-evidence.json"
python3 - "$positive_scenario" "$bad_progress_new_evidence" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "delivery-state":
        artifact["progress_signal"] = "new_evidence"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_progress_new_evidence" >/tmp/t3_bad_progress_new_evidence.out 2>&1; then
  cat /tmp/t3_bad_progress_new_evidence.out >&2
  fail "schema validator should reject generic delivery-state progress_signal=new_evidence"
fi

bad_owner_action_consumption="$TMP_DIR/bad-owner-action-consumption.json"
python3 - "$positive_scenario" "$bad_owner_action_consumption" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "delivery-state":
        artifact["owner_action_consumption"] = [
            {
                "required_owner": "tech-lead",
                "result": "ROUTED"
            }
        ]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_owner_action_consumption" >/tmp/t3_bad_owner_action_consumption.out 2>&1; then
  cat /tmp/t3_bad_owner_action_consumption.out >&2
  fail "schema validator should reject incomplete owner_action_consumption entries"
fi

python3 - "$ROOT" <<'PY' || fail "installed fallback schema validator should resolve nested allOf refs"
import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[1]) / "tools/community"))
from simple_json_schema import SimpleSchemaValidator

schema = {
    "$id": "https://example.local/schema.json",
    "allOf": [
        {"type": "object"},
        {
            "$defs": {
                "stringArray": {
                    "type": "array",
                    "items": {"type": "string"},
                }
            },
            "type": "object",
            "properties": {
                "items": {"$ref": "#/allOf/1/$defs/stringArray"},
            },
        },
    ],
}
SimpleSchemaValidator({schema["$id"]: schema}).validate({"items": ["ok"]}, schema)
PY

python3 "$ROOT/tools/community/validate_canonical_rules.py" \
  --phase-dir "$positive_phase_dir" >/dev/null || fail "rule validator should pass"

legacy_extra="$TMP_DIR/legacy-extra.json"
python3 - "$positive_scenario" "$legacy_extra" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["coverage_matrix"] = []
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
legacy_extra_dir="$TMP_DIR/legacy-extra"
prepare_phase_dir "$legacy_extra" "$legacy_extra_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$legacy_extra_dir" >/tmp/t3_legacy_extra.out 2>&1; then
  cat /tmp/t3_legacy_extra.out >&2
  fail "rule validator should reject legacy extra fields even when schemas allow forward-compatible extensions"
fi

draft_leak="$TMP_DIR/draft-leak.json"
python3 - "$positive_scenario" "$draft_leak" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["draft_trace"] = ["process draft output must not freeze"]
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["candidate_fields"] = {"proving_command": "pytest -q"}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
draft_leak_dir="$TMP_DIR/draft-leak"
prepare_phase_dir "$draft_leak" "$draft_leak_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$draft_leak_dir" >/tmp/t3_draft_leak.out 2>&1; then
  cat /tmp/t3_draft_leak.out >&2
  fail "rule validator should reject draft/candidate leakage in frozen plan/tasks artifacts"
fi
rg -n 'draft/candidate process leakage' /tmp/t3_draft_leak.out >/dev/null 2>&1 || {
  cat /tmp/t3_draft_leak.out >&2
  fail "rule validator should explain draft/candidate leakage"
}

task_contract_noise="$TMP_DIR/task-contract-noise.json"
python3 - "$positive_scenario" "$task_contract_noise" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["field_laundry_list"] = ["task_id", "phase_ref"]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
task_contract_noise_dir="$TMP_DIR/task-contract-noise"
prepare_phase_dir "$task_contract_noise" "$task_contract_noise_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$task_contract_noise_dir" >/tmp/t3_task_contract_noise.out 2>&1; then
  cat /tmp/t3_task_contract_noise.out >&2
  fail "rule validator should reject unsupported task contract fields"
fi
rg -n 'unsupported fields' /tmp/t3_task_contract_noise.out >/dev/null 2>&1 || {
  cat /tmp/t3_task_contract_noise.out >&2
  fail "task contract field-noise failure should name unsupported fields"
}

empty_task_source="$TMP_DIR/empty-task-source.json"
python3 - "$positive_scenario" "$empty_task_source" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["scope_item_refs"] = []
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
empty_task_source_dir="$TMP_DIR/empty-task-source"
prepare_phase_dir "$empty_task_source" "$empty_task_source_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$empty_task_source_dir" >/tmp/t3_empty_task_source.out 2>&1; then
  cat /tmp/t3_empty_task_source.out >&2
  fail "rule validator should reject tasks without source refs"
fi
rg -n 'scope_item_refs' /tmp/t3_empty_task_source.out >/dev/null 2>&1 || {
  cat /tmp/t3_empty_task_source.out >&2
  fail "empty source-ref failure should name scope_item_refs"
}

empty_acceptance_targets="$TMP_DIR/empty-acceptance-targets.json"
python3 - "$positive_scenario" "$empty_acceptance_targets" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["acceptance_targets"] = []
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
empty_acceptance_targets_dir="$TMP_DIR/empty-acceptance-targets"
prepare_phase_dir "$empty_acceptance_targets" "$empty_acceptance_targets_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$empty_acceptance_targets_dir" >/tmp/t3_empty_acceptance_targets.out 2>&1; then
  cat /tmp/t3_empty_acceptance_targets.out >&2
  fail "rule validator should reject tasks without acceptance targets"
fi
rg -n 'acceptance_targets' /tmp/t3_empty_acceptance_targets.out >/dev/null 2>&1 || {
  cat /tmp/t3_empty_acceptance_targets.out >&2
  fail "empty acceptance-target failure should name acceptance_targets"
}

task_dependency_cycle="$TMP_DIR/task-dependency-cycle.json"
python3 - "$positive_scenario" "$task_dependency_cycle" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["depends_on"] = ["T2"]
        artifact["tasks"][1]["depends_on"] = ["T1"]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
task_dependency_cycle_dir="$TMP_DIR/task-dependency-cycle"
prepare_phase_dir "$task_dependency_cycle" "$task_dependency_cycle_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$task_dependency_cycle_dir" >/tmp/t3_task_dependency_cycle.out 2>&1; then
  cat /tmp/t3_task_dependency_cycle.out >&2
  fail "rule validator should reject task dependency cycles"
fi
rg -n 'depends_on cycle' /tmp/t3_task_dependency_cycle.out >/dev/null 2>&1 || {
  cat /tmp/t3_task_dependency_cycle.out >&2
  fail "dependency cycle failure should name depends_on cycle"
}

# investment_risk_signals must be accepted as a valid task field
risk_signals_scenario="$TMP_DIR/risk-signals.json"
python3 - "$positive_scenario" "$risk_signals_scenario" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["investment_risk_signals"] = ["heavy", "risky"]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
risk_signals_dir="$TMP_DIR/risk-signals"
prepare_phase_dir "$risk_signals_scenario" "$risk_signals_dir"
python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$risk_signals_dir" >/tmp/t3_risk_signals.out 2>&1 || {
  cat /tmp/t3_risk_signals.out >&2
  fail "rule validator should accept investment_risk_signals as valid task field"
}

# same-batch dependency must be rejected
batch_dep_conflict="$TMP_DIR/batch-dep-conflict.json"
python3 - "$positive_scenario" "$batch_dep_conflict" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["batch"] = 1
        artifact["tasks"][1]["batch"] = 1
        artifact["tasks"][1]["depends_on"] = ["T1"]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
batch_dep_conflict_dir="$TMP_DIR/batch-dep-conflict"
prepare_phase_dir "$batch_dep_conflict" "$batch_dep_conflict_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$batch_dep_conflict_dir" >/tmp/t3_batch_dep_conflict.out 2>&1; then
  cat /tmp/t3_batch_dep_conflict.out >&2
  fail "rule validator should reject same-batch dependency"
fi
rg -n 'both are in batch' /tmp/t3_batch_dep_conflict.out >/dev/null 2>&1 || {
  cat /tmp/t3_batch_dep_conflict.out >&2
  fail "same-batch dependency failure should name conflicting batch"
}

# same-batch shared_files conflict must be rejected
batch_files_conflict="$TMP_DIR/batch-files-conflict.json"
python3 - "$positive_scenario" "$batch_files_conflict" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "tasks":
        artifact["tasks"][0]["batch"] = 1
        artifact["tasks"][0]["shared_files"] = ["src/config.ts"]
        artifact["tasks"][1]["batch"] = 1
        artifact["tasks"][1]["shared_files"] = ["src/config.ts"]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
batch_files_conflict_dir="$TMP_DIR/batch-files-conflict"
prepare_phase_dir "$batch_files_conflict" "$batch_files_conflict_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$batch_files_conflict_dir" >/tmp/t3_batch_files_conflict.out 2>&1; then
  cat /tmp/t3_batch_files_conflict.out >&2
  fail "rule validator should reject same-batch shared_files conflict"
fi
rg -n 'shared_files conflict' /tmp/t3_batch_files_conflict.out >/dev/null 2>&1 || {
  cat /tmp/t3_batch_files_conflict.out >&2
  fail "shared_files conflict failure should name conflicting files"
}

# schema-validator field sync: every task property in schema must be in TASK_ALLOWED_FIELDS
python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
schema = json.loads(
    (root / "shared/skills/tech-lead/contracts/tasks.schema.json").read_text(encoding="utf-8")
)
task_items = schema["allOf"][1]["properties"]["tasks"]["items"]
schema_props = set(task_items.get("properties", {}).keys())

sys.path.insert(0, str(root / "tools" / "community"))
from validate_canonical_rules import TASK_ALLOWED_FIELDS  # noqa: E402

missing = sorted(schema_props - TASK_ALLOWED_FIELDS)
if missing:
    print(f"task schema properties missing from TASK_ALLOWED_FIELDS: {missing}", file=sys.stderr)
    sys.exit(1)
PY
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  fail "task schema properties must be a subset of TASK_ALLOWED_FIELDS in validate_canonical_rules.py"
fi

legacy_brief_alias_feature="$TMP_DIR/legacy-brief-alias"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$legacy_brief_alias_feature"
python3 - "$legacy_brief_alias_feature/brief.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
payload = json.loads(brief_path.read_text(encoding="utf-8"))
payload["non_functional_req"] = ["legacy alias must not be accepted"]
brief_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$legacy_brief_alias_feature/phase-1" >/tmp/t3_legacy_brief_alias.out 2>&1; then
  cat /tmp/t3_legacy_brief_alias.out >&2
  fail "phase orchestrator should reject legacy product aliases on canonical brief.json"
fi

python3 "$ROOT/tools/community/resolve_evidence_refs.py" \
  --phase-dir "$positive_phase_dir" >/dev/null || fail "evidence resolver should pass"

python3 "$ROOT/tools/community/validate_projection_manifest.py" \
  --phase-dir "$positive_phase_dir" >/dev/null || fail "projection validator should pass"

python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$positive_phase_dir" >/dev/null || fail "phase orchestrator should pass"

golden_normalized="$TMP_DIR/golden-normalized.json"
python3 "$ROOT/tools/community/normalize_canonical_artifact.py" \
  --phase-dir "$golden_phase_dir" >"$golden_normalized" || fail "normalizer should support real canonical phase dir"

python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$golden_phase_dir" >/dev/null || fail "phase orchestrator should support real canonical phase dir"

missing_plan_basis_feature="$TMP_DIR/missing-plan-basis"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$missing_plan_basis_feature"
python3 - "$missing_plan_basis_feature/phase-1/plan.json" <<'PY'
import json
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
payload = json.loads(plan_path.read_text(encoding="utf-8"))
for field in ("goal_source_refs", "constraint_source_refs", "obligation_source_refs", "execution_basis_refs"):
    payload.pop(field, None)
plan_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$missing_plan_basis_feature/phase-1" >/tmp/t3_missing_plan_basis.out 2>&1; then
  cat /tmp/t3_missing_plan_basis.out >&2
  fail "phase orchestrator should reject plan.json without required source/basis refs"
fi

early_phase_feature="$TMP_DIR/early-phase-feature"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$early_phase_feature"
rm -f "$early_phase_feature/phase-1/artifact-registry.json"
rm -f "$early_phase_feature/phase-1/code-review-result.json"
rm -f "$early_phase_feature/phase-1/delivery-state.json"
rm -f "$early_phase_feature/phase-1/design.json"
rm -f "$early_phase_feature/phase-1/plan.json"
rm -f "$early_phase_feature/phase-1/qa-result.json"
rm -f "$early_phase_feature/phase-1/signoff-package.json"
rm -f "$early_phase_feature/phase-1/tasks.json"
rm -f "$early_phase_feature/phase-1/user-decision.json"
rm -f "$early_phase_feature/phase-1/unit-1/test-cases.json"
rm -rf "$early_phase_feature/phase-1/unit-1/tasks"
rm -rf "$early_phase_feature/phase-1/views"

python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$early_phase_feature/phase-1" >/dev/null || fail "phase orchestrator should support upstream-only canonical phase dir"

unknown_enum="$TMP_DIR/unknown-enum.json"
python3 - "$positive_scenario" "$unknown_enum" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "qa-result":
        artifact["gate_result"] = "MAYBE"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$unknown_enum" >/tmp/t3_unknown_enum.out 2>&1; then
  cat /tmp/t3_unknown_enum.out >&2
  fail "schema validator should reject unknown enum"
fi

bad_ref="$TMP_DIR/bad-ref.json"
python3 - "$positive_scenario" "$bad_ref" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact["artifact_type"] == "delivery-state":
        artifact["active_tasks_version_ref"] = "plan-v1"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_ref" >/tmp/t3_bad_ref.out 2>&1; then
  cat /tmp/t3_bad_ref.out >&2
  fail "schema validator should reject bad ref grammar"
fi

bad_producer="$TMP_DIR/bad-producer.json"
python3 - "$ROOT" "$bad_producer" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
target = Path(sys.argv[2])
brief = json.loads(
    (root / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json").read_text(encoding="utf-8")
)
brief["producer"] = "product-director"
target.write_text(json.dumps({"artifacts": [brief]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_producer" >/tmp/t3_bad_producer.out 2>&1; then
  cat /tmp/t3_bad_producer.out >&2
  fail "schema validator should reject producer authority drift before downstream phase validation"
fi
rg -n 'producer authority mismatch for brief' /tmp/t3_bad_producer.out >/dev/null 2>&1 || {
  cat /tmp/t3_bad_producer.out >&2
  fail "schema validator should explain producer authority mismatch"
}

missing_anchor="$TMP_DIR/missing-anchor.json"
python3 - "$positive_scenario" "$missing_anchor" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["evidence_records"][0]["anchor"] = "missing-anchor"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
missing_anchor_dir="$TMP_DIR/missing-anchor"
prepare_phase_dir "$missing_anchor" "$missing_anchor_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$missing_anchor_dir" >/tmp/t3_missing_anchor.out 2>&1; then
  cat /tmp/t3_missing_anchor.out >&2
  fail "evidence resolver should reject missing anchor"
fi

substring_anchor="$TMP_DIR/substring-anchor.json"
python3 - "$positive_scenario" "$substring_anchor" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["evidence_records"][0]["anchor"] = "plan"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
substring_anchor_dir="$TMP_DIR/substring-anchor"
prepare_phase_dir "$substring_anchor" "$substring_anchor_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$substring_anchor_dir" >/tmp/t3_substring_anchor.out 2>&1; then
  cat /tmp/t3_substring_anchor.out >&2
  fail "evidence resolver should reject substring-only anchors"
fi

ref_anchor_drift="$TMP_DIR/ref-anchor-drift.json"
python3 - "$positive_scenario" "$ref_anchor_drift" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["evidence_records"][0]["ref_target"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#definitely-missing-anchor"
payload["evidence_records"][0]["anchor"] = "plan-version"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
ref_anchor_drift_dir="$TMP_DIR/ref-anchor-drift"
prepare_phase_dir "$ref_anchor_drift" "$ref_anchor_drift_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$ref_anchor_drift_dir" >/tmp/t3_ref_anchor_drift.out 2>&1; then
  cat /tmp/t3_ref_anchor_drift.out >&2
  fail "evidence resolver should reject ref_target anchor drift from evidence anchor"
fi

missing_ref_target="$TMP_DIR/missing-ref-target.json"
python3 - "$positive_scenario" "$missing_ref_target" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["evidence_records"][0]["ref_target"] = "artifact://tasks/sample-feature.phase-1.missing@plan-v1#plan-version"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
missing_ref_target_dir="$TMP_DIR/missing-ref-target"
prepare_phase_dir "$missing_ref_target" "$missing_ref_target_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$missing_ref_target_dir" >/tmp/t3_missing_ref_target.out 2>&1; then
  cat /tmp/t3_missing_ref_target.out >&2
  fail "evidence resolver should reject ref_target that is not present in active artifacts"
fi

ref_version_drift="$TMP_DIR/ref-version-drift.json"
python3 - "$positive_scenario" "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json" "$ref_version_drift" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
payload["artifacts"].append(registry)
payload["evidence_records"][0]["ref_target"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#plan-version"
Path(sys.argv[3]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
ref_version_drift_dir="$TMP_DIR/ref-version-drift"
prepare_phase_dir "$ref_version_drift" "$ref_version_drift_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$ref_version_drift_dir" >/tmp/t3_ref_version_drift.out 2>&1; then
  cat /tmp/t3_ref_version_drift.out >&2
  fail "evidence resolver should reject ref_target version drift when registry is present"
fi

empty_artifacts="$TMP_DIR/empty-artifacts.json"
printf '{"artifacts":[]}\n' > "$empty_artifacts"
if python3 "$ROOT/tools/community/normalize_canonical_artifact.py" --fixture "$empty_artifacts" >/tmp/t3_empty_artifacts.out 2>&1; then
  cat /tmp/t3_empty_artifacts.out >&2
  fail "normalizer should reject empty artifact scenarios"
fi

non_object_artifact="$TMP_DIR/non-object-artifact.json"
printf '{"artifacts":["not an object"]}\n' > "$non_object_artifact"
if python3 "$ROOT/tools/community/normalize_canonical_artifact.py" --fixture "$non_object_artifact" >/tmp/t3_non_object_artifact.out 2>&1; then
  cat /tmp/t3_non_object_artifact.out >&2
  fail "normalizer should reject non-object artifacts"
fi

stale_evidence="$TMP_DIR/stale-evidence.json"
python3 - "$positive_scenario" "$stale_evidence" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["evidence_records"][0]["valid_until"] = "2026-04-14T00:30:00Z"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
stale_evidence_dir="$TMP_DIR/stale-evidence"
prepare_phase_dir "$stale_evidence" "$stale_evidence_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$stale_evidence_dir" >/tmp/t3_stale_evidence.out 2>&1; then
  cat /tmp/t3_stale_evidence.out >&2
  fail "evidence resolver should reject stale evidence"
fi

invalid_relation="$TMP_DIR/invalid-relation.json"
python3 - "$positive_scenario" "$invalid_relation" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["evidence_records"][0]["relation_type"] = "guesses"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
invalid_relation_dir="$TMP_DIR/invalid-relation"
prepare_phase_dir "$invalid_relation" "$invalid_relation_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$invalid_relation_dir" >/tmp/t3_invalid_relation.out 2>&1; then
  cat /tmp/t3_invalid_relation.out >&2
  fail "evidence resolver should reject illegal relation_type"
fi

superseded_evidence="$TMP_DIR/superseded-evidence.json"
python3 - "$positive_scenario" "$superseded_evidence" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["evidence_records"][0]["superseded_by_ref"] = "artifact://evidence/sample-feature.phase-1.browser-trace@ev-2#trace-root"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
superseded_evidence_dir="$TMP_DIR/superseded-evidence"
prepare_phase_dir "$superseded_evidence" "$superseded_evidence_dir"
if python3 "$ROOT/tools/community/resolve_evidence_refs.py" --phase-dir "$superseded_evidence_dir" >/tmp/t3_superseded_evidence.out 2>&1; then
  cat /tmp/t3_superseded_evidence.out >&2
  fail "evidence resolver should reject superseded active evidence"
fi

illegal_transition_dir="$TMP_DIR/illegal-transition"
prepare_phase_dir "$NEGATIVE_ROOT/illegal-transition.json" "$illegal_transition_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$illegal_transition_dir" >/tmp/t3_illegal_transition.out 2>&1; then
  cat /tmp/t3_illegal_transition.out >&2
  fail "rule validator should reject illegal transition"
fi

authority_mismatch_dir="$TMP_DIR/authority-mismatch"
prepare_phase_dir "$NEGATIVE_ROOT/authority-mismatch.json" "$authority_mismatch_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$authority_mismatch_dir" >/tmp/t3_authority.out 2>&1; then
  cat /tmp/t3_authority.out >&2
  fail "rule validator should reject authority mismatch"
fi

mixed_version_dir="$TMP_DIR/mixed-version"
prepare_phase_dir "$NEGATIVE_ROOT/mixed-version.json" "$mixed_version_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$mixed_version_dir" >/tmp/t3_mixed_version.out 2>&1; then
  cat /tmp/t3_mixed_version.out >&2
  fail "rule validator should reject mixed-version lineage"
fi

closure_break_dir="$TMP_DIR/closure-break"
prepare_phase_dir "$NEGATIVE_ROOT/closure-break.json" "$closure_break_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$closure_break_dir" >/tmp/t3_closure_break.out 2>&1; then
  cat /tmp/t3_closure_break.out >&2
  fail "rule validator should reject upstream closure break"
fi

signoff_mixed="$TMP_DIR/signoff-mixed.json"
python3 - "$ROOT" "$signoff_mixed" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
payload = {
    "artifacts": [
        json.loads(
            (root / "shared/skills/delivery-owner/templates/signoff-package.template.json").read_text(encoding="utf-8")
        )
    ]
}
payload["artifacts"][0]["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#plan-version"
payload["artifacts"][0]["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
signoff_mixed_dir="$TMP_DIR/signoff-mixed"
prepare_phase_dir "$signoff_mixed" "$signoff_mixed_dir"
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --phase-dir "$signoff_mixed_dir" >/tmp/t3_signoff_mixed.out 2>&1; then
  cat /tmp/t3_signoff_mixed.out >&2
  fail "rule validator should reject baseline/active mixed signoff verdict"
fi

projection_break="$TMP_DIR/projection-break.json"
python3 - "$positive_scenario" "$projection_break" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["projection"]["available_source_refs"] = []
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
projection_break_dir="$TMP_DIR/projection-break"
prepare_phase_dir "$projection_break" "$projection_break_dir"
if python3 "$ROOT/tools/community/validate_projection_manifest.py" --phase-dir "$projection_break_dir" >/tmp/t3_projection_break.out 2>&1; then
  cat /tmp/t3_projection_break.out >&2
  fail "projection validator should reject undeclared source provenance"
fi

projection_fixture_drift="$TMP_DIR/projection-fixture-drift.json"
python3 - "$positive_scenario" "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/phase-prd.json" "$projection_fixture_drift" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
phase_prd = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
payload["artifacts"].append(phase_prd)
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") != "projection-manifest":
        continue
    artifact["source_artifact_refs"] = [
        ref.replace("sample-feature", "other-feature")
        for ref in artifact["source_artifact_refs"]
    ]
    for section in artifact["section_source_map"].values():
        section["source_artifact_refs"] = [
            ref.replace("sample-feature", "other-feature")
            for ref in section["source_artifact_refs"]
        ]
    payload["projection"]["available_source_refs"] = artifact["source_artifact_refs"]
Path(sys.argv[3]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
projection_fixture_drift_dir="$TMP_DIR/projection-fixture-drift"
prepare_phase_dir "$projection_fixture_drift" "$projection_fixture_drift_dir"
if python3 "$ROOT/tools/community/validate_projection_manifest.py" --phase-dir "$projection_fixture_drift_dir" >/tmp/t3_projection_fixture_drift.out 2>&1; then
  cat /tmp/t3_projection_fixture_drift.out >&2
  fail "projection validator should reject fixture-mode source refs that drift from phase-prd artifact identity"
fi

if python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$mixed_version_dir" >/tmp/t3_orchestrator.out 2>&1; then
  cat /tmp/t3_orchestrator.out >&2
  fail "phase orchestrator should fail-close on child validator error"
fi

echo "[PASS] standard chain validator stack"
