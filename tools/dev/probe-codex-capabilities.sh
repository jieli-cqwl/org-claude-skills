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

probe_minimal_exec() {
  local out="$TMP_ROOT/minimal.out"
  local err="$TMP_ROOT/minimal.err"

  if ! (cd "$ROOT_DIR" && timeout 40 codex exec --json 'Reply with exactly OK.' >"$out" 2>"$err"); then
    fail_check "codex exec 最小调用失败"
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

probe_skills() {
  local out="$TMP_ROOT/skills.out"
  local err="$TMP_ROOT/skills.err"

  if ! (cd "$ROOT_DIR" && timeout 60 codex exec --json 'List all currently available skills by exact name only, one per line, no extra text.' >"$out" 2>"$err"); then
    fail_check "skills 列表探针失败"
    sed -n '1,120p' "$err"
    return 0
  fi

  if grep -Eq 'project-manager|tech-lead|product' "$out"; then
    pass "skills 运行时可见"
  else
    fail_check "skills 运行时不可见"
    sed -n '1,200p' "$out"
  fi
}

probe_skill_local_hook() {
  local skill_dir="$CODEX_HOME/skills/zz-runtime-probe"
  local marker="$TMP_ROOT/skill-stop.log"

  rm -rf "$skill_dir"
  mkdir -p "$skill_dir/scripts"

  cat >"$skill_dir/SKILL.md" <<'EOF'
---
name: zz-runtime-probe
user-invocable: true
description: Runtime probe skill.
allowed-tools: Read, Write, Bash
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash $HOME/.codex/skills/zz-runtime-probe/scripts/stop.sh
          timeout: 10
---

When invoked, respond with exactly PROBE_OK and nothing else.
EOF

  cat >"$skill_dir/scripts/stop.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'STOP_HOOK_TRIGGERED\n' >> "$marker"
EOF
  chmod +x "$skill_dir/scripts/stop.sh"

  if ! (cd "$ROOT_DIR" && timeout 60 codex exec --json '/zz-runtime-probe' >"$TMP_ROOT/skill.out" 2>"$TMP_ROOT/skill.err"); then
    fail_check "Codex 临时 skill 调用失败"
    sed -n '1,120p' "$TMP_ROOT/skill.err"
    rm -rf "$skill_dir"
    return 0
  fi

  if grep -Fq 'PROBE_OK' "$TMP_ROOT/skill.out"; then
    pass "Codex 临时 skill 可解析"
  else
    fail_check "Codex 临时 skill 不可解析"
    sed -n '1,200p' "$TMP_ROOT/skill.out"
  fi

  if [ -f "$marker" ]; then
    pass "Codex skill-local Stop hook 已触发"
  else
    warn "Codex skill-local Stop hook 未触发"
  fi

  rm -rf "$skill_dir"
}

probe_global_hooks() {
  local out="$TMP_ROOT/global-hooks.out"
  local err="$TMP_ROOT/global-hooks.err"

  if ! (cd "$ROOT_DIR" && bash "$(dirname "$0")/probe-codex-hooks.sh" >"$out" 2>"$err"); then
    fail_check "Codex 全局 hooks 探针脚本执行失败"
    sed -n '1,120p' "$err"
    return 0
  fi

  if grep -Fq 'no hook events captured' "$out"; then
    warn "Codex hooks.json 默认未捕获任何事件"
  else
    pass "Codex hooks.json 捕获到事件"
  fi
}

probe_agent_delegate() {
  local out="$TMP_ROOT/agent.out"
  local err="$TMP_ROOT/agent.err"

  if ! (cd "$ROOT_DIR" && timeout 45 codex exec --json 'Use the developer agent exactly once. Ask it to reply with exactly DEV_OK and nothing else. Then you reply with exactly MAIN_OK.' >"$out" 2>"$err"); then
    fail_check "Codex agent 委派探针失败"
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

printf 'codex_version=%s\n' "$(codex --version 2>/dev/null || echo unknown)"
printf 'root_dir=%s\n' "$ROOT_DIR"
printf 'codex_home=%s\n' "$CODEX_HOME"

run_probe "Minimal Exec" probe_minimal_exec
run_probe "Skills" probe_skills
run_probe "Skill Local Hook" probe_skill_local_hook
run_probe "Global Hooks" probe_global_hooks
run_probe "Agent Delegate" probe_agent_delegate
