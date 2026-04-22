#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
    (root / "contracts/canonical/templates/runtime/qa-result.template.json").read_text(encoding="utf-8")
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
        json.loads(
            (root / "contracts/canonical/templates/planning/plan.template.json").read_text(encoding="utf-8")
        ),
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
            "artifact://plan/sample-feature.phase-1.plan@plan-v1#handoff-001",
        ],
        "obligation_source_refs": [
            "artifact://plan/sample-feature.phase-1.plan@plan-v1#handoff-001",
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
            "ref_target": "artifact://plan/sample-feature.phase-1.plan@plan-v1#plan-version",
            "artifact_path": "evidence/browser-trace.json",
            "target_path": "targets/plan.txt",
            "anchor": "plan-version",
            "consumer_produced_at": "2026-04-14T01:00:00Z",
            "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v1#plan-version",
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

normalized_output="$TMP_DIR/normalized.json"
python3 "$ROOT/tools/community/normalize_canonical_artifact.py" \
  --fixture "$positive_scenario" >"$normalized_output" || fail "normalizer should pass"

python3 "$ROOT/tools/community/validate_canonical_schema.py" \
  --phase-dir "$positive_phase_dir" >/dev/null || fail "schema validator should pass"

python3 "$ROOT/tools/community/validate_canonical_rules.py" \
  --phase-dir "$positive_phase_dir" >/dev/null || fail "rule validator should pass"

legacy_extra="$TMP_DIR/legacy-extra.json"
python3 - "$positive_scenario" "$legacy_extra" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for artifact in payload["artifacts"]:
    if artifact.get("artifact_type") == "plan":
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
    if artifact.get("artifact_type") == "plan":
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
        artifact["active_plan_version_ref"] = "plan-v1"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$bad_ref" >/tmp/t3_bad_ref.out 2>&1; then
  cat /tmp/t3_bad_ref.out >&2
  fail "schema validator should reject bad ref grammar"
fi

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
payload["evidence_records"][0]["ref_target"] = "artifact://plan/sample-feature.phase-1.plan@plan-v1#definitely-missing-anchor"
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
payload["evidence_records"][0]["ref_target"] = "artifact://plan/sample-feature.phase-1.missing@plan-v1#plan-version"
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
payload["evidence_records"][0]["ref_target"] = "artifact://plan/sample-feature.phase-1.plan@plan-v1#plan-version"
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
            (root / "contracts/canonical/templates/runtime/signoff-package.template.json").read_text(encoding="utf-8")
        )
    ]
}
payload["artifacts"][0]["active_plan_version_ref"] = "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version"
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
