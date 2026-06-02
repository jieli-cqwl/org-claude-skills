#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
removed_prefix="StandardChain运行面分层"
removed_name="${removed_prefix}标准.md"
removed_path="$ROOT/shared/reference/$removed_name"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test ! -e "$removed_path" || fail "removed runtime layering standard still exists: $removed_path"

assert_rg_no_match \
  /tmp/removed_runtime_layering_refs.out \
  "active shared/tests/contracts still reference removed runtime layering standard" \
  -n --fixed-strings "$removed_name" "$ROOT/shared" "$ROOT/tests" "$ROOT/contracts"

assert_rg_no_match \
  /tmp/removed_runtime_layering_semantic_refs.out \
  "active shared/tests/contracts still depend on a runtime layering reference standard" \
  -n -g '!tests/test-standard-chain-runtime-layering-contract.sh' 'reference/.*运行面分层.*标准\.md|运行面分层.*职责边界以' "$ROOT/shared" "$ROOT/tests" "$ROOT/contracts"

printf '[PASS] standard-chain runtime layering standard removed\n'
