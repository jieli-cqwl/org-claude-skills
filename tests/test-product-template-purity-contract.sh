#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_BRIEF="$ROOT/shared/skills/product-director/references/templates/brief-template.md"
DIRECTOR_PHASE="$ROOT/shared/skills/product-director/references/templates/phase-prd-template.md"
MANAGER_BRIEF="$ROOT/shared/skills/product-manager/projections/brief-template.md"
MANAGER_PHASE="$ROOT/shared/skills/product-manager/projections/phase-prd-template.md"
MANAGER_REVIEW="$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md"
EVIDENCE_PLAN="$ROOT/docs/archive/product-role-split-20260414/evidence-and-eval-plan.md"
DEEP_REPORT="$ROOT/docs/archive/product-role-split-20260414/deep-validation-report.md"

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
  actual="$({ grep -En '必须|不得|禁止|仅在|只允许|不要|若|状态枚举|D-G1|M-G1|lock|冻结|通过后|authoritative' "$file" || true; } | wc -l | tr -d ' ')"
  [ "$actual" -le "$max" ] || fail "$file has $actual rule-like lines; expected <= $max"
}

for file in "$DIRECTOR_BRIEF" "$DIRECTOR_PHASE" "$MANAGER_BRIEF" "$MANAGER_PHASE" "$MANAGER_REVIEW"; do
  assert_file "$file"
done

assert_absent '^## MVP 最小闭环说明$' "$DIRECTOR_BRIEF"
assert_absent '^## 交付确认$' "$DIRECTOR_BRIEF"
assert_absent 'UNIT-X|UNIT-Y|UNIT-Z|优先级|依赖|定义文件|交付确认|M-G1' "$DIRECTOR_BRIEF"
assert_absent '优先级|依赖|定义文件|PM 只可补充' "$DIRECTOR_PHASE"

assert_present '^## MVP 最小闭环说明$' "$MANAGER_BRIEF"
assert_present '^## 交付确认$' "$MANAGER_BRIEF"
assert_present '^## 最终结论$' "$MANAGER_REVIEW"
assert_present '^## 审查汇总$' "$MANAGER_REVIEW"
assert_present '^## 审查问题台账$' "$MANAGER_REVIEW"
assert_present '^## 收敛轮次摘要$' "$MANAGER_REVIEW"
assert_present '^## 用户裁决记录$' "$MANAGER_REVIEW"
assert_present '^## 未决阻断$' "$MANAGER_REVIEW"

assert_line_count_at_most 125 "$DIRECTOR_BRIEF"
assert_line_count_at_most 115 "$MANAGER_BRIEF"
assert_line_count_at_most 80 "$MANAGER_REVIEW"
assert_rule_like_count_at_most 4 "$DIRECTOR_BRIEF"
assert_rule_like_count_at_most 6 "$MANAGER_BRIEF"
assert_rule_like_count_at_most 4 "$MANAGER_REVIEW"

assert_file "$EVIDENCE_PLAN"
assert_absent '为什么.*更强|已证明.*最佳实践|完全正确|共享 playbook|shared playbook' "$EVIDENCE_PLAN"

if [ -f "$DEEP_REPORT" ]; then
  assert_absent '为什么.*更强|已证明.*最佳实践|完全正确|共享 playbook|shared playbook' "$DEEP_REPORT"
  assert_present '证据边界|Known Limitations|Scorecard|scorecard' "$DEEP_REPORT"
fi

echo "[PASS] product template purity contract"
