#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOUNDARY_DOC="$ROOT/docs/community-first/boundary-contract.md"
CHAIN_CONTRACT="$ROOT/contracts/community-first-chain.yaml"
BOUNDARY_YAML="$ROOT/contracts/superpowers-boundary.yaml"
README_DOC="$ROOT/docs/community-first/README.md"
PILOT_DOC="$ROOT/docs/community-first/pilot-rollout-checklist.md"
GO_LIVE_DOC="$ROOT/docs/community-first/go-live-plan.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for path in "$BOUNDARY_DOC" "$CHAIN_CONTRACT" "$BOUNDARY_YAML" "$README_DOC" "$PILOT_DOC" "$GO_LIVE_DOC"; do
  [ -f "$path" ] || fail "缺少边界相关文件: ${path#"$ROOT"/}"
done

grep -Fq 'community_first: wrapper_and_contract' "$BOUNDARY_YAML" || fail "community_first 必须标记为 wrapper_and_contract"
grep -Fq 'community_openspec: compat_inventory' "$BOUNDARY_YAML" || fail "community_openspec 必须标记为 compat_inventory"

grep -Fq 'contracts/community-first-chain.yaml' "$BOUNDARY_DOC" || fail "边界合同必须引用链路合同"
grep -Fq 'docs/community-first/boundary-contract.md' "$README_DOC" || fail "community-first README 必须引用边界合同"
grep -Fq 'contracts/community-first-chain.yaml' "$README_DOC" || fail "community-first README 必须引用链路合同"

if grep -Fq 'opsx:apply' "$README_DOC"; then
  fail "community-first README 不应继续把 opsx:apply 写成默认链阶段"
fi

if ! grep -Fq 'writing-plans' "$CHAIN_CONTRACT"; then
  fail "community-first-chain.yaml 必须继续声明 writing-plans 阶段"
fi

if ! grep -Fq 'subagent-driven-development' "$CHAIN_CONTRACT"; then
  fail "community-first-chain.yaml 必须继续声明 subagent-driven-development 阶段"
fi

for path in "$README_DOC" "$PILOT_DOC" "$GO_LIVE_DOC"; do
  if rg -n '/Users/' "$path" >/tmp/org_community_first_legacy_path.out 2>&1; then
    cat /tmp/org_community_first_legacy_path.out >&2
    fail "community-first 活跃文档不应继续引用本机绝对路径"
  fi
done

for path in "$README_DOC" "$PILOT_DOC" "$GO_LIVE_DOC"; do
  if rg -n 'openspec --version|安装 `openspec` CLI|安装 openspec CLI|OpenSpec 本地 canonical' "$path" >/tmp/org_community_first_openspec_runtime.out 2>&1; then
    cat /tmp/org_community_first_openspec_runtime.out >&2
    fail "community-first 活跃文档不应再把 OpenSpec CLI 或 local canonical 写成默认运行前提"
  fi
done

echo "[PASS] community-first boundary"
