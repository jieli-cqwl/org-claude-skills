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
PRODUCT_CHECK="$ROOT/shared/skills/product/scripts/completion_check.sh"
TECH_LEAD_CHECK="$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"

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
grep -Fq "审查分级: {轻量, 标准, 完整, 未指定}" "$QA_TEMPLATE" || fail "qa template missing inherited grade option"
grep -Fq "执行范围: {full, 验证-A, 验证-B, 验证-C, 验证-D}" "$QA_TEMPLATE" || fail "qa template missing execution scope field"
grep -Fq "### QA_A UNIT 执行汇总" "$QA_TEMPLATE" || fail "qa template missing qa_a unit summary"
grep -Fq "### AC 追踪表" "$QA_TEMPLATE" || fail "qa template missing ac trace table"
grep -Fq '"grade":"{轻量, 标准, 完整, 未指定}"' "$QA_TEMPLATE" || fail "qa template metadata missing inherited grade option"
grep -Fq "QA_B（E2E 旅程） | {OK, ISSUE, N/A}（轻量/标准模式不执行）" "$QA_TEMPLATE" || fail "qa template missing standard N/A rule"
grep -Fq "QA_D（探索性测试） | {OK, ISSUE, N/A}（轻量/标准模式不执行）" "$QA_TEMPLATE" || fail "qa template missing full-only rule"
grep -Fq "if [ \"\$qa_grade\" = \"未指定\" ]; then" "$CHECK_SCRIPT" || fail "completion check should treat qa grade 未指定 as inherited from plan"

grep -Fq 'fresh proving command' "$PM_SKILL" || fail "project-manager skill missing fresh proving command requirement"
grep -Fq '完整输出' "$PM_SKILL" || fail "project-manager skill missing full output evidence requirement"
grep -Fq '不得用 Mock 验收替代' "$PM_SKILL" || fail "project-manager skill missing no-mock-final-acceptance rule"
grep -Fq 'proving_command' "$CR_TEMPLATE" || true
grep -Fq 'proving_command' "$PLAN_TEMPLATE" || fail "plan template should expose proving_command for downstream execution"
grep -Fq 'evidence_target' "$PLAN_TEMPLATE" || fail "plan template should expose evidence_target for downstream execution"
grep -Fq 'proving_command' "$ROOT/shared/skills/project-manager/references/templates/dev-report-template.md" || fail "dev-report template missing proving_command field"
grep -Fq 'evidence_target' "$ROOT/shared/skills/project-manager/references/templates/dev-report-template.md" || fail "dev-report template missing evidence_target field"
grep -Fq 'proving_command' "$ACCEPT_TEMPLATE" || fail "acceptance summary missing proving_command cross-check note"
grep -Fq 'evidence_target' "$ACCEPT_TEMPLATE" || fail "acceptance summary missing evidence_target cross-check note"

grep -Fq "仅汇总强门禁阶段；可选增强 \`REVIEW_C\` 不进入此表。" "$ACCEPT_TEMPLATE" || fail "acceptance summary missing REVIEW_C exclusion note"
if rg -n 'REVIEW_C' "$ACCEPT_TEMPLATE" >/tmp/org_pm_phase3_accept_reviewc.out 2>&1; then
  line_count="$(wc -l < /tmp/org_pm_phase3_accept_reviewc.out | tr -d ' ')"
  [ "$line_count" -eq 1 ] || fail "acceptance summary should only mention REVIEW_C in exclusion note"
fi
if grep -Fq "{MAPPED, VERIFIED, BLOCKED}" "$ACCEPT_TEMPLATE"; then
  fail "acceptance summary should not advertise BLOCKED as a normal plan status"
fi
if grep -Fq -- "- BLOCKED:" "$ACCEPT_TEMPLATE"; then
  fail "acceptance summary should not document BLOCKED as a shippable plan state"
fi

grep -Fq -- "- 标准: \`REVIEW_A + REVIEW_B + QA_A + QA_C\`" "$PLAN_TEMPLATE" || fail "plan template missing standard gate matrix"
grep -Fq -- "- \`REVIEW_C\` 仅作为可选增强审查，不进入 \`/project-manager\` 的强门禁判定" "$PLAN_TEMPLATE" || fail "plan template missing REVIEW_C boundary"
grep -Fq "| CON-001 |" "$PLAN_TEMPLATE" || fail "plan template missing zero-padded constraint id example"
grep -Fq "| [TC-U1-001 / N/A] |" "$PLAN_TEMPLATE" || fail "plan template missing N/A test_ref branch"
if grep -Fq -- "- BLOCKED:" "$PLAN_TEMPLATE"; then
  fail "plan template should not instruct users to keep BLOCKED rows in final mapping"
