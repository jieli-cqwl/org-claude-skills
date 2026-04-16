#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONTRACT="$ROOT/contracts/product-artifacts.yaml"
DIRECTOR_CHECK="$ROOT/shared/skills/product-director/scripts/completion_check.sh"
MANAGER_CHECK="$ROOT/shared/skills/product-manager/scripts/completion_check.sh"
ROLE_CONTRACT_TEST="$ROOT/tests/test-product-role-split-contract.sh"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Eq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern '$pattern' in $file"
  fi
}

assert_file "$CONTRACT"
assert_present '^product_artifacts:' "$CONTRACT"
assert_present 'brief_lock:' "$CONTRACT"
assert_present 'prd_lock:' "$CONTRACT"
assert_present 'review_contract:' "$CONTRACT"
assert_present '业务背景与根问题' "$CONTRACT"
assert_present '目标与成功标准' "$CONTRACT"
assert_present '交付计划' "$CONTRACT"
assert_present '阶段目标' "$CONTRACT"
assert_present '入口与出口条件' "$CONTRACT"
assert_present '最终结论' "$CONTRACT"
assert_present '未决阻断' "$CONTRACT"

assert_present 'product-artifacts.yaml' "$DIRECTOR_CHECK"
assert_present 'product-artifacts.yaml' "$MANAGER_CHECK"
assert_present 'load_product_artifact_contract' "$DIRECTOR_CHECK"
assert_present 'load_product_artifact_contract' "$MANAGER_CHECK"
assert_absent 'REQUIRED_BRIEF_LOCK_HEADINGS=\(' "$MANAGER_CHECK"
assert_absent 'REQUIRED_PRD_LOCK_HEADINGS=\(' "$MANAGER_CHECK"
assert_absent '"业务背景与根问题"[[:space:]]+"目标与成功标准"' "$MANAGER_CHECK"

assert_present 'test-product-artifact-contract.sh' "$ROLE_CONTRACT_TEST"

echo "[PASS] product artifact contract"
