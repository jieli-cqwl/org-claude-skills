#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHAIN_CONTRACT="$ROOT/contracts/small-chain.yaml"
BOUNDARY_YAML="$ROOT/contracts/superpowers-boundary.yaml"
README_DOC="$ROOT/README.md"
BRAINSTORMING_SKILL="$ROOT/community/superpowers/skills/brainstorming/SKILL.md"
WRITING_PLANS_SKILL="$ROOT/community/superpowers/skills/writing-plans/SKILL.md"
DESIGN_TEMPLATE="$ROOT/community/superpowers/skills/brainstorming/references/design-template.md"
DESIGN_CHECKLIST="$ROOT/community/superpowers/skills/brainstorming/references/design-completeness-checklist.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Fq "$pattern" "$file" || fail "缺少 small-chain 质量下限内容: ${file#"$ROOT"/} :: $pattern"
}

for path in "$CHAIN_CONTRACT" "$BOUNDARY_YAML" "$README_DOC"; do
  [ -f "$path" ] || fail "缺少 small-chain 边界文件: ${path#"$ROOT"/}"
done

grep -Fq 'small_chain: wrapper_and_contract' "$BOUNDARY_YAML" || fail "small_chain 必须标记为 wrapper_and_contract"
grep -Fq 'community_openspec: archived' "$BOUNDARY_YAML" || fail "community_openspec 必须标记为 archived"
grep -Fq 'contracts/small-chain.yaml' "$README_DOC" || fail "README 必须引用 small-chain 链路合同"
grep -Fq 'contracts/superpowers-boundary.yaml' "$README_DOC" || fail "README 必须引用 superpowers 边界合同"
assert_present 'scope registry' "$README_DOC"
assert_present 'management_status' "$README_DOC"
assert_present 'handoff_status' "$README_DOC"
assert_present 'context_owner' "$README_DOC"
assert_present 'artifact_owner' "$README_DOC"

for skill in using-superpowers brainstorming writing-plans small-chain-execution-router using-git-worktrees subagent-driven-development parallel-subagent-development verification-before-completion requesting-code-review verify-change finishing-a-development-branch archive; do
  grep -Fq "$skill" "$CHAIN_CONTRACT" || fail "small-chain.yaml 缺少阶段: $skill"
done

assert_present 'key_fields:' "$CHAIN_CONTRACT"
assert_present 'always_required:' "$CHAIN_CONTRACT"
assert_present 'problem_statement' "$CHAIN_CONTRACT"
assert_present 'goals_success_criteria' "$CHAIN_CONTRACT"
assert_present 'alternatives_considered' "$CHAIN_CONTRACT"
assert_present 'conditionally_required:' "$CHAIN_CONTRACT"
assert_present 'change_scope' "$CHAIN_CONTRACT"
assert_present 'downstream_impact' "$CHAIN_CONTRACT"
assert_present 'per_task:' "$CHAIN_CONTRACT"
assert_present 'traces' "$CHAIN_CONTRACT"
assert_present 'depends' "$CHAIN_CONTRACT"
assert_present 'complexity' "$CHAIN_CONTRACT"
assert_present 'per_task_section:' "$CHAIN_CONTRACT"
assert_present 'context' "$CHAIN_CONTRACT"
assert_present 'files' "$CHAIN_CONTRACT"
assert_present 'steps' "$CHAIN_CONTRACT"
assert_present 'management_status' "$CHAIN_CONTRACT"
assert_present 'entry_ref' "$CHAIN_CONTRACT"
assert_present 'handoff_status' "$CHAIN_CONTRACT"
assert_present 'execution-routing-input.json' "$CHAIN_CONTRACT"
assert_present 'execution-route.json' "$CHAIN_CONTRACT"
assert_present 'routing_input_hash' "$CHAIN_CONTRACT"
assert_present 'decision_enum: [serial, parallel, blocked]' "$CHAIN_CONTRACT"
assert_present 'plan-stage-worklog-handoff' "$CHAIN_CONTRACT"
assert_present 'parallel-execution-report' "$CHAIN_CONTRACT"
assert_present 'code-review-result.json' "$CHAIN_CONTRACT"
assert_present 'contract_grade_or_runtime_gate_change' "$CHAIN_CONTRACT"

