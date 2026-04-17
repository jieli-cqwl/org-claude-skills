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

for skill in using-superpowers brainstorming writing-plans using-git-worktrees subagent-driven-development verification-before-completion verify-change finishing-a-development-branch archive; do
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
