#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tools/community/standard_chain_negative_cases.py"

[ -f "$RUNNER" ] || {
  printf '[FAIL] missing standard-chain negative case runner\n' >&2
  exit 1
}

python3 "$RUNNER" \
  --pilot "$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json"

printf '[PASS] standard-chain product-delivery negative modes\n'
