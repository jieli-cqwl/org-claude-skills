#!/bin/bash
# 产品文档完整性自动检查脚本
# 执行时机: PostToolUse(Edit|Write) 收口门禁
# 功能: 精确定位当前 feature，并检查 PRD/UNIT/主文档内嵌审查闭环
# 版本: v4.0 2026-03-16

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
product/completion_check.sh — 产品文档完整性自动检查脚本
执行时机: PostToolUse(Edit|Write) 收口门禁
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
source "$HOOKS_LIB/common.sh"
# shellcheck source=/dev/null
source "$HOOKS_LIB/constraint.sh"
hook_init

# --- Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(prd\.md|units/UNIT-[0-9]+\.md)'
resolve_feature_dir "docs/*/prd.md" "$TRANSCRIPT_PATTERN" "prd.md"
output_failures "产品文档完整性检查未通过" ""

PRD_FILE="$FEATURE_DIR/prd.md"
UNITS_DIR="$FEATURE_DIR/units"
TOOL_FILE_PATH=$(tool_input_get '.file_path')

should_run_gate() {
    [ -f "$PRD_FILE" ] || return 1

    if [ -z "${TOOL_NAME:-}" ]; then
        return 0
    fi
    if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
        return 0
    fi
    if [ -n "$TOOL_FILE_PATH" ] && [ "$(basename "$TOOL_FILE_PATH")" != "prd.md" ]; then
        return 1
    fi

    local delivery_section delivery_status
    delivery_section=$(extract_markdown_section "$PRD_FILE" "## 交付确认")
    if [ -n "$delivery_section" ]; then
        delivery_status=$(printf '%s\n' "$delivery_section" \
            | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认状态[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
            | head -1 \
            | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if [ "$delivery_status" = "确认" ]; then
            return 0
        fi
    fi

    if grep -qF "## 审查结论" "$PRD_FILE" || grep -qF "## 交付计划" "$PRD_FILE" || grep -qF "## 交接项" "$PRD_FILE"; then
        return 0
    fi

    return 1
}

if ! should_run_gate; then
    exit 0
fi

if [ ! -f "$PRD_FILE" ]; then
    add_failure "PRD 文档不存在：$PRD_FILE"
elif [ ! -s "$PRD_FILE" ]; then
    add_failure "PRD 文档为空：$PRD_FILE"
fi

# --- 必需章节检查 ---

REQUIRED_SECTIONS=(
    "## 业务背景与根问题"
    "## 目标与成功标准"
    "## 用户角色与核心场景"
    "## 业务术语"
    "## 业务对象"
    "## 当前业务流程"
    "## 目标业务流程"
    "## 范围 / 本期不交付"
    "## 业务规则"
    "## 影响范围"
    "## 功能需求（UNIT 索引）"
    "## 非功能需求"
    "## 全局排除项"
    "## 前置约束"
    "## 待设计决策"
    "## 已排查并排除的潜在问题"
    "## 关键假设"
    "## 共创摘要"
    "## 交付确认"
    "## 审查结论"
    "## 交接项"
)

if [ -f "$PRD_FILE" ]; then
    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -qF "$section" "$PRD_FILE"; then
            add_failure "PRD 缺少章节：$section"
        fi
    done
fi

# --- 已排查并排除的潜在问题至少 2 条 ---

if [ -f "$PRD_FILE" ]; then
    EP_COUNT=$({ grep -oE 'EP-[0-9]+' "$PRD_FILE" 2>/dev/null || true; } | sort -u | wc -l | tr -d ' ')
    if [ "$EP_COUNT" -lt 2 ]; then
        add_failure "「已排查并排除的潜在问题」不足 2 条（当前 ${EP_COUNT} 条），完成校验要求至少 2 条"
    fi
fi

# --- 影响范围必须有实质内容（至少 1 条影响项） ---

if [ -f "$PRD_FILE" ]; then
    IMPACT_SECTION=$(extract_markdown_section "$PRD_FILE" "## 影响范围")
    IMPACT_ITEM_COUNT=$(printf '%s\n' "$IMPACT_SECTION" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        {
            raw = $0
            line = raw
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line == "") next

            if (line ~ /^\|/) {
                c1 = trim($2)
                if (c1 == "" || c1 == "关联功能" || c1 ~ /^-+$/) next
                count++
                next
            }

            if (line ~ /^[-*][[:space:]]+[^[:space:]]/) {
                count++
                next
            }

            if (line ~ /^##[[:space:]]+/) next
            count++
        }
        END { print count + 0 }
    ')

    if [ "$IMPACT_ITEM_COUNT" -lt 1 ]; then
        add_failure "「影响范围」章节无实质内容，至少需要 1 条影响项"
    fi
fi

# --- 待设计决策必须有可追踪 DD 编号 ---

if [ -f "$PRD_FILE" ]; then
    DECISION_SECTION=$(extract_markdown_section "$PRD_FILE" "## 待设计决策")
    DD_COUNT=$({ printf '%s\n' "$DECISION_SECTION" | grep -oE 'DD-[0-9]+' || true; } | sort -u | wc -l | tr -d ' ')
    if [ "$DD_COUNT" -lt 1 ]; then
        add_failure "「待设计决策」未定义任何 DD 编号，design 阶段无可追踪输入"
    fi
fi

# --- 前置约束必须为结构化对象或显式声明无前置约束 ---

if [ -f "$PRD_FILE" ]; then
    CONSTRAINT_ROWS=$(extract_prd_constraint_rows "$PRD_FILE")
    CONSTRAINT_COUNT=$(printf '%s\n' "$CONSTRAINT_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
    NO_CONSTRAINTS_DECLARED=false
    if has_explicit_no_constraints_declaration "$PRD_FILE"; then
        NO_CONSTRAINTS_DECLARED=true
    fi

    if [ "$CONSTRAINT_COUNT" -eq 0 ]; then
        if [ "$NO_CONSTRAINTS_DECLARED" != "true" ]; then
            add_failure "「前置约束」必须至少包含 1 条结构化约束，或显式声明“无前置约束（经评估）”"
        fi
    else
        if [ "$NO_CONSTRAINTS_DECLARED" = "true" ]; then
            add_failure "「前置约束」不能同时包含结构化约束和“无前置约束（经评估）”声明"
        fi

        DUP_CONSTRAINT_IDS=$(printf '%s\n' "$CONSTRAINT_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
        if [ -n "$DUP_CONSTRAINT_IDS" ]; then
            add_failure "「前置约束」存在重复 Constraint ID：$(printf '%s' "$DUP_CONSTRAINT_IDS" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
        fi

        while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref status; do
            [ -n "$constraint_id" ] || continue

            if ! printf '%s' "$constraint_id" | grep -qE '^CON-[0-9]{3,}$'; then
                add_failure "「前置约束」存在非法 Constraint ID：${constraint_id}"
            fi
            if is_placeholder_text "$constraint_type"; then
                add_failure "「前置约束」${constraint_id} 缺少类型"
            fi
            if is_placeholder_text "$description"; then
                add_failure "「前置约束」${constraint_id} 缺少约束内容"
            fi
            if is_placeholder_text "$owner"; then
                add_failure "「前置约束」${constraint_id} 缺少 Owner"
            fi
            if is_placeholder_text "$affected_unit"; then
                add_failure "「前置约束」${constraint_id} 缺少影响 UNIT"
            elif ! printf '%s' "$affected_unit" | grep -qE '(UNIT-[0-9]+|全局)'; then
                add_failure "「前置约束」${constraint_id} 的影响 UNIT 必须包含 UNIT-N 或 全局"
            fi
            if is_placeholder_text "$scope_id" || ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
                add_failure "「前置约束」${constraint_id} 缺少有效 scope_item_id"
            fi
            if is_placeholder_text "$preflight_ref"; then
                add_failure "「前置约束」${constraint_id} 缺少 preflight_ref"
            fi
            normalized_test_ref=$(printf '%s' "$test_ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
            if is_placeholder_text "$normalized_test_ref" && ! printf '%s' "$normalized_test_ref" | grep -qiE '^N/?A$'; then
                add_failure "「前置约束」${constraint_id} 缺少 test_ref"
            fi
            if [ "$status" != "KNOWN" ] && [ "$status" != "BLOCKED" ] && [ "$status" != "VERIFIED" ]; then
                add_failure "「前置约束」${constraint_id} 状态为 ${status}（仅允许 KNOWN/BLOCKED/VERIFIED）"
            fi
        done <<< "$CONSTRAINT_ROWS"
    fi
fi

# --- 共创摘要验证 ---
if [ -f "$PRD_FILE" ]; then
    CO_CREATE_SECTION=$(extract_markdown_section "$PRD_FILE" "## 共创摘要")
    CO_CREATE_DATA_ROWS=$(printf '%s\n' "$CO_CREATE_SECTION" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            c1=trim($2); c2=trim($3); c3=trim($4); c4=trim($5)
            if (c1 == "" || c1 == "阶段" || c1 ~ /^-+$/) next
            if (c1 != "" || c2 != "" || c3 != "" || c4 != "") count++
        }
        END { print count + 0 }
    ')
    if [ "$CO_CREATE_DATA_ROWS" -lt 6 ]; then
        add_failure "「共创摘要」数据行不足 6 条（当前 ${CO_CREATE_DATA_ROWS} 条），必须覆盖 6 个阶段"
    fi

    for stage in \
        "根问题澄清" \
        "目标与成功标准对齐" \
        "语义/范围收口" \
        "UNIT 与 AC" \
        "待设计决策/完整性" \
        "交付确认"; do
        stage_row=$(printf '%s\n' "$CO_CREATE_SECTION" | awk -F'|' -v target="$stage" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            /^\|/ {
                c1=trim($2); c2=trim($3); c3=trim($4); c4=trim($5)
                if (c1 == target) {
                    print c2 "\t" c3 "\t" c4
                    found=1
                    exit
                }
            }
            END { if (!found) exit 1 }
        ' || true)

        if [ -z "$stage_row" ]; then
            add_failure "「共创摘要」缺少阶段记录：${stage}"
            continue
        fi

        stage_question=$(printf '%s' "$stage_row" | awk -F'\t' '{print $1}')
        stage_response=$(printf '%s' "$stage_row" | awk -F'\t' '{print $2}')
        stage_impact=$(printf '%s' "$stage_row" | awk -F'\t' '{print $3}')

        stage_question=$(printf '%s' "$stage_question" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        stage_response=$(printf '%s' "$stage_response" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        stage_impact=$(printf '%s' "$stage_impact" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

        if [ -z "$stage_question" ]; then
            add_failure "「共创摘要」阶段 ${stage} 缺少关键提问"
        fi
        if [ -z "$stage_response" ]; then
            add_failure "「共创摘要」阶段 ${stage} 缺少用户回应"
        fi
        if [ -z "$stage_impact" ]; then
            add_failure "「共创摘要」阶段 ${stage} 缺少影响记录"
        fi
    done
fi

# --- 交付确认门禁 ---
if [ -f "$PRD_FILE" ]; then
    DELIVERY_SECTION=$(extract_markdown_section "$PRD_FILE" "## 交付确认")
    if [ -z "$DELIVERY_SECTION" ]; then
        add_failure "缺少「交付确认」章节"
    else
        delivery_status=$(printf '%s\n' "$DELIVERY_SECTION" \
            | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认状态[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
            | head -1 \
            | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        delivery_time=$(printf '%s\n' "$DELIVERY_SECTION" \
            | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认时间[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
            | head -1 \
            | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

        if [ "$delivery_status" != "确认" ]; then
            add_failure "「交付确认」确认状态必须为「确认」"
        fi
        if ! is_valid_confirmation_time "$delivery_time"; then
            add_failure "「交付确认」缺少有效确认时间（需使用 YYYY-MM-DD HH:mm 且不可为模板占位）"
        fi
    fi
fi

# --- 关键假设验证 ---
if [ -f "$PRD_FILE" ]; then
    KEY_ASSUMPTIONS=$(extract_markdown_section "$PRD_FILE" "## 关键假设")
    KA_ROWS=$(printf '%s\n' "$KEY_ASSUMPTIONS" | grep -cE '^\|[[:space:]]*[^-|]' || true)
    if [ "$KA_ROWS" -lt 2 ]; then
        add_failure "「关键假设」无数据行，至少需要 1 条假设"
    fi
fi

# 从 prd.md 审查结论章节提取 WARN 处理记录
PRD_HANDOFF_CONTENT=""
if [ -f "$PRD_FILE" ]; then
    PRD_HANDOFF_CONTENT=$(extract_markdown_section "$PRD_FILE" "## 审查结论")
fi

validate_ac_scenario_lines() {
    local unit_file="$1" unit_name="$2" ac_section="$3"
    local section_content scenario_lines

    section_content=$(extract_section_content "$unit_file" "$ac_section" 3)
    scenario_lines=$(printf '%s\n' "$section_content" | grep -E '^[[:space:]]*[-*][[:space:]]+' || true)

    if [ -z "$scenario_lines" ]; then
        add_failure "${unit_name} ${ac_section} 无可解析的验收条目（需使用列表并表达 输入/操作 -> 可观察结果）"
        return
    fi

    while IFS= read -r scenario_line; do
        [ -n "$scenario_line" ] || continue
        scenario_expr=$(printf '%s' "$scenario_line" | sed -E 's/^[[:space:]]*[-*][[:space:]]+//; s/^[[:space:]]+//; s/[[:space:]]+$//')

        if ! printf '%s' "$scenario_expr" | grep -qE '(->|→)'; then
            add_failure "${unit_name} ${ac_section} 条目格式不符合「输入/操作 -> 可观察结果」：${scenario_expr}"
            continue
        fi

        left_part=$(printf '%s' "$scenario_expr" | sed -E 's/(->|→).*//; s/^[[:space:]]+//; s/[[:space:]]+$//')
        right_part=$(printf '%s' "$scenario_expr" | sed -E 's/.*(->|→)[[:space:]]*//; s/^[[:space:]]+//; s/[[:space:]]+$//')

        if [ -z "$left_part" ] || [ -z "$right_part" ]; then
            add_failure "${unit_name} ${ac_section} 条目箭头两侧不能为空：${scenario_expr}"
        fi
    done <<< "$scenario_lines"
}

# --- UNIT 检查 ---

if [ ! -d "$UNITS_DIR" ]; then
    add_failure "units/ 目录不存在：$UNITS_DIR"
else
    UNIT_FILE_LIST=$(find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' | sort)
    if [ -z "$UNIT_FILE_LIST" ]; then
        add_failure "units/ 目录下无 UNIT-*.md 文件"
    else
        while IFS= read -r unit_file; do
            [ -n "$unit_file" ] || continue
            unit_name=$(basename "$unit_file")

            if ! grep -qF "## 功能闭环定义" "$unit_file"; then
                add_failure "${unit_name} 缺少「功能闭环定义」章节"
            fi

            if ! grep -qF "## 排除项" "$unit_file"; then
                add_failure "${unit_name} 缺少「排除项」章节"
            else
                exclusion_content=$(extract_markdown_section "$unit_file" "## 排除项")
                exclusion_lines=$(printf '%s\n' "$exclusion_content" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
                if [ "$exclusion_lines" = "0" ]; then
                    add_failure "${unit_name}「排除项」章节为空，必须至少列出一条排除项"
                fi
            fi

            for ac_section in "### 正常场景" "### 异常场景" "### 边界条件"; do
                if ! grep -qF "$ac_section" "$unit_file"; then
                    add_failure "${unit_name} 缺少验收标准子章节：${ac_section}"
                else
                    validate_ac_scenario_lines "$unit_file" "$unit_name" "$ac_section"
                fi
            done
        done <<< "$UNIT_FILE_LIST"
    fi
fi

# --- UNIT 交叉验证（PRD 引用 vs units/ 文件，用 process substitution 代替 TMP_DIR） ---

if [ -f "$PRD_FILE" ] && [ -d "$UNITS_DIR" ]; then
    MISSING_UNITS=$(comm -23 \
        <(grep -oE 'UNIT-[0-9]+' "$PRD_FILE" 2>/dev/null | sort -u) \
        <(find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' -exec basename {} .md \; | sort -u) \
        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
    EXTRA_UNITS=$(comm -13 \
        <(grep -oE 'UNIT-[0-9]+' "$PRD_FILE" 2>/dev/null | sort -u) \
        <(find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' -exec basename {} .md \; | sort -u) \
        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')

    [ -z "$MISSING_UNITS" ] || add_failure "PRD 引用了但 units/ 缺失的 UNIT：$MISSING_UNITS"
    [ -z "$EXTRA_UNITS" ] || add_failure "units/ 存在但 PRD 未引用的 UNIT：$EXTRA_UNITS"
fi

# --- 交付计划检查（所有项目必须） ---

if [ -f "$PRD_FILE" ]; then
    if ! grep -qF "## 交付计划" "$PRD_FILE"; then
        add_failure "PRD 缺少「交付计划」章节"
    else
        phase_section=$(extract_markdown_section "$PRD_FILE" "## 交付计划")
        phase_count=$(printf '%s\n' "$phase_section" | grep -cE '^### Phase [0-9]+' || true)
        if [ "$phase_count" -lt 1 ]; then
            add_failure "「交付计划」中未找到任何 Phase 定义"
        fi
        # 检查工作区映射表
        workspace_count=$(printf '%s\n' "$phase_section" | grep -cE 'phase-[0-9]+/unit-[0-9]+/' || true)
        if [ "$workspace_count" -lt 1 ]; then
            add_failure "「交付计划」缺少工作区路径映射（phase-{N}/unit-{M}/ 格式）"
        fi
        # 检查每个阶段的必需字段
        phase_exit_count=$(printf '%s\n' "$phase_section" | grep -cE '^- 出口条件:' || true)
        phase_status_count=$(printf '%s\n' "$phase_section" | grep -cE '^- 状态:' || true)
        if [ "$phase_exit_count" -lt "$phase_count" ]; then
            add_failure "「交付计划」部分阶段缺少「出口条件」字段"
        fi
        if [ "$phase_status_count" -lt "$phase_count" ]; then
            add_failure "「交付计划」部分阶段缺少「状态」字段"
        fi

        invalid_phase_status_lines=$(printf '%s\n' "$phase_section" | grep -E '^- 状态:' | grep -vE '^- 状态:[[:space:]]*(NOT_STARTED|IN_PROGRESS|DONE)[[:space:]]*$' || true)
        if [ -n "$invalid_phase_status_lines" ]; then
            add_failure "「交付计划」存在非法 Phase 状态（仅允许 NOT_STARTED/IN_PROGRESS/DONE）：$(printf '%s' "$invalid_phase_status_lines" | tr '\n' '; ' | sed -E 's/[;[:space:]]+$//')"
        fi

        # 检查 phase 物理目录已创建
        phase_dirs=$(printf '%s\n' "$phase_section" | grep -oE 'phase-[0-9]+/' | sort -u || true)
        while IFS= read -r phase_path; do
            [ -n "$phase_path" ] || continue
            full_phase_dir="${FEATURE_DIR}/${phase_path%/}"
            if [ ! -d "$full_phase_dir" ]; then
                add_failure "「交付计划」定义了 ${phase_path} 但物理目录未创建：$full_phase_dir"
            fi
        done <<< "$phase_dirs"
    fi
fi

# --- 3+ UNIT 全 MVP 时需 MVP 说明 ---

if [ -d "$UNITS_DIR" ]; then
    UNIT_TOTAL=$(find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' | wc -l | tr -d ' ')
    if [ "$UNIT_TOTAL" -ge 3 ]; then
        MVP_COUNT=0
        while IFS= read -r unit_file; do
            [ -n "$unit_file" ] || continue
            if grep -qE '^\*\*优先级\*\*:[[:space:]]*MVP' "$unit_file"; then
                MVP_COUNT=$((MVP_COUNT + 1))
            fi
        done < <(find "$UNITS_DIR" -maxdepth 1 -type f -name 'UNIT-*.md' | sort)

        if [ "$MVP_COUNT" -eq "$UNIT_TOTAL" ] && [ -f "$PRD_FILE" ]; then
            mvp_section=$(extract_markdown_section "$PRD_FILE" "## MVP 最小闭环说明")
            mvp_lines=$(printf '%s\n' "$mvp_section" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
            if [ "$mvp_lines" = "0" ]; then
                add_failure "UNIT 数量 >= 3 且全部为 MVP，但 PRD 缺少非空的「MVP 最小闭环说明」"
            fi
        fi
    fi
fi


# --- 主文档内嵌审查结论校验 ---

if [ -z "$(extract_section_content "$PRD_FILE" "### 审查汇总" 3)" ]; then
    add_failure "PRD「审查结论」缺少「### 审查汇总」"
fi

PRD_REVIEW_LEDGER_ROWS=$(extract_review_issue_ledger_rows "$PRD_FILE")
if [ -z "$PRD_REVIEW_LEDGER_ROWS" ]; then
    add_failure "PRD「审查结论」缺少可解析的「审查问题台账」"
fi

check_embedded_review_conclusion() {
    local label="$1" prefix="$2"
    local summary_row verdict issue_count issue_rows issue_row_count

    summary_row=$(extract_review_summary_row "$PRD_FILE" "$label")
    if [ -z "$summary_row" ]; then
        add_failure "PRD「审查汇总」缺少${label}视角结论行"
        return
    fi

    verdict=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $2}')
    issue_count=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $3}')

    if ! printf '%s\n' "$verdict" | grep -qE '^(PASS|WARN|FAIL)$'; then
        add_failure "PRD「审查汇总」${label}视角 Verdict 不可解析"
        return
    fi

    if ! printf '%s\n' "$issue_count" | grep -qE '^[0-9]+$'; then
        add_failure "PRD「审查汇总」${label}视角 Issue Count 不可解析"
        return
    fi

    issue_rows=$(printf '%s\n' "$PRD_REVIEW_LEDGER_ROWS" | awk -F'\t' -v prefix="$prefix" '$1 ~ ("^" prefix "-[0-9]{3,}$") { print }')
    issue_row_count=$(printf '%s\n' "$issue_rows" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$verdict" = "PASS" ] && [ "$issue_count" != "0" ]; then
        add_failure "PRD「审查汇总」${label}视角 Verdict=PASS 时 Issue Count 必须为 0"
    fi
    if [ "$verdict" != "PASS" ] && [ "$issue_count" = "0" ]; then
        add_failure "PRD「审查汇总」${label}视角 Verdict=${verdict} 时 Issue Count 不得为 0"
    fi
    if [ "$issue_count" != "$issue_row_count" ]; then
        add_failure "PRD「审查问题台账」${label}视角稳定 issue 数量=${issue_row_count} 与审查汇总 Issue Count=${issue_count} 不一致"
    fi
    if [ "$verdict" = "FAIL" ]; then
        add_failure "${label}审查 Verdict 为 FAIL，阻塞 /product 完成"
    fi

    while IFS=$'\t' read -r issue_id view severity status evidence_anchor handoff_target review_round resolution; do
        [ -n "$issue_id" ] || continue

        if is_placeholder_text "$view"; then
            add_failure "PRD「审查问题台账」${issue_id} 缺少视角"
        fi
        if is_placeholder_text "$severity"; then
            add_failure "PRD「审查问题台账」${issue_id} 缺少 Severity"
        fi
        if is_placeholder_text "$status"; then
            add_failure "PRD「审查问题台账」${issue_id} 缺少 Status"
        fi
        if is_placeholder_text "$evidence_anchor"; then
            add_failure "PRD「审查问题台账」${issue_id} 缺少 Evidence Anchor"
        fi
        if is_placeholder_text "$handoff_target"; then
            add_failure "PRD「审查问题台账」${issue_id} 缺少 Handoff Target"
        fi
        if is_placeholder_text "$review_round"; then
            add_failure "PRD「审查问题台账」${issue_id} 缺少 Review Round"
        fi
        if is_placeholder_text "$resolution"; then
            add_failure "PRD「审查问题台账」${issue_id} 缺少处理摘要"
        fi

        if [ "$verdict" = "WARN" ]; then
            if ! printf '%s\n' "$PRD_HANDOFF_CONTENT" | grep -qF "$issue_id"; then
                add_failure "${label}审查 WARN 项 ${issue_id} 未在 PRD 的「审查结论」中显式记录"
            elif ! validate_handoff_entry "$issue_id" "$PRD_HANDOFF_CONTENT"; then
                add_failure "${label}审查 WARN 项 ${issue_id} 在「审查结论」中缺少实质承接内容（需写明：已修正/承接位置/不处理理由）"
            fi
        fi
    done <<< "$issue_rows"
}

for review_args in \
    "产品|PR" \
    "架构|AR" \
    "测试|TR"; do
    IFS='|' read -r r_label r_prefix <<< "$review_args"
    check_embedded_review_conclusion "$r_label" "$r_prefix"
done

output_failures "产品文档完整性检查未通过" "$FEATURE_DIR"
exit 0
