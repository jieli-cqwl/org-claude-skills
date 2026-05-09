#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOUNDARY="$ROOT/contracts/superpowers-boundary.yaml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  grep -Fq "$pattern" "$BOUNDARY" || fail "boundary contract missing: $pattern"
}

test -f "$BOUNDARY" || fail "missing contracts/superpowers-boundary.yaml"
test -s "$BOUNDARY" || fail "contracts/superpowers-boundary.yaml must not be empty"

assert_present "target_state: superpowers_official_full_mirror"
assert_present "community_superpowers: official_third_party_mirror"
assert_present "standard_chain: first_party_runtime"
assert_present "mirror_root: community/superpowers/skills"
assert_present "upstream_body_policy: exact_locked_ref_original"
assert_present "local_text_allowed_in: []"
assert_present "generated_codex_adapters"
assert_present "runtime_visibility_metadata"
assert_present "source_headers"
assert_present "official_skill_count: 14"
assert_present "codex_discovery_root: ~/.agents/skills"
assert_present "required_file_pattern: ~/.agents/skills/<official-superpowers-skill>/SKILL.md"
assert_present "superpowers_agent_adapters_allowed: false"
assert_present "community_superpowers: third_party_clean_room"
assert_present "first_party_custom_flow: shared_and_contracts_only"

for skill in brainstorming dispatching-parallel-agents executing-plans finishing-a-development-branch receiving-code-review requesting-code-review subagent-driven-development systematic-debugging test-driven-development using-git-worktrees using-superpowers verification-before-completion writing-plans writing-skills; do
  assert_present "  - $skill"
  test -f "$ROOT/community/superpowers/skills/$skill/SKILL.md" || fail "official skill missing: $skill"
done

for forbidden in small_chain small-chain implementation-router parallel-subagent-development verify-change "community/superpowers/codex" "community/superpowers/agents" "declared_forks" "overlay_files" ".codex/skills/<official-superpowers-skill>/SKILL.md"; do
  if grep -Fq "$forbidden" "$BOUNDARY"; then
    fail "boundary contract should not retain old Superpowers/runtime fact: $forbidden"
  fi
done
if grep -Eq 'codex_discovery_root: .*\.codex/skills' "$BOUNDARY"; then
  fail "boundary contract should not retain legacy Codex discovery root"
fi

python3 "$ROOT/tools/community/source_lock_check.py" >/dev/null || fail "boundary/source lock validation failed"

echo "[PASS] superpowers boundary"
