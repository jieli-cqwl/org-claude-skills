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

WRAPPER="$ROOT/shared/hooks/managed/context_contract_validator.py"
[ -f "$WRAPPER" ] || fail "missing context contract hook wrapper"

mkdir -p "$TMP_DIR/no-contract"
python3 "$WRAPPER" <<JSON >"$TMP_DIR/no-contract.out"
{"cwd":"$TMP_DIR/no-contract","stop_hook_active":false}
JSON
assert_present "{}" "$TMP_DIR/no-contract.out"

mkdir -p "$TMP_DIR/invalid/contracts"
cat >"$TMP_DIR/invalid/contracts/active-doc-scope.yaml" <<'EOF'
version: 1
EOF

python3 "$WRAPPER" <<JSON >"$TMP_DIR/invalid.out"
{"cwd":"$TMP_DIR/invalid","stop_hook_active":false}
JSON
assert_present '"continue": false' "$TMP_DIR/invalid.out"
assert_present 'scope_registry_schema_invalid' "$TMP_DIR/invalid.out"

echo "[PASS] context contract hook"
