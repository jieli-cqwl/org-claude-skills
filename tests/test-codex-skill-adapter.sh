#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
TMP_HOME="$(mktemp -d)"
STATE_ROOT="$TMP_HOME/.org-skills-state"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP_HOME/.codex"
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"
TOML

run_with_fake_openspec "$TMP_HOME" env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target codex --force --check quick >/tmp/org_codex_skill_adapter_install.out 2>&1 || {
  cat /tmp/org_codex_skill_adapter_install.out >&2
  fail "install failed"
}

[ ! -e "$TMP_HOME/.codex/skills/codex-doc-review" ] || fail "codex runtime should not install claude-only skill codex-doc-review"
[ ! -e "$TMP_HOME/.codex/skills/review-fix-loop" ] || fail "codex runtime should not install claude-only skill review-fix-loop"
[ ! -e "$TMP_HOME/.codex/skills/code-review-fix" ] || fail "codex runtime should not install claude-only skill code-review-fix"
[ ! -e "$TMP_HOME/.codex/skills/doc-review-fix" ] || fail "codex runtime should not install claude-only skill doc-review-fix"
[ ! -e "$TMP_HOME/.codex/agents/codex-doc-reviewer.md" ] || fail "codex runtime should not install claude-only agent codex-doc-reviewer.md"
[ -f "$TMP_HOME/.codex/skills/brainstorming/agents/openai.yaml" ] || fail "brainstorming should remain codex-auto"
[ -f "$TMP_HOME/.codex/skills/skill-harness/SKILL.md" ] || fail "skill-harness should install as a codex skill"
[ ! -f "$TMP_HOME/.codex/skills/skill-harness/agents/openai.yaml" ] || fail "skill-harness should remain codex manual-only"
[ -f "$TMP_HOME/.codex/skills/feishu-docs/SKILL.md" ] || fail "feishu-docs should install as a codex skill"
[ ! -f "$TMP_HOME/.codex/skills/feishu-docs/agents/openai.yaml" ] || fail "feishu-docs should remain codex manual-only"
[ -f "$TMP_HOME/.codex/skills/hv-analysis/SKILL.md" ] || fail "hv-analysis should install as a codex skill"
[ ! -f "$TMP_HOME/.codex/skills/hv-analysis/agents/openai.yaml" ] || fail "hv-analysis should remain codex manual-only"
[ -f "$TMP_HOME/.codex/skills/ui-ux-pro-max/SKILL.md" ] || fail "ui-ux-pro-max should install as a codex skill"
[ -f "$TMP_HOME/.codex/skills/ui-ux-pro-max/scripts/search.py" ] || fail "ui-ux-pro-max should install its search script"
[ ! -f "$TMP_HOME/.codex/skills/ui-ux-pro-max/agents/openai.yaml" ] || fail "ui-ux-pro-max should remain codex manual-only"
[ ! -e "$TMP_HOME/.codex/skills/skill-auditor" ] || fail "skill-auditor should not install into codex runtime"
[ ! -e "$TMP_HOME/.codex/skills/new-skills" ] || fail "new-skills should not install into codex runtime"
[ ! -f "$TMP_HOME/.codex/skills/using-superpowers/agents/openai.yaml" ] || fail "using-superpowers should be codex manual-only"
[ ! -f "$TMP_HOME/.codex/skills/product-director/agents/openai.yaml" ] || fail "product-director should be codex manual-only"
[ ! -f "$TMP_HOME/.codex/skills/product-manager/agents/openai.yaml" ] || fail "product-manager should be codex manual-only"
[ -f "$TMP_HOME/.codex/hooks.json" ] || fail "codex runtime should render hooks.json"
grep -Fq 'codex_hooks = true' "$TMP_HOME/.codex/config.toml" || fail "codex runtime should enable codex_hooks feature"
grep -Fq "$TMP_HOME/.codex/hooks/managed/block_dangerous.sh" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing managed dangerous bash hook"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing active skill tracker"
grep -Fq "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing stop dispatcher"
grep -Fq '"UserPromptSubmit"' "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing UserPromptSubmit event"
grep -Fq '"Stop"' "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing Stop event"
grep -Fq '"PreToolUse"' "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json missing PreToolUse event"
grep -Fq '"PostToolUse": []' "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json should render empty PostToolUse to match Claude standard events"
grep -Fq '"PostCompact": []' "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json should render empty PostCompact to match Claude standard events"
grep -Fq '"TaskCompleted": []' "$TMP_HOME/.codex/hooks.json" || fail "codex hooks.json should render empty TaskCompleted to match Claude standard events"
if grep -Fq '"SessionStart"' "$TMP_HOME/.codex/hooks.json"; then
  fail "codex hooks.json should not retain non-standard SessionStart"
