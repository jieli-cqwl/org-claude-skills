#!/bin/bash
# overview/scripts/dir-tree.sh — 输出项目目录树形结构
# 输入: $1 = 项目路径（默认 .）, $2 = 深度（默认 3）
# 输出: 文本树形结构

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

PROJECT_DIR="${1:-.}"
DEPTH="${2:-3}"
[ -d "$PROJECT_DIR" ] || script_error "Directory not found: $PROJECT_DIR"

# 构建忽略模式
IGNORE_PATTERN=$(echo "$IGNORE_DIRS" | tr '|' '|')

if command -v tree &>/dev/null; then
    tree "$PROJECT_DIR" -d -L "$DEPTH" --noreport -I "$IGNORE_PATTERN" 2>/dev/null
else
    # 降级到 find + awk
    EXCLUDES=""
    IFS='|' read -ra DIRS <<< "$IGNORE_DIRS"
    for d in "${DIRS[@]}"; do
        EXCLUDES="$EXCLUDES -not -path */${d}/*"
    done

    eval find "$PROJECT_DIR" -maxdepth "$DEPTH" -type d $EXCLUDES 2>/dev/null | sort | awk -v base="$PROJECT_DIR" '
    {
        sub("^" base "/?", "", $0)
        if ($0 == "") { print base; next }
        n = split($0, parts, "/")
        indent = ""
        for (i = 1; i < n; i++) indent = indent "    "
        print indent parts[n] "/"
    }'
fi
