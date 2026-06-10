#!/bin/bash
# overview/scripts/dir-tree.sh — 输出项目目录树形结构
# 输入: $1 = 项目路径（默认 .）, $2 = 深度（默认 3）
# 输出: 文本树形结构

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

PROJECT_DIR="${1:-.}"
DEPTH="${2:-3}"
[ -d "$PROJECT_DIR" ] || script_error "Directory not found: $PROJECT_DIR"
[[ "$DEPTH" =~ ^[0-9]+$ ]] && [ "$DEPTH" -gt 0 ] || script_error "Depth must be a positive integer: $DEPTH"

# 构建忽略模式
IGNORE_PATTERN="$IGNORE_DIRS"

if command -v tree &>/dev/null; then
    tree "$PROJECT_DIR" -d -L "$DEPTH" --noreport -I "$IGNORE_PATTERN" 2>/dev/null
else
    # 降级到 find + awk
    FIND_ARGS=("$PROJECT_DIR" -maxdepth "$DEPTH" -type d)
    IFS='|' read -ra DIRS <<< "$IGNORE_DIRS"
    for d in "${DIRS[@]}"; do
        FIND_ARGS+=(-not -path "*/${d}" -not -path "*/${d}/*")
    done

    find "${FIND_ARGS[@]}" 2>/dev/null | sort | awk -v base="$PROJECT_DIR" '
    {
        path = $0
        if (path == base) { print base; next }
        prefix = base "/"
        if (index(path, prefix) == 1) {
            path = substr(path, length(prefix) + 1)
        }
        n = split(path, parts, "/")
        indent = ""
        for (i = 1; i < n; i++) indent = indent "    "
        print indent parts[n] "/"
    }'
fi
