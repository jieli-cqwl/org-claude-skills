#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

install_test_init

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
post_compact_payload="$(printf '{}' | bash "$home_dir/.claude/hooks/post_compact.sh")" || install_test_fail "claude post_compact hook should emit JSON payload"
printf '%s' "$post_compact_payload" | jq -e '.hookSpecificOutput.hookEventName == "PostCompact"' >/dev/null 2>&1 || install_test_fail "claude post_compact hook should keep PostCompact event name"
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
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/block_dangerous.sh" "managed dangerous hook should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/context_contract_validator.py" "managed context validator hook should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_user_prompt_submit.py" "managed active-skill tracker should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" "$home_dir/.codex/hooks/managed/codex_stop_dispatch.py" "managed stop dispatcher should be installed"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"PostToolUse"' "supported Codex PostToolUse should be present"
install_test_assert_file_contains "$home_dir/.codex/hooks.json" '"matcher": "Write|Edit"' "Codex PostToolUse should match Write/Edit edits"
install_test_assert_file_not_contains "$home_dir/.codex/hooks.json" '"PostCompact"' "Claude-only PostCompact should not render into Codex hooks"
install_test_assert_file_not_contains "$home_dir/.codex/hooks.json" '"TaskCompleted"' "Claude-only TaskCompleted should not render into Codex hooks"
install_test_case_pass "runtime: codex install cleans stale probes and keeps supported user hooks"

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
printf 'platform default rules\n' > "$home_dir/.codex/rules/default.rules"
default_rules_hash="$(shasum "$home_dir/.codex/rules/default.rules" | awk '{print $1}')"
ln -s "$home_dir/.claude/reference/代码质量.md" "$home_dir/.codex/rules/代码质量.md"
[ -L "$home_dir/.codex/rules/代码质量.md" ] || install_test_fail "failed to seed legacy residue symlink"
before_version="$(cat "$state_root/codex/installed-version")"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-audit-residue-install)" --target codex --check quick
after_version="$(cat "$state_root/codex/installed-version")"
[ "$before_version" = "$after_version" ] || install_test_fail "audit should not change installed version"
install_test_assert_path_absent "$home_dir/.codex/rules/代码质量.md" "legacy residue should be removed"
install_test_assert_file_exists "$home_dir/.codex/rules/default.rules" "default.rules should be preserved"
[ "$default_rules_hash" = "$(shasum "$home_dir/.codex/rules/default.rules" | awk '{print $1}')" ] || install_test_fail "default.rules content should remain unchanged"
archive_path="$(find "$state_root/codex/unexpected-artifacts" \( -type f -o -type l \) -path '*/rules/代码质量.md' | head -1)"
[ -n "$archive_path" ] || install_test_fail "legacy residue should be archived"
install_test_case_pass "runtime: codex audit removes legacy symlink residue and preserves platform defaults"

install_test_case_start "runtime: codex install removes retired project-agents-init residue"
home_dir="$(install_test_clone_baseline_home runtime-retired-project-agents-init)"
mkdir -p "$home_dir/.codex/skills/project-agents-init/references"
printf 'legacy retired skill\n' > "$home_dir/.codex/skills/project-agents-init/SKILL.md"
printf 'legacy retired ref\n' > "$home_dir/.codex/skills/project-agents-init/references/legacy.md"
install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path runtime-retired-project-agents-init-install)" --target codex --force --check quick
install_test_assert_path_absent "$home_dir/.codex/skills/project-agents-init" "retired skill project-agents-init should be removed during codex install"
install_test_case_pass "runtime: codex install removes retired project-agents-init residue"

printf '\nInstall runtime tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
