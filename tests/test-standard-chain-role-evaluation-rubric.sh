#!/usr/bin/env bash
set -euo pipefail

# File responsibility: keep the standard-chain role evaluation rubric concrete
# and separated from small-chain routing.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUBRIC="$ROOT/docs/standard-chain-team-readiness/role-evaluation-rubric.md"
SAMPLE="$ROOT/docs/standard-chain-team-readiness/login-homepage-v2-role-evaluation.md"
RUNBOOK="$ROOT/docs/standard-chain-team-readiness/role-evaluation-runbook.md"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

assert_file() {
  test -f "$1" || fail "missing file: $1"
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -q "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -q "$pattern" "$file"; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_file "$RUBRIC"
assert_file "$SAMPLE"
assert_file "$RUNBOOK"

for role in \
  product-director product-manager design test-design tech-lead developer \
  review verify qa consistency-auditor fix delivery-owner
do
  assert_present "\`$role\`" "$RUBRIC"
  assert_present "\`$role\`" "$SAMPLE"
done

for pattern in \
  '存在合理性评分' \
  '胜任度评分' \
  '独立责任域' \
  '不可替代风险' \
  '下游消费关系' \
  '权威字段边界' \
  '反噪音价值' \
  '门禁价值' \
  '输入保真' \
  '输出合约' \
  '证据强度' \
  '边界克制' \
  '缺陷发现能力' \
  '闭环能力' \
  '噪音控制'
do
  assert_present "$pattern" "$RUBRIC"
done

assert_present 'contracts/standard-chain.yaml' "$RUBRIC"
assert_present 'contracts/small-chain.yaml' "$RUBRIC"
assert_present '低风险、小范围、单点变更由 `small-chain` 路由' "$RUBRIC"
assert_absent '轻量模式' "$RUBRIC"
assert_absent '轻量模式' "$RUNBOOK"

assert_present 'login-homepage-v2 角色评估' "$SAMPLE"
assert_present '证据来源' "$SAMPLE"
assert_present 'fix` 未触发' "$SAMPLE"
assert_present '不能把 role evidence 自报 PASS 当作最终依据' "$SAMPLE"
assert_present '整体裁决：PASS' "$SAMPLE"

assert_present '标准链签收后' "$RUNBOOK"
assert_present '不修改 upstream canonical artifacts' "$RUNBOOK"
assert_present '先运行 fresh proving commands' "$RUNBOOK"
assert_present 'role-evaluation-rubric.md' "$RUNBOOK"
assert_present 'login-homepage-v2-role-evaluation.md' "$RUNBOOK"
assert_present 'small-chain' "$RUNBOOK"

printf '[PASS] standard-chain role evaluation rubric\n'