fi
grep -Fq "禁止在最终表中保留 \`BLOCKED\` 行" "$PLAN_TEMPLATE" || fail "plan template should explain BLOCKED rows must be resolved before final output"

grep -Fq "source \"\$(cd \"\$(dirname \"\$0\")\" && pwd)/phase3-grade-matrix.sh\"" "$CHECK_SCRIPT" || fail "completion check should source phase3 matrix"
grep -Fq "review_stage_lines=\$(phase3_required_review_stages \"\$plan_grade\")" "$CHECK_SCRIPT" || fail "completion check should use review matrix function"
grep -Fq "qa_stage_lines=\$(phase3_required_qa_stages \"\$plan_grade\")" "$CHECK_SCRIPT" || fail "completion check should use qa matrix function"
grep -Fq "if ! phase3_is_gate_stage \"\$check_item\"; then" "$CHECK_SCRIPT" || fail "completion check should validate waiver stages from matrix"
grep -Fq 'proving_command' "$CHECK_SCRIPT" || fail "completion check should validate proving_command fields"
grep -Fq 'evidence_target' "$CHECK_SCRIPT" || fail "completion check should validate evidence_target fields"
grep -Fq 'mock_boundary_note' "$CHECK_SCRIPT" || fail "completion check should validate mock boundary fields"
grep -Fq 'Fresh proving command' "$CHECK_SCRIPT" || fail "completion check should require fresh proving command output section"
grep -Fq "^CON-[0-9]{3,}$" "$PRODUCT_CHECK" || fail "product constraint id regex should require zero-padded ids"
grep -Fq "^CON-[0-9]{3,}$" "$TECH_LEAD_CHECK" || fail "tech-lead constraint id regex should require zero-padded ids"
grep -Fq "^CON-[0-9]{3,}$" "$CHECK_SCRIPT" || fail "project-manager constraint id regex should require zero-padded ids everywhere"
grep -Fq "normalized_test_ref" "$TECH_LEAD_CHECK" || fail "tech-lead should normalize test_ref before validation"
grep -Fq "normalized_test_ref" "$CHECK_SCRIPT" || fail "project-manager should normalize test_ref before validation"
grep -Fq "grep -qiE '^N/?A$'" "$TECH_LEAD_CHECK" || fail "tech-lead should allow N/A test_ref in constraint mapping"
grep -Fq "grep -qiE '^N/?A$'" "$CHECK_SCRIPT" || fail "project-manager should allow N/A test_ref in constraint mapping"
if rg -n '\bmapfile\b' "$CHECK_SCRIPT" >/tmp/org_pm_phase3_mapfile.out 2>&1; then
  cat /tmp/org_pm_phase3_mapfile.out >&2
  fail "completion check must stay compatible with bash 3.2 and should not use mapfile"
fi

grep -Fq '允许出现额外系统 skills' "$PM_SKILL" || fail "project-manager skill missing extra system skills note"
grep -Fq '允许存在额外系统 skills' "$PHASE3_DOC" || fail "phase3 dispatch missing extra system skills note"
grep -Fq '计划模式' "$PM_SKILL" || fail "project-manager skill missing planning mode support"
grep -Fq '探索优先' "$PM_SKILL" || fail "project-manager skill missing exploration-first mode"
grep -Fq "等待刷新后的 \`plan.md\`" "$PM_SKILL" || fail "project-manager skill missing replan pause rule"
grep -Fq '## 计划模式' "$PLAN_TEMPLATE" || fail "plan template missing planning mode section"
grep -Fq '## 再计划与解锁规则' "$PLAN_TEMPLATE" || fail "plan template missing replan section"
grep -Fq '## 计划修订记录' "$PLAN_TEMPLATE" || fail "plan template missing plan revision section"
grep -Fq '计划模式' "$TECH_LEAD_CHECK" || fail "tech-lead completion check missing planning mode validation"
grep -Fq '再计划与解锁规则' "$TECH_LEAD_CHECK" || fail "tech-lead completion check missing replan validation"
grep -Fq 'task_type' "$TECH_LEAD_CHECK" || fail "tech-lead completion check missing task_type validation"
grep -Fq 'unlock_condition' "$TECH_LEAD_CHECK" || fail "tech-lead completion check missing unlock condition validation"

echo "[PASS] project-manager phase3 contract"