for skill_file in \
  "$ROOT/community/superpowers/skills/brainstorming/SKILL.md" \
  "$ROOT/community/superpowers/skills/writing-plans/SKILL.md" \
  "$ROOT/community/superpowers/skills/parallel-subagent-development/SKILL.md" \
  "$ROOT/community/superpowers/skills/requesting-code-review/SKILL.md" \
  "$ROOT/community/superpowers/skills/using-git-worktrees/SKILL.md" \
  "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md" \
  "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md" \
  "$ROOT/community/superpowers/skills/verify-change/SKILL.md" \
  "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md" \
  "$ROOT/community/superpowers/skills/archive/SKILL.md"
do
  assert_present 'scope registry' "$skill_file"
  assert_present 'worklog.md' "$skill_file"
  assert_present 'handoff_status' "$skill_file"
done

test -f "$DESIGN_CHECKLIST" || fail "缺少 design completeness checklist: ${DESIGN_CHECKLIST#"$ROOT"/}"
assert_present '5. Content completeness' "$BRAINSTORMING_SKILL"
assert_present 'references/design-completeness-checklist.md' "$BRAINSTORMING_SKILL"
assert_present 'contracts/small-chain.yaml -> brainstorming -> design.md key_fields' "$DESIGN_TEMPLATE"
assert_present '## Goals & Success Criteria' "$DESIGN_TEMPLATE"
assert_present '## Change Scope' "$DESIGN_TEMPLATE"
assert_present '## Invariants' "$DESIGN_TEMPLATE"
assert_present '## Downstream Impact' "$DESIGN_TEMPLATE"
assert_present '## Risks' "$DESIGN_TEMPLATE"
for item in D1 D2 D3 D4 D5 D6 D7 D8; do
  assert_present "| $item |" "$DESIGN_CHECKLIST"
done
assert_present 'D1、D2、D3、D4、D8 不允许 Missing' "$DESIGN_CHECKLIST"

assert_present '  - Traces: {design.md Goals & Success Criteria 表中的目标名}' "$WRITING_PLANS_SKILL"
assert_present '  - Depends: {依赖的 task ID，无依赖写 -}' "$WRITING_PLANS_SKILL"
assert_present '  - Complexity: {simple | moderate | complex}' "$WRITING_PLANS_SKILL"
assert_present 'Context: {1-2 句设计意图和关键约束}' "$WRITING_PLANS_SKILL"
assert_present '5. Trace completeness' "$WRITING_PLANS_SKILL"
assert_present 'Every success criterion in design.md Goals & Success Criteria' "$WRITING_PLANS_SKILL"
assert_present "is referenced by at least one task's Traces field" "$WRITING_PLANS_SKILL"
assert_present '6. Dependency validity' "$WRITING_PLANS_SKILL"
assert_present 'No circular dependencies.' "$WRITING_PLANS_SKILL"
assert_present '7. Context presence' "$WRITING_PLANS_SKILL"
assert_present 'Every task section in plan.md has a non-empty Context field.' "$WRITING_PLANS_SKILL"
assert_present 'execution-routing-input.json' "$WRITING_PLANS_SKILL"
assert_present 'stage: plan' "$WRITING_PLANS_SKILL"
assert_present 'small-chain-execution-router' "$WRITING_PLANS_SKILL"
assert_present 'Invoke small-chain-execution-router' "$WRITING_PLANS_SKILL"
assert_present 'REQUIRED NEXT STEP: run `small-chain-execution-router`' "$WRITING_PLANS_SKILL"
assert_present 'Contract-Grade Failure Matrix' "$WRITING_PLANS_SKILL"
assert_present 'Failure matrix completeness' "$WRITING_PLANS_SKILL"
assert_present 'malformed input, stale state, cross-artifact drift, ambiguous active state, and retry-after-blocked' "$WRITING_PLANS_SKILL"
if grep -Fq 'REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development' "$WRITING_PLANS_SKILL"; then
  fail "writing-plans 不能把 subagent-driven-development 作为 plan 后的直接下一跳"
