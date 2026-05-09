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
  mkdir -p "$target/contracts" "$target/docs/feature--audit/phase-1" "$target/docs/feature--audit/supporting"

  cat >"$target/contracts/active-doc-scope.yaml" <<'EOF'
version: 2
context_contract_phase: cleanup
record_contract:
  required: [feature_path, mode, management_status, layout, entry_ref, context_owner]
  enums:
    mode: [standard-chain]
    management_status: [legacy, managed, migrated]
    layout: [dated-workset, phase-tree]
    context_contract_phase: [cleanup]
scope_entries:
  - feature_path: docs/feature--audit
    mode: standard-chain
    management_status: managed
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: audit-owner
  - feature_path: docs/feature--legacy
    mode: standard-chain
    management_status: legacy
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: legacy-owner
    archive_ref: docs/archive/missing-legacy
    archived_at: 2026-01-01
EOF

  cat >"$target/docs/feature--audit/worklog.md" <<'EOF'
# Audit Worklog

## 2026-01-01 00:00

- actor: Codex
- context_owner: audit-owner
- mode: standard-chain
- stage: BLOCKED
- scope_ref: phase-1
- handoff_status: blocked
- state_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/audit.phase-1.tasks@tasks-v1#plan-version
- next: Waiting
- next_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/audit.phase-1.tasks@tasks-v1#task-registry
- blocker: upstream decision missing
- waiting_on: user
- unblock_condition: user decides
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
assert_present "hooks/managed/context_contract_validator.py" "$TMP_DIR/codex-hooks.json"
if grep -Fq "implementation_router.py" "$TMP_DIR/codex-hooks.json"; then
  fail "codex hooks should not include implementation router"
fi

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
[ "$before_digest" = "$after_digest" ] || fail "audit should not mutate scope registry"
assert_present "risk: long_blocked" "$TMP_DIR/audit.out"
assert_present "risk: supporting_overuse" "$TMP_DIR/audit.out"
assert_present "risk: legacy_drift" "$TMP_DIR/audit.out"
assert_present "risk: expired_waiver" "$TMP_DIR/audit.out"

echo "[PASS] context contract audit"
