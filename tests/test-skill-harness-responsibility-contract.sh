#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-harness/SKILL.md"
AUDIT="$ROOT/shared/skills/skill-harness/references/audit-method.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

literal_token() {
  printf "\140%s\140" "$1"
}

section() {
  local file="$1"
  local heading="$2"

  awk -v heading="$heading" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$file"
}

assert_section_present() {
  local label="$1"
  local text="$2"

  [ -n "$text" ] || fail "$label missing"
}

assert_token_set() {
  local label="$1"
  local text="$2"
  shift 2

  local token
  for token in "$@"; do
    printf '%s\n' "$text" | grep -Fq "$(literal_token "$token")" || fail "$label missing $token"
  done
}

assert_no_token() {
  local label="$1"
  local text="$2"
  local token="$3"

  if printf '%s\n' "$text" | grep -Fq "$(literal_token "$token")"; then
    fail "$label must not contain $token"
  fi
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  local label="$3"

  grep -Fq "$expected" "$file" || fail "$label"
}

assert_contract_sections() {
  local file="$1"
  local label="$2"
  local base conditional

  base="$(section "$file" "## Base Fields")"
  conditional="$(section "$file" "## Conditional Fields")"

  assert_section_present "$label base fields" "$base"
  assert_section_present "$label conditional fields" "$conditional"

  assert_token_set "$label base fields" "$base" \
    overall_verdict \
    dimension \
    dimension_result \
    finding_severity \
    file:line \
    evidence \
    impact \
    recommendation \
    audit_proof_type \
    proof_command \
    gate_type

  assert_no_token "$label base fields" "$base" dry_run_verdict
  assert_no_token "$label base fields" "$base" legacy_baseline_label

  assert_token_set "$label conditional fields" "$conditional" \
    dry_run_verdict \
    legacy_baseline_label

  printf '%s\n' "$conditional" | grep -Fq 'Active/default audit output must not consume conditional fields.' || \
    fail "$label conditional fields missing active/default non-consumption rule"
}

assert_enum_contract() {
  local file="$1"
  local label="$2"

  assert_file_contains "$file" "$(literal_token overall_verdict): $(literal_token 'PASS / FAIL / COMMENT')" "$label missing overall_verdict enum"
  assert_file_contains "$file" "$(literal_token dimension_result): $(literal_token 'PASS / FAIL / WARN / NOT_APPLICABLE')" "$label missing dimension_result enum"
  assert_file_contains "$file" "$(literal_token finding_severity): $(literal_token 'S1 / S2 / S3 / INFO')" "$label missing finding_severity enum"
  assert_file_contains "$file" "$(literal_token audit_proof_type): $(literal_token 'file_evidence / fixture_proof / fresh_proving')" "$label missing audit_proof_type enum"
  assert_file_contains "$file" "$(literal_token dry_run_verdict): $(literal_token 'CONTINUE / STOP')" "$label missing dry_run_verdict enum"
}

assert_final_dimension_enum() {
  local line count

  line="$(grep -F "$(literal_token final_dimension_enum):" "$AUDIT" || true)"
  [ -n "$line" ] || fail "audit method missing final dimension enum"

  for dimension in \
    Trigger \
    Loading \
    Decision \
    Execution \
    Verification \
    Evolution \
    "Main Content Noise" \
    "Chain Integration" \
    "Engineering Control" \
    "Directory Capability"; do
    printf '%s\n' "$line" | grep -Fq "$dimension" || fail "final_dimension_enum missing $dimension"
  done

  count="$(printf '%s\n' "$line" | tr '/' '\n' | wc -l | tr -d ' ')"
  [ "$count" = "10" ] || fail "final_dimension_enum must contain exactly 10 dimensions, got $count"
}

assert_contract_sections "$SKILL" "SKILL"
assert_contract_sections "$AUDIT" "audit method"
assert_enum_contract "$SKILL" "SKILL"
assert_enum_contract "$AUDIT" "audit method"

assert_final_dimension_enum
assert_file_contains "$AUDIT" 'Correctness PASS / Practice FAIL' "audit method missing legacy mapping note"

for file in "$SKILL" "$AUDIT"; do
  if grep -Eq '(^|[^[:alnum:]_])proof_type([^[:alnum:]_]|$)' "$file"; then
    fail "$file contains standalone proof_type"
  fi
done

printf '[PASS] skill-harness responsibility contract\n'
