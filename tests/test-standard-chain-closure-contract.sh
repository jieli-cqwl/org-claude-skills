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

ROOT = Path(sys.argv[1])
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

design_schema = json.loads((ROOT / "shared/skills/design/contracts/design.schema.json").read_text(encoding="utf-8"))
design_properties = next(item for item in reversed(design_schema["allOf"]) if "properties" in item)
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
for field_name in ["unit_coverage_view", "design_gap_report", "special_test_triggers"]:
    if field_name not in test_properties.get("required", []):
        raise SystemExit(f"test-cases schema must require {field_name}")

phase_dir = ROOT / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
signoff = json.loads((phase_dir / "signoff-package.json").read_text(encoding="utf-8"))
decision = json.loads((phase_dir / "user-decision.json").read_text(encoding="utf-8"))
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
rg -q 'consistency-audit-result' /tmp/standard-chain-closure-readiness.out \
  || fail "missing consistency-audit-result failure should name the missing artifact"

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
fix_result["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#plan-version"
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
add_fix_result "$fresh_fix_dir/phase-1" "2026-04-14T03:30:00Z"
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
rg -q 'fix-result freshness' /tmp/standard-chain-closure-stale-fix.out \
  || fail "stale fix-result failure should name fix-result freshness"

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
rg -q 'signoff freshness' /tmp/standard-chain-closure-stale-signoff.out \
  || fail "stale signoff failure should name signoff freshness"

python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG"

printf '[PASS] standard-chain closure contract\n'
