#!/bin/bash
# hooks/lib/constraint.sh — PRD/Plan 约束解析公共函数库
# PRD 前置约束和 Plan 约束映射的提取、比对函数
# 使用方法: source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/constraint.sh"
# 依赖: common.sh 必须先被 source（需要 extract_markdown_section）

# --- PRD 约束 ---

# 从 PRD 的「前置约束」表格提取数据行
# $1: prd.md 文件路径
# 输出: 每行 9 个字段（| 分隔）: constraint_id|type|description|owner|affected_unit|scope_id|preflight_ref|test_ref|status
extract_prd_constraint_rows() {
    local prd_file="$1"
    local constraint_section
    constraint_section=$(extract_markdown_section "$prd_file" "## 前置约束")
    printf '%s\n' "$constraint_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            constraint_id = trim($2)
            constraint_type = trim($3)
            description = trim($4)
            owner = trim($5)
            affected_unit = trim($6)
            scope_id = trim($7)
            preflight_ref = trim($8)
            test_ref = trim($9)
            status = trim($10)

            if (constraint_id == "" || constraint_id == "Constraint ID" || constraint_id ~ /^-+$/) next
            print constraint_id "|" constraint_type "|" description "|" owner "|" affected_unit "|" scope_id "|" preflight_ref "|" test_ref "|" status
        }
    '
}

# 检查 PRD 是否有「无前置约束（经评估）」的显式声明
# $1: prd.md 文件路径
# 返回 0 = 有声明，1 = 无声明
has_explicit_no_constraints_declaration() {
    local prd_file="$1"
    local constraint_section
    constraint_section=$(extract_markdown_section "$prd_file" "## 前置约束")
    printf '%s\n' "$constraint_section" | grep -qE '^[[:space:]]*[-*]?[[:space:]]*无前置约束（经评估）[[:space:]]*$|^[[:space:]]*[-*]?[[:space:]]*无前置约束\(经评估\)[[:space:]]*$'
}

# 从 PRD 约束行构建比对用的去 status 键（前 8 字段）
# $1: extract_prd_constraint_rows 的输出
# 输出: 去重排序后的 8 字段行
build_prd_constraint_pairs() {
    local rows="$1"
    printf '%s\n' "$rows" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        {
            constraint_id = trim($1)
            constraint_type = trim($2)
            description = trim($3)
            owner = trim($4)
            affected_unit = trim($5)
            scope_id = trim($6)
            preflight_ref = trim($7)
            test_ref = trim($8)
            print constraint_id "|" constraint_type "|" description "|" owner "|" affected_unit "|" scope_id "|" preflight_ref "|" test_ref
        }
    ' | sed '/^$/d' | sort -u
}

# --- Plan 约束映射 ---

# 从 Plan 的「PRD 前置约束映射」表格提取数据行
# $1: plan.md 文件路径
# 输出: 每行 11 个字段（| 分隔）: constraint_id|type|description|owner|affected_unit|scope_id|preflight_ref|test_ref|mapped_task|acceptance_evidence|status
extract_plan_constraint_rows() {
    local plan_file="$1"
    local constraint_section
    constraint_section=$(extract_markdown_section "$plan_file" "## PRD 前置约束映射")
    printf '%s\n' "$constraint_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            constraint_id = trim($2)
            constraint_type = trim($3)
            description = trim($4)
            owner = trim($5)
            affected_unit = trim($6)
            scope_id = trim($7)
            preflight_ref = trim($8)
            test_ref = trim($9)
            mapped_task = trim($10)
            acceptance_evidence = trim($11)
            status = trim($12)

            if (constraint_id == "" || constraint_id == "Constraint ID" || constraint_id ~ /^-+$/) next
            print constraint_id "|" constraint_type "|" description "|" owner "|" affected_unit "|" scope_id "|" preflight_ref "|" test_ref "|" mapped_task "|" acceptance_evidence "|" status
        }
    '
}

# 从 Plan 约束行构建比对用的去 mapped/evidence/status 键（前 8 字段）
# $1: extract_plan_constraint_rows 的输出
# 输出: 去重排序后的 8 字段行
build_plan_constraint_pairs() {
    local rows="$1"
    printf '%s\n' "$rows" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        {
            constraint_id = trim($1)
            constraint_type = trim($2)
            description = trim($3)
            owner = trim($4)
            affected_unit = trim($5)
            scope_id = trim($6)
            preflight_ref = trim($7)
            test_ref = trim($8)
            print constraint_id "|" constraint_type "|" description "|" owner "|" affected_unit "|" scope_id "|" preflight_ref "|" test_ref
        }
    ' | sed '/^$/d' | sort -u
}

# --- Plan 审查分级 ---

# 从 plan.md 解析审查分级（轻量/标准/完整）
# $1: plan.md 文件路径
# 输出: 分级值或空字符串（占位符/无效值时）
parse_plan_grade() {
    local plan_file="$1"
    local line value

    line=$(grep -E '(Phase[[:space:]]*3[[:space:]]*审查分级|审查分级)[[:space:]]*[:：]' "$plan_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E 's/.*[:：][[:space:]]*//')
    value=$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

    # 拒绝模板占位值（如 "轻量 | 标准 | 完整" 或 "{轻量, 标准, 完整}"）
    if printf '%s' "$value" | grep -qE '[|/]'; then
        printf '%s' ""
        return 0
    fi
    if printf '%s' "$value" | grep -qE '\{.*\}'; then
        printf '%s' ""
        return 0
    fi

    if printf '%s' "$value" | grep -qE '^(轻量|标准|完整)$'; then
        printf '%s' "$value"
    else
        printf '%s' ""
    fi
}
