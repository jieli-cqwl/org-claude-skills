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

skill_dir="$ROOT/shared/skills/skill-pull"
skill_file="$skill_dir/SKILL.md"

assert_file "$skill_file"
assert_present '^name: skill-pull$' "$skill_file"
assert_present 'daily automated update flow' "$skill_file"
assert_present 'community/SOURCES.yaml' "$skill_file"
assert_present 'anthropic_skills' "$skill_file"
assert_present 'superpowers' "$skill_file"
assert_present 'vercel_skills' "$skill_file"
assert_present 'vercel_agent_browser' "$skill_file"
assert_present 'alchaincyf_darwin_skill' "$skill_file"
assert_present 'nextlevelbuilder_ui_ux_pro_max' "$skill_file"
assert_present 'persona_colleague_skill' "$skill_file"
assert_present 'persona_nuwa_skill' "$skill_file"
assert_present 'persona_yourself_skill' "$skill_file"
assert_present 'persona_midas_skill' "$skill_file"
assert_present 'bash install.sh --target all --check full' "$skill_file"
assert_present 'Full-check install gate' "$skill_file"
assert_present 'tools/community/check_superpowers_upstream_fidelity.py' "$skill_file"
assert_present 'bash install.sh --target all' "$skill_file"
assert_present 'success removes the worktree' "$skill_file"
assert_present 'failure preserves the worktree' "$skill_file"
assert_present 'Source updates' "$skill_file"
assert_present 'Runtime exposure changes' "$skill_file"
assert_present 'Validation results' "$skill_file"
assert_present 'Install result' "$skill_file"

for script in check_candidates.py run_update.py summarize_changes.py skill_pull_lib.py; do
  assert_file "$skill_dir/scripts/$script"
done

assert_present '"skill-pull"' "$ROOT/install.sh"
assert_present 'tests/test-skill-pull-contract.sh' "$ROOT/tests/run-all.sh"
assert_present 'tests/test-skill-pull-scripts.py' "$ROOT/tests/run-all.sh"
assert_present 'tests/test-superpowers-upstream-fidelity.sh' "$ROOT/tests/run-all.sh"
assert_present 'skill-pull' "$ROOT/README.md"
assert_absent 'OpenSpec|openspec' "$skill_file"

echo "[PASS] skill-pull contract"
