#!/bin/bash
# 技术负责人实施计划完整性自动检查脚本
# 执行时机: 用户确认计划后显式运行
# 功能: 检查 plan.md 的 Task 结构完整性与 Design 审查闭环

set -euo pipefail

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/../../project-manager/scripts" && pwd)/phase3-grade-matrix.sh"
hook_init

# --- Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/(unit-[0-9]+/)?)?(plan\.md|design-review-[0-9]+\.md)'
resolve_feature_dir "docs/*/phase-*/plan.md" "$TRANSCRIPT_PATTERN" "plan.md" "docs/*/phase-*"
output_failures "技术负责人实施计划完整性检查未通过" ""

# --- PRD 驱动工作区定位（Phase 级：plan.md + design.md 在 Phase 目录） ---
resolve_phase_work_dir_from_prd "$FEATURE_DIR" "plan.md"
WORK_DIR="$PHASE_WORK_DIR"

PLAN_FILE="$WORK_DIR/plan.md"
PRD_FILE="$FEATURE_DIR/prd.md"
UNITS_DIR="$FEATURE_DIR/units"
PHASE_DIR="$WORK_DIR"
DESIGN_FILE="$WORK_DIR/design.md"

is_placeholder_text() {
    local value
    value=$(printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if [ -z "$value" ]; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^(待补|TBD|TODO|N/?A|无|未填写|\[.*\]|\{.*\}|-|—)$'; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^Y{2,}[-/]M{1,2}[-/]D{1,2}([[:space:]]+H{1,2}:[m]{1,2}(:[s]{1,2})?)?$'; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^(日期|时间|待确认时间|请填写时间)$'; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^(YYYY|MM|DD|HH|hh|mm|ss|[[:space:]]|[-/:])+$'; then
        return 0
    fi
    return 1
}

is_valid_confirmation_time() {
    local value
    value=$(printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if is_placeholder_text "$value"; then
        return 1
    fi
    if ! printf '%s' "$value" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[0-9]{2}:[0-9]{2}$'; then
        return 1
    fi
    return 0
}

extract_design_scope_ids() {
    local design_file="$1"
    local impact_section
    impact_section=$(extract_markdown_section "$design_file" "## 影响范围清单")
    if [ -z "$impact_section" ]; then
        impact_section=$(extract_markdown_section "$design_file" "## 影响访问清单")
    fi
    printf '%s\n' "$impact_section" | grep -oE 'SCOPE-P[0-9]+U[0-9]+-[0-9]+' | sort -u || true
}

extract_scope_freeze_rows() {
    local plan_file="$1"
    local freeze_section
    freeze_section=$(extract_markdown_section "$plan_file" "## Scope Freeze 与映射矩阵")
    printf '%s\n' "$freeze_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            scope_id = trim($2)
            change_type = trim($3)
            risk = trim($4)
            mapped_task = trim($5)
            test_ref = trim($6)
            impact_files = trim($7)
            rollback_ref = trim($8)
            status = trim($9)

            if (scope_id == "" || scope_id == "scope_item_id" || scope_id ~ /^-+$/) next
            gsub(/Task[ ]+/, "Task-", mapped_task)
            print scope_id "|" change_type "|" risk "|" mapped_task "|" test_ref "|" impact_files "|" rollback_ref "|" status
        }
    '
}

has_any_fixed_section() {
    local file="$1"
    shift
    local section

    for section in "$@"; do
        if grep -qF "$section" "$file" 2>/dev/null; then
            return 0
        fi
    done

    return 1
}

extract_task_block() {
    local file="$1" task_id="$2"
    awk -v task_id="$task_id" '
        $0 ~ ("^### " task_id "([[:space:]]*:|:)") { in_block=1; next }
        in_block && /^### Task-[0-9]+([[:space:]]*:|:)/ { exit }
        in_block { print }
    ' "$file"
}

task_block_has_field() {
    local task_block="$1" key_pattern="$2"
    printf '%s\n' "$task_block" \
        | grep -qE "^[[:space:]]*-?[[:space:]]*\\*?\\*?(${key_pattern})\\*?\\*?[[:space:]]*[:：]"
}

extract_task_field_value() {
    local task_block="$1" field_name="$2"
    printf '%s\n' "$task_block" \
        | { grep -E "^[[:space:]]*-?[[:space:]]*(\\*\\*)?${field_name}(\\*\\*)?[[:space:]]*[:：]" || true; } \
        | head -1 \
        | sed -E 's/^[^:：]*[:：][[:space:]]*//'
}

extract_plan_matrix_section() {
    local file="$1"
    local matrix_section=""
    matrix_section=$(extract_markdown_section "$file" "## PRD / Design 覆盖矩阵")
    if [ -z "$matrix_section" ]; then
        matrix_section=$(extract_markdown_section "$file" "## PRD 覆盖矩阵")
    fi
    printf '%s\n' "$matrix_section"
}

extract_design_coverage_rows() {
    local design_file="$1"
    local coverage_section
    coverage_section=$(extract_markdown_section "$design_file" "## 覆盖表")
    printf '%s\n' "$coverage_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            unit = trim($2)
            requirement_type = trim($3)
            requirement_ref = trim($4)
            requirement_desc = trim($5)
            scope_id = trim($6)
            design_ref = trim($7)
            status = trim($8)

            if (unit == "" || unit == "UNIT" || unit ~ /^-+$/) next
            print unit "|" requirement_type "|" requirement_ref "|" requirement_desc "|" scope_id "|" design_ref "|" status
        }
    '
}

extract_plan_matrix_rows() {
    local matrix_section="$1"
    printf '%s\n' "$matrix_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            unit = trim($2)
            requirement_type = trim($3)
            requirement_ref = trim($4)
            requirement_desc = trim($5)
            scope_id = trim($6)
            design_ref = trim($7)
            task_ref = trim($8)
            test_ref = trim($9)
            impact = trim($10)
            coverage_status = trim($11)

            if (unit == "" || unit == "UNIT" || unit ~ /^-+$/) next
            print unit "|" requirement_type "|" requirement_ref "|" requirement_desc "|" scope_id "|" design_ref "|" task_ref "|" test_ref "|" impact "|" coverage_status
        }
    '
}

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

normalize_unit_name() {
    local value="$1"
    printf '%s' "$value" | sed -E 's/^UNIT-0*([0-9]+)$/UNIT-\1/'
}

