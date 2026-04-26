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

make_audit_fixture() {
  local target="$1"
  mkdir -p \
    "$target/contracts" \
    "$target/docs/feature--audit/2026-04-25-audit" \
    "$target/docs/feature--audit/supporting"

  cat >"$target/contracts/active-doc-scope.yaml" <<'EOF'
version: 2
context_contract_phase: bootstrap
record_contract:
  required: [feature_path, mode, management_status, layout, entry_ref, context_owner]
  enums:
    mode: [small-chain, standard-chain]
    management_status: [legacy, managed, migrated]
    layout: [dated-workset, phase-tree]
    context_contract_phase: [bootstrap, enforce, cleanup]
scope_entries:
  - feature_path: docs/feature--audit
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-audit
    context_owner: audit-owner
    owner: audit-owner
  - feature_path: docs/feature--legacy
    mode: small-chain
    management_status: legacy
    status: legacy
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    context_owner: legacy-owner
    owner: legacy-owner
    archive_ref: docs/archive/missing-legacy
    archived_at: 2026-01-01
EOF

  cat >"$target/docs/feature--audit/worklog.md" <<'EOF'
# Audit Worklog

## 2026-01-01 00:00

- actor: Codex
- context_owner: audit-owner
- mode: small-chain
- stage: blocked
- scope_ref: 2026-04-25-audit/tasks.md#T1
- handoff_status: blocked
- state_ref: 2026-04-25-audit/tasks.md#T1
- next: Waiting
- next_ref: 2026-04-25-audit/plan.md#T1
- blocker: upstream decision missing
- waiting_on: user
- unblock_condition: user decides
- decision_needed: choose path
EOF

  cat >"$target/docs/feature--audit/2026-04-25-audit/tasks.md" <<'EOF'
# Tasks
- [ ] T1 Audit
EOF
  cat >"$target/docs/feature--audit/2026-04-25-audit/plan.md" <<'EOF'
# Plan

### Task 1: Audit [T1]
1. [T1] Wait
EOF

  cat >"$target/docs/feature--audit/contract-waivers.md" <<'EOF'
- waiver_id: CW-2026-01-01-001
  rule_id: context.audit.example
  scope: docs/feature--audit
  reason: expired fixture
  approver: context_registry_owner
  approved_at: 2026-01-01
  expires_at: 2026-01-02
  compensating_control: none
EOF

  for idx in 1 2 3 4; do
    cat >"$target/docs/feature--audit/supporting/note-$idx.md" <<'EOF'
- purpose: audit fixture
- serves: tests
- reason_here: support overuse
EOF
  done
}

bash "$ROOT/tools/dev/validate-contracts.sh" >"$TMP_DIR/validate.out" || fail "validate-contracts should pass"
assert_present "[PASS] context contract" "$TMP_DIR/validate.out"

python3 "$ROOT/tools/community/render_hook_registry.py" \
  codex-hooks \
  --registry "$ROOT/shared/hooks/registry.json" \
  --runtime-home "\$HOME/.codex" >"$TMP_DIR/codex-hooks.json"
assert_present "validate_context_contract.py" "$TMP_DIR/codex-hooks.json"

fixture="$TMP_DIR/audit"
make_audit_fixture "$fixture"
before_digest="$(python3 - "$fixture/contracts/active-doc-scope.yaml" <<'PY'
import hashlib
import sys
from pathlib import Path

print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"

bash "$ROOT/tools/dev/run-context-contract-audit.sh" --repo-root "$fixture" >"$TMP_DIR/audit.out" || fail "audit should be report-only and pass"
after_digest="$(python3 - "$fixture/contracts/active-doc-scope.yaml" <<'PY'
import hashlib
import sys
from pathlib import Path

print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
[ "$before_digest" = "$after_digest" ] || fail "audit must not modify registry"
assert_present "risk: long_blocked" "$TMP_DIR/audit.out"
assert_present "risk: expired_waiver" "$TMP_DIR/audit.out"
assert_present "risk: supporting_overuse" "$TMP_DIR/audit.out"
assert_present "risk: legacy_drift" "$TMP_DIR/audit.out"

echo "[PASS] context contract audit"
