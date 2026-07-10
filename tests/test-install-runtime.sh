#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

install_test_init
INSTALL_TEST_REPO_FINGERPRINT_PROBE="$ROOT/shared/skills/skill-quality-audit/evals/.runtime-fingerprint-probe"
INSTALL_TEST_REPO_WORKSPACE_PROBE="$ROOT/shared/skills/runtime-fingerprint-workspace"
install_test_cleanup_with_repo_probe() {
  rm -rf "$INSTALL_TEST_REPO_FINGERPRINT_PROBE"
  rm -rf "$INSTALL_TEST_REPO_WORKSPACE_PROBE"
  install_test_cleanup
}
trap install_test_cleanup_with_repo_probe EXIT

install_test_case_start "runtime: claude hooks merge and uninstall restores baseline"
home_dir="$(install_test_new_home runtime-claude-hooks)"
rm -f "$home_dir/.claude/settings.json"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-claude-hooks-install)" --target claude --force --check quick
install_test_assert_file_exists "$home_dir/.claude/settings.json" "claude install should create settings.json when it is missing"
install_test_assert_file_contains "$home_dir/.claude/settings.json" "bash \$HOME/.claude/hooks/block_dangerous.sh" "hook block_dangerous should be merged"
install_test_assert_file_contains "$home_dir/.claude/settings.json" "bash \$HOME/.claude/hooks/code_quality_check.sh" "hook code_quality_check should be merged"
install_test_assert_file_contains "$home_dir/.claude/settings.json" "bash \$HOME/.claude/hooks/auto_format.sh" "hook auto_format should be merged"
install_test_assert_file_contains "$home_dir/.claude/settings.json" "bash \$HOME/.claude/hooks/post_compact.sh" "hook post_compact should be merged"
install_test_assert_file_contains "$home_dir/.claude/settings.json" "bash \$HOME/.claude/hooks/task_verify.sh" "hook task_verify should be merged"
install_test_assert_file_contains "$home_dir/.claude/settings.json" "python3 \$HOME/.claude/hooks/managed/context_contract_validator.py" "hook context_contract_validator should be merged"
python3 - "$home_dir/.claude/settings.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
pre = data["hooks"]["PreToolUse"]
for item in pre:
    if json.dumps(item, sort_keys=True, ensure_ascii=False).find("code_quality_check.sh") != -1:
        pre.append(item)
        break
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-claude-hooks-dedupe)" --target claude --force --check quick
python3 - "$home_dir/.claude/settings.json" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for event, entries in (data.get("hooks") or {}).items():
    counts = Counter(json.dumps(item, sort_keys=True, ensure_ascii=False) for item in entries)
    if any(count > 1 for count in counts.values()):
        raise SystemExit(f"duplicate hook entries remain in {event}")
PY
[ -x "$home_dir/.claude/hooks/block_dangerous.sh" ] || install_test_fail "claude dangerous hook wrapper should be executable"
[ -x "$home_dir/.claude/hooks/managed/block_dangerous.sh" ] || install_test_fail "claude managed dangerous hook should be executable"
printf '{}' | bash "$home_dir/.claude/hooks/block_dangerous.sh" >/dev/null 2>&1 || install_test_fail "claude dangerous hook wrapper should run without permission errors"
mkdir -p "$home_dir/project"
compact_summary='Sensitive compact summary should be stored locally and must not be injected into additionalContext'
post_compact_input="$(jq -nc \
  --arg sid "session-postcompact-runtime" \
  --arg cwd "$home_dir/project" \
  --arg transcript "$home_dir/transcript.jsonl" \
  --arg summary "$compact_summary" \
  '{
    session_id: $sid,
    transcript_path: $transcript,
    cwd: $cwd,
    hook_event_name: "PostCompact",
    trigger: "auto",
    compact_summary: $summary
  }')"
post_compact_payload="$(printf '%s' "$post_compact_input" | HOME="$home_dir" bash "$home_dir/.claude/hooks/post_compact.sh")" || install_test_fail "claude post_compact hook should emit JSON payload"
post_compact_state="$home_dir/.claude/hooks/state/post-compact/latest-session-postcompact-runtime.json"
post_compact_events="$home_dir/.claude/hooks/state/post-compact/events.jsonl"
printf '%s' "$post_compact_payload" | jq -e '.hookSpecificOutput.hookEventName == "PostCompact"' >/dev/null 2>&1 || install_test_fail "claude post_compact hook should keep PostCompact event name"
install_test_assert_file_exists "$post_compact_state" "claude post_compact hook should persist latest compact summary"
install_test_assert_file_exists "$post_compact_events" "claude post_compact hook should append compact summary audit events"
jq -e --arg summary "$compact_summary" '
  .session_id == "session-postcompact-runtime"
  and .trigger == "auto"
  and .compact_summary == $summary
  and (.summary_length == ($summary | length))
