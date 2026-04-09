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

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_reference_probe_contract() {
  local file="$1"
  local runtime_name="$2"

  assert_present 'Entry Absolute Runtime Link Activation' "$file"
  assert_present 'Rule Absolute Runtime Link Activation' "$file"
  assert_present 'Runtime Entry Reference Activation Probe' "$file"
  assert_present 'Runtime Rule Reference Activation Probe' "$file"
  assert_present 'Runtime Rule Contract Activation Probe' "$file"
  assert_present '运行时入口绝对路径引用探针' "$file"
  assert_present '运行时规则绝对路径引用探针' "$file"
  assert_present 'probe-home' "$file"
  assert_present "prompt=\"\\\$trigger\"" "$file"
  assert_present 'REF_MISSING' "$file"
  assert_present 'RULE_DOC_MISSING' "$file"
  assert_present 'RULE_REF_MISSING' "$file"
  assert_absent 'reference/runtime-reference-probe\.md' "$file"

  if [ "$runtime_name" = "claude" ]; then
    assert_present '\.claude/reference/runtime-entry-reference-probe\.md' "$file"
    assert_present '\.claude/reference/runtime-rule-reference-probe\.md' "$file"
    assert_present '\.claude/rules/铁律\.md' "$file"
    assert_present '\.claude/CLAUDE\.md' "$file"
    assert_present "HOME=\"\\\$probe_home\"" "$file"
    assert_present 'Use the Bash tool exactly once to run' "$file"
    assert_present "cat \\\$reference_path" "$file"
    assert_present "cat \\\$read_path" "$file"
  else
    assert_present '\.codex/reference/runtime-entry-reference-probe\.md' "$file"
    assert_present '\.codex/reference/runtime-rule-reference-probe\.md' "$file"
    assert_present '\.codex/rules/铁律\.md' "$file"
    assert_present '\.codex/AGENTS\.md' "$file"
    assert_present "HOME=\"\\\$probe_home\"" "$file"
    assert_present '1\. Read ' "$file"
    assert_present "reference_path" "$file"
    assert_present "read_path" "$file"
  fi
}

assert_reference_probe_contract "$CLAUDE_PROBE" "claude"
assert_reference_probe_contract "$CODEX_PROBE" "codex"

echo "[PASS] runtime reference activation"
