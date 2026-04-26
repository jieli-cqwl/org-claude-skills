#!/usr/bin/env bash
# File responsibility: verify context-budget allowlist expirations are enforced.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

OUT="$(mktemp "${TMPDIR:-/tmp}/context-budget-expiry.XXXXXX.out")"
trap 'rm -f "$OUT"' EXIT

if CODEX_CONTEXT_BUDGET_TODAY=9999-12-31 bash "$ROOT/tests/test-skill-context-budget.sh" >"$OUT" 2>&1; then
  if grep -q 'WARN_ALLOWED' "$OUT"; then
    cat "$OUT" >&2
    fail "context budget allowlist must fail after expires date"
  fi
  printf '[PASS] skill context budget expiry (no active allowlist)\n'
  exit 0
fi

grep -Eq 'expired|expires=|9999-12-31' "$OUT" \
  || fail "expired allowlist failure should mention expiry details"

printf '[PASS] skill context budget expiry\n'
