#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$PWD}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CLAUDE_LAUNCHER="${CLAUDE_LAUNCHER:-cc codex}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/claude-capabilities.XXXXXX")"
read -r -a CLAUDE_CMD <<<"$CLAUDE_LAUNCHER"

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

make_token() {
  python3 - <<'PY'
import uuid
print(uuid.uuid4().hex[:12])
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
1. Use the Bash tool to run \`cat $read_path\`.
2. Follow the exact instructions in that file. If following the instructions in that file requires reading another file, continue with the required tool call(s).
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
1. Read \`$reference_path\` with the available file-reading tool.
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
    local src="$HOME/$rel_path"
    local dst="$probe_home/$rel_path"

    if [ -d "$src" ]; then
      mkdir -p "$(dirname "$dst")"
      cp -R "$src" "$dst"
    elif [ -f "$src" ]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
  }

  rm -rf "$probe_home"
  mkdir -p "$probe_home"

  for rel in \
    ".claude/CLAUDE.md" \
    ".claude/settings.json" \
    ".claude/rules" \
    ".claude/reference" \
    ".claude/litellm" \
    ".claude-code-router" \
    ".config/ai-gateway/teamplus.env.sh" \
    ".claude.json" \
    ".codex/auth.json" \
    ".codex/config.toml" \
    ".codex/AGENTS.md" \
    ".codex/agents" \
    ".codex/rules" \
    ".codex/reference"
  do
    copy_runtime_context "$rel"
  done
}

probe_auth() {
  local -a auth_cmd
  if [ -n "${CLAUDE_AUTH_LAUNCHER:-}" ]; then
    read -r -a auth_cmd <<<"$CLAUDE_AUTH_LAUNCHER"
  elif command -v claude >/dev/null 2>&1; then
    auth_cmd=(claude)
  else
    auth_cmd=("${CLAUDE_CMD[@]}")
  fi

  set +e
  "${auth_cmd[@]}" auth status >"$TMP_ROOT/auth.out" 2>"$TMP_ROOT/auth.err"
  local rc=$?
  set -e

  if [ "$rc" -ne 0 ]; then
    fail_check "Claude auth status 失败"
    sed -n '1,120p' "$TMP_ROOT/auth.err"
    return 0
  fi

  if grep -Fq '"loggedIn": true' "$TMP_ROOT/auth.out"; then
    pass "Claude 登录状态正常"
  else
    warn "Claude 未处于登录状态"
    sed -n '1,120p' "$TMP_ROOT/auth.out"
  fi
}

probe_proxy() {
  local base_url
  base_url="$(python3 - "$CLAUDE_DIR/settings.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

print((data.get("env") or {}).get("ANTHROPIC_BASE_URL", ""))
PY
)"

  if [ -z "$base_url" ]; then
    pass "Claude 未配置本地代理"
    return 0
  fi

  printf 'proxy_base_url=%s\n' "$base_url"

  if curl -fsS --max-time 5 "${base_url%/}/" >/dev/null 2>&1; then
    pass "Claude 代理端点可达"
  else
    warn "Claude 代理端点不可达"
  fi

  if [[ "$base_url" =~ ^http://(127\.0\.0\.1|localhost):([0-9]+) ]]; then
    local port="${BASH_REMATCH[2]}"
    local pid
    local cmd
    pid="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | head -n1 || true)"
    if [ -n "$pid" ]; then
      cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      if printf '%s' "$cmd" | grep -Eqi 'mock_|/probe/'; then
        fail_check "Claude 当前指向本地 mock/probe 服务，不能作为真实验收环境"
        printf 'listener_pid=%s\n' "$pid"
        printf 'listener_cmd=%s\n' "$cmd"
      fi
    fi
  fi
}

probe_minimal_bare() {
  local expected
  local out="$TMP_ROOT/bare.out"
  local err="$TMP_ROOT/bare.err"
  expected="HELLO_$(make_token)"

  if ! timeout 35 "${CLAUDE_CMD[@]}" --bare --no-session-persistence -p --output-format json "Reply with exactly ${expected}." >"$out" 2>"$err"; then
    fail_check "Claude bare 最小调用失败"
    sed -n '1,160p' "$err"
    return 0
  fi

  if grep -Fq "\"result\":\"${expected}\"" "$out"; then
    pass "Claude bare 最小调用通过"
  else
    fail_check "Claude bare 未返回预期 token"
    sed -n '1,160p' "$out"
  fi
}

probe_regular_output() {
  local expected
  local out="$TMP_ROOT/regular.out"
  local err="$TMP_ROOT/regular.err"
  expected="STREAM_$(make_token)"

  if ! timeout 35 "${CLAUDE_CMD[@]}" --no-session-persistence --verbose -p --output-format stream-json "Reply with exactly ${expected}." >"$out" 2>"$err"; then
    fail_check "Claude 常规模式最小调用失败"
    sed -n '1,160p' "$err"
    return 0
  fi

  if grep -Fq '"type":"assistant"' "$out" && grep -Fq "\"text\":\"${expected}\"" "$out"; then
    pass "Claude 常规模式输出链路可见 assistant 文本"
  else
    fail_check "Claude 常规模式未观察到预期 token"
    sed -n '1,240p' "$out"
  fi

  if grep -Fq '"result":""' "$out"; then
    warn "Claude 常规模式 result 字段为空，建议使用 stream-json 验证真实输出"
  fi
}

probe_global_hooks() {
  local expected
  local marker="$TMP_ROOT/global-hook.log"
  local hook_script="$TMP_ROOT/hook.sh"
  local settings_file="$TMP_ROOT/settings.json"
  local probe_file="$TMP_ROOT/global-tool.txt"
  expected="HOOK_$(make_token)"

  cat >"$hook_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
label="\$1"
input="\$(cat || true)"
{
  printf '=== %s\\n' "\$label"
  printf '%s\\n' "\$input"
} >> "$marker"
EOF
  chmod +x "$hook_script"

  local ccr_settings="${CCR_CLAUDE_SETTINGS:-$HOME/.claude-code-router/claude-settings-ccr.json}"
  if [[ "$CLAUDE_LAUNCHER" == cc\ codex* && -f "$ccr_settings" ]]; then
    python3 - "$ccr_settings" "$hook_script" >"$settings_file" <<'PY'
import json
import sys

settings_path, hook_script = sys.argv[1], sys.argv[2]
try:
    with open(settings_path, encoding="utf-8") as f:
        settings = json.load(f)
except Exception:
    settings = {}

settings["hooks"] = {
    "PreToolUse": [{
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": f"bash {hook_script} PreToolUse"}],
    }],
    "PostToolUse": [{
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": f"bash {hook_script} PostToolUse"}],
    }],
    "Stop": [{
        "hooks": [{"type": "command", "command": f"bash {hook_script} Stop"}],
    }],
}

json.dump(settings, sys.stdout, ensure_ascii=False)
PY
  else
    cat >"$settings_file" <<EOF
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{"type": "command", "command": "bash $hook_script PreToolUse"}]
    }],
    "PostToolUse": [{
      "matcher": "Bash",
      "hooks": [{"type": "command", "command": "bash $hook_script PostToolUse"}]
    }],
    "Stop": [{
      "hooks": [{"type": "command", "command": "bash $hook_script Stop"}]
    }]
  }
}
EOF
  fi

  if ! env CCR_CLAUDE_SETTINGS="$settings_file" timeout 50 "${CLAUDE_CMD[@]}" --no-session-persistence --verbose -p --output-format stream-json --settings "$settings_file" "Use the Bash tool exactly once to run \`printf ${expected} > ${probe_file}\`, then reply with exactly ${expected}." >"$TMP_ROOT/global.out" 2>"$TMP_ROOT/global.err"; then
    fail_check "Claude 全局 hooks 探针失败"
    sed -n '1,160p' "$TMP_ROOT/global.err"
    return 0
  fi

  if [ -f "$marker" ] && grep -Fq '=== PreToolUse' "$marker" && grep -Fq '=== PostToolUse' "$marker" && grep -Fq '=== Stop' "$marker" && [ -f "$probe_file" ] && grep -Fqx "$expected" "$probe_file" && grep -Fq "\"text\":\"${expected}\"" "$TMP_ROOT/global.out"; then
    pass "Claude 全局 hooks 已触发"
  else
    fail_check "Claude 全局 hooks 未完整触发"
    sed -n '1,240p' "$marker" 2>/dev/null || true
    sed -n '1,240p' "$TMP_ROOT/global.out"
  fi
}

probe_skill_local_hook() {
  local skill_name
  local expected
  local skill_dir
  local marker="$TMP_ROOT/skill-stop.log"
  skill_name="zz-runtime-probe-$(make_token)"
  expected="PROBE_$(make_token)"
  skill_dir="$CLAUDE_DIR/skills/$skill_name"

  rm -rf "$skill_dir"
  mkdir -p "$skill_dir/scripts"

  cat >"$skill_dir/SKILL.md" <<EOF
---
name: $skill_name
user-invocable: true
description: Runtime probe skill.
allowed-tools: Read, Bash
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash \$HOME/.claude/skills/$skill_name/scripts/stop.sh
          timeout: 10
---

When invoked, respond with exactly $expected and nothing else.
EOF

  cat >"$skill_dir/scripts/stop.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'STOP_HOOK_TRIGGERED\n' >> "$marker"
EOF
  chmod +x "$skill_dir/scripts/stop.sh"

  if ! timeout 50 "${CLAUDE_CMD[@]}" --no-session-persistence --verbose -p --output-format stream-json "/$skill_name" >"$TMP_ROOT/skill.out" 2>"$TMP_ROOT/skill.err"; then
    fail_check "Claude skill-local hook 探针失败"
    sed -n '1,160p' "$TMP_ROOT/skill.err"
    rm -rf "$skill_dir"
    return 0
  fi

  if grep -Fq "$expected" "$TMP_ROOT/skill.out"; then
    pass "Claude 临时 skill 可解析"
  else
    fail_check "Claude 临时 skill 不可解析"
    sed -n '1,240p' "$TMP_ROOT/skill.out"
  fi

  if [ -f "$marker" ]; then
    pass "Claude skill-local Stop hook 已触发"
  else
    fail_check "Claude skill-local Stop hook 未触发"
  fi

  rm -rf "$skill_dir"
}

probe_entry_reference_activation() {
  local probe_home="$TMP_ROOT/probe-home-entry"
  local reference_file="$probe_home/.claude/reference/runtime-entry-reference-probe.md"
  local entry_file="$probe_home/.claude/CLAUDE.md"
  local trigger="运行时入口绝对路径引用探针"
  local prompt="$trigger"
  local expected
  local out="$TMP_ROOT/entry-reference.out"
  local err="$TMP_ROOT/entry-reference.err"

  expected="REF_$(make_token)"

  if [ ! -d "$CLAUDE_DIR" ]; then
    fail_check "Claude runtime 目录不存在: $CLAUDE_DIR"
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

  if ! (
    cd "$ROOT_DIR"
    env HOME="$probe_home" timeout 50 "${CLAUDE_CMD[@]}" --no-session-persistence --verbose -p --output-format stream-json "$prompt"
  ) >"$out" 2>"$err"; then
    fail_check "Claude 入口 reference 生效探针失败"
    sed -n '1,160p' "$err"
    return 0
  fi

  if grep -Fq "\"text\":\"${expected}\"" "$out"; then
    pass "Claude 入口 external reference 已生效"
  elif grep -Fq '"text":"REF_MISSING"' "$out"; then
    fail_check "Claude 入口 external reference 未生效（触发了 REF_MISSING）"
    sed -n '1,220p' "$out"
  else
    fail_check "Claude 入口 external reference 未返回预期 token"
    sed -n '1,220p' "$out"
  fi
}

probe_rule_reference_activation() {
  local probe_home="$TMP_ROOT/probe-home-rule"
  local reference_file="$probe_home/.claude/reference/runtime-rule-reference-probe.md"
  local rule_file="$probe_home/.claude/rules/铁律.md"
  local entry_file="$probe_home/.claude/CLAUDE.md"
  local trigger="运行时规则绝对路径引用探针"
  local prompt="$trigger"
  local expected
  local out="$TMP_ROOT/rule-reference.out"
  local err="$TMP_ROOT/rule-reference.err"

  expected="RULE_$(make_token)"

  if [ ! -d "$CLAUDE_DIR" ]; then
    fail_check "Claude runtime 目录不存在: $CLAUDE_DIR"
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

  if ! (
    cd "$ROOT_DIR"
    env HOME="$probe_home" timeout 90 "${CLAUDE_CMD[@]}" --no-session-persistence --verbose -p --output-format stream-json "$prompt"
  ) >"$out" 2>"$err"; then
    fail_check "Claude rules 级 runtime contract 生效探针失败"
    sed -n '1,160p' "$err"
    return 0
  fi

  if grep -Fq "\"text\":\"${expected}\"" "$out"; then
    pass "Claude rules 级 runtime contract 已生效"
  elif grep -Fq '"text":"RULE_DOC_MISSING"' "$out"; then
    fail_check "Claude rules 级 runtime contract 未生效（入口未读到规则文件）"
    sed -n '1,220p' "$out"
  elif grep -Fq '"text":"RULE_REF_MISSING"' "$out"; then
    fail_check "Claude rules 级 runtime contract 未生效（规则文件未读到外部引用）"
    sed -n '1,220p' "$out"
  else
    fail_check "Claude rules 级 runtime contract 未返回预期 token"
    sed -n '1,220p' "$out"
  fi
}

probe_agent_delegate() {
  local dev_token
  local main_token
  local out="$TMP_ROOT/agent.out"
  local err="$TMP_ROOT/agent.err"
  local rc=0
  dev_token="DEV_$(make_token)"
  main_token="MAIN_$(make_token)"

  set +e
  (cd "$ROOT_DIR" && timeout 120 "${CLAUDE_CMD[@]}" --no-session-persistence --verbose -p --output-format stream-json "Use the developer agent exactly once. Ask it to reply with exactly ${dev_token} and nothing else. Then you reply with exactly ${main_token}." >"$out" 2>"$err")
  rc=$?
  set -e

  if grep -Fq 'Invalid model name passed in model=claude-' "$out" || grep -Fq 'Invalid model name passed in model=claude-' "$err"; then
    warn "Claude agent 委派被当前代理模型兼容性阻断"
    sed -n '1,320p' "$out"
    sed -n '1,160p' "$err"
    return 0
  fi

  if [ "$rc" -ne 0 ]; then
    fail_check "Claude agent 委派探针失败"
    printf 'exit_code=%s\n' "$rc"
    sed -n '1,320p' "$out"
    sed -n '1,160p' "$err"
    return 0
  fi

  if grep -Fq "$dev_token" "$out" && grep -Fq "$main_token" "$out"; then
    pass "Claude agent 委派可用"
  else
    warn "Claude agent 委派未返回预期结果"
    sed -n '1,320p' "$out"
  fi
}

printf 'claude_launcher=%s\n' "$CLAUDE_LAUNCHER"
printf 'claude_version=%s\n' "$("${CLAUDE_CMD[@]}" --version 2>/dev/null || echo unknown)"
printf 'root_dir=%s\n' "$ROOT_DIR"
printf 'claude_dir=%s\n' "$CLAUDE_DIR"

run_probe "Auth" probe_auth
run_probe "Proxy" probe_proxy
run_probe "Minimal Bare" probe_minimal_bare
run_probe "Regular Output" probe_regular_output
run_probe "Global Hooks" probe_global_hooks
run_probe "Skill Local Hook" probe_skill_local_hook
run_probe "Entry Absolute Runtime Link Activation" probe_entry_reference_activation
run_probe "Rule Absolute Runtime Link Activation" probe_rule_reference_activation
run_probe "Agent Delegate" probe_agent_delegate
