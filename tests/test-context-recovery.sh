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

make_feature() {
  local target="$1"
  local name="$2"
  local hour="$3"
  mkdir -p "$target/docs/feature--$name/phase-1"
  cat >"$target/docs/feature--$name/worklog.md" <<EOF
# ${name} Worklog

## 2026-05-08 ${hour}:00

- actor: Codex
- context_owner: ${name}-owner
- mode: standard-chain
- stage: TASK_EXECUTION
- scope_ref: phase-1
- handoff_status: doing
- state_ref: canonical:phase-1/artifact-registry.json::artifact://plan/${name}.phase-1.plan@plan-v1#plan-version
- next: Execute ${name}
- next_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/${name}.phase-1.tasks@tasks-v1#task-registry
EOF
  cat >"$target/docs/feature--$name/phase-1/delivery-state.json" <<'EOF'
{"current_stage": "TASK_EXECUTION"}
EOF
  cat >"$target/docs/feature--$name/phase-1/artifact-registry.json" <<EOF
{
  "active_revision_id": "rev-1",
  "revisions": [
    {
      "revision_id": "rev-1",
      "entries": [
        {
          "artifact_type": "plan",
          "artifact_id": "${name}.phase-1.plan",
          "version": "plan-v1",
          "artifact_path": "plan.json",
          "lifecycle_state": "FINALIZED",
          "active_for_consumption": true
        },
        {
          "artifact_type": "tasks",
          "artifact_id": "${name}.phase-1.tasks",
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
  printf '{"artifact_type":"plan"}\n' >"$target/docs/feature--$name/phase-1/plan.json"
  printf '{"artifact_type":"tasks"}\n' >"$target/docs/feature--$name/phase-1/tasks.json"
}

make_recovery_fixture() {
  local target="$1"
  mkdir -p "$target/contracts" "$target/docs/feature--unmanaged"
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
scope_entries:
  - feature_path: docs/feature--alpha
    mode: standard-chain
    management_status: managed
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: alpha-owner
  - feature_path: docs/feature--beta
    mode: standard-chain
    management_status: managed
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: beta-owner
  - feature_path: docs/feature--broken
    mode: standard-chain
    management_status: managed
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: broken-owner
EOF
  make_feature "$target" alpha 10
  make_feature "$target" beta 11
  make_feature "$target" broken 09
  python3 - "$target/docs/feature--broken/worklog.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("@plan-v1", "@missing", 1), encoding="utf-8")
PY
  cat >"$target/docs/feature--unmanaged/worklog.md" <<'EOF'
# Unmanaged
EOF
}

fixture="$TMP_DIR/recovery"
make_recovery_fixture "$fixture"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --list >"$TMP_DIR/list.out" || fail "active list should pass"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/list.out"
assert_present "feature_path: docs/feature--alpha" "$TMP_DIR/list.out"
assert_absent "feature_path: docs/feature--unmanaged" "$TMP_DIR/list.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature docs/feature--beta >"$TMP_DIR/exact.out" || fail "exact feature recovery should pass"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/exact.out"
assert_present "canonical:phase-1/artifact-registry.json::artifact://plan/beta.phase-1.plan@plan-v1#plan-version" "$TMP_DIR/exact.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature feature--beta >"$TMP_DIR/basename.out" || fail "basename feature recovery should pass"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/basename.out"

python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature feature >"$TMP_DIR/fuzzy.out" || fail "fuzzy match should produce choices"
assert_present "decision: choose" "$TMP_DIR/fuzzy.out"
assert_present "feature_path: docs/feature--alpha" "$TMP_DIR/fuzzy.out"
assert_present "feature_path: docs/feature--beta" "$TMP_DIR/fuzzy.out"

if python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature docs/feature--broken >"$TMP_DIR/broken.out" 2>&1; then
  fail "broken canonical ref should fail"
fi
assert_present "reason: canonical_ref_unreachable" "$TMP_DIR/broken.out"

if python3 "$ROOT/tools/community/recover_context.py" --repo-root "$fixture" --feature missing >"$TMP_DIR/missing.out" 2>&1; then
  fail "missing feature should fail"
fi
assert_present "reason: feature_not_found" "$TMP_DIR/missing.out"

echo "[PASS] context recovery"
