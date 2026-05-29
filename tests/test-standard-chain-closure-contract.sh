#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

PHASE_DIR="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"

python3 - "$ROOT" <<'PY' || fail "standard-chain closure contract drift"
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(sys.argv[1])
standard_chain = yaml.safe_load((ROOT / "contracts/standard-chain.yaml").read_text(encoding="utf-8"))
field_consumption = yaml.safe_load((ROOT / "contracts/standard-chain-field-consumption.yaml").read_text(encoding="utf-8"))
catalog = json.loads((ROOT / "shared/runtime/standard-chain-catalog.json").read_text(encoding="utf-8"))
artifacts = catalog.get("artifacts", {})

required_artifacts = {"consistency-audit-result", "fix-result"}
missing_artifacts = sorted(required_artifacts - set(artifacts))
if missing_artifacts:
    raise SystemExit(f"catalog missing closure artifacts: {missing_artifacts}")

review_schema = json.loads(
    (ROOT / "shared/skills/review/contracts/code-review-result.schema.json").read_text(encoding="utf-8")
)
review_properties = next(item for item in reversed(review_schema["allOf"]) if "properties" in item)
dimension_schema = review_properties["properties"]["dimension_verdicts"]
if "backward_compatibility" not in dimension_schema.get("required", []):
    raise SystemExit("code-review-result schema must require backward_compatibility dimension")

qa_schema = json.loads((ROOT / "shared/skills/qa/contracts/qa-result.schema.json").read_text(encoding="utf-8"))
qa_properties = next(item for item in reversed(qa_schema["allOf"]) if "properties" in item)
if "stage_results" not in qa_properties.get("required", []):
    raise SystemExit("qa-result schema must require QA stage_results")
if "obligation_results" not in qa_properties.get("required", []):
    raise SystemExit("qa-result schema must require QA obligation_results")

design_schema = json.loads((ROOT / "shared/skills/design/contracts/design.schema.json").read_text(encoding="utf-8"))
design_properties = next(item for item in reversed(design_schema["allOf"]) if "properties" in item)
product_handoff_schema = design_properties["properties"]["product_handoff"]
product_handoff_properties = product_handoff_schema.get("properties", {})
if "warn_followups" in product_handoff_properties:
    raise SystemExit("design product_handoff must not carry warn_followups; review_closure owns WARN routing")
if "warn_followups" in product_handoff_schema.get("required", []):
    raise SystemExit("design product_handoff must not require warn_followups")
for field_name in [
    "co_creation_summary",
    "constraint_inheritance_confirmation",
    "review_closure",
    "final_confirmation",
    "option_analysis",
    "runtime_facts",
    "interfaces",
    "modules",
    "data_architecture",
    "cross_cutting_concerns",
    "verification_mapping",
    "unit_coverage",
    "impact_scope",
    "planning_constraints",
    "product_handoff",
    "risks",
    "risk_response",
    "migration_plan",
    "verification_plan",
    "rollback_plan",
]:
    if field_name not in design_properties.get("required", []):
        raise SystemExit(f"design schema must require {field_name}")

test_schema = json.loads((ROOT / "shared/skills/test-design/contracts/test-cases.schema.json").read_text(encoding="utf-8"))
test_properties = next(item for item in reversed(test_schema["allOf"]) if "properties" in item)
for field_name in ["design_gap_report", "special_test_triggers"]:
    if field_name not in test_properties.get("required", []):
        raise SystemExit(f"test-cases schema must require {field_name}")
for field_name in ["equivalence_matrix", "unit_coverage_view"]:
    if field_name in test_properties.get("properties", {}):
        raise SystemExit(f"test-cases schema must not define derived field {field_name}")

signoff_schema = json.loads(
    (ROOT / "shared/skills/delivery-owner/contracts/signoff-package.schema.json").read_text(encoding="utf-8")
)
signoff_properties = next(item for item in reversed(signoff_schema["allOf"]) if "properties" in item)
if "takeover_note" in signoff_properties["properties"]:
    raise SystemExit("signoff-package schema must not carry takeover_note in active runtime artifact")
if "takeover_note" in signoff_properties.get("required", []):
    raise SystemExit("signoff-package schema must not require takeover_note")
if "runtime_snapshot" in signoff_properties["properties"]:
    raise SystemExit("signoff-package schema must not carry prose runtime_snapshot")