fi
if grep -Fq 'Is isolated workspace already available?' "$WRITING_PLANS_SKILL"; then
  fail "writing-plans 流程图不能绕过 small-chain-execution-router 直接判断 worktree"
fi
assert_present 'community/superpowers/skills/parallel-subagent-development/SKILL.md' "$BOUNDARY_YAML"
assert_present 'contract_grade_review_gate' "$BOUNDARY_YAML"
assert_present 'code_review_required_before:' "$BOUNDARY_YAML"
assert_present 'parallel-subagent-development' "$ROOT/install.sh"
assert_present '"subagent-driven-development": "Use after small-chain-execution-router returns decision=serial' "$ROOT/install.sh"
assert_present '"using-git-worktrees": "Use after small-chain-execution-router returns decision=serial' "$ROOT/install.sh"
assert_present 'description: Use after small-chain-execution-router returns decision=serial' "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md"
assert_present 'description: Use after small-chain-execution-router returns decision=serial' "$ROOT/community/superpowers/skills/using-git-worktrees/SKILL.md"
for nav_skill in brainstorming using-git-worktrees finishing-a-development-branch archive; do
  assert_present 'small-chain-execution-router' "$ROOT/community/superpowers/skills/$nav_skill/SKILL.md"
  assert_present 'parallel-subagent-development' "$ROOT/community/superpowers/skills/$nav_skill/SKILL.md"
done
if rg -n '完整链路：`brainstorming → writing-plans → using-git-worktrees|description: Use after writing-plans produces tasks.md and plan.md' \
  "$ROOT/community/superpowers/skills/brainstorming/SKILL.md" \
  "$ROOT/community/superpowers/skills/using-git-worktrees/SKILL.md" \
  "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md" \
  "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md" \
  "$ROOT/community/superpowers/skills/archive/SKILL.md" >/tmp/org_small_chain_stale_nav.out 2>&1; then
  cat /tmp/org_small_chain_stale_nav.out >&2
  fail "small-chain 活跃 skill 不能保留绕过 router 的旧链路提示"
fi
assert_present 'parallel-execution-report.json' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'code-review-result.json' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'review_conclusion=APPROVE' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'gate_result=PASS' "$ROOT/community/superpowers/skills/verify-change/SKILL.md"

if grep -Fq 'executing-plans' "$CHAIN_CONTRACT"; then
  fail "small-chain.yaml 不应继续引用 executing-plans"
fi

for path in "$README_DOC" "$BOUNDARY_YAML"; do
  if rg -n '/Users/' "$path" >/tmp/org_small_chain_legacy_path.out 2>&1; then
    cat /tmp/org_small_chain_legacy_path.out >&2
    fail "small-chain 活跃文档不应引用本机绝对路径"
  fi
done

for path in "$README_DOC" "$BOUNDARY_YAML"; do
  if rg -n 'openspec --version|安装 `openspec` CLI|安装 openspec CLI|opsx:apply|opsx:verify|opsx:archive' "$path" >/tmp/org_small_chain_legacy_runtime.out 2>&1; then
    cat /tmp/org_small_chain_legacy_runtime.out >&2
    fail "small-chain 活跃文档不应继续把 OpenSpec CLI 或 opsx 作为默认运行前提"
  fi
done

grep -Fq 'openspec: archived' "$BOUNDARY_YAML" || fail "openspec 必须标记为 archived"
grep -Fq 'verify_change_required_before:' "$BOUNDARY_YAML" || fail "边界合同必须声明 verify-change 的前置门禁"
grep -Fq 'archive_requires: integrated_on_target_branch' "$BOUNDARY_YAML" || fail "边界合同必须声明 archive 前置条件"

echo "[PASS] small-chain boundary"
