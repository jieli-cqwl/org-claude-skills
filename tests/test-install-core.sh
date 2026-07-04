#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/install-test-env.sh
. "$ROOT/tests/lib/install-test-env.sh"

GROUP="all"

usage() {
  cat <<'USAGE'
Usage: bash tests/test-install-core.sh [--group all|basic|runtime-noise|runtime-idempotent|runtime-product-split|claude-agents|codex-agent-model-config|codex-agent-config-file|codex-agent-config|codex-agent-file-contracts|codex-local-edit|codex-agent-files]
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --group)
      [ "$#" -ge 2 ] || install_test_fail "--group 缺少参数"
      GROUP="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      install_test_fail "未知参数: $1"
      ;;
  esac
done

case "$GROUP" in
  all|basic|runtime-noise|runtime-idempotent|runtime-product-split|claude-agents|codex-agent-model-config|codex-agent-config-file|codex-agent-config|codex-agent-file-contracts|codex-local-edit|codex-agent-files) ;;
  *) install_test_fail "未知 install-core group: $GROUP" ;;
esac

should_run_group() {
  [ "$GROUP" = "all" ] || [ "$GROUP" = "$1" ]
}

ensure_baseline_home() {
  if [ -z "$INSTALL_TEST_BASELINE_HOME" ]; then
    install_test_create_baseline_home "core-$GROUP-baseline" >/dev/null
  fi
}

install_test_init

if should_run_group basic; then
  install_test_case_start "core: install succeeds without openspec CLI"
  home_dir="$(install_test_new_home core-no-openspec)"
  state_root="$(install_test_state_root "$home_dir")"
  log_file="$(install_test_log_path core-no-openspec)"
  set +e
  INSTALL_TEST_CURRENT_LOG="$log_file"
  run_without_openspec env HOME="$home_dir" ORG_STATE_ROOT="$state_root" ORG_SKIP_CONTRACT_VALIDATION=1 ORG_SKIP_CODEX_HOOK_TRUST_AUDIT=1 \
    bash "$ROOT/install.sh" --target all --check quick >"$log_file" 2>&1
  rc=$?
  set -e
  install_test_assert_success "$rc" "install should succeed when openspec CLI is missing"
  if grep -q "未检测到 openspec CLI" "$log_file"; then
    install_test_fail "install output should not require openspec CLI"
  fi
  install_test_case_pass "core: install succeeds without openspec CLI"

  install_test_case_start "core: dry-run has no metadata side effects"
  home_dir="$(install_test_new_home core-dry-run)"
  state_root="$(install_test_state_root "$home_dir")"
  log_file="$(install_test_log_path core-dry-run)"
  install_test_run_install "$home_dir" "$log_file" --target all --dry-run --force
  install_test_assert_path_absent "$state_root/claude/installed-version" "dry-run should not create claude version metadata"
  install_test_assert_path_absent "$state_root/codex/installed-version" "dry-run should not create codex version metadata"
  install_test_case_pass "core: dry-run has no metadata side effects"

  install_test_case_start "core: conflict blocks install without force"
  home_dir="$(install_test_new_home core-conflict)"
  mkdir -p "$home_dir/.claude/skills/product-director"
  printf 'local-only\n' > "$home_dir/.claude/skills/product-director/SKILL.md"
  log_file="$(install_test_log_path core-conflict)"
  set +e
  install_test_run_install_allow_failure "$home_dir" "$log_file" --target claude --check quick
  rc=$?
  set -e
  install_test_assert_failure "$rc" "conflict install should fail without --force"
  install_test_assert_file_contains "$log_file" "检测到冲突" "conflict message"
  install_test_assert_file_contains "$home_dir/.claude/skills/product-director/SKILL.md" "local-only" "existing conflict file should stay unchanged"
  install_test_case_pass "core: conflict blocks install without force"

  install_test_case_start "core: create baseline for installed-runtime repair cases"
  install_test_create_baseline_home core-baseline >/dev/null
  baseline_home="$INSTALL_TEST_BASELINE_HOME"
  install_test_assert_control_plane_runtime_files "$baseline_home/.claude" "claude baseline runtime"
  install_test_assert_control_plane_runtime_files "$baseline_home/.codex" "codex baseline runtime"
  install_test_assert_file_exists "$baseline_home/.agents/skills/skill-creator/SKILL.md" "Codex user runtime should install repository-managed skill-creator"
  install_test_case_pass "core: create baseline for installed-runtime repair cases"