' "$post_compact_state" >/dev/null 2>&1 || install_test_fail "claude post_compact latest state should preserve compact payload fields"
tail -n 1 "$post_compact_events" | jq -e --arg summary "$compact_summary" '.compact_summary == $summary' >/dev/null 2>&1 || install_test_fail "claude post_compact events log should preserve compact summary"
printf '%s' "$post_compact_payload" | grep -Fq "$compact_summary" && install_test_fail "claude post_compact hook must not inject compact summary into additionalContext"
printf '%s' "$post_compact_payload" | jq -e '.hookSpecificOutput.additionalContext | contains("compact_summary_ref")' >/dev/null 2>&1 || install_test_fail "claude post_compact hook should expose compact summary state reference"
printf '%s' "$post_compact_payload" | grep -Fq 'mode / stage / status / scope_ref / state_ref / next_ref / blocker / decision_needed' || install_test_fail "claude post_compact hook should restore state anchors"
printf '%s' "$post_compact_payload" | grep -Fq '如果 goal / owner / lane / phase 已变化，先回源纠偏，不继续执行' || install_test_fail "claude post_compact hook should require freshness check before continuing"
printf '%s' "$post_compact_payload" | grep -Fq 'blocked / waiting_on / unblock_condition / decision_needed' || install_test_fail "claude post_compact hook should describe blocked fallback"
printf '%s' "$post_compact_payload" | grep -Fq 'readiness / uncertainty 场景额外允许保留最多 3 条理由胶囊' || install_test_fail "claude post_compact hook should describe rationale capsule branch for readiness cases"
install_test_run_install "$home_dir" "$(install_test_log_path runtime-claude-hooks-uninstall)" --uninstall --target claude
install_test_assert_path_absent "$home_dir/.claude/settings.json" "claude uninstall should remove settings.json created only for managed hooks"
install_test_case_pass "runtime: claude hooks merge and uninstall restores baseline"

install_test_case_start "runtime: create baseline for repair cases"
install_test_create_baseline_home runtime-baseline >/dev/null
baseline_home="$INSTALL_TEST_BASELINE_HOME"
install_test_assert_file_exists "$baseline_home/.codex/hooks.json" "baseline should contain codex hooks"
install_test_case_pass "runtime: create baseline for repair cases"

install_test_case_start "runtime: install prunes probe skills and cache noise"
home_dir="$(install_test_new_home runtime-noise-prune)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p "$home_dir/.claude/skills/zz-runtime-probe-leftover" "$home_dir/.codex/skills/zz-runtime-probe-leftover"
printf 'probe residue\n' > "$home_dir/.claude/skills/zz-runtime-probe-leftover/SKILL.md"
printf 'probe residue\n' > "$home_dir/.codex/skills/zz-runtime-probe-leftover/SKILL.md"
for stale_adapter_skill in product-director tech-lead commit; do
  mkdir -p "$home_dir/.codex/skills/$stale_adapter_skill/agents"
  printf 'legacy adapter\n' > "$home_dir/.codex/skills/$stale_adapter_skill/agents/openai.yaml"
done
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-noise-prune-install)" --target all --force --check quick
install_test_assert_path_absent "$home_dir/.claude/skills/zz-runtime-probe-leftover" "claude runtime probe skill residue should be removed"
install_test_assert_path_absent "$home_dir/.codex/skills/zz-runtime-probe-leftover" "codex runtime probe skill residue should be removed"
for stale_adapter_skill in product-director tech-lead commit; do
  install_test_assert_path_absent "$home_dir/.codex/skills/$stale_adapter_skill/agents/openai.yaml" "codex manual-only stale adapter should be removed: $stale_adapter_skill"
done
archive_path="$(find "$state_root/codex/unexpected-artifacts" -path '*/skills/product-director/agents/openai.yaml' -print -quit 2>/dev/null || true)"
[ -n "$archive_path" ] || install_test_fail "codex stale manual-only adapter should be archived"
if find "$home_dir/.claude" "$home_dir/.codex" \( -type d -name '__pycache__' -o -type f -name '*.pyc' -o -type f -name '.DS_Store' \) -print -quit | grep -q .; then
  install_test_fail "runtime should not contain __pycache__, *.pyc, or .DS_Store"
