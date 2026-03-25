#!/bin/bash
# analyze/scripts/extract-artifacts.sh — 从 docs/{feature}/ 提取结构化工件数据
# 输入: $1 = docs/{feature}/ 路径
# 输出: JSON {units: [{id, acs, modules}], tasks: [...], test_cases: [...]}

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

FEATURE_DIR="${1:-.}"
[ -d "$FEATURE_DIR" ] || script_error "Directory not found: $FEATURE_DIR"

# 提取 UNIT ID（UNIT-NNN 模式）
units_raw=$(grep -rhoE 'UNIT-[0-9]{1,4}' "$FEATURE_DIR" 2>/dev/null | sort -u || true)

# 提取 AC 列表（AC- 开头）
acs_raw=$(grep -rhoE 'AC-[0-9]{1,4}[^[:space:]]*' "$FEATURE_DIR" 2>/dev/null | sort -u || true)

# 提取模块名（design.md 中的模块定义，### 或 ## 模块标题）
modules_raw=""
while IFS= read -r design_file; do
    [ -f "$design_file" ] || continue
    modules_raw="$modules_raw$(grep -oE '^#{2,3}\s+模块[：:]\s*\S+|^#{2,3}\s+[A-Za-z][A-Za-z0-9_-]+\s*(模块|Module)' "$design_file" 2>/dev/null | sed 's/^#*\s*//' || true)"$'\n'
done < <(find "$FEATURE_DIR" -name "design.md" -type f 2>/dev/null)

# 提取 Task 列表（plan.md 中的 Task 编号）
tasks_raw=""
while IFS= read -r plan_file; do
    [ -f "$plan_file" ] || continue
    tasks_raw="$tasks_raw$(grep -oE 'Task[- ][0-9]{1,3}' "$plan_file" 2>/dev/null | sort -u || true)"$'\n'
done < <(find "$FEATURE_DIR" -name "plan.md" -type f 2>/dev/null)

# 提取测试用例 ID（TC-NNN 模式）
test_cases_raw=$(grep -rhoE 'TC-[0-9]{1,4}' "$FEATURE_DIR" 2>/dev/null | sort -u || true)

# 构建 JSON
if command -v jq &>/dev/null; then
    # 构建 units 数组
    units_json="[]"
    if [ -n "$units_raw" ]; then
        units_json=$(echo "$units_raw" | sed '/^$/d' | while IFS= read -r uid; do
            # 该 UNIT 关联的 AC
            unit_acs=$(grep -rl "$uid" "$FEATURE_DIR" 2>/dev/null | xargs grep -hoE 'AC-[0-9]{1,4}[^[:space:]]*' 2>/dev/null | sort -u | jq -Rnc '[inputs | select(length>0)]')
            # 该 UNIT 关联的模块
            unit_modules="[]"
            printf '{"id":"%s","acs":%s,"modules":%s}\n' "$uid" "${unit_acs:-[]}" "$unit_modules"
        done | jq -sc '.')
    fi

    tasks_json=$(echo "$tasks_raw" | sed '/^$/d' | sort -u | jq -Rnc '[inputs | select(length>0)]')
    tc_json=$(echo "$test_cases_raw" | sed '/^$/d' | jq -Rnc '[inputs | select(length>0)]')

    jq -nc \
        --argjson units "$units_json" \
        --argjson tasks "$tasks_json" \
        --argjson tc "$tc_json" \
        '{units: $units, tasks: $tasks, test_cases: $tc}'
else
    # 简单 JSON 输出
    printf '{"units":[],"tasks":[],"test_cases":[]}\n'
fi
