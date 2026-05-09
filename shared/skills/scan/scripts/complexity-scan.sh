#!/bin/bash
# scan/scripts/complexity-scan.sh — 粗略统计函数体行数和嵌套深度
# 输入: $1 = 项目路径（默认 .）, $2 = 语言（可选，自动检测）
# 输出: JSON {violations: [{file, line, type, value, threshold}], summary: {long_functions, deep_nesting, total}}

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

PROJECT_DIR="${1:-.}"
[ -d "$PROJECT_DIR" ] || script_error "Directory not found: $PROJECT_DIR"

LANG="${2:-$(detect_language "$PROJECT_DIR")}"

# 复杂度阈值默认与 rules/代码规范.md 一致，可通过环境变量覆盖
FUNC_THRESHOLD="${CODE_NORM_FUNC_MAX_LINES:-40}"
NEST_THRESHOLD="${CODE_NORM_MAX_NESTING:-3}"

# 选择文件扩展名
case "$LANG" in
    java)       EXTS=("java") ;;
    typescript)  EXTS=("ts" "tsx") ;;
    javascript)  EXTS=("js" "jsx") ;;
    go)          EXTS=("go") ;;
    rust)        EXTS=("rs") ;;
    *)           EXTS=("java" "ts" "tsx" "js" "jsx" "go" "rs") ;;
esac

# 构建 find 排除条件
EXCLUDES=""
IFS='|' read -ra DIRS <<< "$IGNORE_DIRS"
for d in "${DIRS[@]}"; do
    EXCLUDES="$EXCLUDES -not -path '*/${d}/*'"
done

# 收集源文件
FILES=""
for ext in "${EXTS[@]}"; do
    FILES="$FILES$(eval find "$PROJECT_DIR" -type f -name "'*.$ext'" $EXCLUDES 2>/dev/null)"$'\n'
done
FILES=$(echo "$FILES" | sed '/^$/d')

file_count=$(echo "$FILES" | sed '/^$/d' | wc -l | tr -d ' ')
check_file_limit "$file_count" || FILES=$(echo "$FILES" | head -n "$MAX_FILES")

# 用 awk 扫描函数长度和嵌套深度
VIOLATIONS=$(echo "$FILES" | while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    awk -v file="$f" -v ft="$FUNC_THRESHOLD" -v nt="$NEST_THRESHOLD" '
    BEGIN { depth=0; func_start=0; func_depth=0 }
    {
        # 统计花括号
        n_open = gsub(/{/, "{")
        n_close = gsub(/}/, "}")

        if (func_start == 0 && n_open > 0) {
            func_start = NR
            func_depth = depth
        }

        depth += n_open - n_close

        if (depth > nt) {
            printf "%s\t%d\tdeep_nesting\t%d\t%d\n", file, NR, depth, nt
        }

        if (depth <= func_depth && func_start > 0) {
            func_len = NR - func_start
            if (func_len > ft) {
                printf "%s\t%d\tlong_function\t%d\t%d\n", file, func_start, func_len, ft
            }
            func_start = 0
        }
    }' "$f" 2>/dev/null || true
done)

long_functions=$(echo "$VIOLATIONS" | awk '/long_function/ {c++} END{print c+0}')
deep_nesting=$(echo "$VIOLATIONS" | awk '/deep_nesting/ {c++} END{print c+0}')
total=$((long_functions + deep_nesting))

# 构建 JSON 输出
if command -v jq &>/dev/null; then
    violations_json="[]"
    if [ -n "$VIOLATIONS" ] && [ "$total" -gt 0 ]; then
        violations_json=$(echo "$VIOLATIONS" | sed '/^$/d' | awk -F'\t' '
        BEGIN { printf "[" }
        NR > 1 { printf "," }
        { printf "{\"file\":\"%s\",\"line\":%s,\"type\":\"%s\",\"value\":%s,\"threshold\":%s}", $1, $2, $3, $4, $5 }
        END { printf "]" }')
    fi
    jq -nc \
        --argjson v "$violations_json" \
        --argjson lf "$long_functions" \
        --argjson dn "$deep_nesting" \
        --argjson t "$total" \
        '{violations: $v, summary: {long_functions: $lf, deep_nesting: $dn, total: $t}}'
else
    printf '{"violations":[],"summary":{"long_functions":%d,"deep_nesting":%d,"total":%d}}\n' \
        "$long_functions" "$deep_nesting" "$total"
fi
