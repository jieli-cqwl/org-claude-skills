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

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Fq "$pattern" "$file"; then
    cat "$file" >&2
    fail "unexpected pattern present: $pattern"
  fi
}

make_recovery_fixture() {
  local target="$1"
  mkdir -p \
    "$target/contracts" \
    "$target/docs/feature--alpha/2026-04-25-alpha" \
    "$target/docs/feature--beta/2026-04-25-beta" \
    "$target/docs/feature--broken/2026-04-25-broken" \
    "$target/docs/feature--unmanaged" \
    "$target/docs/archive/feature--alpha-previous" \
    "$target/docs/archive/feature--old"

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
  - feature_path: docs/feature--alpha
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-alpha
    context_owner: alpha-owner
    owner: alpha-owner
  - feature_path: docs/feature--beta
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-beta
    context_owner: beta-owner
    owner: beta-owner
  - feature_path: docs/feature--broken
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-broken
    context_owner: broken-owner
    owner: broken-owner
  - feature_path: docs/feature--alpha
    mode: small-chain
    management_status: legacy
    status: legacy
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    context_owner: alpha-owner
    owner: alpha-owner
    archive_ref: docs/archive/feature--alpha-previous
    archived_at: 2026-04-20
  - feature_path: docs/feature--old
    mode: small-chain
    management_status: legacy
    status: legacy
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    context_owner: old-owner
    owner: old-owner
    archive_ref: docs/archive/feature--old
    archived_at: 2026-04-19
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
EOF

  for feature in alpha beta broken; do
    local workset="2026-04-25-$feature"
    cat >"$target/docs/feature--$feature/$workset/tasks.md" <<EOF
# Tasks
- [ ] T1 $feature
EOF
    cat >"$target/docs/feature--$feature/$workset/plan.md" <<EOF
# Plan

### Task 1: $feature [T1]
1. [T1] Execute $feature
EOF
  done

  cat >"$target/docs/feature--alpha/worklog.md" <<'EOF'
# Alpha Worklog

## 2026-04-25 10:00

- actor: Codex
- context_owner: alpha-owner
- mode: small-chain
- stage: execute
- scope_ref: 2026-04-25-alpha/tasks.md#T1
- handoff_status: doing
- state_ref: 2026-04-25-alpha/tasks.md#T1
- next: Execute alpha
- next_ref: 2026-04-25-alpha/plan.md#T1
EOF
  cat >"$target/docs/feature--beta/worklog.md" <<'EOF'
# Beta Worklog

## 2026-04-25 11:00

- actor: Codex
- context_owner: beta-owner
- mode: small-chain
- stage: execute
- scope_ref: 2026-04-25-beta/tasks.md#T1
- handoff_status: doing
- state_ref: 2026-04-25-beta/tasks.md#T1
- next: Execute beta
- next_ref: 2026-04-25-beta/plan.md#T1
EOF
  cat >"$target/docs/feature--broken/worklog.md" <<'EOF'
# Broken Worklog

## 2026-04-25 09:00

- actor: Codex
- context_owner: broken-owner
- mode: small-chain
- stage: execute
- scope_ref: 2026-04-25-broken/tasks.md#T1
- handoff_status: doing
- state_ref: 2026-04-25-broken/missing.md#T1
- next: Execute broken
- next_ref: 2026-04-25-broken/plan.md#T1
EOF
  cat >"$target/docs/feature--unmanaged/worklog.md" <<'EOF'
# Unmanaged

## 2026-04-25 12:00

- handoff_status: doing
EOF
  for archived in feature--alpha-previous feature--old; do
    cat >"$target/docs/archive/$archived/worklog.md" <<'EOF'
# Archived Worklog

## 2026-04-20 08:00

- actor: Codex
- context_owner: archive-owner
- mode: small-chain
- stage: finish
- scope_ref: tasks.md#T1
- handoff_status: done
- state_ref: tasks.md#T1
- next: Archived
- next_ref: plan.md#T1
EOF
    cat >"$target/docs/archive/$archived/tasks.md" <<'EOF'
# Tasks
- [x] T1 Archived task
EOF
    cat >"$target/docs/archive/$archived/plan.md" <<'EOF'
# Plan

### Task 1: Archived [T1]
1. [T1] Close archived task
EOF
  done
}

fixture="$TMP_DIR/recovery"
make_recovery_fixture "$fixture"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --list >"$TMP_DIR/list.out" || fail "active list should pass"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/list.out"
assert_present "feature_path: docs/feature--alpha" "$TMP_DIR/list.out"
assert_absent "feature_path: docs/feature--unmanaged" "$TMP_DIR/list.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature docs/feature--beta >"$TMP_DIR/exact.out" || fail "exact feature recovery should pass"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/exact.out"
assert_present "state_ref: 2026-04-25-beta/tasks.md#T1" "$TMP_DIR/exact.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature feature--beta >"$TMP_DIR/basename.out" || fail "basename feature recovery should pass"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/basename.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature feature >"$TMP_DIR/fuzzy.out" || fail "fuzzy match should produce choices"
assert_present "decision: choose" "$TMP_DIR/fuzzy.out"
assert_present "feature_path: docs/feature--alpha" "$TMP_DIR/fuzzy.out"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/fuzzy.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature feature--old >"$TMP_DIR/archived.out" || fail "active miss should recover legacy basename"
assert_present "feature_path: docs/feature--old" "$TMP_DIR/archived.out"
assert_present "archive_ref: docs/archive/feature--old" "$TMP_DIR/archived.out"
assert_present "worklog: docs/archive/feature--old/worklog.md" "$TMP_DIR/archived.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --archived --feature feature--old >"$TMP_DIR/explicit-archived.out" || fail "explicit archived recovery should pass"
assert_present "feature_path: docs/feature--old" "$TMP_DIR/explicit-archived.out"
assert_present "archive_ref: docs/archive/feature--old" "$TMP_DIR/explicit-archived.out"
assert_present "worklog: docs/archive/feature--old/worklog.md" "$TMP_DIR/explicit-archived.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature feature--alpha >"$TMP_DIR/collision.out" || fail "active and archived collision should list choices"
assert_present "decision: choose" "$TMP_DIR/collision.out"
assert_present "archive_ref: docs/archive/feature--alpha-previous" "$TMP_DIR/collision.out"

if python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature docs/feature--broken >"$TMP_DIR/broken.out" 2>&1; then
  fail "unreachable state_ref should block recovery"
fi
assert_present "decision: block" "$TMP_DIR/broken.out"
assert_present "reason: state_ref_unreachable" "$TMP_DIR/broken.out"

python3 "$ROOT/tools/community/update_active_doc_scope.py" --repo-root "$fixture" set-phase enforce
grep -Fq "context_contract_phase: enforce" "$fixture/contracts/active-doc-scope.yaml" || fail "set-phase should write enforce"

mkdir -p "$fixture/docs/archive/feature--beta"
cp "$fixture/docs/feature--beta/worklog.md" "$fixture/docs/archive/feature--beta/worklog.md"
python3 "$ROOT/tools/community/update_active_doc_scope.py" \
  --repo-root "$fixture" \
  archive \
  --feature docs/feature--beta \
  --archive-ref docs/archive/feature--beta \
  --archived-at 2026-04-25
grep -Fq "management_status: legacy" "$fixture/contracts/active-doc-scope.yaml" || fail "archive should mark entry legacy"
grep -Fq "archive_ref: docs/archive/feature--beta" "$fixture/contracts/active-doc-scope.yaml" || fail "archive should write archive_ref"

echo "[PASS] context recovery"
