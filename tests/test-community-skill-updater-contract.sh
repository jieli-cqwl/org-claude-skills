#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  test -f "$path" || fail "missing file: ${path#"$ROOT"/}"
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

skill_dir="$ROOT/shared/skills/community-skill-updater"
skill_file="$skill_dir/SKILL.md"

assert_file "$skill_file"
assert_present '^name: community-skill-updater$' "$skill_file"
assert_present 'daily automated update flow' "$skill_file"
assert_present 'community/SOURCES.yaml' "$skill_file"
assert_present 'anthropic_skills' "$skill_file"
assert_present 'superpowers' "$skill_file"
assert_present 'vercel_skills' "$skill_file"
assert_present 'vercel_agent_browser' "$skill_file"
assert_present 'alchaincyf_darwin_skill' "$skill_file"
assert_present 'nextlevelbuilder_ui_ux_pro_max' "$skill_file"
assert_present 'OpenSpec' "$skill_file"
assert_present 'excluded from daily updates' "$skill_file"
assert_present 'bash install.sh --target all --check full' "$skill_file"
assert_present 'bash install.sh --target all' "$skill_file"
assert_present 'success removes the worktree' "$skill_file"
assert_present 'failure preserves the worktree' "$skill_file"
assert_present 'Source updates' "$skill_file"
assert_present 'Validation results' "$skill_file"
assert_present 'Install result' "$skill_file"

for script in check_candidates.py run_update.py summarize_changes.py community_skill_updater_lib.py; do
  assert_file "$skill_dir/scripts/$script"
done

assert_present '"community-skill-updater"' "$ROOT/install.sh"
assert_present 'tests/test-community-skill-updater-contract.sh' "$ROOT/tests/run-all.sh"
assert_present 'tests/test-community-skill-updater-scripts.py' "$ROOT/tests/run-all.sh"
assert_present 'community-skill-updater' "$ROOT/README.md"
assert_absent 'openspec.*default managed source' "$skill_file"

echo "[PASS] community-skill-updater contract"