fi

if should_run_group runtime-noise; then
  ensure_baseline_home

  install_test_case_start "core: same-version install ignores runtime pycache noise"
  home_dir="$(install_test_clone_baseline_home core-runtime-noise)"
  install_test_refresh_installed_version "$home_dir" codex
  noise_dir="$home_dir/.agents/skills/product-manager/__pycache__"
  mkdir -p "$noise_dir"
  printf 'runtime noise\n' > "$noise_dir/completion_check.cpython-313.pyc"
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-runtime-noise-second)" --target codex --check quick
  install_test_assert_file_contains "$(install_test_log_path core-runtime-noise-second)" "已是最新版本" "same-version runtime noise should not force reinstall"
  install_test_assert_file_not_contains "$(install_test_log_path core-runtime-noise-second)" "运行面不完整" "runtime noise should be pruned before completeness check"
  install_test_assert_path_absent "$noise_dir" "same-version install should clean runtime pycache noise"
  install_test_case_pass "core: same-version install ignores runtime pycache noise"
fi

if should_run_group runtime-idempotent; then
  ensure_baseline_home

  install_test_case_start "core: same-version install is idempotent and repairs dependencies"
  home_dir="$(install_test_clone_baseline_home core-idempotent)"
  install_test_refresh_installed_version "$home_dir" claude
  install_test_refresh_installed_version "$home_dir" codex
  state_root="$(install_test_state_root "$home_dir")"
  codex_skills_dir="$home_dir/.agents/skills"
  install_test_assert_installed_control_plane_gates "$home_dir" "$home_dir/.codex" "codex" "$codex_skills_dir"
  mkdir -p "$home_dir/tools/community" "$home_dir/contracts/canonical"
  install_test_assert_installed_control_plane_gates "$home_dir" "$home_dir/.codex" "codex-shadow" "$codex_skills_dir"
  rm -f "$home_dir/.claude/tools/community/authority_proof.py"
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-idempotent-repair)" --target claude --check quick
  install_test_assert_file_exists "$home_dir/.claude/tools/community/authority_proof.py" "same-version install should restore missing authority_proof.py"
  ver1="$(cat "$state_root/claude/installed-version")"
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-idempotent-second)" --target all --check quick
  ver2="$(cat "$state_root/claude/installed-version")"
  [ "$ver1" = "$ver2" ] || install_test_fail "version changed unexpectedly on idempotent install"
  install_test_assert_file_contains "$(install_test_log_path core-idempotent-second)" "已是最新版本" "idempotent skip message"
  install_test_case_pass "core: same-version install is idempotent and repairs dependencies"
fi

if should_run_group runtime-product-split; then
  ensure_baseline_home

  install_test_case_start "core: same-version install repairs missing product split skills"
  home_dir="$(install_test_clone_baseline_home core-product-split)"
  install_test_refresh_installed_version "$home_dir" claude
  install_test_refresh_installed_version "$home_dir" codex
  codex_skills_dir="$home_dir/.agents/skills"
  rm -f "$home_dir/.claude/skills/product-director/SKILL.md"
  rm -f "$codex_skills_dir/product-manager/SKILL.md"
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-product-split-second)" --target all --check quick
  install_test_assert_file_exists "$home_dir/.claude/skills/product-director/SKILL.md" "same-version install should restore missing Claude product-director skill"
  install_test_assert_file_exists "$codex_skills_dir/product-manager/SKILL.md" "same-version install should restore missing Codex product-manager skill"
  install_test_assert_file_contains "$(install_test_log_path core-product-split-second)" "安装完成" "same-version product split repair should reinstall missing runtime files"
  install_test_assert_file_not_contains "$(install_test_log_path core-product-split-second)" "已是最新版本" "same-version product split repair should not silently skip"
  install_test_case_pass "core: same-version install repairs missing product split skills"