fi
install_test_assert_file_not_contains "$state_root/claude/installed-manifest" "__pycache__" "claude manifest should not include Python cache directories"
install_test_assert_file_not_contains "$state_root/claude/installed-manifest" ".pyc" "claude manifest should not include Python bytecode"
install_test_assert_file_not_contains "$state_root/codex/installed-manifest" "__pycache__" "codex manifest should not include Python cache directories"
install_test_assert_file_not_contains "$state_root/codex/installed-manifest" ".pyc" "codex manifest should not include Python bytecode"
install_test_case_pass "runtime: install prunes probe skills and cache noise"

install_test_case_start "runtime: codex install cleans stale probes and keeps supported user hooks"
home_dir="$(install_test_clone_baseline_home runtime-codex-hooks-cleanup)"
mkdir -p "$home_dir/bin"
python3 - "$home_dir/.codex/config.toml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
for idx, line in enumerate(lines):
    if line.strip() == "[features]":
        insert_at = idx + 1
        break
else:
    raise SystemExit("missing [features]")
lines[insert_at:insert_at] = [
    "codex_hooks = true",
    "collaboration_modes = true",
    "sqlite = true",
    "steer = true",
    "tui_app_server = true",
]
path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
PY
cat > "$home_dir/bin/notify.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$home_dir/bin/notify.sh"
cat > "$home_dir/.codex/hooks.json" <<JSON
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $home_dir/tmp/codex-hooks-probe.stale/probe.sh Stop $home_dir/tmp/events.log"
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "$home_dir/bin/notify.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$home_dir/bin/notify.sh"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$home_dir/bin/notify.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$home_dir/bin/notify.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$home_dir/bin/notify.sh"
          }
        ]
      }
    ]
  }
}
JSON
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-codex-hooks-cleanup-install)" --target codex --force --check quick
install_test_assert_file_not_contains "$home_dir/.codex/hooks.json" "codex-hooks-probe.stale" "stale codex probe hooks should be removed during install"
install_test_assert_file_contains "$home_dir/.codex/config.toml" "hooks = true" "codex install should enable hooks feature"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "codex_hooks = true" "deprecated codex_hooks feature should be cleaned"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "collaboration_modes = true" "removed collaboration_modes feature should be cleaned"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "sqlite = true" "removed sqlite feature should be cleaned"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "steer = true" "removed steer feature should be cleaned"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "tui_app_server = true" "removed tui_app_server feature should be cleaned"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/bin/notify.sh" "valid user hook should be preserved during install"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"SessionStart"' "supported SessionStart user hook should be preserved during codex install"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"PermissionRequest"' "supported PermissionRequest user hook should be preserved during codex install"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"PreCompact"' "supported PreCompact user hook should be preserved during codex install"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"SubagentStop"' "supported SubagentStop user hook should be preserved during codex install"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/block_dangerous.sh" "managed dangerous hook should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/context_contract_validator.py" "managed context validator hook should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_user_prompt_submit.py" "managed active-skill tracker should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_subagent_dispatch_guard.py" "managed subagent dispatch guard should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_stop_dispatch.py" "managed stop dispatcher should be installed"
install_test_assert_file_not_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_context_continuity.py" "context continuity hook should not install by default"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"PostToolUse"' "supported Codex PostToolUse should be present"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"matcher": "Write|Edit"' "Codex PostToolUse should match Write/Edit edits"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"PostCompact"' "supported Codex PostCompact should be present"
install_test_assert_file_not_contains "$home_dir/.codex/hooks.json" '"TaskCompleted"' "Claude-only TaskCompleted should not render into Codex hooks"
python3 - "$home_dir/.codex/hooks.json" "$home_dir" <<'PY'
import json
import shlex
import sys
from pathlib import Path

hooks_path = Path(sys.argv[1])
home = sys.argv[2]
data = json.loads(hooks_path.read_text(encoding="utf-8"))
stop_commands = [
    hook["command"]
    for entry in data["hooks"]["Stop"]
    for hook in entry.get("hooks", [])
]
def managed_script(command):
    parts = shlex.split(command)
    if len(parts) < 2 or Path(parts[0]).name not in {"python", "python3"}:
        return ""
    return parts[1]

expected_prefix = [
    f"{home}/.codex/hooks/managed/context_contract_validator.py",
    f"{home}/.codex/hooks/managed/codex_stop_dispatch.py",
]
if [managed_script(command) for command in stop_commands[:2]] != expected_prefix:
    raise SystemExit(f"managed Stop hooks must keep stable leading order, got: {stop_commands}")
if f"{home}/bin/notify.sh" not in stop_commands:
    raise SystemExit("user Stop hook should still be preserved")
