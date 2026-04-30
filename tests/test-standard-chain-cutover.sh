#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/t6_cutover_absent.out 2>&1; then
    cat /tmp/t6_cutover_absent.out >&2
    fail "unexpected legacy pattern in $file: $pattern"
  fi
}

assert_present 'brief.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/phase-prd.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/design.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/plan.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/tasks.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/unit-\{N\}/tasks/\{task_id\}/developer-report.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/unit-\{N\}/tasks/\{task_id\}/verify-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/qa-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/delivery-state.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/artifact-registry.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'scope registry' "$ROOT/contracts/standard-chain.yaml"
assert_present 'worklog.md' "$ROOT/contracts/standard-chain.yaml"
assert_present 'canonical:' "$ROOT/contracts/standard-chain.yaml"
assert_present 'name: consistency-auditor' "$ROOT/contracts/standard-chain.yaml"
assert_present 'position: sidecar' "$ROOT/contracts/standard-chain.yaml"
assert_present 'decision_authority: advisory_only' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/consistency-audit-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/fix-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/signoff-package.json' "$ROOT/contracts/standard-chain.yaml"
assert_absent 'brief.md|prd.md|design.md|plan.md|qa-report.md|developer-report-Task-N.md|acceptance-summary.md|product-manager-review.md|legacy_projection' "$ROOT/contracts/standard-chain.yaml"
assert_absent 'gate_escalation' "$ROOT/contracts/standard-chain.yaml"

assert_present 'brief.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'phase-prd.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'design.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'plan.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'tasks.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'artifact-registry.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'test-cases.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'developer-report.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_absent 'brief.md|prd.md|qa-report.md|dev-report.md' "$ROOT/shared/protocols/phase-selection-protocol.md"

assert_present 'phase-prd.json' "$ROOT/shared/skills/product-director/references/phase-splitting-guide.md"
assert_present 'phase-prd.json' "$ROOT/shared/skills/product-manager/SKILL.md"
assert_present 'UNIT-\*\.json' "$ROOT/shared/skills/product-manager/references/output-contract.md"

assert_present 'shared/skills/product-director/templates/brief.template.json' "$ROOT/shared/skills/product-director/references/output-contract.md"
assert_present 'shared/skills/product-manager/templates/brief.template.json' "$ROOT/shared/skills/product-manager/references/output-contract.md"
assert_present 'shared/skills/design/templates/design.template.json' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'shared/skills/test-design/templates/test-cases.template.json' "$ROOT/shared/skills/test-design/SKILL.md"
assert_present 'shared/skills/tech-lead/templates/plan.template.json' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present 'shared/skills/developer/templates/developer-report.template.json' "$ROOT/shared/skills/developer/SKILL.md"
assert_present 'shared/skills/review/templates/code-review-result.template.json' "$ROOT/shared/skills/review/SKILL.md"
assert_present 'shared/skills/verify/templates/verify-result.template.json' "$ROOT/shared/skills/verify/SKILL.md"
assert_present 'shared/skills/qa/templates/qa-result.template.json' "$ROOT/shared/skills/qa/SKILL.md"
assert_present 'shared/skills/delivery-owner/templates/signoff-package.template.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'fix-result.json' "$ROOT/shared/skills/fix/SKILL.md"

assert_present 'validate_canonical_schema.py' "$ROOT/shared/skills/product-director/references/output-contract.md"
assert_present '不使用 `validate_standard_chain_phase.py --phase-dir` 作为 Director 完成证明' "$ROOT/shared/skills/product-director/references/output-contract.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/product-manager/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/test-design/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present 'traceability_matrix' "$ROOT/shared/skills/test-design/SKILL.md"
assert_present 'cross_unit_obligations' "$ROOT/shared/skills/test-design/projections/test-cases-template.md"
assert_present 'assertion_target' "$ROOT/shared/skills/developer/SKILL.md"
assert_present 'qa_handoff_contract' "$ROOT/shared/skills/delivery-owner/SKILL.md"
for design_prompt in \
  "$ROOT/shared/skills/design/references/design-reviewer-prompt.md" \
  "$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md" \
  "$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"