fi

if should_run_group claude-agents; then
  ensure_baseline_home

  install_test_case_start "core: same-version claude reinstall repairs stale agent contracts"
  home_dir="$(install_test_clone_baseline_home core-claude-agent-contracts)"
  install_test_refresh_installed_version "$home_dir" claude
  rm -f "$home_dir/.claude/agents/developer.md"
  verifier_agent="$home_dir/.claude/agents/verifier.md"
  python3 - "$verifier_agent" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    "加载 verify skill 结合目标和成功标准交付结果。\n",
    (
        "加载 verify skill 结合目标和成功标准交付结果。\n"
        "输出 verify-result.json，并先读完整方法论与可用工具策略。\n"
    ),
    1,
)
path.write_text(text, encoding="utf-8")
PY
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-claude-agent-contracts-second)" --target claude --check quick
  install_test_assert_file_contains "$(install_test_log_path core-claude-agent-contracts-second)" "安装完成" "same-version stale Claude agent contract should trigger repair install"
  install_test_assert_file_not_contains "$(install_test_log_path core-claude-agent-contracts-second)" "已是最新版本" "same-version stale Claude agent contract should not silently skip"
  install_test_assert_file_exists "$home_dir/.claude/agents/developer.md" "Claude developer agent should be restored"
  install_test_assert_file_contains "$verifier_agent" 'skills:' "Claude verifier agent should preserve Claude Code skills frontmatter"
  install_test_assert_file_contains "$verifier_agent" '  - verify' "Claude verifier agent should declare verify skill"
  install_test_assert_file_contains "$verifier_agent" '加载 verify skill 结合目标和成功标准交付结果。' "Claude verifier agent should be restored to platform best-practice instruction"
  install_test_assert_file_not_contains "$verifier_agent" 'verify-result.json' "Claude verifier agent should not duplicate skill output artifact contracts"
  install_test_assert_file_not_contains "$verifier_agent" '完整方法论' "Claude verifier agent should not duplicate skill methodology"
  install_test_case_pass "core: same-version claude reinstall repairs stale agent contracts"
fi

if should_run_group codex-agent-model-config || should_run_group codex-agent-config; then
  ensure_baseline_home

  install_test_case_start "core: same-version codex reinstall repairs stale agent model config and retires code-reviewer"
  home_dir="$(install_test_clone_baseline_home core-codex-agent-config)"
  install_test_refresh_installed_version "$home_dir" codex
  config_file="$home_dir/.codex/config.toml"
  python3 - "$config_file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    "[agents.developer]\n",
    '[agents.developer]\nmodel = "gpt-5.4-mini"\nmodel_reasoning_effort = "high"\n',
    1,
)
text = text.replace(
    "[agents.consistency-auditor]\n",
    '[agents.consistency-auditor]\nmodel = "gpt-5.4"\nmodel_reasoning_effort = "high"\n',
    1,
)
text += '\n[agents.code-reviewer]\ndescription = "retired reviewer"\nconfig_file = "./agents/code-reviewer.toml"\nmodel = "gpt-5.4"\nmodel_reasoning_effort = "high"\n'
text += '\n[agents.codex-doc-reviewer]\ndescription = "retired doc reviewer"\nconfig_file = "./agents/codex-doc-reviewer.toml"\n'
path.write_text(text, encoding="utf-8")
PY
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-codex-agent-config-second)" --target codex --check quick
  install_test_assert_file_contains "$(install_test_log_path core-codex-agent-config-second)" "安装完成" "same-version stale agent config should trigger repair install"
  install_test_assert_file_not_contains "$(install_test_log_path core-codex-agent-config-second)" "已是最新版本" "same-version stale agent config should not silently skip"
  install_test_assert_file_not_contains "$config_file" 'model = "gpt-5.4-mini"' "developer agent config should inherit global model"
  install_test_assert_file_not_contains "$config_file" 'model = "gpt-5.4"' "managed agent config should inherit global model and retired code-reviewer should be removed"
  install_test_assert_file_not_contains "$config_file" 'model_reasoning_effort = "high"' "agent config should inherit global reasoning effort"
  install_test_assert_file_not_contains "$config_file" "[agents.code-reviewer]" "retired code-reviewer agent section should be removed"
  install_test_assert_file_not_contains "$config_file" "[agents.codex-doc-reviewer]" "retired codex-doc-reviewer agent section should be removed"
  install_test_assert_file_not_contains "$config_file" 'config_file = "./agents/code-reviewer.toml"' "retired code-reviewer config_file should be removed"
  install_test_assert_file_not_contains "$config_file" 'config_file = "./agents/codex-doc-reviewer.toml"' "retired codex-doc-reviewer config_file should be removed"
  install_test_case_pass "core: same-version codex reinstall repairs stale agent model config and retires code-reviewer"
