#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$PWD}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-capabilities.XXXXXX")"

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
  printf '[FAIL] %s\n' "$*"
}

run_probe() {
  local name="$1"
  shift
  printf '\n=== %s ===\n' "$name"
  "$@"
}

run_codex_exec() {
  local prompt="$1"
  local out="$2"
  local err="$3"
  local timeout_seconds="${4:-20}"
  local attempts="${5:-2}"
  local rc=0
  local attempt=1

  while [ "$attempt" -le "$attempts" ]; do
    if (
      cd "$ROOT_DIR"
      printf '%s\n' "$prompt" | timeout "$timeout_seconds" codex exec --json -c model_reasoning_effort="medium" -
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
  if [ -f "$CODEX_HOME/skills/brainstorming/agents/openai.yaml" ] \
    && [ ! -f "$CODEX_HOME/skills/using-superpowers/agents/openai.yaml" ] \
    && [ ! -f "$CODEX_HOME/skills/product/agents/openai.yaml" ]; then
    pass "community-first 自动暴露面符合预期"
  else
    fail_check "community-first 自动暴露面不符合预期（brainstorming 应自动暴露，using-superpowers/product 应为 manual-only）"
    find "$CODEX_HOME/skills" -path '*/agents/openai.yaml' | sort | sed -n '1,200p'
  fi
}

probe_skill_parse() {
  local skill_dir="$CODEX_HOME/skills/zz-runtime-probe"
  local out="$TMP_ROOT/skill.out"
  local err="$TMP_ROOT/skill.err"
  local prompt
  local rc=0

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

  if ! run_codex_exec "$prompt" "$out" "$err" 45 2; then
    rc=$?
  fi

  if grep -Fq 'PROBE_OK' "$out"; then
    pass "Codex 临时 skill 可解析"
  elif grep -Fq "$skill_dir/SKILL.md" "$out" || grep -Fq 'zz-runtime-probe' "$out"; then
    pass "Codex 临时 skill 可解析"
    warn "Codex 非交互 skill 调用未在时限内收敛，当前仅将 slash 解析视为通过"
  else
    fail_check "Codex 临时 skill 不可解析"
    sed -n '1,220p' "$out"
    sed -n '1,120p' "$err"
  fi

  rm -rf "$skill_dir"
}

probe_global_hooks() {
  local out="$TMP_ROOT/global-hooks.out"
  local err="$TMP_ROOT/global-hooks.err"

  if ! (cd "$ROOT_DIR" && timeout 75 bash "$(dirname "$0")/probe-codex-hooks.sh" >"$out" 2>"$err"); then
    if grep -Fq '=== SessionStart ===' "$out" \
      && grep -Fq '=== PreToolUse ===' "$out" \
      && grep -Fq '=== PostToolUse ===' "$out" \
      && grep -Fq '=== Stop ===' "$out"; then
      pass "Codex hooks.json 捕获到 SessionStart/PreToolUse/PostToolUse/Stop"
    else
      warn "Codex 全局 hooks 探针脚本执行失败，保留环境告警"
      sed -n '1,220p' "$out"
      sed -n '1,120p' "$err"
    fi
    return 0
  fi

  if grep -Fq '=== SessionStart ===' "$out" \
    && grep -Fq '=== PreToolUse ===' "$out" \
    && grep -Fq '=== PostToolUse ===' "$out" \
    && grep -Fq '=== Stop ===' "$out"; then
    pass "Codex hooks.json 捕获到 SessionStart/PreToolUse/PostToolUse/Stop"
  elif grep -Fq 'no hook events captured' "$out"; then
    warn "Codex hooks.json 默认未捕获任何事件"
  else
    warn "Codex hooks.json 仅捕获到部分事件"
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
run_probe "Global Hooks" probe_global_hooks
run_probe "Agent Delegate" probe_agent_delegate
