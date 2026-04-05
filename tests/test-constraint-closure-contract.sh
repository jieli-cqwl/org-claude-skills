#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/lib/test-env.sh"
COMMON_SH="$ROOT/shared/hooks/lib/common.sh"
CONSTRAINT_SH="$ROOT/shared/hooks/lib/constraint.sh"
TECH_LEAD_CHECK="$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
PM_CHECK="$ROOT/shared/skills/project-manager/scripts/completion_check.sh"

ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file_contains() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

extract_function_block() {
  local function_name="$1"
  local file="$2"
  awk -v function_name="$function_name" '
    $0 ~ ("^[[:space:]]*" function_name "\\(\\)[[:space:]]*\\{") { in_func=1 }
    in_func { print }
    in_func && $0 ~ /^}[[:space:]]*$/ { exit }
  ' "$file"
}

assert_builder_tracks_constraint_identity() {
  local file="$1"
  local label="$2"
  local prd_builder
  local plan_builder
  local tmp_script

  # 函数可能在脚本本地定义或在公共库 constraint.sh 中定义
  prd_builder="$(extract_function_block "build_prd_constraint_pairs" "$file")"
  [ -n "$prd_builder" ] || prd_builder="$(extract_function_block "build_prd_constraint_pairs" "$CONSTRAINT_SH")"
  plan_builder="$(extract_function_block "build_plan_constraint_pairs" "$file")"
  [ -n "$plan_builder" ] || plan_builder="$(extract_function_block "build_plan_constraint_pairs" "$CONSTRAINT_SH")"
  [ -n "$prd_builder" ] || fail "${label}: missing build_prd_constraint_pairs()"
  [ -n "$plan_builder" ] || fail "${label}: missing build_plan_constraint_pairs()"

  tmp_script="$(mktemp)"
  {
    printf '%s\n' "$prd_builder"
    printf '%s\n' "$plan_builder"
    cat <<'EOF'
prd_base="CON-001|type-a|desc-a|owner-a|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001|KNOWN"
prd_desc_drift="CON-001|type-a|desc-b|owner-a|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001|KNOWN"
prd_owner_drift="CON-001|type-a|desc-a|owner-b|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001|KNOWN"
prd_unit_drift="CON-001|type-a|desc-a|owner-a|UNIT-2|SCOPE-P1U1-001|PF-001|TC-U1-001|KNOWN"

plan_base="CON-001|type-a|desc-a|owner-a|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001|Task-1|QA_A|MAPPED"
plan_desc_drift="CON-001|type-a|desc-b|owner-a|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001|Task-1|QA_A|MAPPED"
plan_owner_drift="CON-001|type-a|desc-a|owner-b|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001|Task-1|QA_A|MAPPED"
plan_unit_drift="CON-001|type-a|desc-a|owner-a|UNIT-2|SCOPE-P1U1-001|PF-001|TC-U1-001|Task-1|QA_A|MAPPED"

prd_base_key=$(build_prd_constraint_pairs "$prd_base")
prd_desc_key=$(build_prd_constraint_pairs "$prd_desc_drift")
prd_owner_key=$(build_prd_constraint_pairs "$prd_owner_drift")
prd_unit_key=$(build_prd_constraint_pairs "$prd_unit_drift")

plan_base_key=$(build_plan_constraint_pairs "$plan_base")
plan_desc_key=$(build_plan_constraint_pairs "$plan_desc_drift")
plan_owner_key=$(build_plan_constraint_pairs "$plan_owner_drift")
plan_unit_key=$(build_plan_constraint_pairs "$plan_unit_drift")

[ "$prd_base_key" != "$prd_desc_key" ] || { echo "prd description drift ignored" >&2; exit 11; }
[ "$prd_base_key" != "$prd_owner_key" ] || { echo "prd owner drift ignored" >&2; exit 12; }
[ "$prd_base_key" != "$prd_unit_key" ] || { echo "prd affected_unit drift ignored" >&2; exit 13; }
[ "$plan_base_key" != "$plan_desc_key" ] || { echo "plan description drift ignored" >&2; exit 21; }
[ "$plan_base_key" != "$plan_owner_key" ] || { echo "plan owner drift ignored" >&2; exit 22; }
[ "$plan_base_key" != "$plan_unit_key" ] || { echo "plan affected_unit drift ignored" >&2; exit 23; }
EOF
  } > "$tmp_script"

  if ! bash "$tmp_script" >/dev/null; then
    rm -f "$tmp_script"
    fail "${label}: constraint identity builder ignored description/owner/affected_unit drift"
  fi

  rm -f "$tmp_script"
}

assert_builder_tracks_constraint_identity "$TECH_LEAD_CHECK" "tech-lead completion_check"
assert_builder_tracks_constraint_identity "$PM_CHECK" "project-manager completion_check"

# shellcheck source=/dev/null
source "$COMMON_SH"

REGEX_LIKE_PAIR='CON-001|type-a|desc[1]|owner-a|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001'
DRIFTED_PAIR='CON-001|type-a|desc1|owner-a|UNIT-1|SCOPE-P1U1-001|PF-001|TC-U1-001'
ACCEPTANCE_REGEX_LIKE_PAIR='CON-001|[env/runtime/shared-service/compliance/rollout/preflight]|VERIFIED|[PF-001 / design.md#preflight-1]|[TC-U1-001 / N/A]'
ACCEPTANCE_DRIFTED_PAIR='CON-001|env/runtime/shared-service/compliance/rollout/preflight|VERIFIED|PF-001 / design.md#preflight-1|TC-U1-001 / N/A'

newline_list_contains_literal "$REGEX_LIKE_PAIR" "$REGEX_LIKE_PAIR" || fail "newline_list_contains_literal should preserve exact constraint pairs"
if newline_list_contains_literal "$DRIFTED_PAIR" "$REGEX_LIKE_PAIR"; then
  fail "newline_list_contains_literal should not treat constraint pairs as regex patterns"
fi
newline_list_contains_literal "$ACCEPTANCE_REGEX_LIKE_PAIR" "$ACCEPTANCE_REGEX_LIKE_PAIR" || fail "newline_list_contains_literal should preserve exact acceptance pairs"
if newline_list_contains_literal "$ACCEPTANCE_DRIFTED_PAIR" "$ACCEPTANCE_REGEX_LIKE_PAIR"; then
  fail "newline_list_contains_literal should not treat acceptance pairs as regex patterns"
fi

assert_file_contains "newline_list_contains_literal \"\\\$plan_constraint_pairs\" \"\\\$prd_pair\"" "$TECH_LEAD_CHECK"
assert_file_contains "newline_list_contains_literal \"\\\$prd_constraint_pairs\" \"\\\$plan_pair\"" "$TECH_LEAD_CHECK"
assert_file_contains "newline_list_contains_literal \"\\\$plan_constraint_pairs\" \"\\\$prd_pair\"" "$PM_CHECK"
assert_file_contains "newline_list_contains_literal \"\\\$prd_constraint_pairs\" \"\\\$plan_pair\"" "$PM_CHECK"
assert_file_contains "newline_list_contains_literal \"\\\$acceptance_constraint_pairs\" \"\\\$plan_pair\"" "$PM_CHECK"

echo "[PASS] constraint closure contract"
