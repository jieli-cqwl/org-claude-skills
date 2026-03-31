#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
MATRIX="$ROOT/shared/skills/project-manager/scripts/phase3-grade-matrix.sh"
PM_SKILL="$ROOT/shared/skills/project-manager/SKILL.md"
PHASE3_DOC="$ROOT/shared/skills/project-manager/references/phase3-dispatch.md"
CR_TEMPLATE="$ROOT/shared/skills/project-manager/references/templates/code-review-report-template.md"
QA_TEMPLATE="$ROOT/shared/skills/project-manager/references/templates/qa-report-template.md"
ACCEPT_TEMPLATE="$ROOT/shared/skills/project-manager/references/templates/acceptance-summary-template.md"
PLAN_TEMPLATE="$ROOT/shared/skills/tech-lead/references/templates/plan-template.md"
CHECK_SCRIPT="$ROOT/shared/skills/project-manager/scripts/completion_check.sh"
RUNTIME_SOP="$ROOT/docs/runtime-acceptance-sop.md"
RELEASE_CHECKLIST="$ROOT/docs/release-checklist.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

# shellcheck source=/dev/null
source "$MATRIX"

assert_lines() {
  local expected="$1"
  shift
  local got
  got="$(printf '%s\n' "$@")"
  [ "$got" = "$expected" ] || fail "unexpected matrix lines: expected [$expected], got [$got]"
}

assert_lines "REVIEW_A" "$(phase3_required_review_stages 轻量)"
assert_lines $'REVIEW_A\nREVIEW_B' "$(phase3_required_review_stages 标准)"
assert_lines $'REVIEW_A\nREVIEW_B' "$(phase3_required_review_stages 完整)"
assert_lines "QA_A" "$(phase3_required_qa_stages 轻量)"
assert_lines $'QA_A\nQA_C' "$(phase3_required_qa_stages 标准)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(phase3_required_qa_stages 完整)"

phase3_optional_review_stage | grep -Fxq 'REVIEW_C' || fail "optional review stage should be REVIEW_C"
phase3_is_gate_stage REVIEW_A || fail "REVIEW_A should be a gate stage"
phase3_is_gate_stage QA_D || fail "QA_D should be a gate stage"
if phase3_is_gate_stage REVIEW_C; then
  fail "REVIEW_C should not be treated as a gate stage"
fi
phase3_is_non_waivable_stage REVIEW_A || fail "REVIEW_A should be non-waivable"
phase3_is_non_waivable_stage QA_A || fail "QA_A should be non-waivable"
if phase3_is_non_waivable_stage REVIEW_B; then
  fail "REVIEW_B should remain waivable"
fi

grep -Fq -- "- 轻量：\`REVIEW_A + QA_A\`" "$PM_SKILL" || fail "project-manager skill missing lightweight matrix"
grep -Fq -- "- 标准：\`REVIEW_A + REVIEW_B + QA_A + QA_C\`" "$PM_SKILL" || fail "project-manager skill missing standard matrix"
grep -Fq -- "- 完整：\`REVIEW_A + REVIEW_B + QA_A + QA_B + QA_C + QA_D\`" "$PM_SKILL" || fail "project-manager skill missing full matrix"
grep -Fq -- "\`REVIEW_C\` 仅作为可选增强审查" "$PM_SKILL" || fail "project-manager skill missing REVIEW_C boundary"

grep -Fq "| 轻量 | \`REVIEW_A\` | \`QA_A\` | 最小强门禁 |" "$PHASE3_DOC" || fail "phase3 dispatch missing lightweight row"
grep -Fq "| 标准 | \`REVIEW_A + REVIEW_B\` | \`QA_A + QA_C\` | 保留基础 AC + 回归防线 |" "$PHASE3_DOC" || fail "phase3 dispatch missing standard row"
grep -Fq "| 完整 | \`REVIEW_A + REVIEW_B\` | \`QA_A + QA_B + QA_C + QA_D\` | 覆盖完整用户旅程与探索性验证 |" "$PHASE3_DOC" || fail "phase3 dispatch missing full row"
grep -Fq "## 可选增强审查 — REVIEW_C（不纳入强门禁）" "$PHASE3_DOC" || fail "phase3 dispatch missing optional REVIEW_C section"

