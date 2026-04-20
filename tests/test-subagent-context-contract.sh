#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
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

# 非运行时文件必须直接删除，不能保留为 reference 噪音
for file in \
  "$ROOT/shared/reference/subagent-recovery-contract.md" \
  "$ROOT/shared/reference/context-noise-metrics.md" \
  "$ROOT/shared/reference/templates/fact-scan-template.md" \
  "$ROOT/shared/reference/templates/hypothesis-draft-template.md" \
  "$ROOT/shared/reference/templates/structure-draft-template.md" \
  "$ROOT/shared/reference/templates/synthesis-template.md" \
  "$ROOT/shared/reference/templates/metrics-log-template.md"
do
  [ ! -e "$file" ] || fail "unexpected retained runtime-noise file: ${file#"$ROOT"/}"
done

assert_no_subagent_chapter() {
  local file="$1"
  assert_absent '^[[:space:]]*#{2,3}[[:space:]]+子代理边界$' "$file"
}

extract_stage_block() {
  local stage="$1"
  awk -v stage="$stage" '
    $0 == "  - name: " stage { in_block=1 }
    in_block && $0 ~ /^  - name: / && $0 != "  - name: " stage { exit }
    in_block { print }
  ' "$ROOT/contracts/skill-chain.yaml"
}

assert_stage_has() {
  local stage="$1"
  local pattern="$2"
  local block
  block="$(extract_stage_block "$stage")"
  printf '%s\n' "$block" | rg -n "$pattern" >/dev/null 2>&1 || fail "missing stage pattern in ${stage}: $pattern"
}

assert_stage_absent() {
  local stage="$1"
  local pattern="$2"
  local block
  block="$(extract_stage_block "$stage")"
  if printf '%s\n' "$block" | rg -n "$pattern" >/dev/null 2>&1; then
    fail "unexpected stage pattern in ${stage}: $pattern"
  fi
}

for skill in design test-design tech-lead delivery-owner; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  assert_no_subagent_chapter "$skill_file"
  assert_absent '需要降噪时启用|必要时启用|复杂项目' "$skill_file"
done

assert_stage_absent 'delivery-owner' 'artifact: "phase-\{N\}/qa-report\.md"'
assert_present 'qa_report_producer: qa' "$ROOT/contracts/skill-chain.yaml"
assert_stage_absent 'design' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_stage_absent 'test-design' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_stage_absent 'tech-lead' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_stage_absent 'delivery-owner' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_absent 'metrics_log_template_ref' "$ROOT/contracts/skill-chain.yaml"

assert_present '主 Agent 保留职责' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present '主 Agent 保留' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_absent '冻结版本锚点|草稿回收记录|RECOVERED' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present '不消费未冻结草稿' "$ROOT/shared/skills/delivery-owner/SKILL.md"

assert_absent 'fact-scan-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROOT/shared/skills/design/references/runtime-fact-capture.md"
assert_present '输入边界' "$ROOT/shared/skills/design/references/runtime-fact-capture.md"
assert_present '证据锚点' "$ROOT/shared/skills/design/references/runtime-fact-capture.md"
assert_present '禁止越权项' "$ROOT/shared/skills/design/references/runtime-fact-capture.md"
assert_absent 'hypothesis-draft-template\.md|structure-draft-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_present 'decision_state.*已冻结' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_absent 'decision_state.*draft / frozen' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_absent 'structure-draft-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROOT/shared/skills/design/references/adr-spec.md"
assert_present '主 Agent.*转写' "$ROOT/shared/skills/design/references/adr-spec.md"
assert_present '不能把 draft 直接落为最终工件' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_present '主 Agent 负责收敛和冻结' "$ROOT/shared/skills/design/SKILL.md"
assert_present '由主 Agent 在冻结后转写' "$ROOT/shared/skills/design/SKILL.md"
assert_present '仍由主 Agent 转写' "$ROOT/shared/skills/design/SKILL.md"

assert_absent 'synthesis-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '派发 prompt 质量要点' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_absent 'Status Synthesis Agent|Evidence Synthesis Agent' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_absent 'status-synthesis|evidence-synthesis' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_absent '^\| Synthesis \|' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_absent '^[[:space:]]*##[[:space:]]+静默降噪$' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_absent 'Context Scan Agent' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_absent 'Problem Hypothesis Agent' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_absent 'sub agent' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_absent 'subagent' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_absent '子代理' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_present '候选线索' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_present '主 Agent 直接进入正常共创节奏' "$ROOT/shared/skills/product-director/references/conversation-guide.md"
assert_present '必须回到用户追问' "$ROOT/shared/skills/product-director/references/conversation-guide.md"

bash "$ROOT/tools/dev/validate-contracts.sh" >/tmp/org-validate-contracts.out 2>&1 || {
  cat /tmp/org-validate-contracts.out >&2
  fail "validate-contracts should pass"
}

echo "[PASS] subagent context contract"
