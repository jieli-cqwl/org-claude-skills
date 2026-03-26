#!/bin/bash
# scan/scripts/project-stats.sh — 按扩展名分组统计项目文件数和行数
# 输入: $1 = 项目路径（默认 .）
# 输出: JSON {project_type, languages: {lang: {files, lines}}, total_files, total_lines}

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

PROJECT_DIR="${1:-.}"
[ -d "$PROJECT_DIR" ] || script_error "Directory not found: $PROJECT_DIR"

LANG=$(detect_language "$PROJECT_DIR")

EXTS="java py ts tsx js jsx go rs vue html css scss"

ext_to_lang() {
    case "$1" in
        java) echo "Java" ;; py) echo "Python" ;;
        ts|tsx) echo "TypeScript" ;; js|jsx) echo "JavaScript" ;;
        go) echo "Go" ;; rs) echo "Rust" ;;
        vue) echo "Vue" ;; html) echo "HTML" ;;
        css) echo "CSS" ;; scss) echo "SCSS" ;;
    esac
}

# 构建 find 排除条件
EXCLUDES=""
IFS='|' read -ra DIRS <<< "$IGNORE_DIRS"
for d in "${DIRS[@]}"; do
    EXCLUDES="$EXCLUDES -not -path */${d}/*"
done

total_files=0
total_lines=0
json_langs="{"

first=true
for ext in $EXTS; do
    lang_name=$(ext_to_lang "$ext")
    count=$(eval find "$PROJECT_DIR" -type f -name "'*.$ext'" $EXCLUDES 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        lines=$(eval find "$PROJECT_DIR" -type f -name "'*.$ext'" $EXCLUDES -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
        total_files=$((total_files + count))
        total_lines=$((total_lines + lines))

        if [ "$first" = true ]; then
            first=false
        else
            json_langs="$json_langs,"
        fi
        json_langs="$json_langs\"$lang_name\":{\"files\":$count,\"lines\":$lines}"
    fi
done

json_langs="$json_langs}"

if command -v jq &>/dev/null; then
    jq -nc \
        --arg pt "$LANG" \
        --argjson langs "$json_langs" \
        --argjson tf "$total_files" \
        --argjson tl "$total_lines" \
        '{project_type: $pt, languages: $langs, total_files: $tf, total_lines: $tl}'
else
    printf '{"project_type":"%s","languages":%s,"total_files":%d,"total_lines":%d}\n' \
        "$LANG" "$json_langs" "$total_files" "$total_lines"
fi