fi

found=0
while IFS= read -r completion_check; do
  [ -n "$completion_check" ] || continue
  found=1
  skill_dir="$(dirname "$(dirname "$completion_check")")"
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  frontmatter="$(sed -n '/^---$/,/^---$/p' "$skill_file")"

  printf '%s\n' "$frontmatter" | grep -q '^hooks:' && fail "$skill_name frontmatter should not contain hooks"
  grep -Fq "Codex 运行说明：completion gate 默认通过 \`~/.codex/hooks.json\` 自动执行。" "$skill_file" || fail "$skill_name missing codex runtime auto-hook note"
  grep -Fq "\`scripts/completion_check.sh\` 依赖 hook payload；不要把它当作 fresh proving command，也不要直接裸跑。" "$skill_file" || fail "$skill_name missing codex runtime gate warning"
  grep -Fq "若 hooks 不可用：先运行离本次改动最近的 fresh proving command，并只对用户汇报该结果；仅在内部排查 gate 时，再构造 hook payload 调用 \`completion_check.sh\`。" "$skill_file" || fail "$skill_name missing codex runtime fallback guidance"
  if rg -n '若 hooks 不可用或需要 fresh proving command，请显式运行：|`bash \\$HOME/\\.codex/skills/.+/scripts/completion_check\\.sh`|显式执行 `scripts/completion_check\\.sh` 并通过，无 FAIL 项' "$skill_file" >/tmp/org_codex_skill_adapter_legacy.out 2>&1; then
    cat /tmp/org_codex_skill_adapter_legacy.out >&2
    fail "$skill_name should not retain misleading direct completion_check instructions"
  fi
done < <(find "$TMP_HOME/.codex/skills" -path '*/scripts/completion_check.sh' | sort)

[ "$found" -eq 1 ] || fail "expected at least one completion_check.sh in codex skills"

if rg -n 'Stop hook（`completion_check\.sh`）执行通过，无 FAIL 项' "$TMP_HOME/.codex/skills" -g 'SKILL.md' >/tmp/org_codex_skill_adapter_legacy.out 2>&1; then
  cat /tmp/org_codex_skill_adapter_legacy.out >&2
  fail "codex skills should not retain legacy Stop hook wording"
fi

mkdir -p "$TMP_HOME/work"
cat > "$TMP_HOME/work/transcript.log" <<'LOG'
write docs/demo/brief.md
LOG

python3 "$TMP_HOME/.codex/hooks/managed/codex_user_prompt_submit.py" <<JSON >/tmp/org_codex_hook_tracker.out 2>/tmp/org_codex_hook_tracker.err
{"cwd":"$TMP_HOME/work","session_id":"session-product-director","transcript_path":"$TMP_HOME/work/transcript.log","prompt":"/product-director 草拟需求"}
JSON

