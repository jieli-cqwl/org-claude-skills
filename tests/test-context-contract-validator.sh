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

make_valid_fixture() {
  local target="$1"
  mkdir -p \
    "$target/contracts" \
    "$target/docs/feature--small/2026-04-25-small" \
    "$target/docs/feature--standard/phase-1"

  cat >"$target/contracts/active-doc-scope.yaml" <<'EOF'
version: 2
context_contract_phase: bootstrap
record_contract:
  required: [feature_path, mode, management_status, layout, entry_ref, context_owner]
  bootstrap_compat_required: [status, owner, rollout_phase]
  enums:
    mode: [small-chain, standard-chain]
    management_status: [legacy, managed, migrated]
    status: [legacy, managed, migrated]
    layout: [dated-workset, phase-tree]
    context_contract_phase: [bootstrap, enforce, cleanup]
  conditional_required:
    dated-workset: [primary_workset_relpath]
    legacy: [archive_ref, archived_at]
scope_entries:
  - feature_path: docs/feature--small
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-small
    context_owner: small-owner
    owner: small-owner
  - feature_path: docs/feature--standard
    mode: standard-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: standard-owner
    owner: standard-owner
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
    update_triggers: [bootstrap]
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

  cat >"$target/docs/feature--small/worklog.md" <<'EOF'
# Small Worklog

## 2026-04-25 10:00

- actor: Codex
- context_owner: small-owner
- mode: small-chain
- stage: execute
- scope_ref: 2026-04-25-small/tasks.md#T1
- handoff_status: doing
- state_ref: 2026-04-25-small/tasks.md#T1
- next: Execute T1
- next_ref: 2026-04-25-small/plan.md#T1
EOF

  cat >"$target/docs/feature--small/2026-04-25-small/design.md" <<'EOF'
# Small Design
EOF
  cat >"$target/docs/feature--small/2026-04-25-small/tasks.md" <<'EOF'
# Tasks
- [ ] T1 Small task
EOF
  cat >"$target/docs/feature--small/2026-04-25-small/plan.md" <<'EOF'
# Plan

### Task 1: Small [T1]
1. [T1] Run small task
EOF

  cat >"$target/docs/feature--standard/worklog.md" <<'EOF'
# Standard Worklog

## 2026-04-25 11:00

- actor: Codex
- context_owner: standard-owner
- mode: standard-chain
- stage: TASK_EXECUTION
- scope_ref: phase-1
- handoff_status: doing
- state_ref: canonical:phase-1/artifact-registry.json::artifact://plan/std.phase-1.plan@plan-v1#plan-version
- next: Execute active task
- next_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/std.phase-1.tasks@tasks-v1#task-registry
EOF

  cat >"$target/docs/feature--standard/phase-1/delivery-state.json" <<'EOF'
{
  "current_stage": "TASK_EXECUTION"
}
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
  cat >"$target/docs/feature--standard/phase-1/plan.json" <<'EOF'
{"artifact_type": "plan"}
EOF
  cat >"$target/docs/feature--standard/phase-1/tasks.json" <<'EOF'
{"artifact_type": "tasks"}
EOF
}

run_validator() {
  python3 "$ROOT/tools/community/validate_context_contract.py" --repo-root "$1"
}

valid_fixture="$TMP_DIR/valid"
make_valid_fixture "$valid_fixture"
run_validator "$valid_fixture" >"$TMP_DIR/valid.out" || fail "valid context fixture should pass"
assert_present "[PASS] context contract" "$TMP_DIR/valid.out"

valid_legacy="$TMP_DIR/valid-legacy"
cp -R "$valid_fixture" "$valid_legacy"
cat >>"$valid_legacy/contracts/active-doc-scope.yaml" <<'EOF'
  - feature_path: docs/feature--legacy-small
    mode: small-chain
    management_status: legacy
    status: legacy
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-small
    context_owner: small-owner
    owner: small-owner
    archive_ref: docs/archive/feature--legacy-small/2026-04-25-small
    archived_at: 2026-04-25
EOF
mkdir -p "$valid_legacy/docs/archive/feature--legacy-small/2026-04-25-small"
cat >"$valid_legacy/docs/archive/feature--legacy-small/2026-04-25-small/worklog.md" <<'EOF'
# Archived Small Worklog

## 2026-04-25 12:00

- actor: Codex
- context_owner: small-owner
- mode: small-chain
- stage: verify
- scope_ref: tasks.md#T1
- handoff_status: done
- state_ref: tasks.md#T1
- next: Archived
- next_ref: plan.md#T1
EOF
cat >"$valid_legacy/docs/archive/feature--legacy-small/2026-04-25-small/tasks.md" <<'EOF'
# Tasks
- [x] T1 Archived task
EOF
cat >"$valid_legacy/docs/archive/feature--legacy-small/2026-04-25-small/plan.md" <<'EOF'
# Plan

