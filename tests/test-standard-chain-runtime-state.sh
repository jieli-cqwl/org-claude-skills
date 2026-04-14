#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-foundation/runtime"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

for path in \
  "$FIXTURE_ROOT/baseline/artifact-registry.json" \
  "$FIXTURE_ROOT/blocked/enter-blocked.json" \
  "$FIXTURE_ROOT/blocked/leave-blocked.json" \
  "$FIXTURE_ROOT/quarantine/artifact-registry.json" \
  "$FIXTURE_ROOT/quarantine/restore-request.json" \
  "$FIXTURE_ROOT/replan/delivery-state.json"; do
  [ -f "$path" ] || fail "missing runtime fixture: ${path#"$ROOT"/}"
done

[ -f "$ROOT/tools/community/canonical_ref_resolver.py" ] || fail "missing canonical_ref_resolver.py"
[ -f "$ROOT/tools/community/manage_artifact_registry.py" ] || fail "missing manage_artifact_registry.py"
[ -f "$ROOT/tools/community/update_delivery_state.py" ] || fail "missing update_delivery_state.py"

resolved_path="$(
  python3 "$ROOT/tools/community/canonical_ref_resolver.py" \
    --registry "$FIXTURE_ROOT/baseline/artifact-registry.json" \
    --ref "artifact://plan/sample-feature.phase-1.plan@plan-v1#plan-version"
)"
[ "$resolved_path" = "tests/fixtures/standard-chain-foundation/runtime/baseline/plan.json" ] \
  || fail "resolver returned unexpected path: $resolved_path"

python3 "$ROOT/tools/community/manage_artifact_registry.py" \
  --fixture "$FIXTURE_ROOT/quarantine/artifact-registry.json" \
  --check-active >/dev/null || fail "active registry validation should pass"

python3 "$ROOT/tools/community/manage_artifact_registry.py" \
  --fixture "$FIXTURE_ROOT/quarantine/artifact-registry.json" \
  --check-append-only >/dev/null || fail "append-only registry validation should pass"

python3 "$ROOT/tools/community/manage_artifact_registry.py" \
  --fixture "$FIXTURE_ROOT/quarantine/restore-request.json" \
  --check-restore >/dev/null || fail "restore flow validation should pass"

python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$FIXTURE_ROOT/baseline/delivery-state.json" \
  --tasks-fixture "$FIXTURE_ROOT/baseline/tasks.json" \
  --check-task-runtime >/dev/null || fail "task runtime alignment should pass"

python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$FIXTURE_ROOT/blocked/enter-blocked.json" \
  --check-enter-blocked >/dev/null || fail "enter blocked should pass"

python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$FIXTURE_ROOT/blocked/leave-blocked.json" \
  --check-leave-blocked >/dev/null || fail "leave blocked should pass"

python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$FIXTURE_ROOT/replan/delivery-state.json" \
  --tasks-fixture "$FIXTURE_ROOT/replan/tasks-v2.json" \
  --check-replan-switch >/dev/null || fail "replan switch should pass"

apply_restore_output="$TMP_DIR/apply-restore.json"
python3 "$ROOT/tools/community/manage_artifact_registry.py" \
  --fixture "$FIXTURE_ROOT/quarantine/restore-request.json" \
  --apply-restore >"$apply_restore_output"
python3 - "$FIXTURE_ROOT/quarantine/restore-request.json" "$apply_restore_output" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["registry"]
data = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
assert data["active_revision_id"] == "rev-3"
assert len(data["revisions"]) == 3
assert data["revisions"][:2] == source["revisions"]
restored = [entry for entry in data["revisions"][-1]["entries"] if entry["artifact_id"] == "sample-feature.phase-1.qa"]
assert restored and restored[0]["restore_basis_refs"] == [
    "artifact://evidence/sample-feature.phase-1.restore@ev-restore#root"
]
PY

task_update_fixture="$TMP_DIR/task-runtime-update.json"
python3 - "$FIXTURE_ROOT/baseline/delivery-state.json" "$task_update_fixture" <<'PY'
import json
import sys
from pathlib import Path

state = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload = {
    "state": state,
    "task_update": {
        "task_id": "T1",
        "runtime_status": "COMPLETED",
        "owner": "developer",
        "attempt_count": 2,
        "current_batch": 1,
        "next_action": "verify",
        "latest_upstream_refs": [
            "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-T1"
        ],
    },
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
apply_task_runtime_output="$TMP_DIR/apply-task-runtime.json"
python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$task_update_fixture" \
  --tasks-fixture "$FIXTURE_ROOT/baseline/tasks.json" \
  --apply-task-runtime >"$apply_task_runtime_output"
python3 - "$apply_task_runtime_output" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
task = data["tasks"][0]
assert task["runtime_status"] == "COMPLETED"
assert task["attempt_count"] == 2
assert task["next_action"] == "verify"
PY

apply_enter_blocked_output="$TMP_DIR/apply-enter-blocked.json"
python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$FIXTURE_ROOT/blocked/enter-blocked.json" \
  --apply-enter-blocked >"$apply_enter_blocked_output"
python3 - "$apply_enter_blocked_output" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert data["current_stage"] == "BLOCKED"
assert data["resume_stage"] == "TASK_EXECUTION"
PY

apply_leave_blocked_output="$TMP_DIR/apply-leave-blocked.json"
python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$FIXTURE_ROOT/blocked/leave-blocked.json" \
  --apply-leave-blocked >"$apply_leave_blocked_output"
python3 - "$apply_leave_blocked_output" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert data["current_stage"] == "TASK_EXECUTION"
assert data["unblocked_by_ref"] == "artifact://user-decision/sample-feature.phase-1.decision@v1#approve"
PY

apply_replan_output="$TMP_DIR/apply-replan-switch.json"
python3 "$ROOT/tools/community/update_delivery_state.py" \
  --fixture "$FIXTURE_ROOT/replan/delivery-state.json" \
  --tasks-fixture "$FIXTURE_ROOT/replan/tasks-v2.json" \
  --apply-replan-switch >"$apply_replan_output"
python3 - "$apply_replan_output" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert data["active_plan_version_ref"] == "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version"
assert data["active_tasks_version_ref"] == "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
PY

cp "$FIXTURE_ROOT/quarantine/artifact-registry.json" "$TMP_DIR/draft-active.json"
python3 - "$TMP_DIR/draft-active.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["revisions"][-1]["entries"][0]["lifecycle_state"] = "DRAFT"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/manage_artifact_registry.py" --fixture "$TMP_DIR/draft-active.json" --check-active >/tmp/t2_draft.out 2>&1; then
  cat /tmp/t2_draft.out >&2
  fail "active DRAFT entry should fail"
fi

cp "$FIXTURE_ROOT/quarantine/artifact-registry.json" "$TMP_DIR/superseded-active.json"
python3 - "$TMP_DIR/superseded-active.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["revisions"][-1]["entries"][0]["lifecycle_state"] = "SUPERSEDED"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/manage_artifact_registry.py" --fixture "$TMP_DIR/superseded-active.json" --check-active >/tmp/t2_superseded.out 2>&1; then
  cat /tmp/t2_superseded.out >&2
  fail "active SUPERSEDED entry should fail"
fi

cp "$FIXTURE_ROOT/baseline/artifact-registry.json" "$TMP_DIR/resolver-draft.json"
python3 - "$TMP_DIR/resolver-draft.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["revisions"][0]["entries"][0]["lifecycle_state"] = "DRAFT"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/canonical_ref_resolver.py" --registry "$TMP_DIR/resolver-draft.json" --ref "artifact://plan/sample-feature.phase-1.plan@plan-v1#plan-version" >/tmp/t2_resolver.out 2>&1; then
  cat /tmp/t2_resolver.out >&2
  fail "resolver should reject non-finalized active entry"
fi

if python3 "$ROOT/tools/community/canonical_ref_resolver.py" --registry "$FIXTURE_ROOT/baseline/artifact-registry.json" --ref "artifact://plan/sample-feature.phase-1.plan@plan-v10#plan-version" >/tmp/t2_resolver_prefix.out 2>&1; then
  cat /tmp/t2_resolver_prefix.out >&2
  fail "resolver should reject version-prefix collisions"
fi

cp "$FIXTURE_ROOT/baseline/delivery-state.json" "$TMP_DIR/superseded-task-runtime.json"
python3 - "$TMP_DIR/superseded-task-runtime.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["tasks"][0]["task_id"] = "T2"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$TMP_DIR/superseded-task-runtime.json" --tasks-fixture "$FIXTURE_ROOT/baseline/tasks.json" --check-task-runtime >/tmp/t2_task_runtime.out 2>&1; then
  cat /tmp/t2_task_runtime.out >&2
  fail "runtime state should reject superseded task dispatch"
fi

cp "$FIXTURE_ROOT/baseline/delivery-state.json" "$TMP_DIR/task-version-drift.json"
python3 - "$TMP_DIR/task-version-drift.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$TMP_DIR/task-version-drift.json" --tasks-fixture "$FIXTURE_ROOT/baseline/tasks.json" --check-task-runtime >/tmp/t2_task_version.out 2>&1; then
  cat /tmp/t2_task_version.out >&2
  fail "runtime state should reject task version drift"
fi

cp "$FIXTURE_ROOT/replan/delivery-state.json" "$TMP_DIR/replan-lineage-drift.json"
python3 - "$TMP_DIR/replan-lineage-drift.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["state"]["tasks"] = [
    {
        "task_id": "T999",
        "runtime_status": "IN_PROGRESS",
        "owner": "developer",
        "attempt_count": 1,
        "current_batch": 2,
        "next_action": "continue",
        "latest_upstream_refs": [
            "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T999"
        ],
    }
]
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$TMP_DIR/replan-lineage-drift.json" --tasks-fixture "$FIXTURE_ROOT/replan/tasks-v2.json" --check-replan-switch >/tmp/t2_replan_lineage.out 2>&1; then
  cat /tmp/t2_replan_lineage.out >&2
  fail "replan switch should reject unknown tasks in new active lineage"
