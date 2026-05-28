#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MANAGER_BRIEF="$ROOT/shared/skills/product-manager/projections/brief-template.md"
MANAGER_PHASE="$ROOT/shared/skills/product-manager/projections/phase-prd-template.md"
MANAGER_REVIEW="$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md"
DIRECTOR_BRIEF_JSON="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
MANAGER_BRIEF_JSON="$ROOT/shared/skills/product-manager/templates/brief.template.json"
MANAGER_PHASE_JSON="$ROOT/shared/skills/product-manager/templates/phase-prd.template.json"
MANAGER_UNIT_JSON="$ROOT/shared/skills/product-manager/templates/unit-definition.template.json"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Eq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern '$pattern' in $file"
  fi
}

assert_line_count_at_most() {
  local max="$1" file="$2"
  local actual
  actual="$(wc -l < "$file" | tr -d ' ')"
  [ "$actual" -le "$max" ] || fail "$file has $actual lines; expected <= $max"
}

assert_rule_like_count_at_most() {
  local max="$1" file="$2"
  local actual
  actual="$({ grep -En '必须|不得|禁止|仅在|只允许|不要|若|状态枚举|D-G1|lock|冻结|通过后|authoritative' "$file" || true; } | wc -l | tr -d ' ')"
  [ "$actual" -le "$max" ] || fail "$file has $actual rule-like lines; expected <= $max"
}

for file in \
  "$MANAGER_BRIEF" \
  "$MANAGER_PHASE" \
  "$MANAGER_REVIEW" \
  "$DIRECTOR_BRIEF_JSON" \
  "$DIRECTOR_PHASE_JSON" \
  "$MANAGER_BRIEF_JSON" \
  "$MANAGER_PHASE_JSON" \
  "$MANAGER_UNIT_JSON"; do
  assert_file "$file"
done

if [ -d "$ROOT/shared/skills/product-director/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi

for file in "$DIRECTOR_BRIEF_JSON" "$DIRECTOR_PHASE_JSON" "$MANAGER_BRIEF_JSON" "$MANAGER_PHASE_JSON" "$MANAGER_UNIT_JSON"; do
  assert_absent 'runtime control decisions|canonical-only runtime control|standard-chain operators|migrate standard-chain|cutover readiness|foundation registry|legacy phase migration|standard-chain canonical planning|downstream skills consume canonical JSON' "$file"
done

assert_absent '"review_conclusion"[[:space:]]*:' "$MANAGER_BRIEF_JSON"
assert_absent '"delivery_confirmation"[[:space:]]*:' "$MANAGER_BRIEF_JSON"
assert_absent '"review_conclusion"[[:space:]]*:' "$MANAGER_PHASE_JSON"
assert_absent 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|agent-team://.*reviewer/R2|CONFIRMATION' "$MANAGER_BRIEF_JSON"
assert_absent 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|agent-team://.*reviewer/R2|CONFIRMATION' "$MANAGER_PHASE_JSON"

jq -e '
  .artifact_type == "brief"
  and .producer == "product-director"
  and (.authoritative_fields | index("$.director_confirmation"))
  and .director_confirmation.locked_fields
  and all(.delivery_plan[]; .iteration_timebox_days == 14)
  and all(.director_confirmation.locked_fields.delivery_plan[]; .iteration_timebox_days == 14)
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
  and (.delivery_confirmation? | not)
' "$DIRECTOR_BRIEF_JSON" >/dev/null || fail "director brief JSON template must define canonical Director handoff envelope"
jq -e '
  .artifact_type == "phase-prd"
  and .producer == "product-director"
  and (.authoritative_fields | index("$.director_confirmation"))
  and .director_confirmation.locked_fields
  and .phase_goal
  and .entry_conditions
  and .exit_conditions
  and (.unit_index? | not)
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
' "$DIRECTOR_PHASE_JSON" >/dev/null || fail "director phase JSON template must define canonical Director handoff envelope"

assert_absent 'UX-0[0-9]|以上为起始项|按产品实际情况增删|分页规范|敏感信息.*脱敏|前端控制|后端控制|页面功能[[:space:]]*\\|[[:space:]]*各模块入口|表单校验[[:space:]]*\\|[[:space:]]*必填项校验|安全控制[[:space:]]*\\|[[:space:]]*敏感字段|端：前端 / 后端 / 全栈' "$MANAGER_PHASE"

assert_line_count_at_most 115 "$MANAGER_BRIEF"
assert_line_count_at_most 80 "$MANAGER_REVIEW"
assert_rule_like_count_at_most 6 "$MANAGER_BRIEF"
assert_rule_like_count_at_most 4 "$MANAGER_REVIEW"

echo "[PASS] product template purity contract"
