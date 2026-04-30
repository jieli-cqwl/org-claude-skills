#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTIVE="$ROOT/shared/skills/delivery-owner"
HISTORICAL="$ROOT/shared/skills/delivery-owner-h"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ ! -f "$ACTIVE/scripts/commit_preflight_check.sh" ] \
  || fail "commit preflight must not remain in active delivery-owner"
[ -f "$HISTORICAL/scripts/commit_preflight_check.sh" ] \
  || fail "historical delivery-owner-h must retain commit preflight during migration"

printf '[PASS] delivery-owner commit preflight retired from active skill\n'
