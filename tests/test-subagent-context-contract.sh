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

# 共享契约只在中央 reference 保持真源，不再要求每个 SKILL 重复 prose
for field in agent_kind current_judgment_type decision_state input_boundary evidence_anchor forbidden_action unresolved_item; do
  assert_present "$field" "$ROOT/shared/reference/subagent-recovery-contract.md"
done

for field in subagent_policy max_subagents recovery_contract_ref metrics_ref allowed_subagent_kinds; do
  assert_present "$field" "$ROOT/contracts/skill-chain.yaml"
done

for metric in M1 M2 M3 M4 M5 M6; do
  assert_present "$metric" "$ROOT/shared/reference/context-noise-metrics.md"
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

for skill in product design test-design tech-lead delivery-owner; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  assert_no_subagent_chapter "$skill_file"
  assert_absent '需要降噪时启用|必要时启用|复杂项目' "$skill_file"
  assert_stage_has "$skill" 'subagent_policy:'
  assert_stage_has "$skill" 'max_subagents:'
  assert_stage_has "$skill" 'recovery_contract_ref:'
  assert_stage_has "$skill" 'metrics_ref:'
  assert_stage_has "$skill" 'allowed_subagent_kinds:'
done

assert_stage_absent 'delivery-owner' 'artifact: "phase-\{N\}/qa-report\.md"'
assert_present 'qa_report_producer: qa' "$ROOT/contracts/skill-chain.yaml"

assert_present '^\| `agent_kind` \|' "$ROOT/shared/reference/templates/fact-scan-template.md"
assert_present '^\| `current_judgment_type` \|' "$ROOT/shared/reference/templates/fact-scan-template.md"
assert_present '^\| `decision_state` \|' "$ROOT/shared/reference/templates/fact-scan-template.md"
assert_present '^\| `input_boundary` \|' "$ROOT/shared/reference/templates/fact-scan-template.md"
assert_present '^\| `evidence_anchor` \|' "$ROOT/shared/reference/templates/fact-scan-template.md"
assert_present '^\| `forbidden_action` \|' "$ROOT/shared/reference/templates/fact-scan-template.md"
assert_present '^\| `unresolved_item` \|' "$ROOT/shared/reference/templates/fact-scan-template.md"

assert_present '^\| `agent_kind` \|' "$ROOT/shared/reference/templates/hypothesis-draft-template.md"
assert_present '^\| `current_judgment_type` \|' "$ROOT/shared/reference/templates/hypothesis-draft-template.md"
assert_present '^\| `decision_state` \|' "$ROOT/shared/reference/templates/hypothesis-draft-template.md"
assert_present '^\| `input_boundary` \|' "$ROOT/shared/reference/templates/hypothesis-draft-template.md"
assert_present '^\| `evidence_anchor` \|' "$ROOT/shared/reference/templates/hypothesis-draft-template.md"
assert_present '^\| `forbidden_action` \|' "$ROOT/shared/reference/templates/hypothesis-draft-template.md"
assert_present '^\| `unresolved_item` \|' "$ROOT/shared/reference/templates/hypothesis-draft-template.md"

assert_present '^\| `agent_kind` \|' "$ROOT/shared/reference/templates/structure-draft-template.md"
assert_present '^\| `current_judgment_type` \|' "$ROOT/shared/reference/templates/structure-draft-template.md"
assert_present '^\| `decision_state` \|' "$ROOT/shared/reference/templates/structure-draft-template.md"
assert_present '^\| `input_boundary` \|' "$ROOT/shared/reference/templates/structure-draft-template.md"
assert_present '^\| `evidence_anchor` \|' "$ROOT/shared/reference/templates/structure-draft-template.md"
assert_present '^\| `forbidden_action` \|' "$ROOT/shared/reference/templates/structure-draft-template.md"
assert_present '^\| `unresolved_item` \|' "$ROOT/shared/reference/templates/structure-draft-template.md"

assert_present '^\| `agent_kind` \|' "$ROOT/shared/reference/templates/synthesis-template.md"
assert_present '^\| `current_judgment_type` \|' "$ROOT/shared/reference/templates/synthesis-template.md"
assert_present '^\| `decision_state` \|' "$ROOT/shared/reference/templates/synthesis-template.md"
assert_present '^\| `input_boundary` \|' "$ROOT/shared/reference/templates/synthesis-template.md"
assert_present '^\| `evidence_anchor` \|' "$ROOT/shared/reference/templates/synthesis-template.md"
assert_present '^\| `forbidden_action` \|' "$ROOT/shared/reference/templates/synthesis-template.md"
assert_present '^\| `unresolved_item` \|' "$ROOT/shared/reference/templates/synthesis-template.md"
assert_absent 'accepted_candidate' "$ROOT/shared/reference/templates/synthesis-template.md"

assert_present 'M1' "$ROOT/shared/reference/templates/metrics-log-template.md"
assert_present 'M6' "$ROOT/shared/reference/templates/metrics-log-template.md"
assert_present '采集人' "$ROOT/shared/reference/templates/metrics-log-template.md"
assert_present 'M1 / M2' "$ROOT/shared/reference/templates/metrics-log-template.md"
assert_present 'M3 / M4' "$ROOT/shared/reference/templates/metrics-log-template.md"
assert_present 'M5 = 0' "$ROOT/shared/reference/templates/metrics-log-template.md"
assert_present '少于 `3` 个样本' "$ROOT/shared/reference/templates/metrics-log-template.md"
assert_present 'metrics_log_template_ref' "$ROOT/contracts/skill-chain.yaml"
assert_present '\./templates/metrics-log-template\.md' "$ROOT/shared/reference/context-noise-metrics.md"

assert_present '主 Agent 保留职责' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present '主 Agent 保留' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present '冻结版本锚点' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present '不消费未冻结草稿' "$ROOT/shared/skills/delivery-owner/SKILL.md"

assert_present 'fact-scan-template\.md' "$ROOT/shared/skills/design/references/runtime-fact-capture.md"
assert_present 'hypothesis-draft-template\.md' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_present 'decision_state.*已冻结' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_absent 'decision_state.*draft / frozen' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_present 'structure-draft-template\.md' "$ROOT/shared/skills/design/references/adr-spec.md"
assert_present '主 Agent.*转写' "$ROOT/shared/skills/design/references/adr-spec.md"
assert_present '不能把 draft schema 直接落为最终工件' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_present '主 Agent 负责收敛和冻结' "$ROOT/shared/skills/design/SKILL.md"
assert_present '由主 Agent 在冻结后转写' "$ROOT/shared/skills/design/SKILL.md"
assert_present '仍由主 Agent 转写' "$ROOT/shared/skills/design/SKILL.md"

assert_present 'synthesis-template\.md' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_absent '^[[:space:]]*##[[:space:]]+静默降噪$' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_absent '明确根问题、范围或成功标准' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_absent 'Context Scan Agent' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_absent 'Problem Hypothesis Agent' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_absent 'sub agent' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_absent 'subagent' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_absent '子代理' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_present '候选线索' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_present '主 Agent 继续问用户' "$ROOT/shared/skills/product/references/conversation-guide.md"
assert_present '必须回到用户追问' "$ROOT/shared/skills/product/references/conversation-guide.md"

bash "$ROOT/tools/dev/validate-contracts.sh" >/tmp/org-validate-contracts.out 2>&1 || {
  cat /tmp/org-validate-contracts.out >&2
  fail "validate-contracts should pass"
}

echo "[PASS] subagent context contract"