state_file="$TMP_HOME/.codex/hooks/state/active-skills/session-product-director.json"
[ -f "$state_file" ] || fail "active skill tracker should persist session skill state"
grep -Fq '"skill": "product-director"' "$state_file" || fail "active skill state should record product-director skill"

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch.out 2>/tmp/org_codex_stop_dispatch.err
{"cwd":"$TMP_HOME/work","session_id":"session-product-director","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-1","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "stop dispatcher should translate gate failure into a Stop hook response"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch.out || fail "stop dispatcher should stop the Codex Stop hook instead of continuing the turn"
grep -Eq 'Director 基线检查未通过|产品文档完整性检查未通过|无法定位当前 feature|Brief 文档不存在|canonical JSON artifacts' /tmp/org_codex_stop_dispatch.out /tmp/org_codex_stop_dispatch.err || fail "stop dispatcher should surface product-director gate failure context"
if rg -n 'transcript_path=|session_id=|tool_input\.file_path|hook payload|stdin 为空|/tmp/' /tmp/org_codex_stop_dispatch.out /tmp/org_codex_stop_dispatch.err >/tmp/org_codex_stop_dispatch_leak.out 2>&1; then
  cat /tmp/org_codex_stop_dispatch_leak.out >&2
  fail "stop dispatcher should not leak internal hook details in user-visible output"
fi

cat > "$TMP_HOME/.codex/hooks/state/active-skills/session-verify.json" <<'JSON'
{"skill":"verify","session_id":"session-verify"}
JSON
cat > "$TMP_HOME/work/verify-transcript.log" <<'LOG'
write docs/demo/phase-1/unit-1/tasks/T1/verify-result.json
LOG

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_verify.out 2>/tmp/org_codex_stop_dispatch_verify.err
{"cwd":"$TMP_HOME/work","session_id":"session-verify","transcript_path":"$TMP_HOME/work/verify-transcript.log","turn_id":"turn-verify","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "verify stop dispatcher should translate gate failure into a Stop hook response"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch_verify.out || fail "verify stop dispatcher should stop the turn when verify gate blocks"
grep -Eq 'verify-result\.json|Task 级精准验收|verify artifact' /tmp/org_codex_stop_dispatch_verify.out /tmp/org_codex_stop_dispatch_verify.err || fail "verify stop dispatcher should surface verify gate failure context"

mkdir -p "$TMP_HOME/work/docs/demo/phase-1/unit-1/tasks/T1"
cat > "$TMP_HOME/work/docs/demo/phase-1/unit-1/tasks/T1/developer-report.json" <<'JSON'
{
  "task_id":"T1",
  "runtime_status":"DONE",
  "summary_text":"verified runtime fixture",
  "task_scope":["shared/hooks/managed/codex_stop_dispatch.py"],
  "reviewable_anchor":"artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes":["shared/hooks/managed/codex_stop_dispatch.py"],
  "tdd_evidence_index":[
    {
      "phase":"RED",
      "commit_sha":"aa11bb2",
      "test_ref":"tests/test-codex-skill-adapter.sh#verify-pass",
      "result":"FAIL_EXPECTED",
      "ac_refs":["artifact://test-cases/demo.phase-1.unit-1.test-cases@v1#AC-T1-1"]
    },
    {
      "phase":"GREEN",
      "commit_sha":"cc33dd4",
      "test_ref":"tests/test-codex-skill-adapter.sh#verify-pass",
      "result":"PASS",
      "ac_refs":["artifact://test-cases/demo.phase-1.unit-1.test-cases@v1#AC-T1-1"]
    }
  ]
}
JSON
cat > "$TMP_HOME/work/docs/demo/phase-1/unit-1/tasks/T1/verify-result.json" <<'JSON'
{
  "task_id":"T1",
  "gate_result":"PASS",
  "baseline_plan_version_ref":"artifact://plan/demo.phase-1.plan@plan-v1#plan-version",
  "baseline_tasks_version_ref":"artifact://tasks/demo.phase-1.tasks@tasks-v1#task-registry",
  "developer_report_ref":"artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "phase_verdicts":{
    "spec_review":{"status":"SPEC_OK","evidence_ref":"artifact://verify-result/demo.phase-1.unit-1.task-T1.verify-result@v1#spec-review"},
    "phase2a":{"status":"2A_OK","evidence_ref":"artifact://verify-result/demo.phase-1.unit-1.task-T1.verify-result@v1#phase2a"},
    "phase2b":{"status":"2B_OK","evidence_ref":"artifact://verify-result/demo.phase-1.unit-1.task-T1.verify-result@v1#phase2b"},
    "phase2c":{"status":"2C_OK","evidence_ref":"artifact://verify-result/demo.phase-1.unit-1.task-T1.verify-result@v1#phase2c"}
  },
  "ac_verification":[
    {
      "ac_ref":"artifact://test-cases/demo.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "file_path":"shared/hooks/managed/codex_stop_dispatch.py",
      "line_number":42,
      "status":"PASS",
      "boundary_check":"missing session_id returns stop payload"
    }
  ],
  "goal_closure":[{"goal_ref":"artifact://brief/demo.brief@v1#goal-1","result":"MET"}],
  "evidence_refs":["artifact://evidence/demo.verify@v1#summary"]
}
JSON
cat > "$TMP_HOME/.codex/hooks/state/active-skills/session-verify-pass.json" <<'JSON'
{"skill":"verify","session_id":"session-verify-pass"}
JSON
cat > "$TMP_HOME/work/verify-pass-transcript.log" <<'LOG'
write docs/demo/phase-1/unit-1/tasks/T1/verify-result.json
LOG

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_verify_pass.out 2>/tmp/org_codex_stop_dispatch_verify_pass.err
{"cwd":"$TMP_HOME/work","session_id":"session-verify-pass","transcript_path":"$TMP_HOME/work/verify-pass-transcript.log","turn_id":"turn-verify-pass","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "verify stop dispatcher should preserve the happy-path response"
grep -Fq '"decision":"allow"' /tmp/org_codex_stop_dispatch_verify_pass.out || fail "verify stop dispatcher should surface the allow decision for valid verify artifacts"
if grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch_verify_pass.out; then
  cat /tmp/org_codex_stop_dispatch_verify_pass.out >&2
  fail "verify stop dispatcher should not emit a blocking Stop payload after a successful verify gate"
fi

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_missing_session.out 2>/tmp/org_codex_stop_dispatch_missing_session.err
{"cwd":"$TMP_HOME/work","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-missing-session","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "stop dispatcher should convert missing session_id into a stop payload"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch_missing_session.out || fail "missing session_id should fail closed"
grep -Fq 'session_id' /tmp/org_codex_stop_dispatch_missing_session.out || fail "missing session_id should surface a user-readable reason"

cat > "$TMP_HOME/.codex/hooks/state/active-skills/session-corrupt.json" <<'JSON'
{"skill":
JSON
set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_corrupt_state.out 2>/tmp/org_codex_stop_dispatch_corrupt_state.err
{"cwd":"$TMP_HOME/work","session_id":"session-corrupt","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-corrupt-state","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "stop dispatcher should convert corrupt active-skill state into a stop payload"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch_corrupt_state.out || fail "corrupt active-skill state should fail closed"
grep -Fq 'active skill 状态损坏' /tmp/org_codex_stop_dispatch_corrupt_state.out || fail "corrupt active-skill state should surface a user-readable reason"

mkdir -p "$TMP_HOME/.codex/skills/fake-skill/scripts" "$TMP_HOME/.codex/hooks/state/active-skills"
cat > "$TMP_HOME/.codex/skills/fake-skill/scripts/completion_check.sh" <<'SH'
#!/usr/bin/env bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "Completion hook 初始化失败：" >&2
echo "  - hook payload 缺少 tool_name，无法判断是否为 acceptance-summary.md 收口写入" >&2
echo "  - transcript_path=/tmp/fake.log, session_id=session-fake" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
exit 2
SH

python3 - "$TMP_HOME/.codex/hooks/registry.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["skill_completion_gates"].append(
    {
        "skill": "fake-skill",
        "handler_rel": "skills/fake-skill/scripts/completion_check.sh",
        "timeout_sec": 15,
        "codex": {"supported": True},
    }
)
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

cat > "$TMP_HOME/.codex/hooks/state/active-skills/session-fake.json" <<'JSON'
{"skill":"fake-skill","session_id":"session-fake"}
JSON

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_raw.out 2>/tmp/org_codex_stop_dispatch_raw.err
{"cwd":"$TMP_HOME/work","session_id":"session-fake","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-2","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "stop dispatcher should sanitize non-structured gate failures"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch_raw.out || fail "raw gate failure should still stop the turn"
grep -Eq 'Completion hook 初始化失败|运行时上下文' /tmp/org_codex_stop_dispatch_raw.out /tmp/org_codex_stop_dispatch_raw.err || fail "raw gate failure should keep a user-readable summary"
if rg -n 'hook payload|transcript_path=|session_id=|tool_name|/tmp/fake\.log' /tmp/org_codex_stop_dispatch_raw.out /tmp/org_codex_stop_dispatch_raw.err >/tmp/org_codex_stop_dispatch_raw_leak.out 2>&1; then
  cat /tmp/org_codex_stop_dispatch_raw_leak.out >&2
  fail "raw gate failure should be sanitized before reaching user-visible output"
fi

mkdir -p "$TMP_HOME/.codex/skills/allow-skill/scripts"
cat > "$TMP_HOME/.codex/skills/allow-skill/scripts/completion_check.sh" <<'SH'
#!/usr/bin/env bash
echo '{"decision":"allow"}'
exit 0
SH
chmod +x "$TMP_HOME/.codex/skills/allow-skill/scripts/completion_check.sh"

python3 - "$TMP_HOME/.codex/hooks/registry.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["skill_completion_gates"].append(
    {
        "skill": "allow-skill",
        "handler_rel": "skills/allow-skill/scripts/completion_check.sh",
        "timeout_sec": 15,
        "codex": {"supported": True},
    }
)
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

cat > "$TMP_HOME/.codex/hooks/state/active-skills/session-allow.json" <<'JSON'
{"skill":"allow-skill","session_id":"session-allow"}
JSON

python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_allow.out 2>/tmp/org_codex_stop_dispatch_allow.err
{"cwd":"$TMP_HOME/work","session_id":"session-allow","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-allow","stop_hook_active":false,"last_assistant_message":"done"}
JSON

grep -Fq '{"decision":"allow"}' /tmp/org_codex_stop_dispatch_allow.out || fail "successful gate stdout should be forwarded"
if rg -n '"continue":[[:space:]]*false|"stopReason"|"systemMessage"' /tmp/org_codex_stop_dispatch_allow.out >/tmp/org_codex_stop_dispatch_allow_fail.out 2>&1; then
  cat /tmp/org_codex_stop_dispatch_allow_fail.out >&2
  fail "successful gate stdout should not be converted into a stop failure"
fi

mkdir -p "$TMP_HOME/.codex/skills/timeout-skill/scripts"
cat > "$TMP_HOME/.codex/skills/timeout-skill/scripts/completion_check.sh" <<'SH'
#!/usr/bin/env bash
sleep 2
exit 0
SH
chmod +x "$TMP_HOME/.codex/skills/timeout-skill/scripts/completion_check.sh"

python3 - "$TMP_HOME/.codex/hooks/registry.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for entry in data["skill_completion_gates"]:
    if entry["skill"] == "fake-skill":
        entry["handler_rel"] = "skills/fake-skill/scripts/missing.sh"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_missing_gate.out 2>/tmp/org_codex_stop_dispatch_missing_gate.err
{"cwd":"$TMP_HOME/work","session_id":"session-fake","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-missing-gate","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "stop dispatcher should convert missing gate files into a stop payload"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch_missing_gate.out || fail "missing gate file should fail closed"
grep -Fq 'completion gate 缺失' /tmp/org_codex_stop_dispatch_missing_gate.out || fail "missing gate file should surface a user-readable reason"

python3 - "$TMP_HOME/.codex/hooks/registry.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["skill_completion_gates"].append(
    {
        "skill": "timeout-skill",
        "handler_rel": "skills/timeout-skill/scripts/completion_check.sh",
        "timeout_sec": 1,
        "codex": {"supported": True},
    }
)
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

cat > "$TMP_HOME/.codex/hooks/state/active-skills/session-timeout.json" <<'JSON'
{"skill":"timeout-skill","session_id":"session-timeout"}
JSON

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch_timeout.out 2>/tmp/org_codex_stop_dispatch_timeout.err
{"cwd":"$TMP_HOME/work","session_id":"session-timeout","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-timeout","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "timeout gate should return sanitized stop response"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch_timeout.out || fail "timed out gate should stop the turn"
grep -Eq 'timeout|超时' /tmp/org_codex_stop_dispatch_timeout.out /tmp/org_codex_stop_dispatch_timeout.err || fail "timed out gate should surface timeout reason"

echo "[PASS] codex skill adapter"