PY
install_test_case_pass "runtime: codex install cleans stale probes and keeps supported user hooks"

install_test_case_start "runtime: codex context continuity is opt-in and metadata-only"
home_dir="$(install_test_new_home runtime-codex-context-continuity)"
(
  export ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-codex-context-continuity-install)" --target codex --force --check quick
)
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_context_continuity.py" "context continuity hook should install only when explicitly enabled"
install_test_assert_file_exists "$home_dir/.org-skills-state/codex/context-continuity-enabled" "context continuity opt-in should persist after enabled install"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-codex-context-continuity-reinstall)" --target codex --force --check quick
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_context_continuity.py" "persisted context continuity opt-in should survive reinstall without env"
install_test_assert_file_contains "$(install_test_log_path runtime-codex-context-continuity-reinstall)" "context continuity ready probe passed" "persisted context continuity opt-in should prove ready recovery"
install_test_assert_file_contains "$(install_test_log_path runtime-codex-context-continuity-reinstall)" "context continuity incomplete probe passed" "persisted context continuity opt-in should prove degraded recovery"
for event in UserPromptSubmit Stop PreCompact PostCompact; do
  jq -e --arg event "$event" --arg script "$home_dir/.codex/hooks/managed/codex_context_continuity.py" '
    any(.hooks[$event][]?;
      any(.hooks[]?; (.command | contains($script + " --event " + $event)))
    )
  ' "$home_dir/.codex/hooks.json" >/dev/null 2>&1 || install_test_fail "context continuity should register $event hook when enabled"
done
jq -e --arg script "$home_dir/.codex/hooks/managed/codex_context_continuity.py" '
  any(.hooks.SessionStart[]?;
    (.matcher == "compact")
    and any(.hooks[]?; (.command | contains($script + " --event SessionStart --source compact")))
  )
' "$home_dir/.codex/hooks.json" >/dev/null 2>&1 || install_test_fail "context continuity should register SessionStart compact hook when enabled"

context_prompt='不对，这里核心不是迁移，而是 LLM 上下文窗口治理'
context_payload="$(jq -nc \
  --arg sid "codex-context-runtime" \
  --arg tid "turn-1" \
  --arg prompt "$context_prompt" \
  --arg cwd "$home_dir/project" \
  --arg transcript "$home_dir/project/context-transcript.jsonl" \
  '{session_id: $sid, turn_id: $tid, hook_event_name: "UserPromptSubmit", user_prompt: $prompt, cwd: $cwd, transcript_path: $transcript}')"
printf '%s' "$context_payload" | HOME="$home_dir" python3 "$home_dir/.codex/hooks/managed/codex_context_continuity.py" >/dev/null \
  || install_test_fail "context continuity should record latest user correction"
context_state_update="$(jq -nc \
  --arg sid "codex-context-runtime" \
  --arg tid "turn-1" \
  --arg prompt "$context_prompt" \
  '{
    session_id: $sid,
    turn_id: $tid,
    base_revision: 0,
    task: {
      task_status: "active",
      active_goal: "prove installed context continuity recovery",
      scope_boundary: "installed Codex runtime hook state only",
      non_goals: [],
      latest_user_correction: $prompt,
      current_phase: "runtime verification",
      current_plan: ["record state", "seal compact", "recover"],
      completed_items: [{item: "prompt metadata recorded", evidence_refs: ["tests/test-install-runtime.sh"]}],
      pending_items: ["session recovery"],
      blockers: [],
      next_action: "continue from structured recovery state"
    }
  }')"
HOME="$home_dir" python3 "$home_dir/.codex/hooks/managed/codex_context_continuity.py" state-update --payload "$context_state_update" >/dev/null \
  || install_test_fail "context continuity should record runtime recovery state"
context_precompact="$(jq -nc \
  --arg sid "codex-context-runtime" \
  --arg cwd "$home_dir/project" \
  '{session_id: $sid, hook_event_name: "PreCompact", trigger: "auto", cwd: $cwd}')"
printf '%s' "$context_precompact" | HOME="$home_dir" python3 "$home_dir/.codex/hooks/managed/codex_context_continuity.py" >/dev/null \
  || install_test_fail "context continuity should seal precompact state"
context_summary='runtime compact summary should not be stored in full by default'
context_postcompact="$(jq -nc \
  --arg sid "codex-context-runtime" \
  --arg cwd "$home_dir/project" \
  --arg summary "$context_summary" \
  '{session_id: $sid, hook_event_name: "PostCompact", trigger: "auto", cwd: $cwd, compact_summary: $summary}')"
