#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

RULE="$ROOT/shared/rules/文档管理.md"

assert_present 'contracts/active-doc-scope\.yaml' "$RULE"
assert_present 'managed / migrated' "$RULE"
assert_present 'docs/\{feature\}/worklog\.md' "$RULE"
assert_present 'handoff_status / state_ref / next_ref' "$RULE"
assert_present 'small-chain 的进展真源是 active workset 内的 design\.md / tasks\.md / plan\.md / verify-change-report\.md' "$RULE"
assert_present 'standard-chain 的进展真源是 canonical JSON' "$RULE"
assert_present 'validate_context_contract\.py' "$RULE"
assert_present 'recover_context\.py' "$RULE"
assert_present 'archive_ref / archived_at' "$RULE"

echo "[PASS] doc management rule contract"