fi

cp "$FIXTURE_ROOT/blocked/enter-blocked.json" "$TMP_DIR/invalid-resume-stage.json"
python3 - "$TMP_DIR/invalid-resume-stage.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["blocker"]["resume_stage"] = "DESIGN"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$TMP_DIR/invalid-resume-stage.json" --check-enter-blocked >/tmp/t2_enter_blocked.out 2>&1; then
  cat /tmp/t2_enter_blocked.out >&2
  fail "enter blocked should reject invalid resume stage"
fi

cp "$FIXTURE_ROOT/blocked/enter-blocked.json" "$TMP_DIR/mismatched-block-origin.json"
python3 - "$TMP_DIR/mismatched-block-origin.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["state"]["current_stage"] = "PHASE_REVIEW"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$TMP_DIR/mismatched-block-origin.json" --check-enter-blocked >/tmp/t2_block_origin.out 2>&1; then
  cat /tmp/t2_block_origin.out >&2
  fail "enter blocked should reject blocked_from_stage drift"
fi

cp "$FIXTURE_ROOT/blocked/leave-blocked.json" "$TMP_DIR/mismatched-unblock.json"
python3 - "$TMP_DIR/mismatched-unblock.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["resolution"]["resume_stage"] = "REPLAN_PENDING"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$TMP_DIR/mismatched-unblock.json" --check-leave-blocked >/tmp/t2_leave_blocked.out 2>&1; then
  cat /tmp/t2_leave_blocked.out >&2
  fail "leave blocked should reject resume stage drift"
fi

cp "$FIXTURE_ROOT/quarantine/restore-request.json" "$TMP_DIR/wrong-restore-basis.json"
python3 - "$TMP_DIR/wrong-restore-basis.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["restore_basis_refs"] = ["artifact://evidence/sample-feature.phase-1.restore@ev-wrong#root"]
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/manage_artifact_registry.py" --fixture "$TMP_DIR/wrong-restore-basis.json" --check-restore >/tmp/t2_restore_basis.out 2>&1; then
  cat /tmp/t2_restore_basis.out >&2
  fail "restore should reject wrong restore_basis_refs"
fi

echo "[PASS] standard chain runtime state"