grep -Fq "强门禁仅跟踪 \`REVIEW_A / REVIEW_B\`。" "$CR_TEMPLATE" || fail "code-review template missing strong gate note"
grep -Fq '"review":{"REVIEW_A"' "$CR_TEMPLATE" || fail "code-review template metadata missing REVIEW_A"
grep -Fq '"REVIEW_B"' "$CR_TEMPLATE" || fail "code-review template metadata missing REVIEW_B"
if grep -Fq '"REVIEW_C"' "$CR_TEMPLATE"; then
  fail "code-review template metadata should not include REVIEW_C"
fi

grep -Fq "强门禁矩阵：轻量=\`QA_A\`；标准=\`QA_A + QA_C\`；完整=\`QA_A + QA_B + QA_C + QA_D\`。" "$QA_TEMPLATE" || fail "qa template missing gate matrix note"
grep -Fq "QA_B（E2E 旅程） | {OK, ISSUE, N/A}（轻量/标准模式不执行）" "$QA_TEMPLATE" || fail "qa template missing standard N/A rule"
grep -Fq "QA_D（探索性测试） | {OK, ISSUE, N/A}（轻量/标准模式不执行）" "$QA_TEMPLATE" || fail "qa template missing full-only rule"

grep -Fq "仅汇总强门禁阶段；可选增强 \`REVIEW_C\` 不进入此表。" "$ACCEPT_TEMPLATE" || fail "acceptance summary missing REVIEW_C exclusion note"
if rg -n 'REVIEW_C' "$ACCEPT_TEMPLATE" >/tmp/org_pm_phase3_accept_reviewc.out 2>&1; then
  line_count="$(wc -l < /tmp/org_pm_phase3_accept_reviewc.out | tr -d ' ')"
  [ "$line_count" -eq 1 ] || fail "acceptance summary should only mention REVIEW_C in exclusion note"
fi

grep -Fq -- "- 标准: \`REVIEW_A + REVIEW_B + QA_A + QA_C\`" "$PLAN_TEMPLATE" || fail "plan template missing standard gate matrix"
grep -Fq -- "- \`REVIEW_C\` 仅作为可选增强审查，不进入 \`/project-manager\` 的强门禁判定" "$PLAN_TEMPLATE" || fail "plan template missing REVIEW_C boundary"

grep -Fq "source \"\$(cd \"\$(dirname \"\$0\")\" && pwd)/phase3-grade-matrix.sh\"" "$CHECK_SCRIPT" || fail "completion check should source phase3 matrix"
grep -Fq "review_stage_lines=\$(phase3_required_review_stages \"\$plan_grade\")" "$CHECK_SCRIPT" || fail "completion check should use review matrix function"
grep -Fq "qa_stage_lines=\$(phase3_required_qa_stages \"\$plan_grade\")" "$CHECK_SCRIPT" || fail "completion check should use qa matrix function"
grep -Fq "if ! phase3_is_gate_stage \"\$check_item\"; then" "$CHECK_SCRIPT" || fail "completion check should validate waiver stages from matrix"
if rg -n '\bmapfile\b' "$CHECK_SCRIPT" >/tmp/org_pm_phase3_mapfile.out 2>&1; then
  cat /tmp/org_pm_phase3_mapfile.out >&2
  fail "completion check must stay compatible with bash 3.2 and should not use mapfile"
fi

grep -Fq '允许出现额外系统 skills' "$RUNTIME_SOP" || fail "runtime acceptance SOP missing extra system skills note"
grep -Fq '允许存在额外系统 skills' "$RELEASE_CHECKLIST" || fail "release checklist missing extra system skills note"

echo "[PASS] project-manager phase3 contract"