### Task 1: Archived [T1]
1. [T1] Archive task
EOF
run_validator "$valid_legacy" >"$TMP_DIR/valid-legacy.out" || fail "valid legacy archived fixture should pass"
assert_present "[PASS] context contract" "$TMP_DIR/valid-legacy.out"

bad_legacy="$TMP_DIR/bad-legacy"
cp -R "$valid_legacy" "$bad_legacy"
python3 - "$bad_legacy/docs/archive/feature--legacy-small/2026-04-25-small/worklog.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("state_ref: tasks.md#T1", "state_ref: 2026-04-25-small/tasks.md#T1"), encoding="utf-8")
PY
if run_validator "$bad_legacy" >"$TMP_DIR/bad-legacy.out" 2>&1; then
  fail "unreachable archived worklog ref should fail"
fi
assert_present "reason: state_ref_unreachable" "$TMP_DIR/bad-legacy.out"

duplicate="$TMP_DIR/duplicate"
cp -R "$valid_fixture" "$duplicate"
python3 - "$duplicate/contracts/active-doc-scope.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
extra = """
  - feature_path: docs/feature--small
    mode: small-chain
    management_status: migrated
    status: migrated
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-small
    context_owner: small-owner
    owner: small-owner
"""
path.write_text(text + extra, encoding="utf-8")
PY
if run_validator "$duplicate" >"$TMP_DIR/duplicate.out" 2>&1; then
  fail "duplicate active feature should fail"
fi
assert_present "reason: duplicate_active_feature" "$TMP_DIR/duplicate.out"

missing_field="$TMP_DIR/missing-field"
cp -R "$valid_fixture" "$missing_field"
python3 - "$missing_field/docs/feature--small/worklog.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("- next_ref: 2026-04-25-small/plan.md#T1\n", ""), encoding="utf-8")
PY
if run_validator "$missing_field" >"$TMP_DIR/missing-field.out" 2>&1; then
  fail "missing worklog next_ref should fail"
fi
assert_present "reason: worklog_required_field_missing" "$TMP_DIR/missing-field.out"

unreachable="$TMP_DIR/unreachable"
cp -R "$valid_fixture" "$unreachable"
python3 - "$unreachable/docs/feature--small/worklog.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("2026-04-25-small/tasks.md#T1", "2026-04-25-small/missing.md#T1"), encoding="utf-8")
PY
if run_validator "$unreachable" >"$TMP_DIR/unreachable.out" 2>&1; then
  fail "unreachable worklog ref should fail"
fi
assert_present "reason: state_ref_unreachable" "$TMP_DIR/unreachable.out"

bad_ownership="$TMP_DIR/bad-ownership"
cp -R "$valid_fixture" "$bad_ownership"
python3 - "$bad_ownership/contracts/context-artifact-ownership.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("mechanical_checks: [schema]", "mechanical_checks: []", 1), encoding="utf-8")
PY
if run_validator "$bad_ownership" >"$TMP_DIR/bad-ownership.out" 2>&1; then
  fail "invalid ownership contract should fail"
fi
assert_present "reason: ownership_contract_invalid" "$TMP_DIR/bad-ownership.out"

supporting="$TMP_DIR/supporting"
cp -R "$valid_fixture" "$supporting"
mkdir -p "$supporting/docs/feature--small/supporting"
printf '# Extra\n' >"$supporting/docs/feature--small/supporting/context-note.md"
if run_validator "$supporting" >"$TMP_DIR/supporting.out" 2>&1; then
  fail "supporting doc without metadata should fail"
fi
assert_present "reason: supporting_metadata_missing" "$TMP_DIR/supporting.out"

drift="$TMP_DIR/drift"
cp -R "$valid_fixture" "$drift"
python3 - "$drift/docs/feature--small/2026-04-25-small/plan.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(
    path.read_text(encoding="utf-8") + "2. [T2] Drift task\n",
    encoding="utf-8",
)
PY
if run_validator "$drift" >"$TMP_DIR/drift.out" 2>&1; then
  fail "small-chain task/plan drift should fail"
fi
assert_present "reason: small_chain_task_plan_mismatch" "$TMP_DIR/drift.out"

inactive="$TMP_DIR/inactive"
cp -R "$valid_fixture" "$inactive"
python3 - "$inactive/docs/feature--standard/phase-1/artifact-registry.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["revisions"][0]["entries"][0]["active_for_consumption"] = False
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
if run_validator "$inactive" >"$TMP_DIR/inactive.out" 2>&1; then
  fail "inactive canonical ref should fail"
fi
assert_present "reason: canonical_ref_unreachable" "$TMP_DIR/inactive.out"

echo "[PASS] context contract validator"
