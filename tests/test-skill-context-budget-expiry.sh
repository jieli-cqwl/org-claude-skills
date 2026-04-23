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

if CODEX_CONTEXT_BUDGET_TODAY=2026-05-16 bash "$ROOT/tests/test-skill-context-budget.sh" >"$OUT" 2>&1; then
  cat "$OUT" >&2
  fail "context budget allowlist must fail after expires date"
fi

grep -Eq 'expired|expires=2026-05-15|2026-05-16' "$OUT" \
  || fail "expired allowlist failure should mention expiry details"

printf '[PASS] skill context budget expiry\n'
