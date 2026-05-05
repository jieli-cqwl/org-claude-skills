#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/test-design"
HISTORY_DIR="$ROOT/shared/skills/test-design-h"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: ${1#"$ROOT"/}"
}

assert_absent() {
  local pattern="$1" path="$2"
  if grep -R -n -E "$pattern" "$path" >/tmp/test_design_clean_resource.out 2>&1; then
    cat /tmp/test_design_clean_resource.out >&2
    fail "unexpected pattern under ${path#"$ROOT"/}: $pattern"
  fi
}

assert_present() {
  local pattern="$1" file="$2"
  grep -E "$pattern" "$file" >/dev/null || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_file "$SKILL_DIR/SKILL.md"
assert_file "$SKILL_DIR/references/methodology.md"
assert_file "$SKILL_DIR/references/test-obligation-shaping.md"
assert_file "$SKILL_DIR/references/specialty-test-design.md"
assert_file "$SKILL_DIR/references/testdesign-reviewer-prompt.md"
assert_file "$SKILL_DIR/references/testdesign-product-reviewer-prompt.md"
assert_file "$SKILL_DIR/references/testdesign-arch-reviewer-prompt.md"
assert_file "$SKILL_DIR/scripts/preflight_check.sh"
assert_file "$SKILL_DIR/scripts/completion_check.sh"
assert_file "$SKILL_DIR/contracts/test-cases.schema.json"
assert_file "$SKILL_DIR/templates/test-cases.template.json"
assert_file "$SKILL_DIR/projections/test-cases-template.md"

for removed in \
  integration-test-methodology.md \
  contract-test-methodology.md \
  security-test-methodology.md \
  performance-test-methodology.md; do
  [ ! -e "$SKILL_DIR/references/$removed" ] || fail "old specialty reference still exists: $removed"
done

assert_absent '^(>|[[:space:]])*(Trigger|Read|Expect|Consume|Sync):' "$SKILL_DIR/references"
assert_absent '产品是一等真源|下游消费者成功标准|输入准入|主 Agent|主 agent|本 eval 不要求实际写文件|不要求实际写文件|要求先执行 design|要求先回到 design' "$SKILL_DIR"
assert_absent 'references/methodology\.md.*Trigger:.*Read:.*Expect:.*Consume:.*Evidence:.*Sync:' "$SKILL_DIR/SKILL.md"
assert_absent '引用锚点合同|execution_basis_ref|用户裁决记录|all columns required' "$SKILL_DIR/projections/test-cases-template.md"
assert_absent '你的下游消费者是|Bash 使用边界|人类投影视图只用于阅读|完成前确认|证明命令|hook-payload|准入失败时按|回 /product-manager|回 /design|## 主流程|\*\*TD-|completion_check\.sh <|写入并运行 gate' "$SKILL_DIR/SKILL.md"

assert_present 'references/methodology\.md' "$SKILL_DIR/SKILL.md"
assert_present 'references/test-obligation-shaping\.md' "$SKILL_DIR/SKILL.md"
assert_present 'references/specialty-test-design\.md' "$SKILL_DIR/SKILL.md"
assert_present 'references/testdesign-reviewer-prompt\.md' "$SKILL_DIR/SKILL.md"
assert_present '你复核 findings' "$SKILL_DIR/SKILL.md"
assert_present '事实输入仅限 canonical JSON' "$SKILL_DIR/SKILL.md"
assert_present '^## 流程细节$' "$SKILL_DIR/SKILL.md"
assert_present '等待用户裁决' "$SKILL_DIR/SKILL.md"
assert_present '相邻 Skill 只作为可选下一步，是否执行由用户裁决' "$SKILL_DIR/SKILL.md"
assert_present '记录最终裁决、修正依据和未承接风险' "$SKILL_DIR/SKILL.md"
assert_present '写入并等待 hooks gate' "$SKILL_DIR/SKILL.md"
assert_present 'hooks completion gate 未返回 BLOCKED' "$SKILL_DIR/SKILL.md"
assert_present '3 视角×max10轮' "$SKILL_DIR/SKILL.md"
assert_present 'R2 / CONFIRMATION' "$SKILL_DIR/SKILL.md"
assert_present '只重提 FAIL 视角' "$SKILL_DIR/SKILL.md"
assert_present '连续 2 轮 FAIL 数不减少' "$SKILL_DIR/SKILL.md"
assert_present '同一 issue 连续 3 轮未关闭' "$SKILL_DIR/SKILL.md"
assert_present 'review_conclusion\.convergence_evidence\[\]' "$SKILL_DIR/SKILL.md"
assert_present 'Phase 级收口时已运行 `python3 tools/community/validate_standard_chain_phase\.py --phase-dir "\$PHASE_DIR"`' "$SKILL_DIR/SKILL.md"
for section in \
  test_analysis \
  traceability_matrix \
  ac_coverage_matrix \
  equivalence_matrix \
  test_cases \
  qa_handoff_contract \
  unit_coverage_view \
  design_gap_report \
  cross_unit_obligations \
  special_test_triggers \
  review_conclusion \
  issue_ledger; do
  assert_present "$section" "$SKILL_DIR/SKILL.md"
  if [ "$section" = "issue_ledger" ]; then
    assert_present "^### $section /" "$SKILL_DIR/projections/test-cases-template.md"
  else
    assert_present "^## $section /" "$SKILL_DIR/projections/test-cases-template.md"
  fi
done

if diff -qr "$SKILL_DIR" "$HISTORY_DIR" >/tmp/test_design_history_diff.out 2>&1; then
  fail "active test-design should not be isomorphic to test-design-h"
fi

printf '[PASS] test-design clean resource\n'
