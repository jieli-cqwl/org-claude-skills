#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -n -F "$pattern" "$file" >/dev/null 2>&1 || fail "missing literal in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -n -F "$pattern" "$file" >/tmp/org_managed_doc_absent.out 2>&1; then
    cat /tmp/org_managed_doc_absent.out >&2
    fail "unexpected literal in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_json_allowed_root() {
  local file="$1"
  local root="$2"
  jq -e --arg root "$root" '
    .scripts[]
    | select(.id == "completion-check" or .path == "scripts/completion_check.sh")
    | .allowed_input_roots | index($root)
  ' "$file" >/dev/null || fail "missing allowed input root in ${file#"$ROOT"/}: $root"
}

assert_no_legacy_managed_doc_dirs() {
  local legacy_dirs=(
    "$ROOT/docs/reports/tech-debt"
    "$ROOT/docs/reports/security"
  )

  for dir in "${legacy_dirs[@]}"; do
    [ ! -e "$dir" ] || fail "legacy managed docs directory must not remain active: ${dir#"$ROOT"/}"
  done
}

assert_managed_scan_security_outputs() {
  local scan_skill="$ROOT/shared/skills/scan/SKILL.md"
  local scan_script="$ROOT/shared/skills/scan/scripts/completion_check.sh"
  local scan_manifest="$ROOT/shared/skills/scan/scripts/manifest.json"
  local security_skill="$ROOT/shared/skills/security/SKILL.md"
  local security_script="$ROOT/shared/skills/security/scripts/completion_check.sh"
  local security_manifest="$ROOT/shared/skills/security/scripts/manifest.json"

  assert_present 'docs/reports--tech-debt/[YYYY-MM-DD]_技术债扫描报告.md' "$scan_skill"
  assert_present 'docs/reports--tech-debt' "$scan_script"
  assert_json_allowed_root "$scan_manifest" 'docs/reports--tech-debt'
  assert_absent 'docs/reports/tech-debt' "$scan_skill"
  assert_absent 'docs/reports/tech-debt' "$scan_script"
  assert_absent 'docs/reports/tech-debt' "$scan_manifest"

  assert_present 'docs/reports--security/[YYYY-MM-DD]_安全扫描报告.md' "$security_skill"
  assert_present 'docs/reports--security' "$security_script"
  assert_json_allowed_root "$security_manifest" 'docs/reports--security'
  assert_absent 'docs/reports/security' "$security_skill"
  assert_absent 'docs/reports/security' "$security_script"
  assert_absent 'docs/reports/security' "$security_manifest"
}

assert_managed_refactor_outputs() {
  local skill="$ROOT/shared/skills/refactor/SKILL.md"
  local script="$ROOT/shared/skills/refactor/scripts/completion_check.sh"

  assert_present 'docs/refactor--{模块名}/plan.md' "$skill"
  assert_present 'docs/refactor--[^/"[:space:]*{}]+/plan\.md' "$script"
  assert_present 'docs/refactor--*/plan.md' "$script"
  assert_absent 'docs/重构-' "$script"
}

assert_optional_archives_use_managed_dirs() {
  assert_present 'docs/ai-cli-updates--YYYY-MM-DD/report.md' "$ROOT/shared/skills/cli-updater/SKILL.md"
  assert_absent 'docs/ai-cli-updates/YYYY-MM-DD-report.md' "$ROOT/shared/skills/cli-updater/SKILL.md"

  assert_present 'docs/github-repo-radar--{topic}/report.md' "$ROOT/shared/skills/github-repo-radar/SKILL.md"
  assert_absent 'docs/github-repo-radar/{topic}-report.md' "$ROOT/shared/skills/github-repo-radar/SKILL.md"
}

assert_hotfix_fallback_uses_managed_dir() {
  assert_present 'docs/hotfix--YYYYMMDD-HHMM/' "$ROOT/shared/skills/fix/SKILL.md"
  assert_present 'docs/hotfix--YYYYMMDD-HHMM' "$ROOT/shared/skills/fix/projections/fix-report-template.md"
  assert_absent 'docs/hotfix-YYYYMMDD-HHMM' "$ROOT/shared/skills/fix/SKILL.md"
  assert_absent 'docs/hotfix-YYYYMMDD-HHMM' "$ROOT/shared/skills/fix/projections/fix-report-template.md"
}

assert_no_legacy_managed_doc_dirs
assert_managed_scan_security_outputs
assert_managed_refactor_outputs
assert_optional_archives_use_managed_dirs
assert_hotfix_fallback_uses_managed_dir

printf '[PASS] managed doc output contract\n'