fi

if should_run_group codex-agent-config-file || should_run_group codex-agent-config; then
  ensure_baseline_home

  install_test_case_start "core: same-version codex reinstall repairs managed agent config_file drift"
  home_dir="$(install_test_clone_baseline_home core-codex-agent-config-file)"
  install_test_refresh_installed_version "$home_dir" codex
  config_file="$home_dir/.codex/config.toml"
  python3 - "$config_file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    'config_file = "./agents/consistency-auditor.toml"',
    'config_file = "./agents/consistency-auditor.toml.bak"',
    1,
)
path.write_text(text, encoding="utf-8")
PY
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-codex-agent-config-file-second)" --target codex --check quick
  install_test_assert_file_contains "$(install_test_log_path core-codex-agent-config-file-second)" "安装完成" "same-version agent config_file drift should trigger repair install"
  install_test_assert_file_not_contains "$(install_test_log_path core-codex-agent-config-file-second)" "已是最新版本" "same-version agent config_file drift should not silently skip"
  install_test_assert_file_contains "$config_file" 'config_file = "./agents/consistency-auditor.toml"' "consistency-auditor config_file should be repaired exactly"
  install_test_assert_file_not_contains "$config_file" 'config_file = "./agents/consistency-auditor.toml.bak"' "consistency-auditor config_file drift should be removed"
  install_test_case_pass "core: same-version codex reinstall repairs managed agent config_file drift"
fi

if should_run_group codex-agent-file-contracts || should_run_group codex-agent-files; then
  ensure_baseline_home

  install_test_case_start "core: same-version codex reinstall repairs stale review OpenAI policy"
  home_dir="$(install_test_clone_baseline_home core-codex-review-policy)"
  install_test_refresh_installed_version "$home_dir" codex
  review_policy="$home_dir/.agents/skills/review/agents/openai.yaml"
  cat >> "$review_policy" <<'YAML'
  execution_kind: agent_backed
  agent_type: code-reviewer
  allow_nested_agents: false
YAML
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-codex-review-policy-second)" --target codex --check quick
  install_test_assert_file_contains "$(install_test_log_path core-codex-review-policy-second)" "安装完成" "same-version stale review policy should trigger repair install"
  install_test_assert_file_not_contains "$(install_test_log_path core-codex-review-policy-second)" "已是最新版本" "same-version stale review policy should not silently skip"
  install_test_assert_file_contains "$review_policy" "allow_implicit_invocation: false" "review OpenAI policy should keep explicit manual invocation"
  install_test_assert_file_not_contains "$review_policy" "execution_kind: agent_backed" "review OpenAI policy should not stay agent-backed"
  install_test_assert_file_not_contains "$review_policy" "agent_type: code-reviewer" "review OpenAI policy should not point to retired code-reviewer"
  install_test_assert_file_not_contains "$review_policy" "allow_nested_agents:" "review OpenAI policy should not carry nested-agent runtime policy"
  install_test_case_pass "core: same-version codex reinstall repairs stale review OpenAI policy"

  install_test_case_start "core: same-version codex reinstall repairs stale agent file contracts"
  home_dir="$(install_test_clone_baseline_home core-codex-agent-file-contracts)"
  install_test_refresh_installed_version "$home_dir" codex
  verifier_agent="$home_dir/.codex/agents/verifier.toml"
  printf 'retired reviewer\n' > "$home_dir/.codex/agents/code-reviewer.toml"
