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
[ ! -f "$TMP_HOME/.codex/skills/using-superpowers/agents/openai.yaml" ] || fail "using-superpowers should be codex manual-only"
[ ! -f "$TMP_HOME/.codex/skills/product/agents/openai.yaml" ] || fail "product should be codex manual-only"
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
  grep -Fq "若 hooks 不可用或需要 fresh proving command，请显式运行：" "$skill_file" || fail "$skill_name missing codex runtime fallback note"
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
{"cwd":"$TMP_HOME/work","session_id":"session-product","transcript_path":"$TMP_HOME/work/transcript.log","prompt":"/product 草拟需求"}
JSON

state_file="$TMP_HOME/.codex/hooks/state/active-skills/session-product.json"
[ -f "$state_file" ] || fail "active skill tracker should persist session skill state"
grep -Fq '"skill": "product"' "$state_file" || fail "active skill state should record product skill"

set +e
python3 "$TMP_HOME/.codex/hooks/managed/codex_stop_dispatch.py" <<JSON >/tmp/org_codex_stop_dispatch.out 2>/tmp/org_codex_stop_dispatch.err
{"cwd":"$TMP_HOME/work","session_id":"session-product","transcript_path":"$TMP_HOME/work/transcript.log","turn_id":"turn-1","stop_hook_active":false,"last_assistant_message":"done"}
JSON
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "stop dispatcher should translate gate failure into a Stop hook response"
grep -Fq '"continue": false' /tmp/org_codex_stop_dispatch.out || fail "stop dispatcher should stop the Codex Stop hook instead of continuing the turn"
grep -Eq '产品文档完整性检查未通过|无法定位当前 feature' /tmp/org_codex_stop_dispatch.out /tmp/org_codex_stop_dispatch.err || fail "stop dispatcher should surface completion gate failure context"

echo "[PASS] codex skill adapter"