context_output="$(printf '%s' "$context_postcompact" | HOME="$home_dir" python3 "$home_dir/.codex/hooks/managed/codex_context_continuity.py")" \
  || install_test_fail "context continuity should record PostCompact metadata"
context_state="$home_dir/.codex/hooks/state/context-continuity/codex-context-runtime.json"
install_test_assert_file_exists "$context_state" "context continuity should persist task state card"
[ -z "$context_output" ] || install_test_fail "context continuity PostCompact hook must not emit hook-specific additionalContext"
printf '%s' "$context_output" | grep -Fq "$context_summary" && install_test_fail "context continuity must not inject compact summary into additionalContext"
install_test_assert_file_not_contains "$context_state" "$context_summary" "context continuity should not store full compact summary by default"
jq -e --arg summary "$context_summary" --arg prompt "$context_prompt" '
  .last_user_prompt_preview == $prompt
  and (.last_user_prompt_hash | type == "string" and length == 64)
  and .recovery_status == "READY"
  and .postcompact.summary_length == ($summary | length)
  and (.postcompact.summary_sha256 | type == "string" and length == 64)
  and (.postcompact | has("compact_summary") | not)
' "$context_state" >/dev/null 2>&1 || install_test_fail "context continuity state should preserve prompt and compact metadata only"
context_sessionstart="$(jq -nc \
  --arg sid "codex-context-runtime" \
  --arg cwd "$home_dir/project" \
  '{session_id: $sid, hook_event_name: "SessionStart", source: "compact", cwd: $cwd}')"
context_recovery_output="$(printf '%s' "$context_sessionstart" | HOME="$home_dir" python3 "$home_dir/.codex/hooks/managed/codex_context_continuity.py")" \
  || install_test_fail "context continuity should emit SessionStart compact recovery context"
printf '%s' "$context_recovery_output" | jq -e '
  .hookSpecificOutput.hookEventName == "SessionStart"
  and (.hookSpecificOutput.additionalContext | contains("task_state_ref:"))
  and (.hookSpecificOutput.additionalContext | contains("precompact_checkpoint_ref:"))
  and (.hookSpecificOutput.additionalContext | contains("compact_summary_ref:"))
  and (.hookSpecificOutput.additionalContext | contains("recovery_status: READY"))
  and (.hookSpecificOutput.additionalContext | contains("allowed_next_step: CONTINUE_FROM_STATE"))
  and (.hookSpecificOutput.additionalContext | contains("不要猜测"))
' >/dev/null 2>&1 || install_test_fail "context continuity should inject recovery context only from SessionStart compact"
printf '%s' "$context_recovery_output" | grep -Fq "$context_summary" && install_test_fail "context continuity must not inject compact summary from SessionStart"
jq -e '
  .last_recovery_injection.hook_event_name == "SessionStart"
  and .last_recovery_injection.source == "compact"
  and (.last_recovery_injection.task_state_ref | contains("codex-context-runtime.json"))
  and (.last_recovery_injection.precompact_checkpoint_ref | contains("latest-precompact-codex-context-runtime.json"))
  and (.last_recovery_injection.compact_summary_ref | contains("latest-postcompact-codex-context-runtime.json"))
  and (.last_recovery_injection.additional_context_sha256 | type == "string" and length == 64)
' "$context_state" >/dev/null 2>&1 || install_test_fail "context continuity should persist SessionStart compact injection evidence"
install_test_case_pass "runtime: codex context continuity is opt-in and metadata-only"

install_test_case_start "runtime: codex install warns instead of failing on untrusted hooks"
home_dir="$(install_test_new_home runtime-codex-untrusted-hooks)"
bin_dir="$(prepare_fake_openspec "$home_dir")"
cat > "$bin_dir/codex" <<'PY'
#!/usr/bin/env python3
import json
import os
import shutil
import sys


def response(request_id, result):
    print(json.dumps({"jsonrpc": "2.0", "id": request_id, "result": result}), flush=True)


def hook(event, key, command):
    return {
        "key": f"{os.environ['HOME']}/.codex/hooks.json:{key}",
        "eventName": event,
        "handlerType": "command",
        "matcher": None,
        "command": command,
        "timeoutSec": 10,
        "statusMessage": None,
        "sourcePath": f"{os.environ['HOME']}/.codex/hooks.json",
        "source": "user",
        "pluginId": None,
        "displayOrder": 0,
        "enabled": True,
        "isManaged": False,
        "currentHash": "sha256:test",
        "trustStatus": "untrusted",
    }


if sys.argv[1:4] != ["app-server", "--enable", "hooks"]:
    raise SystemExit("unexpected fake codex invocation")