if "runtime_snapshot" in signoff_properties.get("required", []):
    raise SystemExit("signoff-package schema must not require prose runtime_snapshot")
goal_extension = signoff_properties["properties"]["goal_closure"]["items"]["allOf"][1]
if "goal_source_ref" in goal_extension.get("properties", {}):
    raise SystemExit("signoff-package goal_closure must not duplicate goal_ref as goal_source_ref")
if "goal_source_ref" in goal_extension.get("required", []):
    raise SystemExit("signoff-package goal_closure must not require duplicate goal_source_ref")

signoff_template = json.loads(
    (ROOT / "shared/skills/delivery-owner/templates/signoff-package.template.json").read_text(encoding="utf-8")
)
if "takeover_note" in signoff_template:
    raise SystemExit("signoff-package template must not include takeover_note")
if "$.takeover_note" in signoff_template.get("authoritative_fields", []):
    raise SystemExit("signoff-package authoritative_fields must not include $.takeover_note")
if "runtime_snapshot" in signoff_template:
    raise SystemExit("signoff-package template must not include runtime_snapshot")
if "$.runtime_snapshot" in signoff_template.get("authoritative_fields", []):
    raise SystemExit("signoff-package authoritative_fields must not include $.runtime_snapshot")
for index, row in enumerate(signoff_template.get("goal_closure", [])):
    if "goal_source_ref" in row:
        raise SystemExit(f"signoff-package template goal_closure[{index}] must not include duplicate goal_source_ref")

design_template = json.loads((ROOT / "shared/skills/design/templates/design.template.json").read_text(encoding="utf-8"))
if "warn_followups" in design_template["product_handoff"]:
    raise SystemExit("design template product_handoff must not include warn_followups")

delivery_state_schema = json.loads(
    (ROOT / "shared/skills/delivery-owner/contracts/delivery-state.schema.json").read_text(encoding="utf-8")
)
delivery_state_properties = next(item for item in reversed(delivery_state_schema["allOf"]) if "properties" in item)
kickoff_schema = delivery_state_properties["properties"]["kickoff"]
if "blocking_reason" in kickoff_schema.get("properties", {}):
    raise SystemExit("delivery-state kickoff must not carry prose blocking_reason")
if "blocking_reason" in kickoff_schema.get("required", []):
    raise SystemExit("delivery-state kickoff must not require prose blocking_reason")
if "summary_text" in delivery_state_properties.get("properties", {}):
    raise SystemExit("delivery-state schema must not carry prose summary_text")
if "summary_text" in delivery_state_properties.get("required", []):
    raise SystemExit("delivery-state schema must not require prose summary_text")

delivery_state_template = json.loads(
    (ROOT / "shared/skills/delivery-owner/templates/delivery-state.template.json").read_text(encoding="utf-8")
)
if "blocking_reason" in delivery_state_template.get("kickoff", {}):
    raise SystemExit("delivery-state template kickoff must not include prose blocking_reason")
if "summary_text" in delivery_state_template:
    raise SystemExit("delivery-state template must not include prose summary_text")
if "$.summary_text" in delivery_state_template.get("authoritative_fields", []):
    raise SystemExit("delivery-state authoritative_fields must not include $.summary_text")

artifact_defs = [
    output
    for step in standard_chain["chain"]
    for output in step.get("outputs", [])
]
signoff_artifact = next(
    item for item in artifact_defs if item["artifact"] == "phase-{N}/signoff-package.json"
)
if "takeover_note" in signoff_artifact.get("key_fields", []):
    raise SystemExit("standard-chain signoff-package key_fields must not include takeover_note")
delivery_state_artifact = next(
    item for item in artifact_defs if item["artifact"] == "phase-{N}/delivery-state.json"
)
if "summary_text" in delivery_state_artifact.get("key_fields", []):
    raise SystemExit("standard-chain delivery-state key_fields must not include summary_text")
if "runtime_snapshot" in signoff_artifact.get("key_fields", []):
    raise SystemExit("standard-chain signoff-package key_fields must not include runtime_snapshot")
signoff_consumption = next(
    artifact["fields"]
    for artifact in field_consumption["artifacts"]
    if artifact["path"] == "docs/{feature}/phase-{N}/signoff-package.json"
)
if "takeover_note" in signoff_consumption:
    raise SystemExit("field-consumption signoff-package must not include takeover_note")
if "runtime_snapshot" in signoff_consumption:
    raise SystemExit("field-consumption signoff-package must not include runtime_snapshot")