normalize_requirement_ref() {
    local value="$1"
    printf '%s' "$value" | sed -E 's/[[:space:]]+//g'
}

normalize_design_ref() {
    local value="$1"
    printf '%s' "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

build_design_coverage_keys() {
    local design_file="$1"
    local rows
    rows=$(extract_design_coverage_rows "$design_file")
    printf '%s\n' "$rows" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        function normalize_unit(s) { s = trim(s); if (s ~ /^UNIT-0*[0-9]+$/) sub(/^UNIT-0*/, "UNIT-", s); return s }
        function normalize_requirement_ref(s) { s = trim(s); gsub(/[[:space:]]+/, "", s); return s }
        {
            unit = normalize_unit($1)
            requirement_type = trim($2)
            requirement_ref = normalize_requirement_ref($3)
            requirement_desc = trim($4)
            scope_id = trim($5)
            design_ref = trim($6)
            status = trim($7)
            print unit "|" requirement_type "|" requirement_ref "|" scope_id "|" design_ref
        }
    ' | sed '/^$/d' | sort -u
}

build_plan_matrix_keys() {
    local matrix_section="$1"
    local rows
    rows=$(extract_plan_matrix_rows "$matrix_section")
    printf '%s\n' "$rows" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        function normalize_unit(s) { s = trim(s); if (s ~ /^UNIT-0*[0-9]+$/) sub(/^UNIT-0*/, "UNIT-", s); return s }
        function normalize_requirement_ref(s) { s = trim(s); gsub(/[[:space:]]+/, "", s); return s }
        {
            unit = normalize_unit($1)
            requirement_type = trim($2)
            requirement_ref = normalize_requirement_ref($3)
            requirement_desc = trim($4)
            scope_id = trim($5)
            design_ref = trim($6)
            task_ref = trim($7)
            test_ref = trim($8)
            impact = trim($9)
            coverage_status = trim($10)
            print unit "|" requirement_type "|" requirement_ref "|" scope_id "|" design_ref
        }
    ' | sed '/^$/d' | sort -u
}

is_valid_plan_coverage_status() {
    local requirement_type="$1" coverage_status="$2"
    case "$requirement_type|$coverage_status" in
        AC\|COVERED|AC\|COVERED-NO-TEST|GAC\|COVERED|GAC\|COVERED-NO-TEST|EX\|EX-VERIFIED|EX\|EX-NO-TEST)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_allowed_plan_status_for_design() {
    local requirement_type="$1" design_status="$2" coverage_status="$3"

    if [ "$design_status" = "DESIGN-GAP" ]; then
        return 1
    fi
    if [ "$design_status" != "COVERED" ]; then
        return 1
    fi

    is_valid_plan_coverage_status "$requirement_type" "$coverage_status"
}

parse_plan_grade() {
    local plan_file="$1"
    local line value

    line=$(grep -E '(Phase[[:space:]]*3[[:space:]]*审查分级|审查分级)[[:space:]]*[:：]' "$plan_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E 's/.*[:：][[:space:]]*//')
    value=$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

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

extract_plan_gate_stages_for_grade() {
    local plan_file="$1" grade="$2"
    local gate_section matrix_section grade_line

    gate_section=$(extract_markdown_section "$plan_file" "## Phase 3 审查分级")
    matrix_section=$(printf '%s\n' "$gate_section" | sed -n '/^强门禁矩阵:/,/^>/p')
    grade_line=$(printf '%s\n' "$matrix_section" | grep -E "^[[:space:]]*-[[:space:]]*${grade}[[:space:]]*:" | head -1 || true)

    printf '%s\n' "$grade_line" | grep -oE 'REVIEW_[A-Z]+|QA_[A-Z]+' | while IFS= read -r stage; do
        [ -n "$stage" ] || continue
        if phase3_is_gate_stage "$stage"; then
            printf '%s\n' "$stage"
        fi
    done | sort -u || true
}

line_marks_stage_non_waivable() {
    local line="$1" stage="$2"
    printf '%s\n' "$line" | grep -qiE "(不可豁免|不得豁免|non-waivable|not waivable).{0,20}${stage}|${stage}.{0,20}(不可豁免|不得豁免|non-waivable|not waivable)"
}

extract_plan_waived_stages() {
    local plan_file="$1"
    local phase3_section line stage

    phase3_section=$(extract_markdown_section "$plan_file" "## Phase 3 审查分级")
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if ! printf '%s\n' "$line" | grep -qiE '豁免|waive|waiver'; then
            continue
        fi

        while IFS= read -r stage; do
            [ -n "$stage" ] || continue
            if ! phase3_is_gate_stage "$stage"; then
                continue
            fi
            if line_marks_stage_non_waivable "$line" "$stage"; then
                continue
            fi
            printf '%s\n' "$stage"
        done < <(printf '%s\n' "$line" | grep -oE 'REVIEW_[A-Z]+|QA_[A-Z]+' || true)
    done <<< "$phase3_section" | sort -u || true
}

check_phase3_gate_matrix() {
    local plan_file="$1" grade="$2"
    local gate_stages required_reviews required_qas required_stages missing_stages unexpected_stages stage waived_stages

    [ -n "$grade" ] || return 0

    gate_stages=$(extract_plan_gate_stages_for_grade "$plan_file" "$grade")
    if [ -z "$gate_stages" ]; then
        add_failure "T7c: plan.md 的「Phase 3 审查分级」缺少 ${grade} 对应的可解析强门禁矩阵"
        return 0
    fi

    required_reviews=$(phase3_required_review_stages "$grade" 2>/dev/null || true)
    required_qas=$(phase3_required_qa_stages "$grade" 2>/dev/null || true)
    required_stages=$(printf '%s\n%s\n' "$required_reviews" "$required_qas" | sed '/^$/d' | sort -u)

    missing_stages=$(comm -23 \
        <(printf '%s\n' "$required_stages" | sed '/^$/d' | sort -u) \
        <(printf '%s\n' "$gate_stages" | sed '/^$/d' | sort -u) \
        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
    unexpected_stages=$(comm -13 \
        <(printf '%s\n' "$required_stages" | sed '/^$/d' | sort -u) \
        <(printf '%s\n' "$gate_stages" | sed '/^$/d' | sort -u) \
        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')

    if [ -n "$missing_stages" ]; then
        add_failure "T7c: plan.md 的 Phase 3 强门禁矩阵与审查分级 ${grade} 不一致，缺少阶段：${missing_stages}"
    fi
    if [ -n "$unexpected_stages" ]; then
        add_failure "T7c: plan.md 的 Phase 3 强门禁矩阵与审查分级 ${grade} 不一致，多出阶段：${unexpected_stages}"
    fi

    waived_stages=$(extract_plan_waived_stages "$plan_file")
    while IFS= read -r stage; do
        [ -n "$stage" ] || continue
        if phase3_is_non_waivable_stage "$stage"; then
            add_failure "T7c: plan.md 试图豁免不可豁免阶段：${stage}"
        fi
    done <<< "$waived_stages"
}

check_plan_matrix_against_design() {
    local matrix_section="$1" design_file="$2"
    local design_keys plan_keys design_rows plan_rows normalized_unit normalized_ref normalized_design_ref design_key plan_key
    local unit requirement_type requirement_ref requirement_desc scope_id design_ref status task_ref test_ref impact coverage_status design_status

    design_rows=$(extract_design_coverage_rows "$design_file")
    design_keys=$(build_design_coverage_keys "$design_file")
    plan_keys=$(build_plan_matrix_keys "$matrix_section")

    while IFS='|' read -r unit requirement_type requirement_ref requirement_desc scope_id design_ref status; do
        [ -n "$unit" ] || continue

        normalized_unit=$(normalize_unit_name "$unit")
        normalized_ref=$(normalize_requirement_ref "$requirement_ref")
        normalized_design_ref=$(normalize_design_ref "$design_ref")
        design_key="${normalized_unit}|${requirement_type}|${normalized_ref}|${scope_id}|${normalized_design_ref}"

        if [ "$status" = "DESIGN-GAP" ]; then
            if printf '%s\n' "$plan_keys" | grep -qx "$design_key"; then
                add_failure "T6: design 覆盖表 ${unit}/${requirement_ref} 为 DESIGN-GAP，不得进入 plan 覆盖矩阵"
            fi
            continue
        fi

        if ! printf '%s\n' "$plan_keys" | grep -qx "$design_key"; then
            add_failure "T6: design 覆盖表 ${unit}/${requirement_ref} 未在 plan 覆盖矩阵中按 requirement_ref/scope_item_id/design_ref 完整承接"
        fi
    done <<< "$design_rows"

    plan_rows=$(extract_plan_matrix_rows "$matrix_section")
    while IFS='|' read -r unit requirement_type requirement_ref requirement_desc scope_id design_ref task_ref test_ref impact coverage_status; do
        [ -n "$unit" ] || continue

        normalized_unit=$(normalize_unit_name "$unit")
        normalized_ref=$(normalize_requirement_ref "$requirement_ref")
        normalized_design_ref=$(normalize_design_ref "$design_ref")
        plan_key="${normalized_unit}|${requirement_type}|${normalized_ref}|${scope_id}|${normalized_design_ref}"

        if ! printf '%s\n' "$design_keys" | grep -qx "$plan_key"; then
            add_failure "T6: plan 覆盖矩阵 ${unit}/${requirement_ref} 引用了 design 覆盖表未声明的 requirement_ref/scope_item_id/design_ref 组合"
            continue
        fi

        design_status=$(printf '%s\n' "$design_rows" | awk -F'|' -v key="$plan_key" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            function normalize_unit(s) { s = trim(s); if (s ~ /^UNIT-0*[0-9]+$/) sub(/^UNIT-0*/, "UNIT-", s); return s }
            function normalize_requirement_ref(s) { s = trim(s); gsub(/[[:space:]]+/, "", s); return s }
            {
                row_key = normalize_unit($1) "|" trim($2) "|" normalize_requirement_ref($3) "|" trim($5) "|" trim($6)
                if (row_key == key) {
                    print trim($7)
                    exit
                }
            }
        ')

        if ! is_allowed_plan_status_for_design "$requirement_type" "$design_status" "$coverage_status"; then
            add_failure "T6: plan 覆盖矩阵 ${unit}/${requirement_ref} 的 coverage_status=${coverage_status} 与 design status=${design_status:-missing} / requirement_type=${requirement_type} 不兼容"
        fi
        if is_placeholder_text "$design_ref"; then
            add_failure "T6: plan 覆盖矩阵 ${unit}/${requirement_ref} 缺少 design_ref"
        fi
        if is_placeholder_text "$test_ref"; then
            add_failure "T6: plan 覆盖矩阵 ${unit}/${requirement_ref} 缺少 test_ref"
        fi
        if is_placeholder_text "$task_ref" || ! printf '%s' "$task_ref" | grep -qE '^Task-[0-9]+$'; then
            add_failure "T6: plan 覆盖矩阵 ${unit}/${requirement_ref} 缺少有效 Task 引用"
        fi
    done <<< "$plan_rows"
}

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
            status = trim($9)
            print constraint_id "|" constraint_type "|" description "|" owner "|" affected_unit "|" scope_id "|" preflight_ref "|" test_ref
        }
    ' | sed '/^$/d' | sort -u
}

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
            mapped_task = trim($9)
            acceptance_evidence = trim($10)
            status = trim($11)
            print constraint_id "|" constraint_type "|" description "|" owner "|" affected_unit "|" scope_id "|" preflight_ref "|" test_ref
        }
    ' | sed '/^$/d' | sort -u
}

# T1: plan.md 存在且非空
if [ ! -f "$PLAN_FILE" ]; then
    add_failure "T1: plan.md 不存在：$PLAN_FILE"
elif [ ! -s "$PLAN_FILE" ]; then
    add_failure "T1: plan.md 为空：$PLAN_FILE"
fi

# T0: 前置输入存在性校验（prd.md + units/ + design.md）
if [ ! -f "$PRD_FILE" ]; then
    add_failure "T0: 缺少前置文档 prd.md：$PRD_FILE"
elif [ ! -s "$PRD_FILE" ]; then
    add_failure "T0: 前置文档 prd.md 为空：$PRD_FILE"
fi

if [ ! -d "$UNITS_DIR" ]; then
    add_failure "T0: 缺少前置目录 units/：$UNITS_DIR"
elif [ "$(find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' | wc -l | tr -d ' ')" = "0" ]; then
    add_failure "T0: units/ 目录下无 UNIT-*.md 文件：$UNITS_DIR"
fi

if [ ! -f "$DESIGN_FILE" ]; then
    add_failure "T0: 缺少前置文档 design.md：$DESIGN_FILE"
elif [ ! -s "$DESIGN_FILE" ]; then
    add_failure "T0: 前置文档 design.md 为空：$DESIGN_FILE"
fi

# test-cases.md 在 UNIT 级（Phase 下可能有多个 UNIT）
UNIT_TC_FILES=$(find "$WORK_DIR" -path '*/unit-*/test-cases.md' -type f 2>/dev/null | sort || true)
if [ -z "$UNIT_TC_FILES" ]; then
    add_failure "T0: Phase 工作区下未找到任何 unit-*/test-cases.md：$WORK_DIR"
fi

TEST_CASE_IDS=""
while IFS= read -r tc_file; do
    [ -n "$tc_file" ] && [ -f "$tc_file" ] || continue
    if [ ! -s "$tc_file" ]; then
        add_failure "T0: 前置文档为空：$tc_file"
        continue
    fi
    unit_tcs=$(sed -nE 's/^### (TC(-[A-Z][0-9]+)?-[0-9]+):.*/\1/p' "$tc_file" | sort -u || true)
    TEST_CASE_IDS="${TEST_CASE_IDS:+$TEST_CASE_IDS
}${unit_tcs}"
done <<< "$UNIT_TC_FILES"
TEST_CASE_IDS=$(printf '%s\n' "$TEST_CASE_IDS" | sed '/^$/d' | sort -u)
if [ -z "$TEST_CASE_IDS" ]; then
    add_failure "T0: 所有 test-cases.md 中未解析到任何 TC 编号（需包含 ### TC-NNN 或 ### TC-U{N}-NNN: 标题）"
fi

if [ ! -f "$PLAN_FILE" ] || [ ! -s "$PLAN_FILE" ]; then
    output_failures "技术负责人实施计划完整性检查未通过" "$WORK_DIR"
    exit 0
fi

PRD_CONSTRAINT_ROWS=""
PRD_CONSTRAINT_IDS=""
if [ -f "$PRD_FILE" ] && [ -s "$PRD_FILE" ]; then
    PRD_CONSTRAINT_ROWS=$(extract_prd_constraint_rows "$PRD_FILE")
    PRD_CONSTRAINT_IDS=$(printf '%s\n' "$PRD_CONSTRAINT_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort -u || true)
fi

# T0.1: Unit 级不应存在 plan.md（plan.md 应在 Phase 工作区）
for unit_plan in "$WORK_DIR"/unit-*/plan.md; do
    [ -f "$unit_plan" ] || continue
    rel_path="${unit_plan#"$WORK_DIR"/}"
    add_failure "${rel_path} 不应存在 — plan.md 应在 Phase 工作区（${WORK_DIR}/plan.md）"
done

# T2: plan.md 必需章节完整（标准模板 + legacy 兼容）
REQUIRED_SECTION_GROUPS=(
    "## 输入分析"
    "## Design 评审结论"
    "## PRD 前置约束映射"
    "## PRD / Design 覆盖矩阵|## PRD 覆盖矩阵"
    "## Scope Freeze 与映射矩阵"
    "## Task 清单|## Task 列表"
    "## 依赖关系"
    "## 并行策略|## 执行策略"
    "## Phase 3 审查分级"
    "## 前置验证点"
    "## 关键里程碑"
    "## 用户确认记录"
)

for section_group in "${REQUIRED_SECTION_GROUPS[@]}"; do
    IFS='|' read -r -a section_aliases <<< "$section_group"
    if ! has_any_fixed_section "$PLAN_FILE" "${section_aliases[@]}"; then
        add_failure "T2: plan.md 缺少章节：${section_aliases[0]}"
    fi
done

# T2.1: 用户确认记录
USER_CONFIRM_SECTION=$(extract_markdown_section "$PLAN_FILE" "## 用户确认记录")
if [ -z "$USER_CONFIRM_SECTION" ]; then
    add_failure "T2.1: plan.md 缺少「用户确认记录」章节"
else
    user_confirm_status=$(printf '%s\n' "$USER_CONFIRM_SECTION" \
        | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认状态[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
        | head -1 \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    user_confirm_time=$(printf '%s\n' "$USER_CONFIRM_SECTION" \
        | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认时间[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
        | head -1 \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    if [ "$user_confirm_status" != "确认" ]; then
        add_failure "T2.1: 用户确认记录状态必须为「确认」"
    fi
    if ! is_valid_confirmation_time "$user_confirm_time"; then
        add_failure "T2.1: 用户确认记录缺少有效确认时间（需使用 YYYY-MM-DD HH:mm 且不可为模板占位）"
    fi
fi

# T3-T5: Task 结构验证（逐 Task 强校验）
PLAN_MATRIX_SECTION=$(extract_plan_matrix_section "$PLAN_FILE")
PLAN_MATRIX_ROWS=$(printf '%s\n' "$PLAN_MATRIX_SECTION" | grep -E '^\|' || true)

TASK_IDS=$(sed -nE 's/^### (Task-[0-9]+).*/\1/p' "$PLAN_FILE")
TASK_COUNT=$(printf '%s\n' "$TASK_IDS" | sed '/^$/d' | wc -l | tr -d ' ')
TASK_SCOPE_PAIRS=""
TASK_CONSTRAINT_PAIRS=""
if [ "$TASK_COUNT" -eq 0 ]; then
    add_failure "T3: plan.md 未解析到任何 Task（需包含 ### Task-N 标题）"
else
    while IFS= read -r task_id; do
        [ -n "$task_id" ] || continue
        TASK_BLOCK=$(extract_task_block "$PLAN_FILE" "$task_id")

        task_block_has_field "$TASK_BLOCK" '文件|file_path' \
            || add_failure "T3: ${task_id} 缺少 文件/file_path 字段"

        task_block_has_field "$TASK_BLOCK" 'design_ref' \
            || add_failure "T4: ${task_id} 缺少 design_ref 字段"
        task_block_has_field "$TASK_BLOCK" 'scope_item_ref' \
            || add_failure "T4: ${task_id} 缺少 scope_item_ref 字段"
        task_block_has_field "$TASK_BLOCK" 'constraint_ref' \
            || add_failure "T4: ${task_id} 缺少 constraint_ref 字段"
        task_block_has_field "$TASK_BLOCK" 'unit_ref' \
            || add_failure "T4: ${task_id} 缺少 unit_ref 字段"
        task_block_has_field "$TASK_BLOCK" 'api_ref' \
            || add_failure "T4: ${task_id} 缺少 api_ref 字段"
        task_block_has_field "$TASK_BLOCK" 'test_ref' \
            || add_failure "T4: ${task_id} 缺少 test_ref 字段"

        task_block_has_field "$TASK_BLOCK" 'depends_on' \
            || add_failure "T5: ${task_id} 缺少 depends_on 字段"
        task_block_has_field "$TASK_BLOCK" 'shared_files' \
            || add_failure "T5: ${task_id} 缺少 shared_files 字段"
        task_block_has_field "$TASK_BLOCK" 'impact_files' \
            || add_failure "T5: ${task_id} 缺少 impact_files 字段"

        scope_item_ref_value=$(extract_task_field_value "$TASK_BLOCK" "scope_item_ref")
        scope_targets=$(printf '%s' "$scope_item_ref_value" | grep -oE 'SCOPE-P[0-9]+U[0-9]+-[0-9]+' | sort -u || true)
        if [ -z "$scope_targets" ]; then
            add_failure "T4: ${task_id} scope_item_ref 未引用任何 scope_item_id"
        else
            while IFS= read -r scope_id; do
                [ -n "$scope_id" ] || continue
                TASK_SCOPE_PAIRS="${TASK_SCOPE_PAIRS}${scope_id}|${task_id}
"
            done <<< "$scope_targets"
        fi

        constraint_ref_value=$(extract_task_field_value "$TASK_BLOCK" "constraint_ref")
        constraint_targets=$(printf '%s' "$constraint_ref_value" | grep -oE 'CON-[0-9]{3,}' | sort -u || true)
        if [ -z "$constraint_targets" ]; then
            normalized_constraint_ref=$(printf '%s' "$constraint_ref_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
            if [ "$normalized_constraint_ref" != "无" ]; then
                add_failure "T4: ${task_id} constraint_ref 未引用任何 Constraint ID，且未显式写无"
            fi
        else
            while IFS= read -r constraint_id; do
                [ -n "$constraint_id" ] || continue
                TASK_CONSTRAINT_PAIRS="${TASK_CONSTRAINT_PAIRS}${constraint_id}|${task_id}
"
            done <<< "$constraint_targets"
        fi

        test_ref_value=$(extract_task_field_value "$TASK_BLOCK" "test_ref")
        if [ -n "$test_ref_value" ]; then
            test_targets=$(printf '%s' "$test_ref_value" | grep -oE 'TC(-[A-Z][0-9]+)?-[0-9]+' | sort -u || true)
            if [ -z "$test_targets" ]; then
                add_failure "T4: ${task_id} test_ref 未引用任何 TC 编号"
            elif [ -n "$TEST_CASE_IDS" ]; then
                while IFS= read -r tc_id; do
                    [ -n "$tc_id" ] || continue
                    if ! printf '%s\n' "$TEST_CASE_IDS" | grep -qx "$tc_id"; then
                        add_failure "T4: ${task_id} test_ref 指向不存在的测试用例：${tc_id}"
                    fi
                done <<< "$test_targets"
            fi

            matrix_task_rows=$(printf '%s\n' "$PLAN_MATRIX_ROWS" | awk -F'|' -v task="$task_id" '
                function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
                /^\|/ {
                    task_col = trim($6)
                    if (!(task_col ~ /^Task-[0-9]+$/)) task_col = trim($7)
                    if (task_col == "" || task_col == "Task" || task_col ~ /^-+$/) next
                    if (task_col == task) print $0
                }
            ')
            if [ -z "$matrix_task_rows" ]; then
                add_failure "T6: 覆盖矩阵未找到 ${task_id} 对应行"
            else
                matrix_test_targets=$(printf '%s\n' "$matrix_task_rows" | awk -F'|' '
                    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
                    /^\|/ {
                        task_col = trim($6)
                        if (task_col ~ /^Task-[0-9]+$/) {
                            ref_col = trim($7)
                        } else {
                            ref_col = trim($8)
                        }
                        if (ref_col != "" && ref_col !~ /^-+$/) print ref_col
                    }
                ' | grep -oE 'TC(-[A-Z][0-9]+)?-[0-9]+' | sort -u || true)

                if [ -z "$matrix_test_targets" ]; then
                    add_failure "T6: 覆盖矩阵中 ${task_id} 的 test_ref 列未声明任何 TC 编号"
                else
                    missing_matrix_tcs=$(comm -23 \
                        <(printf '%s\n' "$test_targets" | sed '/^$/d' | sort -u) \
                        <(printf '%s\n' "$matrix_test_targets" | sed '/^$/d' | sort -u) \
                        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
                    extra_matrix_tcs=$(comm -13 \
                        <(printf '%s\n' "$test_targets" | sed '/^$/d' | sort -u) \
                        <(printf '%s\n' "$matrix_test_targets" | sed '/^$/d' | sort -u) \
                        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')

                    [ -z "$missing_matrix_tcs" ] || add_failure "T6: ${task_id} test_ref 与覆盖矩阵不一致（矩阵缺少：${missing_matrix_tcs}）"
                    [ -z "$extra_matrix_tcs" ] || add_failure "T6: ${task_id} test_ref 与覆盖矩阵不一致（矩阵多出：${extra_matrix_tcs}）"
                fi
            fi
        fi

        unit_ref_value=$(extract_task_field_value "$TASK_BLOCK" "unit_ref")
        if [ -n "$unit_ref_value" ] && [ -d "$UNITS_DIR" ]; then
            unit_targets=$(printf '%s' "$unit_ref_value" | grep -oE 'UNIT-[0-9]+' | sort -u || true)
            while IFS= read -r unit_id; do
                [ -n "$unit_id" ] || continue
                if [ ! -f "$UNITS_DIR/${unit_id}.md" ]; then
                    add_failure "T4: ${task_id} unit_ref 指向不存在的 UNIT 文件：${unit_id}"
                fi
            done <<< "$unit_targets"
        fi

        design_ref_value=$(extract_task_field_value "$TASK_BLOCK" "design_ref")
        if [ -n "$design_ref_value" ]; then
            mod_targets=$(printf '%s' "$design_ref_value" | grep -oE 'MOD-[0-9]+' | sort -u || true)
            while IFS= read -r mod_id; do
                [ -n "$mod_id" ] || continue
                if [ ! -f "$PHASE_DIR/design/${mod_id}.md" ]; then
                    add_failure "T4: ${task_id} design_ref 指向不存在的 MOD 文件：${mod_id}"
                fi
            done <<< "$mod_targets"
        fi

        if [ -n "$constraint_targets" ]; then
            while IFS= read -r constraint_id; do
                [ -n "$constraint_id" ] || continue
                if ! printf '%s\n' "$PRD_CONSTRAINT_IDS" | grep -qx "$constraint_id"; then
                    add_failure "T4: ${task_id} constraint_ref 指向 PRD 前置约束未声明的 Constraint ID：${constraint_id}"
                fi
            done <<< "$constraint_targets"
        fi
    done <<< "$TASK_IDS"
fi

# T6.1: 覆盖矩阵不得引用 Task 清单未定义的任务（反向一致性）
MATRIX_TASK_IDS=$(printf '%s\n' "$PLAN_MATRIX_ROWS" | awk -F'|' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^\|/ {
        task_col = trim($6)
        if (!(task_col ~ /^Task[- ][0-9]+$/)) task_col = trim($7)
        if (task_col == "" || task_col == "Task" || task_col ~ /^-+$/) next
        gsub(/Task[ ]+/, "Task-", task_col)
        if (task_col ~ /^Task-[0-9]+$/) print task_col
    }
' | sort -u || true)

if [ -n "$MATRIX_TASK_IDS" ] && [ -n "$TASK_IDS" ]; then
    EXTRA_MATRIX_TASKS=$(comm -23 \
        <(printf '%s\n' "$MATRIX_TASK_IDS" | sed '/^$/d' | sort -u) \
        <(printf '%s\n' "$TASK_IDS" | sed '/^$/d' | sort -u) \
        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
    [ -z "$EXTRA_MATRIX_TASKS" ] || add_failure "T6: 覆盖矩阵存在未在 Task 清单定义的任务：${EXTRA_MATRIX_TASKS}"
fi

# T6: PRD 覆盖矩阵无 UNCOVERED/DESIGN-GAP，且必须逐行消费 design 覆盖表
MATRIX_SECTION=$(extract_plan_matrix_section "$PLAN_FILE")
MATRIX_ROWS=$(printf '%s\n' "$MATRIX_SECTION" | grep -E '^\|' || true)
if [ -n "$MATRIX_ROWS" ] && printf '%s\n' "$MATRIX_ROWS" | grep -qE '\|[[:space:]]*(UNCOVERED|DESIGN-GAP)[[:space:]]*\|[[:space:]]*$'; then
    add_failure "T6: PRD 覆盖矩阵存在 UNCOVERED 或 DESIGN-GAP 行"
fi

DESIGN_COVERAGE_ROWS=""
DESIGN_COVERAGE_COUNT=0
if [ -f "$DESIGN_FILE" ] && [ -s "$DESIGN_FILE" ]; then
    DESIGN_COVERAGE_ROWS=$(extract_design_coverage_rows "$DESIGN_FILE")
    DESIGN_COVERAGE_COUNT=$(printf '%s\n' "$DESIGN_COVERAGE_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
fi
if [ "$DESIGN_COVERAGE_COUNT" -eq 0 ]; then
    add_failure "T6: design.md 覆盖表缺少数据行，无法校验追踪链"
else
    check_plan_matrix_against_design "$MATRIX_SECTION" "$DESIGN_FILE"
fi

# T6.1b: PRD 前置约束映射闭环校验
PLAN_CONSTRAINT_ROWS=$(extract_plan_constraint_rows "$PLAN_FILE")
PLAN_CONSTRAINT_COUNT=$(printf '%s\n' "$PLAN_CONSTRAINT_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
PRD_CONSTRAINT_COUNT=$(printf '%s\n' "$PRD_CONSTRAINT_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')

if [ "$PRD_CONSTRAINT_COUNT" -gt 0 ] && [ "$PLAN_CONSTRAINT_COUNT" -eq 0 ]; then
    add_failure "T6.1b: PRD 存在前置约束，但 plan.md 缺少「PRD 前置约束映射」数据行"
elif [ "$PRD_CONSTRAINT_COUNT" -eq 0 ] && [ "$PLAN_CONSTRAINT_COUNT" -gt 0 ]; then
    add_failure "T6.1b: plan.md 存在前置约束映射，但 PRD 未声明任何前置约束"
elif [ "$PLAN_CONSTRAINT_COUNT" -gt 0 ]; then
    prd_constraint_pairs=$(build_prd_constraint_pairs "$PRD_CONSTRAINT_ROWS")
    plan_constraint_pairs=$(build_plan_constraint_pairs "$PLAN_CONSTRAINT_ROWS")
    plan_constraint_ids=$(printf '%s\n' "$PLAN_CONSTRAINT_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort -u || true)
    dup_plan_constraint_ids=$(printf '%s\n' "$PLAN_CONSTRAINT_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
    if [ -n "$dup_plan_constraint_ids" ]; then
        add_failure "T6.1b: PRD 前置约束映射存在重复 Constraint ID：$(printf '%s' "$dup_plan_constraint_ids" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
    fi

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref mapped_task acceptance_evidence status; do
        [ -n "$constraint_id" ] || continue

        if ! printf '%s' "$constraint_id" | grep -qE '^CON-[0-9]{3,}$'; then
            add_failure "T6.1b: 存在非法 Constraint ID：${constraint_id}"
        fi
        if ! printf '%s\n' "$PRD_CONSTRAINT_IDS" | grep -qx "$constraint_id"; then
            add_failure "T6.1b: ${constraint_id} 未在 PRD 前置约束中声明"
        fi
        if is_placeholder_text "$constraint_type"; then
            add_failure "T6.1b: ${constraint_id} 缺少类型"
        fi
        if is_placeholder_text "$description"; then
            add_failure "T6.1b: ${constraint_id} 缺少约束内容"
        fi
        if is_placeholder_text "$owner"; then
            add_failure "T6.1b: ${constraint_id} 缺少 Owner"
        fi
        if is_placeholder_text "$affected_unit"; then
            add_failure "T6.1b: ${constraint_id} 缺少影响 UNIT"
        elif ! printf '%s' "$affected_unit" | grep -qE '(UNIT-[0-9]+|全局)'; then
            add_failure "T6.1b: ${constraint_id} 的影响 UNIT 必须包含 UNIT-N 或 全局"
        fi
        if is_placeholder_text "$scope_id" || ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
            add_failure "T6.1b: ${constraint_id} 缺少有效 scope_item_id"
        fi
        if is_placeholder_text "$preflight_ref"; then
            add_failure "T6.1b: ${constraint_id} 缺少 preflight_ref"
        fi
        normalized_test_ref=$(printf '%s' "$test_ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$normalized_test_ref" && ! printf '%s' "$normalized_test_ref" | grep -qiE '^N/?A$'; then
            add_failure "T6.1b: ${constraint_id} 缺少 test_ref"
        fi
        if is_placeholder_text "$mapped_task" || ! printf '%s' "$mapped_task" | grep -qE '^Task-[0-9]+$'; then
            add_failure "T6.1b: ${constraint_id} 缺少有效映射 Task"
        elif ! printf '%s\n' "$TASK_IDS" | grep -qx "$mapped_task"; then
            add_failure "T6.1b: ${constraint_id} 映射到未定义 Task：${mapped_task}"
        fi
        if is_placeholder_text "$acceptance_evidence"; then
            add_failure "T6.1b: ${constraint_id} 缺少验收证据"
        fi
        if [ "$status" != "MAPPED" ] && [ "$status" != "VERIFIED" ]; then
            add_failure "T6.1b: ${constraint_id} 状态为 ${status}（仅允许 MAPPED/VERIFIED）"
        fi
        if ! printf '%s\n' "$TASK_CONSTRAINT_PAIRS" | grep -qE "^${constraint_id}\|${mapped_task}$"; then
            add_failure "T6.1b: ${constraint_id} 未在 ${mapped_task} 的 constraint_ref 中声明（blackbox/orphan 映射）"
        fi
    done <<< "$PLAN_CONSTRAINT_ROWS"

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref status; do
        [ -n "$constraint_id" ] || continue
        prd_pair="${constraint_id}|${constraint_type}|${description}|${owner}|${affected_unit}|${scope_id}|${preflight_ref}|${test_ref}"
        if ! newline_list_contains_literal "$plan_constraint_pairs" "$prd_pair"; then
            add_failure "T6.1b: PRD 前置约束 ${constraint_id} 未在 plan 映射表中按 type/description/owner/affected_unit/scope_item_id/preflight_ref/test_ref 完整承接"
        fi
    done <<< "$PRD_CONSTRAINT_ROWS"

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref mapped_task acceptance_evidence status; do
        [ -n "$constraint_id" ] || continue
        plan_pair="${constraint_id}|${constraint_type}|${description}|${owner}|${affected_unit}|${scope_id}|${preflight_ref}|${test_ref}"
        if ! newline_list_contains_literal "$prd_constraint_pairs" "$plan_pair"; then
            add_failure "T6.1b: plan 前置约束映射 ${constraint_id} 引用了 PRD 未声明的 type/description/owner/affected_unit/scope_item_id/preflight_ref/test_ref 组合"
        fi
    done <<< "$PLAN_CONSTRAINT_ROWS"
fi

# T6.2: Scope Freeze 与映射矩阵闭环校验（无 orphan / blackbox）
DESIGN_SCOPE_IDS=""
if [ -f "$DESIGN_FILE" ] && [ -s "$DESIGN_FILE" ]; then
    DESIGN_SCOPE_IDS=$(extract_design_scope_ids "$DESIGN_FILE")
fi
if [ -z "$DESIGN_SCOPE_IDS" ]; then
    add_failure "T6.2: design.md 未解析到任何 scope_item_id（需在「影响访问清单」或「影响范围清单」定义）"
fi

FREEZE_ROWS=$(extract_scope_freeze_rows "$PLAN_FILE")
FREEZE_COUNT=$(printf '%s\n' "$FREEZE_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$FREEZE_COUNT" -eq 0 ]; then
    add_failure "T6.2: plan.md「Scope Freeze 与映射矩阵」缺少数据行"
else
    FREEZE_SCOPE_IDS=$(printf '%s\n' "$FREEZE_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort -u || true)
    FREEZE_TASK_IDS=$(printf '%s\n' "$FREEZE_ROWS" | awk -F'|' '{print $4}' | sed '/^$/d' | sort -u || true)

    dup_freeze_scope_ids=$(printf '%s\n' "$FREEZE_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
    if [ -n "$dup_freeze_scope_ids" ]; then
        add_failure "T6.2: Scope Freeze 存在重复 scope_item_id：$(printf '%s' "$dup_freeze_scope_ids" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
    fi

    while IFS='|' read -r scope_id change_type risk mapped_task test_ref impact_files rollback_ref status; do
        [ -n "$scope_id" ] || continue

        if ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
            add_failure "T6.2: Scope Freeze 存在非法 scope_item_id：${scope_id}"
        fi
        if is_placeholder_text "$mapped_task" || ! printf '%s' "$mapped_task" | grep -qE '^Task-[0-9]+$'; then
            add_failure "T6.2: ${scope_id} 缺少有效映射 Task"
        elif ! printf '%s\n' "$TASK_IDS" | grep -qx "$mapped_task"; then
            add_failure "T6.2: ${scope_id} 映射到未定义 Task：${mapped_task}"
        fi
        if is_placeholder_text "$test_ref" || ! printf '%s' "$test_ref" | grep -qE 'TC(-[A-Z][0-9]+)?-[0-9]+'; then
            add_failure "T6.2: ${scope_id} 缺少有效 test_ref"
        fi
        if is_placeholder_text "$impact_files"; then
            add_failure "T6.2: ${scope_id} 缺少 impact_files"
        fi
        if is_placeholder_text "$rollback_ref"; then
            add_failure "T6.2: ${scope_id} 缺少 rollback_ref"
        fi
        if [ "$status" != "FROZEN" ]; then
            add_failure "T6.2: ${scope_id} 状态为 ${status}（必须为 FROZEN）"
        fi
        if ! printf '%s\n' "$TASK_SCOPE_PAIRS" | grep -qE "^${scope_id}\|${mapped_task}$"; then
            add_failure "T6.2: ${scope_id} 未在 ${mapped_task} 的 scope_item_ref 中声明（blackbox/orphan 映射）"
        fi
    done <<< "$FREEZE_ROWS"

    while IFS= read -r design_scope_id; do
        [ -n "$design_scope_id" ] || continue
        if ! printf '%s\n' "$FREEZE_SCOPE_IDS" | grep -qx "$design_scope_id"; then
            add_failure "T6.2: design.md 中 ${design_scope_id} 未在 Scope Freeze 映射（orphan）"
        fi
    done <<< "$DESIGN_SCOPE_IDS"

    if [ -n "$TASK_SCOPE_PAIRS" ]; then
        while IFS='|' read -r task_scope_id task_scope_task; do
            [ -n "$task_scope_id" ] || continue
            if ! printf '%s\n' "$FREEZE_SCOPE_IDS" | grep -qx "$task_scope_id"; then
                add_failure "T6.2: ${task_scope_task} 的 ${task_scope_id} 未出现在 Scope Freeze 矩阵"
            fi
        done <<< "$TASK_SCOPE_PAIRS"
    fi
fi

# T7: Task AC 无模糊词
FUZZY_LINES=$(grep -nE '(基本上|应该|可能|大概|差不多)' "$PLAN_FILE" 2>/dev/null | head -5 || true)
if [ -n "$FUZZY_LINES" ]; then
    add_failure "T7: plan.md 含模糊用词（HARD-GATE 4）：\n${FUZZY_LINES}"
fi

# T7b: Phase 3 审查分级必须可解析（且非模板占位）
PHASE3_GRADE_LINE=$(grep -E '审查分级[[:space:]]*[:：]' "$PLAN_FILE" 2>/dev/null | head -1 || true)
PHASE3_GRADE_VALUE=$(printf '%s' "$PHASE3_GRADE_LINE" | sed -E 's/.*[:：][[:space:]]*//')
PHASE3_GRADE_VALUE=$(printf '%s' "$PHASE3_GRADE_VALUE" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

if [ -z "$PHASE3_GRADE_VALUE" ]; then
    add_failure "T7b: plan.md 缺少 Phase 3 审查分级字段"
elif printf '%s' "$PHASE3_GRADE_VALUE" | grep -qE '[|/]'; then
    add_failure "T7b: plan.md 的 Phase 3 审查分级仍是模板占位值（${PHASE3_GRADE_VALUE}）"
elif printf '%s' "$PHASE3_GRADE_VALUE" | grep -qE '\{.*\}'; then
    add_failure "T7b: plan.md 的 Phase 3 审查分级仍是模板占位值（${PHASE3_GRADE_VALUE}）"
elif ! printf '%s' "$PHASE3_GRADE_VALUE" | grep -qE '^(轻量|标准|完整)$'; then
    add_failure "T7b: plan.md 的 Phase 3 审查分级非法（${PHASE3_GRADE_VALUE}）"
fi

check_phase3_gate_matrix "$PLAN_FILE" "$PHASE3_GRADE_VALUE"

# T8: design-review-N.md 存在且有评审结论（在 WORK_DIR 下查找）
REVIEW_FILES=$(find "$WORK_DIR" -maxdepth 1 -type f -name 'design-review-[0-9]*.md' 2>/dev/null | sort)
if [ -z "$REVIEW_FILES" ]; then
    add_failure "T8: design-review-N.md 不存在于 $WORK_DIR/"
else
    LATEST_REVIEW_FILE=""
    LATEST_REVIEW_INDEX=-1
    while IFS= read -r review_file; do
        [ -n "$review_file" ] || continue
        review_base=$(basename "$review_file")
        review_index=$(printf '%s' "$review_base" | sed -nE 's/^design-review-([0-9]+)\.md$/\1/p')

        if [ ! -s "$review_file" ]; then
            add_failure "T8: 审查文件为空：$review_file"
            continue
        fi
        if ! grep -qE '(DESIGN_OK|DESIGN_ISSUE)' "$review_file" 2>/dev/null; then
            add_failure "T8: 审查文件缺少评审结论（DESIGN_OK/DESIGN_ISSUE）：$(basename "$review_file")"
        fi

        if [ -n "$review_index" ] && [ "$review_index" -gt "$LATEST_REVIEW_INDEX" ]; then
            LATEST_REVIEW_INDEX="$review_index"
            LATEST_REVIEW_FILE="$review_file"
        fi
    done <<< "$REVIEW_FILES"

    if [ -z "$LATEST_REVIEW_FILE" ]; then
        add_failure "T8: 无法确定最新 design-review-N.md 审查文件"
    else
        if grep -qE 'REVIEW:[[:space:]]*DESIGN_ISSUE' "$LATEST_REVIEW_FILE" 2>/dev/null; then
            add_failure "T8: 最新设计评审结论为 DESIGN_ISSUE，禁止输出 plan.md：$(basename "$LATEST_REVIEW_FILE")"
        fi
        if ! grep -qE 'REVIEW:[[:space:]]*DESIGN_OK' "$LATEST_REVIEW_FILE" 2>/dev/null; then
            add_failure "T8: 最新设计评审缺少 DESIGN_OK 结论：$(basename "$LATEST_REVIEW_FILE")"
        fi
    fi
fi

extract_independent_review_status() {
    local plan_file="$1"
    local line value

    line=$(grep -E '独立审查收敛状态[[:space:]]*[:：]' "$plan_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E 's/.*[:：][[:space:]]*//')
    value=$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

    if printf '%s' "$value" | grep -qE '[|/]'; then
        printf '%s' ""
        return 0
    fi
    if printf '%s' "$value" | grep -qE '\{.*\}'; then
        printf '%s' ""
        return 0
    fi

    case "$value" in
        REVIEW_PASS|"FAIL 已修正")
            printf '%s' "$value"
            ;;
        *)
            printf '%s' ""
            ;;
    esac
}

# T9: 独立审查已执行（plan.md 必须填写结构化收敛状态）
INDEPENDENT_REVIEW_STATUS=$(extract_independent_review_status "$PLAN_FILE")
if [ -z "$INDEPENDENT_REVIEW_STATUS" ]; then
    add_failure "T9: plan.md 缺少有效的独立审查收敛状态（仅允许 REVIEW_PASS / FAIL 已修正）"
fi

output_failures "技术负责人实施计划完整性检查未通过" "$WORK_DIR"
exit 0
