#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOUNDARY_DOC="$ROOT/docs/small-chain/boundary-contract.md"
CHAIN_CONTRACT="$ROOT/contracts/small-chain.yaml"
BOUNDARY_YAML="$ROOT/contracts/superpowers-boundary.yaml"
README_DOC="$ROOT/docs/small-chain/README.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for path in "$BOUNDARY_DOC" "$CHAIN_CONTRACT" "$BOUNDARY_YAML" "$README_DOC"; do
  [ -f "$path" ] || fail "缺少 small-chain 边界文件: ${path#"$ROOT"/}"
done

grep -Fq 'small_chain: wrapper_and_contract' "$BOUNDARY_YAML" || fail "small_chain 必须标记为 wrapper_and_contract"
grep -Fq 'community_openspec: archived' "$BOUNDARY_YAML" || fail "community_openspec 必须标记为 archived"

grep -Fq 'contracts/small-chain.yaml' "$BOUNDARY_DOC" || fail "边界合同必须引用 small-chain 链路合同"
grep -Fq 'docs/small-chain/boundary-contract.md' "$README_DOC" || fail "small-chain README 必须引用边界合同"
grep -Fq 'contracts/small-chain.yaml' "$README_DOC" || fail "small-chain README 必须引用链路合同"

for skill in using-superpowers brainstorming writing-plans using-git-worktrees subagent-driven-development verification-before-completion verify-change finishing-a-development-branch archive; do
  grep -Fq "$skill" "$CHAIN_CONTRACT" || fail "small-chain.yaml 缺少阶段: $skill"
done

if grep -Fq 'executing-plans' "$CHAIN_CONTRACT"; then
  fail "small-chain.yaml 不应继续引用 executing-plans"
fi

for path in "$README_DOC" "$BOUNDARY_DOC"; do
  if rg -n '/Users/' "$path" >/tmp/org_small_chain_legacy_path.out 2>&1; then
    cat /tmp/org_small_chain_legacy_path.out >&2
    fail "small-chain 活跃文档不应引用本机绝对路径"
  fi
done

for path in "$README_DOC" "$BOUNDARY_DOC"; do
  if rg -n 'openspec --version|安装 `openspec` CLI|安装 openspec CLI|opsx:apply|opsx:verify|opsx:archive' "$path" >/tmp/org_small_chain_legacy_runtime.out 2>&1; then
    cat /tmp/org_small_chain_legacy_runtime.out >&2
    fail "small-chain 活跃文档不应继续把 OpenSpec CLI 或 opsx 作为默认运行前提"
  fi
done

# openspec 归档完整性检查
ARCHIVE_DIR="$ROOT/docs/archive/openspec"
[ -d "$ARCHIVE_DIR" ] || fail "docs/archive/openspec/ 目录不存在"
for sub in config.yaml changes designs plans specs; do
  [ -e "$ARCHIVE_DIR/$sub" ] || fail "docs/archive/openspec/$sub 不存在"
done
grep -Fq 'openspec: archived' "$BOUNDARY_YAML" || fail "openspec 必须标记为 archived"

echo "[PASS] small-chain boundary"
