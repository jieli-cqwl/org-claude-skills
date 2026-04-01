#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOUNDARY="$ROOT/contracts/superpowers-boundary.yaml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$BOUNDARY" || fail "缺少 contracts/superpowers-boundary.yaml"
test -s "$BOUNDARY" || fail "contracts/superpowers-boundary.yaml 不能为空"

for key in version target_state runtime_roles canonical_targets declared_forks allowed_legacy_paths overlay_files; do
  grep -Eq "^${key}:" "$BOUNDARY" || fail "boundary contract 缺少顶层字段: $key"
done

for key in community_superpowers community_first openspec community_openspec; do
  grep -Eq "^  ${key}:" "$BOUNDARY" || fail "boundary contract 缺少 runtime_roles.${key}"
done

for key in default_chain_contract boundary_contract_doc source_lock overlay_contract; do
  value="$(sed -n "s/^  ${key}: //p" "$BOUNDARY")"
  [ -n "$value" ] || fail "boundary contract 缺少 canonical_targets.${key}"
  [ -f "$ROOT/$value" ] || fail "boundary contract 指向缺失文件: $value"
done

while IFS= read -r path; do
  [ -f "$ROOT/$path" ] || fail "overlay_files 声明的文件不存在: $path"
done < <(sed -n 's/^  - \(community\/superpowers\/.*\)$/\1/p' "$BOUNDARY")

if rg -n 'docs/superpowers/specs|docs/superpowers/plans' "$ROOT/community/superpowers" >/tmp/org_superpowers_legacy_paths.out 2>&1; then
  cat /tmp/org_superpowers_legacy_paths.out >&2
  fail "community/superpowers 不应再保留未声明的 docs/superpowers/* 历史路径"
fi

if rg -n "Error 500|That.s an error|That's an error" "$ROOT/community/superpowers" >/tmp/org_superpowers_noise.out 2>&1; then
  cat /tmp/org_superpowers_noise.out >&2
  fail "community/superpowers 不应再保留正文噪音"
fi

if rg -n 'opsx:(propose|apply|verify|archive)' "$ROOT/community/superpowers" >/tmp/org_superpowers_local_workflow.out 2>&1; then
  cat /tmp/org_superpowers_local_workflow.out >&2
  fail "community/superpowers 不应继续回写本仓库特有的 opsx:* 本地流程名"
fi

echo "[PASS] superpowers boundary"
