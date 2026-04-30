#!/bin/bash
# consistency-audit/scripts/extract-artifacts.sh — 从 docs/{feature}/ 提取 canonical JSON 工件数据
# 输入: $1 = docs/{feature}/ 路径
# 输出: JSON {units: [{id, acs, modules}], tasks: [...], test_cases: [...], artifacts: [...]}

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

FEATURE_DIR="${1:-.}"
[ -d "$FEATURE_DIR" ] || script_error "Directory not found: $FEATURE_DIR"

# shellcheck disable=SC2016

# Extract matching strings from canonical JSON values when jq is available.
json_strings_matching() {
    local pattern="$1"
    if ! command -v jq &>/dev/null; then
        return 0
    fi
    while IFS= read -r json_file; do
        [ -f "$json_file" ] || continue
        jq -r --arg pattern "$pattern" '.. | strings | select(test($pattern))' "$json_file" 2>/dev/null || true
    done < <(find "$FEATURE_DIR" -name "*.json" -type f 2>/dev/null)
}

# Extract matching strings directly from JSON files as a lightweight fallback.
grep_json_artifact_strings() {
    local pattern="$1"
    find "$FEATURE_DIR" -name "*.json" -type f -exec grep -hoE "$pattern" {} + 2>/dev/null || true
}

# List recognized canonical artifact paths relative to the feature directory.
artifact_paths_json() {
    if ! command -v jq &>/dev/null; then
        printf '[]'
        return 0
    fi
    find "$FEATURE_DIR" \
        \( -name "brief.json" \
        -o -name "phase-prd.json" \
        -o -name "UNIT-*.json" \
        -o -name "design.json" \
        -o -name "plan.json" \
        -o -name "tasks.json" \
        -o -name "test-cases.json" \
        -o -name "developer-report.json" \
        -o -name "verify-result.json" \
        -o -name "code-review-result.json" \
        -o -name "qa-result.json" \
        -o -name "delivery-state.json" \
        -o -name "artifact-registry.json" \
        -o -name "consistency-audit-result.json" \
        -o -name "signoff-package.json" \
        -o -name "user-decision.json" \) \
        -type f 2>/dev/null \
        | sed "s#^$FEATURE_DIR/##" \
        | sort -u \
        | jq -Rnc '[inputs | select(length>0)]'
}

# 提取 UNIT ID（canonical JSON）
units_raw=$(
    {
        json_strings_matching 'UNIT-[0-9]{1,4}'
        find "$FEATURE_DIR" -path "*/units/UNIT-*.json" -type f 2>/dev/null | sed -E 's#.*/(UNIT-[0-9]{1,4})\.json#\1#'
        grep_json_artifact_strings 'UNIT-[0-9]{1,4}'
    } | grep -oE 'UNIT-[0-9]{1,4}' | sort -u || true
)

# 提取 AC 列表（canonical JSON）
acs_raw=$(
    {
        json_strings_matching 'AC-[0-9]{1,4}'
        grep_json_artifact_strings 'AC-[0-9]{1,4}[^[:space:]]*'
    } | grep -oE 'AC-[0-9]{1,4}[^[:space:]]*' | sort -u || true
)

# 提取模块名（design.json key_decisions）
modules_raw=""
while IFS= read -r design_json; do
    [ -f "$design_json" ] || continue
    if command -v jq &>/dev/null; then
        modules_raw="$modules_raw$(jq -r '
          .key_decisions? // empty
          | if type == "array" then .[] else . end
          | if type == "object" then (.module // .module_name // .decision_id // .id // .title // .summary // empty) else . end
        ' "$design_json" 2>/dev/null || true)"$'\n'
    fi
done < <(find "$FEATURE_DIR" -name "design.json" -type f 2>/dev/null)

# 提取 Task 列表（tasks.json/plan.json）
tasks_raw=""
while IFS= read -r task_json; do
    [ -f "$task_json" ] || continue
    if command -v jq &>/dev/null; then
        tasks_raw="$tasks_raw$(jq -r '
          (.tasks? // .task_list? // empty)
          | if type == "array" then .[] else empty end
          | if type == "object" then (.task_id // .id // empty) else . end
        ' "$task_json" 2>/dev/null || true)"$'\n'
    fi
done < <(find "$FEATURE_DIR" \( -name "tasks.json" -o -name "plan.json" \) -type f 2>/dev/null)

# 提取测试用例 ID（test-cases.json）
test_cases_raw=$(
    {
        if command -v jq &>/dev/null; then
            while IFS= read -r test_json; do
                [ -f "$test_json" ] || continue
                jq -r '
                  (.test_cases? // empty)
                  | if type == "array" then .[] else empty end
                  | if type == "object" then (.case_id // .id // empty) else . end
                ' "$test_json" 2>/dev/null || true
            done < <(find "$FEATURE_DIR" -name "test-cases.json" -type f 2>/dev/null)
        fi
        json_strings_matching 'TC-[0-9]{1,4}'
        grep_json_artifact_strings 'TC-[0-9]{1,4}'
    } | grep -oE 'TC-[0-9]{1,4}' | sort -u || true
)

# 构建 JSON
if command -v jq &>/dev/null; then
    # 构建 units 数组
    units_json="[]"
    if [ -n "$units_raw" ]; then
        units_json=$(echo "$units_raw" | sed '/^$/d' | while IFS= read -r uid; do
            # 该 UNIT 关联的 AC
            unit_acs=$(find "$FEATURE_DIR" -name "*.json" -type f -exec grep -l "$uid" {} + 2>/dev/null | while IFS= read -r unit_json; do
                grep -hoE 'AC-[0-9]{1,4}[^[:space:]]*' "$unit_json" 2>/dev/null || true
            done | sort -u | jq -Rnc '[inputs | select(length>0)]')
            # 该 UNIT 关联的模块
            unit_modules="[]"
            printf '{"id":"%s","acs":%s,"modules":%s}\n' "$uid" "${unit_acs:-[]}" "$unit_modules"
        done | jq -sc '.')
    fi

    tasks_json=$(echo "$tasks_raw" | sed '/^$/d' | sort -u | jq -Rnc '[inputs | select(length>0)]')
    tc_json=$(echo "$test_cases_raw" | sed '/^$/d' | jq -Rnc '[inputs | select(length>0)]')
    modules_json=$(echo "$modules_raw" | sed '/^$/d' | sort -u | jq -Rnc '[inputs | select(length>0)]')
    artifacts_json=$(artifact_paths_json)

    jq -nc \
        --argjson units "$units_json" \
        --argjson tasks "$tasks_json" \
        --argjson tc "$tc_json" \
        --argjson modules "$modules_json" \
        --argjson artifacts "$artifacts_json" \
        '{units: $units, tasks: $tasks, test_cases: $tc, modules: $modules, artifacts: $artifacts}'
else
    # 简单 JSON 输出
    printf '{"units":[],"tasks":[],"test_cases":[],"modules":[],"artifacts":[]}\n'
fi
