#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -Eq "$pattern" "$file" || fail "$label"
}

assert_present '^version: 2$' "$ROOT/contracts/active-doc-scope.yaml" "active scope registry must be version 2"
assert_present '^context_contract_phase: bootstrap$' "$ROOT/contracts/active-doc-scope.yaml" "registry must declare bootstrap phase"
assert_present 'management_status' "$ROOT/contracts/active-doc-scope.yaml" "target management_status field missing"
assert_present 'context_owner' "$ROOT/contracts/active-doc-scope.yaml" "target context_owner field missing"
assert_present 'entry_ref' "$ROOT/contracts/active-doc-scope.yaml" "target entry_ref field missing"
assert_present 'status.*compatibility|compatibility.*status|v1 compatibility' "$ROOT/contracts/active-doc-scope.yaml" "bootstrap compatibility wording missing"
assert_present 'scope registry|active-doc-scope' "$ROOT/README.md" "README must mention scope registry"
assert_present 'management_status in \[managed, migrated\]' "$ROOT/README.md" "README must mention active management_status values"
assert_present 'handoff_status' "$ROOT/README.md" "README must mention handoff_status"
assert_present 'context_owner' "$ROOT/README.md" "README must mention context_owner"
assert_present 'artifact_owner' "$ROOT/README.md" "README must mention artifact_owner"
assert_present 'canonical:' "$ROOT/README.md" "README must mention canonical refs"
assert_present 'worklog.md' "$ROOT/contracts/small-chain.yaml" "small-chain contract must mention worklog entry"
assert_present 'active_status_field: management_status' "$ROOT/contracts/small-chain.yaml" "small-chain contract must use management_status"
assert_present 'allowed_stages: \[entry, plan, env, execute, verify-preflight, verify, integrate, finish, blocked\]' "$ROOT/contracts/small-chain.yaml" "small-chain stages missing"
assert_present 'canonical:' "$ROOT/contracts/standard-chain.yaml" "standard-chain contract must mention canonical active ref grammar"

mkdir -p "$TMP_DIR/contracts" "$TMP_DIR/docs/feature--context--lifecycle/2026-04-25-demo"
python3 "$ROOT/tools/community/update_active_doc_scope.py" bootstrap --root "$TMP_DIR" --phase bootstrap
assert_present '^version: 2$' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper bootstrap must write version 2"
assert_present '^context_contract_phase: bootstrap$' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper bootstrap must write bootstrap phase"

python3 "$ROOT/tools/community/update_active_doc_scope.py" adopt \
  --root "$TMP_DIR" \
  --feature-path docs/feature--context--lifecycle \
  --mode small-chain \
  --layout dated-workset \
  --workset 2026-04-25-demo \
  --context-owner feature-runtime-owner
assert_present 'feature_path: docs/feature--context--lifecycle' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper adopt must write feature_path"
assert_present 'management_status: managed' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper adopt must write management_status"
assert_present 'entry_ref: worklog.md' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper adopt must write entry_ref"

python3 "$ROOT/tools/community/update_active_doc_scope.py" phase --root "$TMP_DIR" --phase enforce
assert_present '^context_contract_phase: enforce$' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper phase must switch enforce"

python3 "$ROOT/tools/community/update_active_doc_scope.py" archive \
  --root "$TMP_DIR" \
  --feature-path docs/feature--context--lifecycle \
  --archive-ref docs/archive/feature--context--lifecycle \
  --archived-at 2026-04-26
assert_present 'management_status: legacy' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper archive must mark legacy"
assert_present 'archive_ref: docs/archive/feature--context--lifecycle' "$TMP_DIR/contracts/active-doc-scope.yaml" "helper archive must write archive_ref"

printf '[PASS] active doc scope lifecycle bootstrap\n'
