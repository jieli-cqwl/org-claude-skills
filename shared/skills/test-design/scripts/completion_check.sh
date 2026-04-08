#!/bin/bash
# 测试设计文档完整性自动检查脚本
# 执行时机: 审查收敛并准备交付 /tech-lead 前显式运行
# 功能: 精确定位当前 feature，并检查 test-cases.md/主文档内嵌审查闭环
# 版本: v3.0 2026-03-23

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
test-design/completion_check.sh — 测试设计文档完整性自动检查脚本
执行时机: 审查收敛并准备交付 /tech-lead 前显式运行
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
hook_init
export HOOK_STRICT_BLOCK=1

# test-design 覆盖 common.sh 的 is_placeholder_text：
# 不含日期格式模式检查，因为 YYYY-MM-DD/HH:mm 等在测试用例中是合法的对照输入
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

# --- Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/unit-[0-9]+/)?(test-cases\.md)'
resolve_feature_dir "docs/*/phase-*/unit-*/test-cases.md" "$TRANSCRIPT_PATTERN" "test-cases.md" "docs/*/phase-*/unit-*"
output_failures "测试设计文档完整性检查未通过" ""

# --- PRD 驱动工作区定位 ---
resolve_work_dir_from_prd "$FEATURE_DIR" "test-cases.md"
WORK_DIR="$UNIT_WORK_DIR"

TEST_CASES_FILE="$WORK_DIR/test-cases.md"
UNITS_DIR="$FEATURE_DIR/units"
PRD_FILE="$FEATURE_DIR/prd.md"
PHASE_DIR=$(derive_phase_dir "$WORK_DIR")
DESIGN_FILE="$PHASE_DIR/design.md"

parse_stat_count() {
    local stats_section="$1" label="$2"
    printf '%s\n' "$stats_section" \
        | sed -nE "s/^\\|[[:space:]]*${label}[[:space:]]*\\|[[:space:]]*([0-9]+)[[:space:]]*\\|.*$/\\1/p" \
        | head -1
}

count_tc_type() {
    local test_section="$1" label="$2"
    printf '%s\n' "$test_section" \
        | { grep -E "^[[:space:]]*-[[:space:]]*(\\*\\*)?类型(\\*\\*)?[[:space:]]*[:：].*${label}" || true; } \
        | wc -l | tr -d ' '
}

extract_tc_ids_from_rows() {
    local rows="$1"
    printf '%s\n' "$rows" | grep -oE 'TC(-[A-Z][0-9]+)?-[0-9]+' | sort -u || true
}

get_tc_type_by_id() {
    local test_section="$1" tc_id="$2"
    local tc_block type_line type_value

    tc_block=$(printf '%s\n' "$test_section" | awk -v id="$tc_id" '
        $0 ~ ("^### " id ":") { in_block=1; next }
        in_block && /^### / { exit }
        in_block { print }
    ')
    type_line=$(printf '%s\n' "$tc_block" | grep -E '^[[:space:]]*-[[:space:]]*(\*\*)?类型(\*\*)?[[:space:]]*[:：]' | head -1 || true)
    type_value=$(printf '%s' "$type_line" | sed -E 's/^[^:：]*[:：][[:space:]]*//; s/[`*]//g')

    if printf '%s' "$type_value" | grep -q "正例"; then
        printf '%s' "正例"
    elif printf '%s' "$type_value" | grep -q "反例"; then
        printf '%s' "反例"
    elif printf '%s' "$type_value" | grep -q "边界"; then
        printf '%s' "边界"
    elif printf '%s' "$type_value" | grep -q "排除项验证"; then
        printf '%s' "排除项验证"
    else
        printf '%s' ""
    fi
}

collect_scope_unit_files() {
    local unit_view_section="$1" matrix_section="$2"
    local unit_ids unit_id files num unit_plain unit_padded

    files=""
    unit_ids=$(printf '%s\n%s\n' "$unit_view_section" "$matrix_section" | grep -oE 'UNIT-[0-9]+' | sort -u || true)
    while IFS= read -r unit_id; do
        [ -n "$unit_id" ] || continue
        if [ -f "$UNITS_DIR/${unit_id}.md" ]; then
            files="${files:+$files
}$UNITS_DIR/${unit_id}.md"
        fi
    done <<< "$unit_ids"

    if [ -z "$files" ]; then
        if [[ "$WORK_DIR" =~ /unit-([0-9]+)$ ]]; then
            num="${BASH_REMATCH[1]}"
            unit_plain="UNIT-${num}"
            unit_padded=$(printf 'UNIT-%03d' "$num")

            if [ -f "$UNITS_DIR/${unit_padded}.md" ]; then
                files="${files:+$files
}$UNITS_DIR/${unit_padded}.md"
            fi
            if [ -f "$UNITS_DIR/${unit_plain}.md" ]; then
                files="${files:+$files
}$UNITS_DIR/${unit_plain}.md"
            fi
        fi
    fi

    if [ -z "$files" ] && [ -d "$UNITS_DIR" ]; then
        files=$(find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' 2>/dev/null | sort || true)
    fi

    printf '%s\n' "$files" | sed '/^$/d'
}

