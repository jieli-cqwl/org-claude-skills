#!/usr/bin/env bash
set -euo pipefail

# 文件职责：校验发布 tag、VERSION、CHANGELOG 与 docs/releases 的一致性。
# 边界：只做仓库静态元数据校验，不做安装、运行时或外部服务验证。

usage() {
  cat <<'EOF'
Usage:
  bash tools/release/validate-release-metadata.sh <tag> [repo-root]
EOF
}

# 函数意图：输出用户可理解的失败原因并立即终止发布元数据校验。
fail() {
  printf '[release-metadata][FAIL] %s\n' "$*" >&2
  exit 1
}

# 函数意图：要求关键文件存在，否则说明发布元数据不完整。
require_file() {
  local file_path="$1"
  [ -f "$file_path" ] || fail "缺少文件: $file_path"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage >&2
  exit 1
fi

tag="$1"
repo_root="${2:-$(cd "$(dirname "$0")/../.." && pwd)}"

case "$tag" in
  v*) ;;
  *) fail "只支持 v* tag，收到: $tag" ;;
esac

version="${tag#v}"
[ -n "$version" ] || fail "tag 不能为空版本号: $tag"

version_file="$repo_root/VERSION"
changelog_file="$repo_root/CHANGELOG.md"
docs_file="$repo_root/docs/releases/${version}.md"
expected_title="# org-claude-skills v${version} 发布说明"

require_file "$version_file"
require_file "$changelog_file"
require_file "$docs_file"

actual_version="$(tr -d '[:space:]' < "$version_file")"
[ "$actual_version" = "$version" ] || fail "VERSION=$actual_version 与 tag $tag 不一致"

actual_title="$(awk 'NR == 1 { print; exit }' "$docs_file")"
[ "$actual_title" = "$expected_title" ] || fail "发布说明标题不一致，期望: $expected_title，实际: $actual_title"

awk -v ver="$version" '
$0 == "## " ver { in_section = 1; found = 1; next }
in_section && /^## / { exit }
in_section && /^- / { bullet = 1 }
END { exit(found && bullet ? 0 : 1) }
' "$changelog_file" || fail "CHANGELOG.md 缺少版本 ${version} 的非空变更条目"

printf '[release-metadata][PASS] %s 对应的版本元数据一致\n' "$tag"
