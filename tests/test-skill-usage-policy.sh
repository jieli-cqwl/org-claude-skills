#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

POLICY="$ROOT/docs/skill-usage-policy.md"
INSTALL="$ROOT/install.sh"
RUNNER="$ROOT/tests/run-all.sh"
README="$ROOT/README.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local text="$2"
  local label="$3"

  grep -Fq -- "$text" "$file" || fail "$label missing from $file: $text"
}

assert_not_contains_function() {
  local function_name="$1"
  local text="$2"

  if extract_install_function "$function_name" | grep -Fq -- "$text"; then
    fail "$function_name should not contain $text"
  fi
}

assert_contains_function() {
  local function_name="$1"
  local text="$2"

  extract_install_function "$function_name" | grep -Fq -- "$text" || fail "$function_name missing $text"
}

extract_install_function() {
  local function_name="$1"

  awk -v fn="$function_name" '
    $0 == fn "() {" { in_function = 1 }
    in_function { print }
    in_function && $0 == "}" { exit }
  ' "$INSTALL"
}

test -f "$POLICY" || fail "missing skill usage policy"
assert_contains "$README" 'docs/skill-usage-policy.md' "README policy link"
assert_contains "$RUNNER" '"tests/test-skill-usage-policy.sh"' "run-all policy gate"

assert_contains "$POLICY" '来源层解决文件覆盖，触发层解决语义重叠。' "source vs trigger principle"
assert_contains "$POLICY" 'Codex 运行时中，manual-only skill 必须移除 `agents/openai.yaml`' "manual-only codex adapter rule"
assert_contains "$POLICY" '| 官网、Landing、品牌页 | `frontend-design` | `ui-ux-pro-max`、`theme-factory`、`canvas-design` | `webapp-testing` |' "frontend website policy"
assert_contains "$POLICY" '| 后台管理系统 | `frontend-design` | `ui-ux-pro-max`、`ux`、`security` | `webapp-testing`、`qa` |' "admin policy"
assert_contains "$POLICY" '| H5、移动端、UniApp | `h5` | `ui-ux-pro-max`、`ux` | `webapp-testing`、`qa` |' "h5 policy"
assert_contains "$POLICY" '- `ui-ux-pro-max` 不提供自动触发入口。' "ui-ux manual policy"
assert_contains "$POLICY" '- `agent-browser` 不提供自动触发入口。' "agent-browser manual policy"

assert_contains_function "community_anthropic_selected" '"frontend-design"'
assert_contains_function "community_anthropic_selected" '"webapp-testing"'
assert_contains_function "community_nextlevelbuilder_selected" '"ui-ux-pro-max"'
assert_contains_function "community_vercel_selected" '"agent-browser"'

assert_contains_function "low_frequency_manual_only_skills" '"ui-ux-pro-max"'
assert_contains_function "low_frequency_manual_only_skills" '"h5"'
assert_contains_function "low_frequency_manual_only_skills" '"agent-browser"'
assert_contains_function "low_frequency_manual_only_skills" '"theme-factory"'
assert_contains_function "low_frequency_manual_only_skills" '"web-artifacts-builder"'
assert_not_contains_function "low_frequency_manual_only_skills" '"frontend-design"'
assert_not_contains_function "low_frequency_manual_only_skills" '"webapp-testing"'

printf '[PASS] skill usage policy gate\n'
