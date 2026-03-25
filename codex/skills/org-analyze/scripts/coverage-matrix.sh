#!/bin/bash
# analyze/scripts/coverage-matrix.sh — 交叉匹配 UNIT 在各工件中的覆盖情况
# 输入: 管道接收 extract-artifacts.sh 的 JSON，或 $1 = docs/{feature}/ 路径
# 输出: JSON {matrix: [{unit_id, has_design, has_plan, has_test, status}], coverage_rate}

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

command -v jq &>/dev/null || script_error "jq is required for coverage-matrix.sh"

SCRIPT_DIR="$(dirname "$0")"

# 判断输入来源：管道 or 参数
if [ ! -t 0 ]; then
    INPUT_JSON=$(cat)
elif [ -n "${1:-}" ] && [ -d "$1" ]; then
    INPUT_JSON=$("$SCRIPT_DIR/extract-artifacts.sh" "$1")
else
    script_error "Usage: extract-artifacts.sh <dir> | coverage-matrix.sh  OR  coverage-matrix.sh <dir>"
fi

FEATURE_DIR="${1:-.}"

# 提取 UNIT ID 列表
UNIT_IDS=$(echo "$INPUT_JSON" | jq -r '.units[].id // empty' 2>/dev/null | sort -u)

if [ -z "$UNIT_IDS" ]; then
    jq -nc '{"matrix":[],"coverage_rate":0}'
    exit 0
fi

total=0
covered=0
matrix="["
first=true

while IFS= read -r uid; do
    [ -n "$uid" ] || continue
    total=$((total + 1))

    has_design=false
    has_plan=false
    has_test=false

    if [ -d "$FEATURE_DIR" ]; then
        # 检查 design.md 中是否出现该 UNIT
        if find "$FEATURE_DIR" -name "design.md" -type f -exec grep -ql "$uid" {} + 2>/dev/null; then
            has_design=true
        fi
        # 检查 plan.md 中是否出现该 UNIT
        if find "$FEATURE_DIR" -name "plan.md" -type f -exec grep -ql "$uid" {} + 2>/dev/null; then
            has_plan=true
        fi
        # 检查 test-cases.md 中是否出现该 UNIT
        if find "$FEATURE_DIR" -name "test-cases.md" -type f -exec grep -ql "$uid" {} + 2>/dev/null; then
            has_test=true
        fi
    fi

    status="incomplete"
    if [ "$has_design" = true ] && [ "$has_plan" = true ] && [ "$has_test" = true ]; then
        status="complete"
        covered=$((covered + 1))
    fi

    if [ "$first" = true ]; then
        first=false
    else
        matrix="$matrix,"
    fi
    matrix="$matrix{\"unit_id\":\"$uid\",\"has_design\":$has_design,\"has_plan\":$has_plan,\"has_test\":$has_test,\"status\":\"$status\"}"
done <<< "$UNIT_IDS"

matrix="$matrix]"

if [ "$total" -gt 0 ]; then
    rate=$(awk "BEGIN { printf \"%.1f\", ($covered / $total) * 100 }")
else
    rate="0"
fi

jq -nc \
    --argjson matrix "$matrix" \
    --argjson rate "$rate" \
    '{matrix: $matrix, coverage_rate: $rate}'