home = os.environ["HOME"]
python = shutil.which("python3") or "python3"
hooks = [
    hook("preToolUse", "pre_tool_use:0:0", f"bash {home}/.codex/hooks/managed/block_dangerous.sh"),
    hook("postToolUse", "post_tool_use:0:0", f"{python} {home}/.codex/hooks/managed/context_contract_validator.py"),
    hook("userPromptSubmit", "user_prompt_submit:0:0", f"{python} {home}/.codex/hooks/managed/codex_user_prompt_submit.py"),
    hook("subagentStart", "subagent_start:0:0", f"{python} {home}/.codex/hooks/managed/codex_subagent_dispatch_guard.py"),
    hook("stop", "stop:0:0", f"{python} {home}/.codex/hooks/managed/codex_stop_dispatch.py"),
]

for raw_line in sys.stdin:
    message = json.loads(raw_line)
    method = message.get("method")
    if method == "initialize":
        response(message["id"], {})
    elif method == "hooks/list":
        response(message["id"], {"data": [{"cwd": os.getcwd(), "hooks": hooks, "warnings": [], "errors": []}]})
PY
chmod +x "$bin_dir/codex"
log_file="$(install_test_log_path runtime-codex-untrusted-hooks-install)"
PATH="$bin_dir:$PATH" env HOME="$home_dir" ORG_STATE_ROOT="$(install_test_state_root "$home_dir")" ORG_SKIP_CONTRACT_VALIDATION=1 ORG_SKIP_CODEX_HOOK_TRUST_AUDIT=0 \
  bash "$ROOT/install.sh" --target codex --force --check quick >"$log_file" 2>&1 || install_test_fail "codex install should not fail only because hooks are untrusted"
install_test_assert_file_contains "$log_file" "Codex hooks 已安装但尚未 trusted/managed" "install should warn when hooks still need review"
install_test_assert_file_contains "$log_file" "/hooks" "install warning should tell the user how to review hooks"
install_test_case_pass "runtime: codex install warns instead of failing on untrusted hooks"

install_test_case_start "runtime: codex install ignores external untrusted hooks during managed audit"
home_dir="$(install_test_new_home runtime-codex-external-untrusted-hooks)"
bin_dir="$(prepare_fake_openspec "$home_dir")"
cat > "$bin_dir/codex" <<'PY'
#!/usr/bin/env python3
import json
import os
import shutil
import sys


def response(request_id, result):
    print(json.dumps({"jsonrpc": "2.0", "id": request_id, "result": result}), flush=True)


def hook(event, key, command, status):
    return {
        "key": f"{os.environ['HOME']}/.codex/hooks.json:{key}",
        "eventName": event,
        "handlerType": "command",
        "matcher": None,
        "command": command,
        "timeoutSec": 10,
        "statusMessage": None,
        "sourcePath": f"{os.environ['HOME']}/.codex/hooks.json",
        "source": "user",
        "pluginId": None,
        "displayOrder": 0,
        "enabled": True,
        "isManaged": False,
        "currentHash": "sha256:test",
        "trustStatus": status,
    }


if sys.argv[1:4] != ["app-server", "--enable", "hooks"]:
    raise SystemExit("unexpected fake codex invocation")

home = os.environ["HOME"]
python = shutil.which("python3") or "python3"
hooks = [
    hook("preToolUse", "pre_tool_use:0:0", f"bash {home}/.codex/hooks/managed/block_dangerous.sh", "trusted"),
    hook("postToolUse", "post_tool_use:0:0", f"{python} {home}/.codex/hooks/managed/context_contract_validator.py", "trusted"),
    hook("userPromptSubmit", "user_prompt_submit:0:0", f"{python} {home}/.codex/hooks/managed/codex_user_prompt_submit.py", "trusted"),
    hook("subagentStart", "subagent_start:0:0", f"{python} {home}/.codex/hooks/managed/codex_subagent_dispatch_guard.py", "trusted"),
    hook("stop", "stop:0:0", f"{python} {home}/.codex/hooks/managed/codex_stop_dispatch.py", "trusted"),
    hook("stop", "stop:1:0", f"{home}/bin/external-notify.sh", "modified"),
]

for raw_line in sys.stdin:
    message = json.loads(raw_line)
    method = message.get("method")
    if method == "initialize":
        response(message["id"], {})
    elif method == "hooks/list":
        response(message["id"], {"data": [{"cwd": os.getcwd(), "hooks": hooks, "warnings": [], "errors": []}]})
