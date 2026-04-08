#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

CLAUDE_PROBE="$ROOT/tools/dev/probe-claude-capabilities.sh"
CODEX_PROBE="$ROOT/tools/dev/probe-codex-capabilities.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_reference_probe_contract() {
  local file="$1"
  local runtime_name="$2"

  assert_present 'Entry Reference Activation' "$file"
  assert_present 'reference/runtime-reference-probe\.md' "$file"
  assert_present '运行时外部引用探针' "$file"
  assert_present 'probe-home' "$file"
  assert_present "prompt=\"\\\$trigger\"" "$file"
  assert_present 'REF_MISSING' "$file"

  if [ "$runtime_name" = "claude" ]; then
    assert_present '\.claude/reference/runtime-reference-probe\.md' "$file"
    assert_present '\.claude/CLAUDE\.md' "$file"
    assert_present "HOME=\"\\\$probe_home\"" "$file"
  else
    assert_present '\.codex/reference/runtime-reference-probe\.md' "$file"
    assert_present '\.codex/AGENTS\.md' "$file"
    assert_present "HOME=\"\\\$probe_home\"" "$file"
  fi
}

assert_reference_probe_contract "$CLAUDE_PROBE" "claude"
assert_reference_probe_contract "$CODEX_PROBE" "codex"

echo "[PASS] runtime reference activation"