extract_eq_matrix_rows() {
    local eq_section="$1"
    printf '%s\n' "$eq_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            scope_id = trim($2)
            ac_ref = trim($3)
            tc_ref = trim($4)
            compare_input = trim($5)
            invariant = trim($6)
            eq_status = trim($7)
            note = trim($8)

            if (scope_id == "" || scope_id == "scope_item_id" || scope_id ~ /^-+$/) next
            print scope_id "|" ac_ref "|" tc_ref "|" compare_input "|" invariant "|" eq_status "|" note
        }
    '
}

check_tc_verification() {
    local test_section="$1"
    local tc_ids tc_id tc_block verification_line verification_value

    tc_ids=$(printf '%s\n' "$test_section" | sed -nE 's/^### (TC(-[A-Z][0-9]+)?-[0-9]+):.*/\1/p')
    if [ -z "$tc_ids" ]; then
        add_failure "测试用例章节未解析到任何 TC 编号（需存在 ### TC-NNN: 标题）"
        return
    fi

    while IFS= read -r tc_id; do
        [ -n "$tc_id" ] || continue
        tc_block=$(printf '%s\n' "$test_section" | awk -v id="$tc_id" '
            $0 ~ ("^### " id ":") { in_block=1; next }
            in_block && /^### / { exit }
            in_block { print }
        ')

        verification_line=$(printf '%s\n' "$tc_block" | grep -E '^[[:space:]]*-[[:space:]]*(\*\*)?(验证命令|验证步骤|验证方式)(\*\*)?[[:space:]]*[:：]' | head -1 || true)
        if [ -z "$verification_line" ]; then
            add_failure "${tc_id} 缺少可执行验证字段（验证命令/验证步骤/验证方式）"
            continue
        fi

        verification_value=$(printf '%s' "$verification_line" | sed -E 's/^[^:：]*[:：][[:space:]]*//; s/^[`[:space:]]+//; s/[`[:space:]]+$//')
        if [ -z "$verification_value" ] || printf '%s' "$verification_value" | grep -qiE '^(待补|TBD|TODO|N/?A|无|-)$'; then
            add_failure "${tc_id} 的验证字段为占位内容，需提供可执行命令或步骤"
        fi
    done <<< "$tc_ids"
}

count_unit_files() {
    [ -d "$UNITS_DIR" ] || { printf '%s' "0"; return; }
    find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' 2>/dev/null | wc -l | tr -d ' '
}

# P0 前置条件: prd.md + units/ + design.md
if [ ! -f "$PRD_FILE" ]; then
    add_failure "缺少前置文档 prd.md：$PRD_FILE"
elif [ ! -s "$PRD_FILE" ]; then
    add_failure "前置文档 prd.md 为空：$PRD_FILE"
fi

UNIT_FILE_COUNT=$(count_unit_files)
if [ "$UNIT_FILE_COUNT" = "0" ]; then
    add_failure "缺少前置文档 units/UNIT-*.md（目录为空或不存在）：$UNITS_DIR"
fi

if [ ! -f "$DESIGN_FILE" ]; then
    add_failure "缺少前置文档 design.md：$DESIGN_FILE"
elif [ ! -s "$DESIGN_FILE" ]; then
    add_failure "前置文档 design.md 为空：$DESIGN_FILE"
fi

# C1: test-cases.md 存在且非空
if [ ! -f "$TEST_CASES_FILE" ]; then
    add_failure "测试用例文档不存在：$TEST_CASES_FILE"
elif [ ! -s "$TEST_CASES_FILE" ]; then
    add_failure "测试用例文档为空：$TEST_CASES_FILE"
fi

# C2: test-cases.md 必需章节全部存在（合并后用"审查结论"替代原两个章节）
REQUIRED_SECTIONS=(
    "## 用例统计"
    "## UNIT 覆盖视图"
    "## AC 覆盖矩阵"
    "## 等价性对照矩阵"
    "## Design 问题报告"
    "## 测试用例"
    "## 审查结论"
)

if [ -f "$TEST_CASES_FILE" ]; then
    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -qF "$section" "$TEST_CASES_FILE"; then
            add_failure "test-cases.md 缺少章节：$section"
        fi
    done
fi

# C3: 用例数量校验：反例+边界 >= 正例
if [ -f "$TEST_CASES_FILE" ]; then
    STATS_SECTION=$(extract_markdown_section "$TEST_CASES_FILE" "## 用例统计")
    UNIT_VIEW_SECTION=$(extract_markdown_section "$TEST_CASES_FILE" "## UNIT 覆盖视图")
    MATRIX_SECTION=$(extract_markdown_section "$TEST_CASES_FILE" "## AC 覆盖矩阵")
    EQ_SECTION=$(extract_markdown_section "$TEST_CASES_FILE" "## 等价性对照矩阵")
    DESIGN_SECTION=$(extract_markdown_section "$TEST_CASES_FILE" "## Design 问题报告")
    TEST_SECTION=$(extract_markdown_section "$TEST_CASES_FILE" "## 测试用例")
    SCOPE_UNIT_FILES=$(collect_scope_unit_files "$UNIT_VIEW_SECTION" "$MATRIX_SECTION")

    POSITIVE_COUNT=$(parse_stat_count "$STATS_SECTION" "正例")
    NEGATIVE_COUNT=$(parse_stat_count "$STATS_SECTION" "反例")
    BOUNDARY_COUNT=$(parse_stat_count "$STATS_SECTION" "边界")
    EXCLUSION_COUNT=$(parse_stat_count "$STATS_SECTION" "排除项验证")
    SPECIAL_COUNT=$(parse_stat_count "$STATS_SECTION" "专项测试")

    POSITIVE_COUNT=${POSITIVE_COUNT:-0}
    NEGATIVE_COUNT=${NEGATIVE_COUNT:-0}
    BOUNDARY_COUNT=${BOUNDARY_COUNT:-0}
    EXCLUSION_COUNT=${EXCLUSION_COUNT:-0}
    SPECIAL_COUNT=${SPECIAL_COUNT:-0}

    ACTUAL_POSITIVE_COUNT=$(count_tc_type "$TEST_SECTION" "正例")
    ACTUAL_NEGATIVE_COUNT=$(count_tc_type "$TEST_SECTION" "反例")
    ACTUAL_BOUNDARY_COUNT=$(count_tc_type "$TEST_SECTION" "边界")
    ACTUAL_EXCLUSION_COUNT=$(count_tc_type "$TEST_SECTION" "排除项验证")
    ACTUAL_SPECIAL_COUNT=$(count_tc_type "$TEST_SECTION" "专项")

    NEG_BOUND_SUM=$((NEGATIVE_COUNT + BOUNDARY_COUNT))

    if [ "$NEG_BOUND_SUM" -lt "$POSITIVE_COUNT" ]; then
        add_failure "反例(${NEGATIVE_COUNT})+边界(${BOUNDARY_COUNT})=${NEG_BOUND_SUM} < 正例(${POSITIVE_COUNT})，不满足 HARD-GATE 2"
    fi

    if [ "$POSITIVE_COUNT" -ne "$ACTUAL_POSITIVE_COUNT" ] || [ "$NEGATIVE_COUNT" -ne "$ACTUAL_NEGATIVE_COUNT" ] || [ "$BOUNDARY_COUNT" -ne "$ACTUAL_BOUNDARY_COUNT" ] || [ "$EXCLUSION_COUNT" -ne "$ACTUAL_EXCLUSION_COUNT" ]; then
        add_failure "用例统计与测试用例正文不一致（统计: 正${POSITIVE_COUNT}/反${NEGATIVE_COUNT}/边${BOUNDARY_COUNT}/排${EXCLUSION_COUNT}；正文: 正${ACTUAL_POSITIVE_COUNT}/反${ACTUAL_NEGATIVE_COUNT}/边${ACTUAL_BOUNDARY_COUNT}/排${ACTUAL_EXCLUSION_COUNT}）"
    fi

    # C4: 每条 AC 必须有正例/反例/边界
    AC_IDS=$({
        while IFS= read -r uf; do
            [ -f "$uf" ] || continue
            grep -oE 'G?AC(-[A-Z][0-9]+)?-[0-9]+' "$uf" || true
        done <<< "$SCOPE_UNIT_FILES"
    } | sort -u)

    if [ -z "$AC_IDS" ]; then
        AC_IDS=$(printf '%s\n' "$MATRIX_SECTION" | grep -oE 'G?AC(-[A-Z][0-9]+)?-[0-9]+' | sort -u || true)
    fi

    if [ -z "$AC_IDS" ]; then
        add_failure "未解析到任何 AC 编号，无法验证「每条 AC 正/反/边界覆盖」"
    else
        while IFS= read -r ac_id; do
            [ -n "$ac_id" ] || continue
            ac_rows=$(printf '%s\n' "$MATRIX_SECTION" | grep -E '^\|' | grep -F "$ac_id" || true)
            if [ -z "$ac_rows" ]; then
                add_failure "${ac_id} 未出现在 AC 覆盖矩阵中"
                continue
            fi

            ac_tc_targets=$(extract_tc_ids_from_rows "$ac_rows")
            if [ -z "$ac_tc_targets" ]; then
                add_failure "${ac_id} 在 AC 覆盖矩阵中未声明任何 TC 编号"
                continue
            fi

            has_pos=0
            has_neg=0
            has_bound=0
            while IFS= read -r tc_id; do
                [ -n "$tc_id" ] || continue
                if ! printf '%s\n' "$TEST_SECTION" | grep -qE "^### ${tc_id}:"; then
                    add_failure "${ac_id} 映射了 ${tc_id}，但测试用例章节不存在该 TC"
                    continue
                fi

                tc_type=$(get_tc_type_by_id "$TEST_SECTION" "$tc_id")
                [ "$tc_type" = "正例" ] && has_pos=1
                [ "$tc_type" = "反例" ] && has_neg=1
                [ "$tc_type" = "边界" ] && has_bound=1
            done <<< "$ac_tc_targets"

            [ "$has_pos" = "1" ] || add_failure "${ac_id} 缺少正例类型测试用例映射"
            [ "$has_neg" = "1" ] || add_failure "${ac_id} 缺少反例类型测试用例映射"
            [ "$has_bound" = "1" ] || add_failure "${ac_id} 缺少边界类型测试用例映射"
        done <<< "$AC_IDS"
    fi

    # C5: 排除项验证覆盖（优先按 EX 编号，兜底按排除项条目数）
    EX_IDS=$({
        while IFS= read -r uf; do
            [ -f "$uf" ] || continue
            grep -oE 'G?EX-[0-9]+' "$uf" || true
        done <<< "$SCOPE_UNIT_FILES"
    } | sort -u)

    if [ -n "$EX_IDS" ]; then
        while IFS= read -r ex_id; do
            [ -n "$ex_id" ] || continue
            if ! printf '%s\n%s\n' "$TEST_SECTION" "$MATRIX_SECTION" | grep -qF "$ex_id"; then
                add_failure "${ex_id} 未在测试用例或覆盖矩阵中承接"
            fi
        done <<< "$EX_IDS"
        [ "$ACTUAL_EXCLUSION_COUNT" -gt 0 ] || add_failure "存在排除项编号但未提供排除项验证用例"
    else
        ex_item_count=0
        while IFS= read -r unit_file; do
            [ -f "$unit_file" ] || continue
            ex_section=$(extract_markdown_section "$unit_file" "## 排除项")
            ex_lines=$(printf '%s\n' "$ex_section" | grep -cE '^[[:space:]]*[-*][[:space:]]+[^[:space:]]' || true)
            ex_item_count=$((ex_item_count + ex_lines))
        done <<< "$SCOPE_UNIT_FILES"

        if [ "$ex_item_count" -gt 0 ] && [ "$ACTUAL_EXCLUSION_COUNT" -lt "$ex_item_count" ]; then
            add_failure "排除项验证用例不足：排除项条目 ${ex_item_count} 条，但仅有 ${ACTUAL_EXCLUSION_COUNT} 条排除项验证用例"
        fi
    fi

    # C6: 每条测试用例需有可执行验证命令/步骤
    check_tc_verification "$TEST_SECTION"

    # C6.1: 等价性对照矩阵完整性与阻断条件
    EQ_ROWS=$(extract_eq_matrix_rows "$EQ_SECTION")
    EQ_COUNT=$(printf '%s\n' "$EQ_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$EQ_COUNT" -eq 0 ]; then
        add_failure "等价性对照矩阵缺少数据行"
    else
        eq_duplicate_scope_ids=$(printf '%s\n' "$EQ_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
        if [ -n "$eq_duplicate_scope_ids" ]; then
            add_failure "等价性对照矩阵存在重复 scope_item_id：$(printf '%s' "$eq_duplicate_scope_ids" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
        fi

        MATRIX_SCOPE_IDS=$(printf '%s\n' "$MATRIX_SECTION" | grep -oE 'SCOPE-P[0-9]+U[0-9]+-[0-9]+' | sort -u || true)
        has_design_gap_eq=0

        while IFS='|' read -r scope_id ac_ref tc_ref compare_input invariant eq_status note; do
            [ -n "$scope_id" ] || continue

            if ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
                add_failure "等价性对照矩阵存在非法 scope_item_id：${scope_id}"
            fi
            if is_placeholder_text "$ac_ref" || ! printf '%s' "$ac_ref" | grep -qE 'AC(-[A-Z][0-9]+)?-[0-9]+'; then
                add_failure "等价性对照矩阵 ${scope_id} 缺少有效关联 AC"
            fi
            if is_placeholder_text "$tc_ref" || ! printf '%s' "$tc_ref" | grep -qE 'TC(-[A-Z][0-9]+)?-[0-9]+'; then
                add_failure "等价性对照矩阵 ${scope_id} 缺少有效关联 TC"
            fi
            if is_placeholder_text "$compare_input"; then
                add_failure "等价性对照矩阵 ${scope_id} 缺少对照输入"
            fi
            if is_placeholder_text "$invariant"; then
                add_failure "等价性对照矩阵 ${scope_id} 缺少不变量定义"
            fi

            if [ "$eq_status" != "EQ-COVERED" ] && [ "$eq_status" != "DESIGN-GAP(EQ)" ]; then
                add_failure "等价性对照矩阵 ${scope_id} 结果状态非法：${eq_status}（仅允许 EQ-COVERED 或 DESIGN-GAP(EQ)）"
            fi
            if [ "$eq_status" = "DESIGN-GAP(EQ)" ]; then
                has_design_gap_eq=1
            fi

            if [ -n "$MATRIX_SCOPE_IDS" ] && ! printf '%s\n' "$MATRIX_SCOPE_IDS" | grep -qx "$scope_id"; then
                add_failure "等价性对照矩阵 ${scope_id} 未在 AC 覆盖矩阵声明 scope_item_id"
            fi

            tc_targets=$(printf '%s' "$tc_ref" | grep -oE 'TC(-[A-Z][0-9]+)?-[0-9]+' | sort -u || true)
            while IFS= read -r tc_id; do
                [ -n "$tc_id" ] || continue
                if ! printf '%s\n' "$TEST_SECTION" | grep -qE "^### ${tc_id}:"; then
                    add_failure "等价性对照矩阵 ${scope_id} 关联的 ${tc_id} 在测试用例章节不存在"
                fi
            done <<< "$tc_targets"
        done <<< "$EQ_ROWS"

        if [ "$has_design_gap_eq" = "1" ]; then
            add_failure "存在 DESIGN-GAP(EQ)，阻断进入 /tech-lead"
            if ! printf '%s\n' "$DESIGN_SECTION" | grep -qE '(DESIGN-GAP\(EQ\)|等价性缺口|DI-[0-9]+)'; then
                add_failure "存在 DESIGN-GAP(EQ) 但 Design 问题报告缺少对应证据记录"
            fi
        fi
    fi

    # C6.1: DESIGN-GAP 与 Design 问题报告一致性
    has_design_gap=0
    if printf '%s\n' "$MATRIX_SECTION" | grep -q "DESIGN-GAP"; then
        has_design_gap=1
    fi
    if [ "$has_design_gap" = "1" ]; then
        if ! printf '%s\n' "$DESIGN_SECTION" | grep -qE '(DI-[0-9]+|DESIGN-GAP|缺口|问题)'; then
            add_failure "AC 覆盖矩阵包含 DESIGN-GAP，但 Design 问题报告缺少可追溯证据（DI 编号或问题描述）"
        fi
        if printf '%s\n' "$DESIGN_SECTION" | grep -qE '无设计缺口|无问题'; then
            add_failure "AC 覆盖矩阵包含 DESIGN-GAP，但 Design 问题报告写为"无设计缺口/无问题""
        fi
    fi

    # C6.2: 专项测试展开需有触发依据或保守展开记录（仅在专项测试 > 0 时强制）
    if [ "$SPECIAL_COUNT" -gt 0 ] || [ "$ACTUAL_SPECIAL_COUNT" -gt 0 ]; then
        if ! grep -qE '(触发依据|触发条件|保守展开|conservative)' "$TEST_CASES_FILE"; then
            add_failure "检测到专项测试（统计=${SPECIAL_COUNT}，正文=${ACTUAL_SPECIAL_COUNT}），但未记录触发依据或保守展开说明"
        fi
    fi
fi

# --- 主文档内嵌审查结论检查 ---

# 提取 test-cases.md 审查结论章节供 WARN 承接校验使用
TESTCASES_REVIEW_CONCLUSION=""
if [ -f "$TEST_CASES_FILE" ]; then
    TESTCASES_REVIEW_CONCLUSION=$(extract_markdown_section "$TEST_CASES_FILE" "## 审查结论")
fi

if [ -z "$(extract_section_content "$TEST_CASES_FILE" "### 审查汇总" 3)" ]; then
    add_failure "test-cases.md「审查结论」缺少「### 审查汇总」"
fi

TEST_REVIEW_LEDGER_ROWS=$(extract_review_issue_ledger_rows "$TEST_CASES_FILE")
if [ -z "$TEST_REVIEW_LEDGER_ROWS" ]; then
    add_failure "test-cases.md「审查结论」缺少可解析的「审查问题台账」"
fi

CONVERGENCE_ROWS=$(extract_convergence_rows "$TEST_CASES_FILE")
if [ -z "$CONVERGENCE_ROWS" ]; then
    add_failure "test-cases.md「审查结论」缺少「收敛轮次摘要」或数据行为空"
else
    while IFS=$'\t' read -r round result note; do
        [ -n "$round" ] || continue
        if is_placeholder_text "$result"; then
            add_failure "收敛轮次 ${round} 缺少结果"
        fi
        if is_placeholder_text "$note"; then
            add_failure "收敛轮次 ${round} 缺少说明"
        fi
    done <<< "$CONVERGENCE_ROWS"
fi

check_embedded_review_conclusion() {
    local label="$1" prefix="$2"
    local summary_row verdict issue_count issue_rows issue_row_count

    summary_row=$(extract_review_summary_row "$TEST_CASES_FILE" "$label")
    if [ -z "$summary_row" ]; then
        add_failure "test-cases.md「审查汇总」缺少${label}视角结论行"
        return
    fi

    verdict=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $2}')
    issue_count=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $3}')

    if ! printf '%s\n' "$verdict" | grep -qE '^(PASS|WARN|FAIL)$'; then
        add_failure "test-cases.md「审查汇总」${label}视角 Verdict 不可解析"
        return
    fi

    if ! printf '%s\n' "$issue_count" | grep -qE '^[0-9]+$'; then
        add_failure "test-cases.md「审查汇总」${label}视角 Issue Count 不可解析"
        return
    fi

    issue_rows=$(printf '%s\n' "$TEST_REVIEW_LEDGER_ROWS" | awk -F'\t' -v prefix="$prefix" '$1 ~ ("^" prefix "-[0-9]{3,}$") { print }')
    issue_row_count=$(printf '%s\n' "$issue_rows" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$verdict" = "PASS" ] && [ "$issue_count" != "0" ]; then
        add_failure "test-cases.md「审查汇总」${label}视角 Verdict=PASS 时 Issue Count 必须为 0"
    fi
    if [ "$verdict" != "PASS" ] && [ "$issue_count" = "0" ]; then
        add_failure "test-cases.md「审查汇总」${label}视角 Verdict=${verdict} 时 Issue Count 不得为 0"
    fi
    if [ "$issue_count" != "$issue_row_count" ]; then
        add_failure "test-cases.md「审查问题台账」${label}视角稳定 issue 数量=${issue_row_count} 与审查汇总 Issue Count=${issue_count} 不一致"
    fi
    if [ "$verdict" = "FAIL" ]; then
        add_failure "${label}视角审查存在 FAIL 结论"
    fi

    while IFS=$'\t' read -r issue_id view severity status evidence_anchor handoff_target review_round resolution; do
        [ -n "$issue_id" ] || continue

        if is_placeholder_text "$view"; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 缺少视角"
        fi
        if is_placeholder_text "$severity"; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 缺少 Severity"
        fi
        if is_placeholder_text "$status"; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 缺少 Status"
        fi
        if is_placeholder_text "$evidence_anchor"; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 缺少 Evidence Anchor"
        fi
        if is_placeholder_text "$handoff_target"; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 缺少 Handoff Target"
        fi
        if is_placeholder_text "$review_round"; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 缺少 Review Round"
        fi
        if is_placeholder_text "$resolution"; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 缺少处理摘要"
        fi

        if [ -n "$CONVERGENCE_ROWS" ] && ! printf '%s\n' "$CONVERGENCE_ROWS" | awk -F'\t' -v target="$review_round" '$1 == target { found=1 } END { exit !found }'; then
            add_failure "test-cases.md「审查问题台账」${issue_id} 的 Review Round=${review_round} 未在收敛轮次摘要中登记"
        fi

        if [ "$verdict" = "WARN" ]; then
            if ! printf '%s\n' "$TESTCASES_REVIEW_CONCLUSION" | grep -qF "$issue_id"; then
                add_failure "${label}视角 WARN 项 ${issue_id} 未在 test-cases.md「审查结论」中显式记录"
            elif ! validate_handoff_entry "$issue_id" "$TESTCASES_REVIEW_CONCLUSION"; then
                add_failure "${label}视角 WARN 项 ${issue_id} 在「审查结论」中缺少实质承接内容（需写明：已修正/承接位置/不处理理由）"
            fi

            tc_targets=$(printf '%s' "$handoff_target" | grep -oE 'TC(-[A-Z][0-9]+)?-[0-9]+' || true)
            if [ -n "$tc_targets" ] && [ -f "$TEST_CASES_FILE" ]; then
                test_section=$(extract_markdown_section "$TEST_CASES_FILE" "## 测试用例")
                while IFS= read -r tc_ref; do
                    [ -n "$tc_ref" ] || continue
                    if ! printf '%s\n' "$test_section" | grep -qF "$tc_ref"; then
                        add_failure "WARN 项 ${issue_id} 承接到 ${tc_ref}，但测试用例章节中未找到该用例"
                    fi
                done <<< "$tc_targets"
            fi

            unit_targets=$(printf '%s' "$handoff_target" | grep -oE 'UNIT-[0-9]+' || true)
            if [ -n "$unit_targets" ]; then
                while IFS= read -r unit_id; do
                    [ -n "$unit_id" ] || continue
                    if [ ! -f "$UNITS_DIR/${unit_id}.md" ]; then
                        add_failure "WARN 项 ${issue_id} 承接到 ${unit_id}，但 units/ 中未找到该文件"
                    fi
                done <<< "$unit_targets"
            fi

            ac_targets=$(printf '%s' "$handoff_target" | grep -oE 'G?AC(-[A-Z][0-9]+)?-[0-9]+' || true)
            if [ -n "$ac_targets" ] && [ -f "$TEST_CASES_FILE" ]; then
                matrix_section=$(extract_markdown_section "$TEST_CASES_FILE" "## AC 覆盖矩阵")
                while IFS= read -r ac_id; do
                    [ -n "$ac_id" ] || continue
                    if ! printf '%s\n' "$matrix_section" | grep -qF "$ac_id"; then
                        add_failure "WARN 项 ${issue_id} 承接到 ${ac_id}，但 AC 覆盖矩阵中未找到该编号"
                    fi
                done <<< "$ac_targets"
            fi
        fi
    done <<< "$issue_rows"
}

for view_args in \
    "测试质量|TQR" \
    "产品|TPR" \
    "架构|TAR"; do
    IFS='|' read -r v_label v_prefix <<< "$view_args"
    check_embedded_review_conclusion "$v_label" "$v_prefix"
done

output_failures "测试设计文档完整性检查未通过" "$WORK_DIR"
exit 0