delivery_state_consumption = next(
    artifact["fields"]
    for artifact in field_consumption["artifacts"]
    if artifact["path"] == "docs/{feature}/phase-{N}/delivery-state.json"
)
if "summary_text" in delivery_state_consumption:
    raise SystemExit("field-consumption delivery-state must not include summary_text")

phase_dir = ROOT / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
signoff = json.loads((phase_dir / "signoff-package.json").read_text(encoding="utf-8"))
delivery_state = json.loads((phase_dir / "delivery-state.json").read_text(encoding="utf-8"))
decision = json.loads((phase_dir / "user-decision.json").read_text(encoding="utf-8"))
design = json.loads((phase_dir / "design.json").read_text(encoding="utf-8"))
if "takeover_note" in signoff:
    raise SystemExit("golden signoff-package must not include takeover_note")
if "runtime_snapshot" in signoff:
    raise SystemExit("golden signoff-package must not include runtime_snapshot")
if "$.runtime_snapshot" in signoff.get("authoritative_fields", []):
    raise SystemExit("golden signoff-package authoritative_fields must not include $.runtime_snapshot")
if "blocking_reason" in delivery_state.get("kickoff", {}):
    raise SystemExit("golden delivery-state kickoff must not include prose blocking_reason")
if "summary_text" in delivery_state:
    raise SystemExit("golden delivery-state must not include prose summary_text")
if "$.summary_text" in delivery_state.get("authoritative_fields", []):
    raise SystemExit("golden delivery-state authoritative_fields must not include $.summary_text")
for index, row in enumerate(signoff.get("goal_closure", [])):
    if "goal_source_ref" in row:
        raise SystemExit(f"golden signoff-package goal_closure[{index}] must not include duplicate goal_source_ref")
if "warn_followups" in design["product_handoff"]:
    raise SystemExit("golden design product_handoff must not include warn_followups")
if signoff.get("current_stage") != "CLOSED":
    raise SystemExit("golden signoff-package must represent CLOSED final signoff")
if signoff.get("sign_off_status") != "SIGNED_OFF":
    raise SystemExit("golden signoff-package must be SIGNED_OFF")
if decision.get("decision") != "APPROVE":
    raise SystemExit("golden user-decision must approve the phase")
if decision.get("sign_off_status") != "SIGNED_OFF":
    raise SystemExit("golden user-decision must be SIGNED_OFF")

tasks = json.loads((phase_dir / "tasks.json").read_text(encoding="utf-8"))
task_refs = {
    task["task_id"]: {
        "unit_refs": task.get("unit_refs", []),
        "scope_item_refs": task.get("scope_item_refs", []),
        "test_refs": task.get("test_refs", []),
    }
    for task in tasks.get("tasks", [])
}
for task_id, refs in task_refs.items():
    if not refs["unit_refs"]:
        raise SystemExit(f"task {task_id} must carry unit_refs")
    if not refs["scope_item_refs"]:
        raise SystemExit(f"task {task_id} must carry scope_item_refs")
    if not refs["test_refs"]:
        raise SystemExit(f"task {task_id} must carry test_refs")

test_cases = json.loads((phase_dir / "unit-1/test-cases.json").read_text(encoding="utf-8"))
covered_ac_ids = {
    row.get("ac_id")
    for row in test_cases.get("ac_coverage_matrix", [])
    if isinstance(row, dict)
}
for task_id, refs in task_refs.items():
    expected_ac = f"AC-{task_id}-1"
    if expected_ac not in covered_ac_ids:
        raise SystemExit(f"test-cases must cover task AC ref: {expected_ac}")

registry = json.loads((phase_dir / "artifact-registry.json").read_text(encoding="utf-8"))
active_revision_id = registry["active_revision_id"]
active_entries = [
    entry
    for revision in registry.get("revisions", [])
    if revision.get("revision_id") == active_revision_id
    for entry in revision.get("entries", [])
    if entry.get("active_for_consumption") is True
]
active_types = {entry.get("artifact_type") for entry in active_entries}
if "consistency-audit-result" not in active_types:
    raise SystemExit("golden registry must activate consistency-audit-result")

readiness_closure_text = (ROOT / "tools/community/readiness_closure_checks.py").read_text(
    encoding="utf-8"
)
if "goal_source_ref" in readiness_closure_text:
    raise SystemExit("readiness closure checks must consume goal_ref, not duplicate goal_source_ref")
