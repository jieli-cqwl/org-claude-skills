#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$PWD}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-capabilities.XXXXXX")"
FAIL_COUNT=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

pass() {
  printf '[PASS] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

fail_check() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$*"
}

json_agent_message_has_exact_text() {
  local file="$1"
  local expected="$2"
  python3 - "$file" "$expected" <<'PY'
import json
import sys

path = sys.argv[1]
expected = sys.argv[2]

with open(path, encoding="utf-8") as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        item = obj.get("item")
        if obj.get("type") != "item.completed" or not isinstance(item, dict):
            continue
        if item.get("type") != "agent_message":
            continue
        if item.get("text", "").strip() == expected:
            raise SystemExit(0)

raise SystemExit(1)
PY
}

json_agent_message_has_line() {
  local file="$1"
  local expected="$2"
  python3 - "$file" "$expected" <<'PY'
import json
import sys

path = sys.argv[1]
expected = sys.argv[2]

with open(path, encoding="utf-8") as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        item = obj.get("item")
        if obj.get("type") != "item.completed" or not isinstance(item, dict):
            continue
        if item.get("type") != "agent_message":
            continue
        lines = [line.strip() for line in item.get("text", "").splitlines()]
        if expected in lines:
            raise SystemExit(0)

raise SystemExit(1)
PY
}

