#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

CLAUDE_PROBE="$ROOT/tools/dev/probe-claude-capabilities.sh"
CODEX_PROBE="$ROOT/tools/dev/probe-codex-capabilities.sh"
CODEX_HOOKS_PROBE="$ROOT/tools/dev/probe-codex-hooks.sh"

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

assert_probe_stability_contract() {
  assert_present 'If following the instructions in that file requires reading another file, continue with the required tool call\(s\)\.' "$CLAUDE_PROBE"
  assert_absent "cp -R \"\\\$HOME/\\.codex\" \"\\\$probe_home/\\.codex\"" "$CLAUDE_PROBE"
  assert_absent "cp -R \"\\\$CODEX_HOME\" \"\\\$probe_home/\\.codex\"" "$CODEX_PROBE"
  assert_present 'copy_runtime_context' "$CODEX_PROBE"
  assert_present 'FAIL_COUNT=0' "$CODEX_PROBE"
  assert_present 'FAIL_COUNT=' "$CODEX_PROBE"
  assert_present 'codex capability probe recorded %s failure\(s\)' "$CODEX_PROBE"
  assert_present 'fail_check "Codex 全局 hooks 探针脚本执行失败"' "$CODEX_PROBE"
  assert_present 'fail_check "Codex hooks.json 默认未捕获任何事件"' "$CODEX_PROBE"
  assert_present 'fail_check "Codex hooks.json 仅捕获到部分事件"' "$CODEX_PROBE"
  assert_present 'PROBE_RC=0' "$CODEX_HOOKS_PROBE"
  assert_present 'assert_hook_events_captured' "$CODEX_HOOKS_PROBE"
  assert_present 'missing hook event:' "$CODEX_HOOKS_PROBE"
  assert_present 'codex hooks probe command failed' "$CODEX_HOOKS_PROBE"
  assert_absent 'timeout 20 codex' "$CODEX_HOOKS_PROBE"
  assert_present 'timeout 60 codex' "$CODEX_HOOKS_PROBE"
}

assert_reference_probe_contract "$CLAUDE_PROBE" "claude"
assert_reference_probe_contract "$CODEX_PROBE" "codex"
assert_probe_stability_contract

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/bin"

cat > "$TMP_DIR/bin/codex" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 7
EOF
chmod +x "$TMP_DIR/bin/codex"
if PATH="$TMP_DIR/bin:$PATH" bash "$CODEX_HOOKS_PROBE" >/tmp/runtime_probe_rc.out 2>&1; then
  cat /tmp/runtime_probe_rc.out >&2
  fail "codex hooks probe should fail when codex exits non-zero"
fi
assert_present 'codex hooks probe command failed' /tmp/runtime_probe_rc.out

cat > "$TMP_DIR/bin/codex" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 0
EOF
chmod +x "$TMP_DIR/bin/codex"
if PATH="$TMP_DIR/bin:$PATH" bash "$CODEX_HOOKS_PROBE" >/tmp/runtime_probe_events.out 2>&1; then
  cat /tmp/runtime_probe_events.out >&2
  fail "codex hooks probe should fail when no hook events are captured"
fi
assert_present 'no hook events captured|missing hook event:' /tmp/runtime_probe_events.out

cat > "$TMP_DIR/bin/codex" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 7
EOF
chmod +x "$TMP_DIR/bin/codex"
if PATH="$TMP_DIR/bin:$PATH" bash "$CODEX_PROBE" >/tmp/runtime_capabilities_probe.out 2>&1; then
  cat /tmp/runtime_capabilities_probe.out >&2
  fail "codex capabilities probe should fail when codex exec fails"
fi
assert_present 'codex capability probe recorded [0-9]+ failure' /tmp/runtime_capabilities_probe.out

echo "[PASS] runtime reference activation"
