#!/usr/bin/env bash
set -euo pipefail

# 文件职责：验证发布元数据校验脚本的通过与失败分支。
# 边界：只构造最小仓库夹具，不依赖真实网络、真实运行时或外部账号。

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0

# 函数意图：输出测试失败原因并立即终止，避免错误门禁静默通过。
fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

# 函数意图：记录单个测试场景通过，便于汇总门禁覆盖范围。
pass() {
  PASS=$((PASS + 1))
  printf '[PASS] %s\n' "$*"
}

# 函数意图：创建最小发布元数据夹具，用于独立验证脚本行为。
new_fixture() {
  TMP_ROOT="$(mktemp -d)"
  mkdir -p "$TMP_ROOT/docs/releases"

  cat > "$TMP_ROOT/VERSION" <<'EOF'
1.2.4
EOF

  cat > "$TMP_ROOT/CHANGELOG.md" <<'EOF'
# Changelog

## 1.2.4
- 发布说明条目
EOF

  cat > "$TMP_ROOT/docs/releases/1.2.4.md" <<'EOF'
# org-claude-skills v1.2.4 发布说明

## 核心变更

1. 示例发布说明。
EOF
}

# 函数意图：清理临时夹具，避免测试副作用污染后续场景。
cleanup_fixture() {
  if [ -n "${TMP_ROOT:-}" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
  TMP_ROOT=""
}

trap cleanup_fixture EXIT

new_fixture
bash "$ROOT/tools/release/validate-release-metadata.sh" v1.2.4 "$TMP_ROOT" >/tmp/org_release_metadata_pass.out 2>&1 || {
  cat /tmp/org_release_metadata_pass.out >&2
  fail "发布元数据校验应通过"
}
pass "一致的发布元数据可以通过"
cleanup_fixture

new_fixture
set +e
bash "$ROOT/tools/release/validate-release-metadata.sh" 1.2.4 "$TMP_ROOT" >/tmp/org_release_metadata_bad_tag.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "非 v* tag 应阻断"
grep -q '只支持 v\* tag' /tmp/org_release_metadata_bad_tag.out || fail "缺少非 v* tag 的错误提示"
pass "非 v* tag 会阻断"
cleanup_fixture

new_fixture
printf '1.2.3\n' > "$TMP_ROOT/VERSION"
set +e
bash "$ROOT/tools/release/validate-release-metadata.sh" v1.2.4 "$TMP_ROOT" >/tmp/org_release_metadata_version.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "VERSION 不一致应阻断"
grep -q 'VERSION=1.2.3 与 tag v1.2.4 不一致' /tmp/org_release_metadata_version.out || fail "缺少 VERSION 不一致的错误提示"
pass "VERSION 不一致会阻断"
cleanup_fixture

new_fixture
rm -f "$TMP_ROOT/docs/releases/1.2.4.md"
set +e
bash "$ROOT/tools/release/validate-release-metadata.sh" v1.2.4 "$TMP_ROOT" >/tmp/org_release_metadata_docs.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "缺少发布说明应阻断"
grep -q '缺少文件:' /tmp/org_release_metadata_docs.out || fail "缺少发布说明时应提示缺少文件"
pass "缺少发布说明会阻断"
cleanup_fixture

new_fixture
cat > "$TMP_ROOT/CHANGELOG.md" <<'EOF'
# Changelog

## 1.2.4
说明文字但没有 bullet
EOF
set +e
bash "$ROOT/tools/release/validate-release-metadata.sh" v1.2.4 "$TMP_ROOT" >/tmp/org_release_metadata_changelog.out 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "空的 changelog 条目应阻断"
grep -q 'CHANGELOG.md 缺少版本 1.2.4 的非空变更条目' /tmp/org_release_metadata_changelog.out || fail "缺少 changelog 条目时应提示明确错误"
pass "空的 changelog 条目会阻断"
cleanup_fixture

printf '\nRelease metadata tests passed: %d\n' "$PASS"
