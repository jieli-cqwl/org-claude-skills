#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Fq "$pattern" "$file" || {
    cat "$file" >&2
    fail "expected pattern missing: $pattern"
  }
}

make_standard_fixture() {
  local target="$1"
  mkdir -p "$target/contracts" "$target/docs/feature--standard/phase-1"

  cat >"$target/contracts/active-doc-scope.yaml" <<'EOF'
version: 2
context_contract_phase: cleanup
record_contract:
  required: [feature_path, mode, management_status, layout, entry_ref, context_owner]
  bootstrap_compat_required: []
  enums:
    mode: [standard-chain]
    management_status: [legacy, managed, migrated]
    status: [legacy, managed, migrated]
    layout: [dated-workset, phase-tree]
    context_contract_phase: [cleanup]
  conditional_required:
    dated-workset: [primary_workset_relpath]
    legacy: [archive_ref, archived_at]
scope_entries:
  - feature_path: docs/feature--standard
    mode: standard-chain
    management_status: managed
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: standard-owner
EOF

  cat >"$target/contracts/context-artifact-ownership.yaml" <<'EOF'
version: 1
repo_owners:
  context_registry_owner: runtime-maintainers
  context_contract_owner: runtime-maintainers
  context_validator_owner: runtime-maintainers
artifacts:
  - artifact_id: scope_registry
    path: contracts/active-doc-scope.yaml
    artifact_owner: context_registry_owner
    update_triggers: [cleanup]
    mechanical_checks: [schema]
  - artifact_id: context_artifact_ownership
    path: contracts/context-artifact-ownership.yaml
    artifact_owner: context_contract_owner
    update_triggers: [owner_model_change]
    mechanical_checks: [schema]
waiver_approvers:
  scope_registry: context_registry_owner
  context_artifact_ownership: context_contract_owner
  context_validator: context_validator_owner
EOF

  cat >"$target/docs/feature--standard/worklog.md" <<'EOF'
# Standard Worklog

## 2026-05-08 11:00

- actor: Codex
- context_owner: standard-owner
- mode: standard-chain
- stage: TASK_EXECUTION
- scope_ref: phase-1
- handoff_status: doing
- state_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/std.phase-1.tasks@tasks-v1#plan-version
- next: Execute active task
- next_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/std.phase-1.tasks@tasks-v1#task-registry
EOF

  cat >"$target/docs/feature--standard/phase-1/delivery-state.json" <<'EOF'
{"current_stage": "TASK_EXECUTION"}
EOF
  cat >"$target/docs/feature--standard/phase-1/artifact-registry.json" <<'EOF'
{
  "active_revision_id": "rev-1",
  "revisions": [
    {
      "revision_id": "rev-1",
      "entries": [
        {
          "artifact_type": "plan",
          "artifact_id": "std.phase-1.plan",
          "version": "plan-v1",
          "artifact_path": "plan.json",
          "lifecycle_state": "FINALIZED",
          "active_for_consumption": true
        },
        {
          "artifact_type": "tasks",
          "artifact_id": "std.phase-1.tasks",
          "version": "tasks-v1",
          "artifact_path": "tasks.json",
          "lifecycle_state": "FINALIZED",
          "active_for_consumption": true
        }
      ]
    }
  ]
}
EOF
  printf '{"artifact_type":"plan"}\n' >"$target/docs/feature--standard/phase-1/plan.json"
  printf '{"artifact_type":"tasks"}\n' >"$target/docs/feature--standard/phase-1/tasks.json"
}

run_validator() {
  python3 "$ROOT/tools/community/validate_context_contract.py" --repo-root "$1"
}

valid="$TMP_DIR/valid"
make_standard_fixture "$valid"
run_validator "$valid" >"$TMP_DIR/valid.out" || fail "valid standard-chain fixture should pass"
assert_present "[PASS] context contract" "$TMP_DIR/valid.out"

bad_mode="$TMP_DIR/bad-mode"
cp -R "$valid" "$bad_mode"
python3 - "$bad_mode/contracts/active-doc-scope.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("mode: standard-chain", "mode: legacy-chain", 1), encoding="utf-8")
PY
if run_validator "$bad_mode" >"$TMP_DIR/bad-mode.out" 2>&1; then
  fail "non-standard active mode should fail"
fi
assert_present "reason: scope_registry_schema_invalid" "$TMP_DIR/bad-mode.out"

bad_stage="$TMP_DIR/bad-stage"
cp -R "$valid" "$bad_stage"
python3 - "$bad_stage/docs/feature--standard/worklog.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("stage: TASK_EXECUTION", "stage: UNKNOWN_STAGE"), encoding="utf-8")
PY
if run_validator "$bad_stage" >"$TMP_DIR/bad-stage.out" 2>&1; then
  fail "invalid standard stage should fail"
fi
assert_present "reason: worklog_enum_invalid" "$TMP_DIR/bad-stage.out"

bad_ref="$TMP_DIR/bad-ref"
cp -R "$valid" "$bad_ref"
python3 - "$bad_ref/docs/feature--standard/worklog.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("artifact://tasks/std.phase-1.tasks@tasks-v1", "artifact://tasks/std.phase-1.tasks@missing"), encoding="utf-8")
PY
if run_validator "$bad_ref" >"$TMP_DIR/bad-ref.out" 2>&1; then
  fail "unresolvable canonical ref should fail"
fi
assert_present "reason: canonical_ref_unreachable" "$TMP_DIR/bad-ref.out"

echo "[PASS] context contract validator"