PY
chmod +x "$bin_dir/codex"
log_file="$(install_test_log_path runtime-codex-external-untrusted-hooks-install)"
PATH="$bin_dir:$PATH" env HOME="$home_dir" ORG_STATE_ROOT="$(install_test_state_root "$home_dir")" ORG_SKIP_CONTRACT_VALIDATION=1 ORG_SKIP_CODEX_HOOK_TRUST_AUDIT=0 \
  bash "$ROOT/install.sh" --target codex --force --check quick >"$log_file" 2>&1 || install_test_fail "codex install should pass when only external hooks need review"
install_test_assert_file_not_contains "$log_file" "Codex hooks 已安装但尚未 trusted/managed" "install should not warn for external hooks outside managed audit scope"
install_test_case_pass "runtime: codex install ignores external untrusted hooks during managed audit"

install_test_case_start "runtime: codex install migrates legacy hooks feature with commented table header"
home_dir="$(install_test_new_home runtime-codex-commented-features)"
cat > "$home_dir/.codex/config.toml" <<'TOML'
model = "gpt-5"

[features] # user-owned feature table
codex_hooks = true
child_agents_md = true
TOML
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-codex-commented-features-install)" --target codex --force --check quick
install_test_assert_file_contains "$home_dir/.codex/config.toml" "hooks = true" "codex install should migrate legacy hooks feature under commented [features] header"
install_test_assert_file_not_contains "$home_dir/.codex/config.toml" "codex_hooks" "deprecated codex_hooks feature should be cleaned under commented [features] header"
python3 - "$home_dir/.codex/config.toml" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
headers = [
    line
    for line in path.read_text(encoding="utf-8").splitlines()
    if re.match(r"^\s*\[features\]\s*(?:#.*)?$", line)
]
if len(headers) != 1:
    raise SystemExit(f"expected exactly one [features] table, got {len(headers)}")
PY
install_test_case_pass "runtime: codex install migrates legacy hooks feature with commented table header"

install_test_case_start "runtime: codex audit removes legacy symlink residue and preserves platform defaults"
home_dir="$(install_test_clone_baseline_home runtime-audit-residue)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p "$home_dir/.codex/rules"
mkdir -p "$home_dir/.codex/reference"
printf 'platform default rules\n' > "$home_dir/.codex/rules/default.rules"
default_rules_hash="$(shasum "$home_dir/.codex/rules/default.rules" | awk '{print $1}')"
ln -s "$home_dir/.claude/reference/旧质量指南.md" "$home_dir/.codex/rules/旧质量指南.md"
printf 'legacy hard rule\n' > "$home_dir/.codex/rules/铁律.md"
printf 'legacy reuse reference\n' > "$home_dir/.codex/reference/代码复用.md"
mkdir -p "$INSTALL_TEST_REPO_FINGERPRINT_PROBE"
printf 'non-runtime eval probe\n' > "$INSTALL_TEST_REPO_FINGERPRINT_PROBE/probe.txt"
mkdir -p "$INSTALL_TEST_REPO_WORKSPACE_PROBE"
printf 'non-runtime workspace probe\n' > "$INSTALL_TEST_REPO_WORKSPACE_PROBE/probe.txt"
[ -L "$home_dir/.codex/rules/旧质量指南.md" ] || install_test_fail "failed to seed legacy residue symlink"
before_version="$(cat "$state_root/codex/installed-version")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-audit-residue-install)" --target codex --check quick
after_version="$(cat "$state_root/codex/installed-version")"
[ "$before_version" = "$after_version" ] || install_test_fail "audit should not change installed version"
rm -rf "$INSTALL_TEST_REPO_FINGERPRINT_PROBE"
rm -rf "$INSTALL_TEST_REPO_WORKSPACE_PROBE"
install_test_assert_path_absent "$home_dir/.codex/rules/旧质量指南.md" "legacy residue should be removed"
install_test_assert_path_absent "$home_dir/.codex/rules/铁律.md" "retired hard rule residue should be removed"
install_test_assert_path_absent "$home_dir/.codex/reference/代码复用.md" "retired reference residue should be removed"
install_test_assert_file_exists "$home_dir/.codex/rules/default.rules" "default.rules should be preserved"
[ "$default_rules_hash" = "$(shasum "$home_dir/.codex/rules/default.rules" | awk '{print $1}')" ] || install_test_fail "default.rules content should remain unchanged"
archive_path="$(find "$state_root/codex/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/旧质量指南.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "legacy residue should be archived"
archive_path="$(find "$state_root/codex/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/铁律.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "retired hard rule residue should be archived"
archive_path="$(find "$state_root/codex/unexpected-artifacts" \( -type f -o -type l \) -path '*/reference/代码复用.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "retired reference residue should be archived"
install_test_run_install "$home_dir" "$(install_test_log_path runtime-audit-residue-uninstall)" --target codex --uninstall
install_test_assert_path_absent "$home_dir/.codex/rules/旧质量指南.md" "codex uninstall should not restore retired legacy rule residue"
install_test_assert_path_absent "$home_dir/.codex/rules/铁律.md" "codex uninstall should not restore retired hard rule residue"
install_test_assert_path_absent "$home_dir/.codex/reference/代码复用.md" "codex uninstall should not restore retired reference residue"
install_test_case_pass "runtime: codex audit removes legacy symlink residue and preserves platform defaults"