PY

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-closure.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$tmp_dir/sample-feature"
rm "$tmp_dir/sample-feature/phase-1/consistency-audit-result.json"
if python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$tmp_dir/sample-feature/phase-1" \
  --catalog "$CATALOG" >/tmp/standard-chain-closure-readiness.out 2>&1; then
  fail "readiness must reject missing consistency-audit-result"
fi
grep -Eq 'consistency-audit-result' /tmp/standard-chain-closure-readiness.out \
  || fail "missing consistency-audit-result failure should name the missing artifact"

missing_obligation_dir="$tmp_dir/missing-obligation-results/sample-feature"
mkdir -p "$(dirname "$missing_obligation_dir")"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$missing_obligation_dir"
python3 - "$missing_obligation_dir/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
payload = json.loads(qa_path.read_text(encoding="utf-8"))
payload.pop("obligation_results", None)
qa_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$missing_obligation_dir/phase-1" \
  --catalog "$CATALOG" >/tmp/standard-chain-closure-missing-obligation.out 2>&1; then
  fail "readiness must reject qa-result without obligation_results"
fi
grep -Eq 'obligation_results' /tmp/standard-chain-closure-missing-obligation.out \
  || fail "missing obligation_results failure should name the missing QA obligation result"

add_fix_result() {
  local phase_dir="$1"
  local produced_at="$2"
  python3 - "$ROOT" "$phase_dir" "$produced_at" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
produced_at = sys.argv[3]

fix_result = json.loads((root / "shared/skills/fix/templates/fix-result.template.json").read_text(encoding="utf-8"))
fix_result["produced_at"] = produced_at
fix_result["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
(phase_dir / "fix-result.json").write_text(json.dumps(fix_result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

registry_path = phase_dir / "artifact-registry.json"
registry = json.loads(registry_path.read_text(encoding="utf-8"))
for revision in registry["revisions"]:
    if revision["revision_id"] != registry["active_revision_id"]:
        continue
    revision["entries"].append({
        "scope_ref": "artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal",
        "artifact_id": "sample-feature.phase-1.fix",
        "artifact_type": "fix-result",
        "version": "v1",
        "artifact_path": "fix-result.json",
        "lifecycle_state": "FINALIZED",
        "active_for_consumption": True,
        "produced_by": "fix",
        "restore_basis_refs": []
    })
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

fresh_fix_dir="$tmp_dir/fresh-fix/sample-feature"
mkdir -p "$(dirname "$fresh_fix_dir")"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$fresh_fix_dir"
add_fix_result "$fresh_fix_dir/phase-1" "2026-04-13T23:59:00Z"
python3 - "$ROOT" "$fresh_fix_dir/phase-1" <<'PY' \
  || fail "readiness internals must accept active fix-result older than signoff observation"
import sys
from pathlib import Path

root = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))

from delivery_owner_optional_artifacts import assert_optional_fix_result_freshness
from manage_artifact_registry import load_json as load_registry_json
from validate_readiness_contract import assert_active_registry_matches_artifacts
from validate_standard_chain_readiness import collect_validation_artifact_paths

artifact_paths = collect_validation_artifact_paths(phase_dir)
if phase_dir / "fix-result.json" not in artifact_paths:
    raise SystemExit("optional fix-result was not collected for readiness validation")
assert_active_registry_matches_artifacts(
    phase_dir,
    artifact_paths,
    load_registry_json(phase_dir / "artifact-registry.json"),
)
assert_optional_fix_result_freshness(phase_dir)
PY

stale_fix_dir="$tmp_dir/stale-fix/sample-feature"
mkdir -p "$(dirname "$stale_fix_dir")"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$stale_fix_dir"
add_fix_result "$stale_fix_dir/phase-1" "2026-04-14T04:30:00Z"
if python3 - "$ROOT" "$stale_fix_dir/phase-1" >/tmp/standard-chain-closure-stale-fix.out 2>&1 <<'PY'; then
import sys
from pathlib import Path

root = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))

from delivery_owner_optional_artifacts import assert_optional_fix_result_freshness

assert_optional_fix_result_freshness(phase_dir)
PY
  fail "readiness must reject signoff evidence that predates active fix-result"
fi
grep -Eq 'fix-result freshness' /tmp/standard-chain-closure-stale-fix.out \
  || fail "stale fix-result failure should name fix-result freshness"

