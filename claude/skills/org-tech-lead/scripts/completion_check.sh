#!/bin/bash
# 技术负责人实施计划完整性自动检查脚本
# 触发时机: tech-lead skill-local Stop
# 功能: 检查 plan.md 的 Task 结构完整性与 Design 审查闭环

set -euo pipefail

source "$HOME/.claude/hooks/lib/common.sh"
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
    return 1
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
    "## PRD / Design 覆盖矩阵|## PRD 覆盖矩阵"
    "## Scope Freeze 与映射矩阵"
    "## Task 清单|## Task 列表"
    "## 依赖关系"
    "## 并行策略|## 执行策略"
    "## Phase 3 审查分级"
    "## 前置验证点"
    "## 关键里程碑"
)

for section_group in "${REQUIRED_SECTION_GROUPS[@]}"; do
    IFS='|' read -r -a section_aliases <<< "$section_group"
    if ! has_any_fixed_section "$PLAN_FILE" "${section_aliases[@]}"; then
        add_failure "T2: plan.md 缺少章节：${section_aliases[0]}"
    fi
done

# T3-T5: Task 结构验证（逐 Task 强校验）
PLAN_MATRIX_SECTION=$(extract_plan_matrix_section "$PLAN_FILE")
PLAN_MATRIX_ROWS=$(printf '%s\n' "$PLAN_MATRIX_SECTION" | grep -E '^\|' || true)

TASK_IDS=$(sed -nE 's/^### (Task-[0-9]+).*/\1/p' "$PLAN_FILE")
TASK_COUNT=$(printf '%s\n' "$TASK_IDS" | sed '/^$/d' | wc -l | tr -d ' ')
TASK_SCOPE_PAIRS=""
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

# T6: PRD 覆盖矩阵无 UNCOVERED/DESIGN-GAP（仅检查矩阵数据行）
MATRIX_SECTION=$(extract_plan_matrix_section "$PLAN_FILE")
MATRIX_ROWS=$(printf '%s\n' "$MATRIX_SECTION" | grep -E '^\|' || true)
if [ -n "$MATRIX_ROWS" ] && printf '%s\n' "$MATRIX_ROWS" | grep -qE '\|[[:space:]]*(UNCOVERED|DESIGN-GAP)[[:space:]]*\|[[:space:]]*$'; then
    add_failure "T6: PRD 覆盖矩阵存在 UNCOVERED 或 DESIGN-GAP 行"
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

# T9: 独立审查已执行（plan.md 含审查结论标记）
if ! grep -qE '(独立审查|REVIEW_PASS|审查.*通过|FAIL.*已修正|审查结论)' "$PLAN_FILE" 2>/dev/null; then
    add_failure "T9: plan.md 中缺少独立审查结论标记"
fi

output_failures "技术负责人实施计划完整性检查未通过" "$WORK_DIR"
exit 0