install_test_case_start "runtime: rule audit preserves local unmanaged team rules"
home_dir="$(install_test_clone_baseline_home runtime-local-team-rule)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p "$home_dir/.claude/rules"
printf 'local team safety rule\n' > "$home_dir/.claude/rules/local-team-safety.md"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-local-team-rule-install)" --target claude --check quick
install_test_assert_file_contains "$home_dir/.claude/rules/local-team-safety.md" "local team safety rule" "local unmanaged team rule should remain active"
archive_path="$(find "$state_root/claude/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/local-team-safety.md' 2>/dev/null | head -1 || true)"
[ -z "$archive_path" ] || install_test_fail "local unmanaged team rule should not be archived"
install_test_case_pass "runtime: rule audit preserves local unmanaged team rules"

install_test_case_start "runtime: claude audit removes legacy active rule residue"
home_dir="$(install_test_clone_baseline_home runtime-claude-rule-residue)"
state_root="$(install_test_state_root "$home_dir")"
mkdir -p "$home_dir/.claude/rules"
mkdir -p "$home_dir/.claude/reference"
printf 'legacy code rules\n' > "$home_dir/.claude/rules/代码规范.md"
printf 'legacy completion rules\n' > "$home_dir/.claude/rules/完成前验证.md"
printf 'legacy execution control rules\n' > "$home_dir/.claude/rules/执行纪律.md"
printf 'legacy document governance rules\n' > "$home_dir/.claude/rules/文档管理.md"
printf 'legacy hard rule\n' > "$home_dir/.claude/rules/铁律.md"
printf 'legacy performance reference\n' > "$home_dir/.claude/reference/性能效率.md"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-claude-rule-residue-install)" --target claude --check quick
install_test_assert_path_absent "$home_dir/.claude/rules/代码规范.md" "claude legacy code rule residue should be removed"
install_test_assert_path_absent "$home_dir/.claude/rules/完成前验证.md" "claude legacy completion rule residue should be removed"
install_test_assert_path_absent "$home_dir/.claude/rules/执行纪律.md" "claude legacy execution rule residue should be removed"
install_test_assert_path_absent "$home_dir/.claude/rules/文档管理.md" "claude legacy document governance rule residue should be removed"
install_test_assert_path_absent "$home_dir/.claude/rules/铁律.md" "claude retired hard rule residue should be removed"
install_test_assert_path_absent "$home_dir/.claude/reference/性能效率.md" "claude retired reference residue should be removed"
archive_path="$(find "$state_root/claude/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/代码规范.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "claude legacy code rule residue should be archived"
archive_path="$(find "$state_root/claude/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/完成前验证.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "claude legacy completion rule residue should be archived"
archive_path="$(find "$state_root/claude/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/执行纪律.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "claude legacy execution rule residue should be archived"
archive_path="$(find "$state_root/claude/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/文档管理.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "claude legacy document governance rule residue should be archived"
archive_path="$(find "$state_root/claude/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/铁律.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "claude retired hard rule residue should be archived"
archive_path="$(find "$state_root/claude/unexpected-artifacts" \( -type f -o -type l \) -path '*/reference/性能效率.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "claude retired reference residue should be archived"
install_test_case_pass "runtime: claude audit removes legacy active rule residue"

install_test_case_start "runtime: codex install removes retired project-agents-init residue"
home_dir="$(install_test_clone_baseline_home runtime-retired-project-agents-init)"
mkdir -p "$home_dir/.codex/skills/project-agents-init/references"
printf 'legacy retired skill\n' > "$home_dir/.codex/skills/project-agents-init/SKILL.md"
printf 'legacy retired ref\n' > "$home_dir/.codex/skills/project-agents-init/references/legacy.md"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-retired-project-agents-init-install)" --target codex --force --check quick
install_test_assert_path_absent "$home_dir/.codex/skills/project-agents-init" "retired skill project-agents-init should be removed during codex install"
install_test_case_pass "runtime: codex install removes retired project-agents-init residue"

printf '\nInstall runtime tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
