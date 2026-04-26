#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$ROOT/tests/fixtures/context-contract/audit"
AUDIT="$ROOT/tools/dev/run-context-contract-audit.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

before="$(git -C "$ROOT" diff -- tests/fixtures/context-contract/audit)"
bash "$AUDIT" "$FIX" >/tmp/context_audit.out
after="$(git -C "$ROOT" diff -- tests/fixtures/context-contract/audit)"
[ "$before" = "$after" ] || fail "audit must not modify fixture files"

grep -Fq '"mode": "audit"' /tmp/context_audit.out || fail "audit mode missing"
grep -Fq '"decision": "report"' /tmp/context_audit.out || fail "audit report decision missing"
grep -Fq '"reason": "audit_long_blocked"' /tmp/context_audit.out || fail "long blocked finding missing"
grep -Fq '"reason": "audit_expired_waiver"' /tmp/context_audit.out || fail "expired waiver finding missing"
grep -Fq '"reason": "audit_supporting_metadata_missing"' /tmp/context_audit.out || fail "supporting metadata finding missing"
grep -Fq '"reason": "audit_legacy_drift"' /tmp/context_audit.out || fail "legacy drift finding missing"

printf '[PASS] context contract audit\n'