stale_review_after_fix_dir="$tmp_dir/stale-review-after-fix/sample-feature"
mkdir -p "$(dirname "$stale_review_after_fix_dir")"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$stale_review_after_fix_dir"
add_fix_result "$stale_review_after_fix_dir/phase-1" "2026-04-14T03:15:00Z"
python3 - "$stale_review_after_fix_dir/phase-1" <<'PY'
import json
import sys
from pathlib import Path

phase_dir = Path(sys.argv[1])
for index, verify_path in enumerate(sorted(phase_dir.glob("unit-*/tasks/*/verify-result.json")), start=1):
    payload = json.loads(verify_path.read_text(encoding="utf-8"))
    payload["produced_at"] = f"2026-04-14T03:16:0{index}Z"
    verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 - "$ROOT" "$stale_review_after_fix_dir/phase-1" >/tmp/standard-chain-closure-stale-review-after-fix.out 2>&1 <<'PY'; then
import sys
from pathlib import Path

root = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))

from delivery_owner_optional_artifacts import assert_optional_fix_result_freshness

assert_optional_fix_result_freshness(phase_dir)
PY
  fail "readiness must reject code-review-result that predates active fix-result"
fi
grep -Eq 'code-review-result.produced_at|fix-result freshness' /tmp/standard-chain-closure-stale-review-after-fix.out \
  || fail "stale post-fix review failure should name code-review-result freshness"

stale_developer_after_fix_dir="$tmp_dir/stale-developer-after-fix/sample-feature"
mkdir -p "$(dirname "$stale_developer_after_fix_dir")"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$stale_developer_after_fix_dir"
add_fix_result "$stale_developer_after_fix_dir/phase-1" "2026-04-14T03:15:00Z"
python3 - "$stale_developer_after_fix_dir/phase-1" <<'PY'
import json
import sys
from pathlib import Path

phase_dir = Path(sys.argv[1])
for index, verify_path in enumerate(sorted(phase_dir.glob("unit-*/tasks/*/verify-result.json")), start=1):
    payload = json.loads(verify_path.read_text(encoding="utf-8"))
    payload["produced_at"] = f"2026-04-14T03:16:1{index}Z"
    verify_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
for relative, produced_at in {
    "code-review-result.json": "2026-04-14T03:17:00Z",
    "qa-result.json": "2026-04-14T03:18:00Z",
    "consistency-audit-result.json": "2026-04-14T03:19:00Z",
}.items():
    path = phase_dir / relative
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["produced_at"] = produced_at
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 - "$ROOT" "$stale_developer_after_fix_dir/phase-1" >/tmp/standard-chain-closure-stale-developer-after-fix.out 2>&1 <<'PY'; then
import sys
from pathlib import Path

root = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools/community"))

from delivery_owner_optional_artifacts import assert_optional_fix_result_freshness

assert_optional_fix_result_freshness(phase_dir)
PY
  fail "readiness must reject developer-report that predates active fix-result"
fi
grep -Eq 'developer-report.produced_at|fix-result freshness' /tmp/standard-chain-closure-stale-developer-after-fix.out \
  || fail "stale post-fix developer failure should name developer-report freshness"

stale_signoff_dir="$tmp_dir/stale-signoff/sample-feature"
mkdir -p "$(dirname "$stale_signoff_dir")"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$stale_signoff_dir"
python3 - "$stale_signoff_dir/phase-1" <<'PY'
import json
import sys
from pathlib import Path

phase_dir = Path(sys.argv[1])
signoff_path = phase_dir / "signoff-package.json"
signoff = json.loads(signoff_path.read_text(encoding="utf-8"))
signoff["last_observed_at"] = "2026-04-14T03:00:00Z"
signoff_path.write_text(json.dumps(signoff, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

oracle_path = phase_dir / "replay/phase-operational.replay-oracle.json"
oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
oracle["artifacts"]["signoff-package"]["last_observed_at"] = "2026-04-14T03:00:00Z"
oracle_path.write_text(json.dumps(oracle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$stale_signoff_dir/phase-1" \
  --catalog "$CATALOG" >/tmp/standard-chain-closure-stale-signoff.out 2>&1; then
  fail "readiness must reject signoff observation that predates latest evidence"
fi
grep -Eq 'signoff freshness' /tmp/standard-chain-closure-stale-signoff.out \
  || fail "stale signoff failure should name signoff freshness"

python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG"

printf '[PASS] standard-chain closure contract\n'