do
  assert_present 'candidate_design_json' "$design_prompt"
  assert_absent '最终冻结工件|final design|design\.json#[A-Za-z_]|design\.json\.[A-Za-z_]' "$design_prompt"
  assert_absent 'design/MOD-\*|ADR-\*|design\.json\.review_conclusion|\bADR\b|MOD-[0-9]|brief\.md|prd\.md|UNIT-\*\.md|test-cases\.md' "$design_prompt"
done
for design_prompt in \
  "$ROOT/shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md" \
  "$ROOT/shared/skills/test-design/references/methodology.md"
do
  assert_present 'canonical `design.json`' "$design_prompt"
  assert_absent 'design/MOD-\*|ADR-\*|design\.json\.review_conclusion|\bADR\b|MOD-[0-9]|brief\.md|prd\.md|UNIT-\*\.md|test-cases\.md' "$design_prompt"
done
assert_absent 'artifact-registry.json.*只用于理解 AC|存在性、active 状态和引用解析由前置脚本或 gate 判定' "$ROOT/shared/skills/developer/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/review/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/verify/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/qa/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
for standard_skill in \
  "$ROOT/shared/skills/product-director/SKILL.md" \
  "$ROOT/shared/skills/product-manager/SKILL.md" \
  "$ROOT/shared/skills/tech-lead/SKILL.md" \
  "$ROOT/shared/skills/test-design/SKILL.md" \
  "$ROOT/shared/skills/verify/SKILL.md" \
  "$ROOT/shared/skills/qa/SKILL.md" \
  "$ROOT/shared/skills/delivery-owner/SKILL.md" \
  "$ROOT/shared/skills/fix/SKILL.md" \
  "$ROOT/shared/skills/consistency-audit/SKILL.md"
do
  assert_present 'scope registry' "$standard_skill"
  assert_present 'worklog.md' "$standard_skill"
  assert_present 'canonical:' "$standard_skill"
done

assert_absent 'scope registry|worklog\.md|active-doc-scope|artifact-registry' "$ROOT/shared/skills/design/SKILL.md"
assert_absent 'scope registry|worklog\.md|canonical: active refs' "$ROOT/shared/skills/developer/SKILL.md"

for agent_contract in "$ROOT/shared/agents"/*.md
do
  assert_absent '^# Step Contract$|^运行时边界：|^输入：|^输出：|^scope（可选）|^要求：|^阻断条件：' "$agent_contract"
  assert_absent '\{work_dir\}|\{phase_dir\}|docs/\{feature\}|developer-report\.json|verify-result\.json|qa-result\.json|code-review-result\.json|test-cases\.json|plan\.json|design\.json|brief\.json|phase-prd\.json|UNIT-\*\.json|MOD-\*\.md|ADR-\*\.md' "$agent_contract"
  assert_absent '下文若仍出现 legacy 名称' "$agent_contract"
  assert_absent '不再直接依赖旧 `md` 工件' "$agent_contract"
  assert_absent '不再把旧 `md` 章节当作控制输入' "$agent_contract"
done

assert_present '^你是 designer。' "$ROOT/shared/agents/designer.md"
assert_present '^你是 tech-lead。' "$ROOT/shared/agents/tech-lead.md"
assert_present '评审设计可执行性' "$ROOT/shared/agents/tech-lead.md"
assert_present '拆分任务批次' "$ROOT/shared/agents/tech-lead.md"
assert_present '^你是 test-designer。' "$ROOT/shared/agents/test-designer.md"
assert_present '^你是 developer。' "$ROOT/shared/agents/developer.md"
assert_present '单个 Task' "$ROOT/shared/agents/developer.md"
assert_present '^你是 code-reviewer。' "$ROOT/shared/agents/code-reviewer.md"
assert_present '^你是 verifier。' "$ROOT/shared/agents/verifier.md"
assert_present '^你是 qa。' "$ROOT/shared/agents/qa.md"
assert_present '^你是 fixer。' "$ROOT/shared/agents/fixer.md"
assert_present '根因定位.*最小修复' "$ROOT/shared/agents/fixer.md"
assert_present '^你是 consistency-auditor。' "$ROOT/shared/agents/consistency-auditor.md"
assert_present 'advisory 结论' "$ROOT/shared/agents/consistency-auditor.md"

echo "[PASS] standard chain cutover"