prepend_follow_file_probe() {
  local doc_file="$1"
  local section_title="$2"
  local trigger="$3"
  local read_path="$4"
  local fallback_token="$5"
  local original

  original="$(cat "$doc_file")"

  cat >"$doc_file" <<EOF
## $section_title

For the exact user message "$trigger", this temporary probe section overrides all later workflow or confirmation instructions in this document.

When the user message is exactly "$trigger":
1. Read \`$read_path\`.
2. Follow the exact instructions in that file.
3. If the file is missing or unreadable, reply with exactly $fallback_token.
4. Do not add extra words.

$original
EOF
}

prepend_read_reference_probe() {
  local doc_file="$1"
  local section_title="$2"
  local trigger="$3"
  local reference_path="$4"
  local fallback_token="$5"
  local original

  original="$(cat "$doc_file")"

  cat >"$doc_file" <<EOF
## $section_title

For the exact user message "$trigger", this temporary probe section overrides all later workflow or confirmation instructions in this document.

When the user message is exactly "$trigger":
1. Read \`$reference_path\`.
2. Reply with exactly the activation token defined there.
3. If the file is missing or unreadable, reply with exactly $fallback_token.
4. Do not add extra words.

$original
EOF
}

run_probe() {
  local name="$1"
  shift
  printf '\n=== %s ===\n' "$name"
  "$@"
}

prepare_probe_home() {
  local probe_home="$1"

  copy_runtime_context() {
    local rel_path="$1"
    local src="$CODEX_HOME/$rel_path"
    local dst="$probe_home/.codex/$rel_path"

    if [ -d "$src" ]; then
      mkdir -p "$(dirname "$dst")"
      cp -R "$src" "$dst"
    elif [ -f "$src" ]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
  }

  rm -rf "$probe_home"
  mkdir -p "$probe_home/.codex"

  for rel in \
    "auth.json" \
    "config.toml" \
    "AGENTS.md" \
    "agents" \
    "rules" \
    "reference"
  do
    copy_runtime_context "$rel"
  done
}

run_codex_exec() {
  local prompt="$1"
  local out="$2"
  local err="$3"
  local timeout_seconds="${4:-20}"
  local attempts="${5:-2}"
  local exec_home="${CODEX_EXEC_HOME:-$HOME}"
  local rc=0
  local attempt=1

  while [ "$attempt" -le "$attempts" ]; do
    if (
      cd "$ROOT_DIR"
      HOME="$exec_home" CODEX_HOME="$exec_home/.codex" \
        timeout "$timeout_seconds" codex exec --json -c model_reasoning_effort="medium" - <<<"$prompt"
    ) >"$out" 2>"$err"; then
      return 0
    fi
    rc=$?
    if [ "$attempt" -lt "$attempts" ]; then
      sleep 1
    fi
    attempt=$((attempt + 1))
  done

  return "$rc"
}

probe_minimal_exec() {
  local out="$TMP_ROOT/minimal.out"
  local err="$TMP_ROOT/minimal.err"

  if ! run_codex_exec 'Reply with exactly OK.' "$out" "$err" 30 2; then
    fail_check "codex exec 最小调用失败"
    sed -n '1,120p' "$out"
    sed -n '1,120p' "$err"
    return 0
  fi

  if grep -Fq '"text":"OK"' "$out"; then
    pass "codex exec 最小调用通过"
  else
    fail_check "codex exec 未返回 OK"
    sed -n '1,200p' "$out"
  fi
}

probe_default_surface() {
  local out="$TMP_ROOT/default-surface.out"
  local err="$TMP_ROOT/default-surface.err"

  if ! run_codex_exec 'List all currently available skills by exact name only, one per line, no extra text.' "$out" "$err" 60 2; then
    fail_check "Codex 默认暴露面 runtime 枚举失败"
    sed -n '1,220p' "$out"
    sed -n '1,120p' "$err"
    return 0
  fi

  if ! json_agent_message_has_line "$out" "brainstorming"; then
    fail_check "Codex runtime 技能枚举未看到 brainstorming"
    sed -n '1,220p' "$out"
    sed -n '1,120p' "$err"
    return 0
  fi

  if [ ! -f "$CODEX_HOME/skills/brainstorming/agents/openai.yaml" ] \
    || [ -f "$CODEX_HOME/skills/using-superpowers/agents/openai.yaml" ] \
    || [ -f "$CODEX_HOME/skills/product-director/agents/openai.yaml" ] \
    || [ -f "$CODEX_HOME/skills/product-manager/agents/openai.yaml" ]; then
    fail_check "small-chain 自动暴露面不符合预期（brainstorming 应自动暴露，using-superpowers/product-director/product-manager 应为 manual-only）"
    find "$CODEX_HOME/skills" -path '*/agents/openai.yaml' | sort | sed -n '1,200p'
    return 0
  fi

  pass "small-chain 默认暴露面符合预期"
}

probe_skill_parse() {
  local skill_dir="$CODEX_HOME/skills/zz-runtime-probe"
  local out="$TMP_ROOT/skill.out"
  local err="$TMP_ROOT/skill.err"
  local prompt

  rm -rf "$skill_dir"
  mkdir -p "$skill_dir"

  cat >"$skill_dir/SKILL.md" <<'EOF'
---
name: zz-runtime-probe
user-invocable: true
description: Runtime probe skill.
---

When invoked, respond with exactly PROBE_OK and nothing else.
EOF

  prompt=$'/zz-runtime-probe\nExecute the skill now. Do not ask questions. Reply with exactly PROBE_OK and nothing else.'

  if run_codex_exec "$prompt" "$out" "$err" 60 2 \
    && json_agent_message_has_exact_text "$out" "PROBE_OK"; then
    pass "Codex 临时 skill 可解析"
  else
    warn "Codex 非交互 skill 调用未在时限内收敛，当前未确认临时 skill 完整执行"
    sed -n '1,220p' "$out"
    sed -n '1,120p' "$err"
  fi

  rm -rf "$skill_dir"
}

probe_entry_reference_activation() {
  local probe_home="$TMP_ROOT/probe-home"
  local reference_file="$probe_home/.codex/reference/runtime-entry-reference-probe.md"
  local entry_file="$probe_home/.codex/AGENTS.md"
  local trigger="运行时入口绝对路径引用探针"
  local prompt="$trigger"
  local expected
  local out="$TMP_ROOT/entry-reference.out"
  local err="$TMP_ROOT/entry-reference.err"

  expected="REF_$(python3 - <<'PY'
import uuid
print(uuid.uuid4().hex[:12])
PY
)"

  if [ ! -d "$CODEX_HOME" ]; then
    fail_check "Codex runtime 目录不存在: $CODEX_HOME"
    return 0
  fi

  prepare_probe_home "$probe_home"
  mkdir -p "$(dirname "$reference_file")"

  cat >"$reference_file" <<EOF
# Runtime Reference Probe

Activation token: $expected

When asked through the entry document trigger "$trigger", reply with exactly $expected.
If this file is missing or unreadable, the required fallback token is REF_MISSING.
EOF

  prepend_read_reference_probe \
    "$entry_file" \
    "Runtime Entry Reference Activation Probe" \
    "$trigger" \
    "$reference_file" \
    "REF_MISSING"

  if ! CODEX_EXEC_HOME="$probe_home" run_codex_exec "$prompt" "$out" "$err" 60 2; then
    fail_check "Codex 入口 reference 生效探针失败"
    sed -n '1,220p' "$out"
    sed -n '1,160p' "$err"
    return 0
  fi

  if json_agent_message_has_exact_text "$out" "$expected"; then
    pass "Codex 入口 external reference 已生效"
  elif json_agent_message_has_exact_text "$out" "REF_MISSING"; then
    fail_check "Codex 入口 external reference 未生效（触发了 REF_MISSING）"
    sed -n '1,260p' "$out"
  else
    fail_check "Codex 入口 external reference 未返回预期 token"
    sed -n '1,260p' "$out"
  fi
}

probe_rule_reference_activation() {
  local probe_home="$TMP_ROOT/probe-home"
  local reference_file="$probe_home/.codex/reference/runtime-rule-reference-probe.md"
  local rule_file="$probe_home/.codex/rules/铁律.md"
  local entry_file="$probe_home/.codex/AGENTS.md"
  local trigger="运行时规则绝对路径引用探针"
  local prompt="$trigger"
  local expected
  local out="$TMP_ROOT/rule-reference.out"
  local err="$TMP_ROOT/rule-reference.err"

  expected="RULE_$(python3 - <<'PY'
import uuid
print(uuid.uuid4().hex[:12])
PY
)"

  if [ ! -d "$CODEX_HOME" ]; then
    fail_check "Codex runtime 目录不存在: $CODEX_HOME"
    return 0
  fi

  prepare_probe_home "$probe_home"
  mkdir -p "$(dirname "$reference_file")"

  cat >"$reference_file" <<EOF
# Runtime Rule Reference Probe

Activation token: $expected

When asked through the rule document trigger "$trigger", reply with exactly $expected.
If this file is missing or unreadable, the required fallback token is RULE_REF_MISSING.
EOF

  prepend_read_reference_probe \
    "$rule_file" \
    "Runtime Rule Reference Activation Probe" \
    "$trigger" \
    "$reference_file" \
    "RULE_REF_MISSING"

  prepend_follow_file_probe \
    "$entry_file" \
    "Runtime Rule Contract Activation Probe" \
    "$trigger" \
    "$rule_file" \
    "RULE_DOC_MISSING"

  if ! CODEX_EXEC_HOME="$probe_home" run_codex_exec "$prompt" "$out" "$err" 60 2; then
    fail_check "Codex rules 级 runtime contract 生效探针失败"
    sed -n '1,220p' "$out"
    sed -n '1,160p' "$err"
    return 0
  fi

  if json_agent_message_has_exact_text "$out" "$expected"; then
    pass "Codex rules 级 runtime contract 已生效"
  elif json_agent_message_has_exact_text "$out" "RULE_DOC_MISSING"; then
    fail_check "Codex rules 级 runtime contract 未生效（入口未读到规则文件）"
    sed -n '1,260p' "$out"
  elif json_agent_message_has_exact_text "$out" "RULE_REF_MISSING"; then
    fail_check "Codex rules 级 runtime contract 未生效（规则文件未读到外部引用）"
    sed -n '1,260p' "$out"
  else
    fail_check "Codex rules 级 runtime contract 未返回预期 token"
    sed -n '1,260p' "$out"
  fi
}

probe_global_hooks() {
  local out="$TMP_ROOT/global-hooks.out"
  local err="$TMP_ROOT/global-hooks.err"

  if ! (cd "$ROOT_DIR" && timeout 75 bash "$(dirname "$0")/probe-codex-hooks.sh" >"$out" 2>"$err"); then
    fail_check "Codex 全局 hooks 探针脚本执行失败"
    sed -n '1,220p' "$out"
    sed -n '1,120p' "$err"
    return 0
  fi

  if grep -Fq '=== SessionStart ===' "$out" \
    && grep -Fq '=== PreToolUse ===' "$out" \
    && grep -Fq '=== PostToolUse ===' "$out" \
    && grep -Fq '=== Stop ===' "$out"; then
    pass "Codex hooks.json 捕获到 SessionStart/PreToolUse/PostToolUse/Stop"
  elif grep -Fq 'no hook events captured' "$out"; then
    fail_check "Codex hooks.json 默认未捕获任何事件"
  else
    fail_check "Codex hooks.json 仅捕获到部分事件"
  fi
}

probe_agent_delegate() {
  local out="$TMP_ROOT/agent.out"
  local err="$TMP_ROOT/agent.err"

  if ! run_codex_exec 'Use the developer agent exactly once. Ask it to reply with exactly DEV_OK and nothing else. Then you reply with exactly MAIN_OK.' "$out" "$err" 60 2; then
    fail_check "Codex agent 委派探针失败"
    sed -n '1,220p' "$out"
    sed -n '1,160p' "$err"
    return 0
  fi

  if grep -Fq 'DEV_OK' "$out" && grep -Fq 'MAIN_OK' "$out"; then
    pass "Codex agent 委派可用"
  else
    fail_check "Codex agent 委派未返回预期结果"
    sed -n '1,260p' "$out"
  fi
}

printf 'codex_bin=%s\n' "$(command -v codex 2>/dev/null || echo unknown)"
printf 'codex_bin_real=%s\n' "$(python3 - <<'PY'
import os, shutil
path = shutil.which("codex")
print(os.path.realpath(path) if path else "unknown")
PY
)"
printf 'root_dir=%s\n' "$ROOT_DIR"
printf 'codex_home=%s\n' "$CODEX_HOME"
printf 'codex_agents_md=%s\n' "$CODEX_HOME/AGENTS.md"
printf 'codex_input_mode=stdin\n'

run_probe "Minimal Exec" probe_minimal_exec
run_probe "Default Surface" probe_default_surface
run_probe "Skill Parse" probe_skill_parse
run_probe "Entry Absolute Runtime Link Activation" probe_entry_reference_activation
run_probe "Rule Absolute Runtime Link Activation" probe_rule_reference_activation
run_probe "Global Hooks" probe_global_hooks
run_probe "Agent Delegate" probe_agent_delegate

if [ "${FAIL_COUNT:-0}" -ne 0 ]; then
  printf '\n[SUMMARY] codex capability probe recorded %s failure(s)\n' "$FAIL_COUNT" >&2
  exit 1
fi