python3 - "$verifier_agent" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    '# model 和 model_reasoning_effort 故意省略：继承 Codex 当前默认设置。\n',
    'model = "gpt-5.4-mini"\nmodel_reasoning_effort = "high"\n',
    1,
)
text = text.replace('sandbox_mode = "workspace-write"', 'sandbox_mode = "read-only"', 1)
text = re.sub(
    r'developer_instructions = """[\s\S]*?"""',
    (
        'developer_instructions = """'
        '先读并严格遵循以下文档后再执行：\n'
        '- 硬约束：{{HOME}}/.codex/rules/completion-claims.md\n'
        '- 完整方法论：{{HOME}}/.agents/skills/verify/SKILL.md\n'
        '可用工具：Read, Bash, Glob, Grep, Write。Write 仅用于输出 verify-result.json；禁止使用 Edit。\n'
        '"""'
    ),
    text,
    count=1,
)
path.write_text(text, encoding="utf-8")
PY
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-codex-agent-file-contracts-second)" --target codex --check quick
  install_test_assert_file_contains "$(install_test_log_path core-codex-agent-file-contracts-second)" "安装完成" "same-version stale agent file contract should trigger repair install"
  install_test_assert_file_not_contains "$(install_test_log_path core-codex-agent-file-contracts-second)" "已是最新版本" "same-version stale agent file contract should not silently skip"
  install_test_assert_file_not_contains "$verifier_agent" 'model = "gpt-5.4-mini"' "verifier agent file should inherit global model"
  install_test_assert_file_not_contains "$verifier_agent" 'model_reasoning_effort = "high"' "verifier agent file should inherit global reasoning effort"
  install_test_assert_file_contains "$verifier_agent" 'sandbox_mode = "workspace-write"' "verifier agent should preserve workspace-write sandbox"
  install_test_assert_file_contains "$verifier_agent" "加载 \`verify\` skill，结合目标和成功标准交付结果。" "verifier agent should be restored to platform best-practice instruction"
  install_test_assert_file_not_contains "$verifier_agent" 'verify-result.json' "verifier agent should not duplicate skill output artifact contracts"
  install_test_assert_file_not_contains "$verifier_agent" '先读并严格遵循' "verifier agent should not duplicate AGENTS.md/rules loading"
  install_test_assert_file_not_contains "$verifier_agent" '可用工具' "verifier agent should not duplicate tool policy"
  install_test_assert_path_absent "$home_dir/.codex/agents/code-reviewer.toml" "retired code-reviewer agent file should be removed even when absent from manifest"
  install_test_case_pass "core: same-version codex reinstall repairs stale agent file contracts"
fi

if should_run_group codex-local-edit || should_run_group codex-agent-files; then
  ensure_baseline_home

  install_test_case_start "core: same-version codex reinstall preserves local developer edits"
  home_dir="$(install_test_clone_baseline_home core-codex-local-edit)"
  codex_skills_dir="$home_dir/.agents/skills"
  install_test_refresh_installed_version "$home_dir" codex
  printf '\n## 本地补充\n- 这段内容用于验证同版本重装不会覆盖本地修改\n' >> "$codex_skills_dir/developer/SKILL.md"
  install_test_run_install_fake_openspec "$home_dir" "$(install_test_log_path core-codex-local-edit-second)" --target codex --check quick
  install_test_assert_file_contains "$codex_skills_dir/developer/SKILL.md" "## 本地补充" "codex reinstall should preserve local developer SKILL.md edits when version matches"
  install_test_assert_file_contains "$(install_test_log_path core-codex-local-edit-second)" "已是最新版本" "same-version codex reinstall should skip when runtime contains local edits"
  install_test_case_pass "core: same-version codex reinstall preserves local developer edits"
fi

printf '\nInstall core tests passed: %d\n' "$INSTALL_TEST_CASE_COUNT"
