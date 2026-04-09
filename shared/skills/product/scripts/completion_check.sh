#!/bin/bash
# 产品文档完整性自动检查脚本
# 执行时机: PostToolUse(Edit|Write) 收口门禁
# 功能: 精确定位当前 feature，并检查 brief.md/phase-prd/UNIT/审查闭环
# 版本: v5.0 2026-04-09
# 产出结构: brief.md + phase-{N}/prd.md + phase-{N}/units/UNIT-*.md

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

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(brief\.md|phase-[0-9]+/prd\.md|phase-[0-9]+/units/UNIT-[0-9]+\.md)'
resolve_feature_dir "docs/*/brief.md" "$TRANSCRIPT_PATTERN" "brief.md"
# 当 brief.md 锚定无法唯一定位时，尝试 phase-prd 作为备选锚点
_fc_count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
if [ -z "$FEATURE_DIR" ] || [ "$_fc_count" != "1" ]; then
    FAILURES=""
    resolve_feature_dir "docs/*/phase-*/prd.md" "$TRANSCRIPT_PATTERN" "prd.md" "docs/*/phase-*"
fi
# 最终 fallback：从 TOOL_FILE_PATH 直接提取 feature dir
_fc_count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
if { [ -z "$FEATURE_DIR" ] || [ "$_fc_count" != "1" ]; } && [ -n "$TOOL_FILE_PATH" ]; then
    _path_candidate=$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^(docs/[^/]+)/.*#\1#p')
    if [ -n "$_path_candidate" ] && [ -d "$_path_candidate" ]; then
        FAILURES=""
        FEATURE_DIR="$_path_candidate"
        FEATURE_CANDIDATES="$_path_candidate"
    fi
fi
output_failures "产品文档完整性检查未通过" ""

BRIEF_FILE="$FEATURE_DIR/brief.md"

# --- 分阶段门禁策略 ---
# 成熟度信号: brief.md 的 ## 审查结论 中包含可解析的 Verdict（PASS/WARN/FAIL）
# 早期写入（无 Verdict）: 仅做轻量结构检查
# 全量校验（有 Verdict）: 运行完整 completeness_check

has_verdict() {
    [ -f "$BRIEF_FILE" ] || return 1
    local review_section
    review_section=$(extract_section_by_name "$BRIEF_FILE" "审查结论" 2)
    [ -n "$review_section" ] || return 1
    printf '%s\n' "$review_section" | grep -qE '(PASS|WARN|FAIL)' 2>/dev/null
}

should_run_gate() {
    [ -f "$BRIEF_FILE" ] || return 1

    if [ -z "${TOOL_NAME:-}" ]; then
        return 0
    fi
    if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
        return 0
    fi

    # 编辑 brief.md / phase-prd / UNIT 文件时触发
    if [ -n "$TOOL_FILE_PATH" ]; then
        local basename_file
        basename_file=$(basename "$TOOL_FILE_PATH")
        if [ "$basename_file" = "brief.md" ]; then
            return 0
        fi
        # phase-{N}/prd.md or phase-{N}/units/UNIT-*.md
        if printf '%s' "$TOOL_FILE_PATH" | grep -qE 'phase-[0-9]+/(prd\.md|units/UNIT-[0-9]+\.md)'; then
            return 0
        fi
        return 1
    fi

    # file_path 为空时：检查 brief.md 是否包含 late-stage 标志章节（兼容无 file_path 的调用方式）
    if grep -qF "## 审查结论" "$BRIEF_FILE" || grep -qF "## 交付计划" "$BRIEF_FILE" || grep -qF "## 交接项" "$BRIEF_FILE"; then
        return 0
    fi

    return 1
}

if ! should_run_gate; then
    exit 0
fi

# --- 轻量检查（始终执行） ---

if [ ! -f "$BRIEF_FILE" ]; then
    add_failure "Brief 文档不存在：$BRIEF_FILE"
elif [ ! -s "$BRIEF_FILE" ]; then
    add_failure "Brief 文档为空：$BRIEF_FILE"
fi

# 如果没有 Verdict，做轻量检查（brief 存在性 + 当前编辑文件的基本格式）后退出
if ! has_verdict; then
    # 当前编辑文件的基本格式校验
    if [ -n "$TOOL_FILE_PATH" ] && [ -f "$TOOL_FILE_PATH" ]; then
        local_edited_basename=$(basename "$TOOL_FILE_PATH")
        if [ "$local_edited_basename" = "prd.md" ] && printf '%s' "$TOOL_FILE_PATH" | grep -qE 'phase-[0-9]+/prd\.md'; then
            for section in "## 阶段目标" "## 入口与出口条件" "## 功能需求（UNIT 索引）"; do
                if ! grep -qF "$section" "$TOOL_FILE_PATH"; then
                    add_failure "$(printf '%s' "$TOOL_FILE_PATH" | grep -oE 'phase-[0-9]+/prd\.md') 缺少章节：$section"
                fi
            done
        fi
        if printf '%s' "$TOOL_FILE_PATH" | grep -qE 'UNIT-[0-9]+\.md$'; then
            if [ ! -s "$TOOL_FILE_PATH" ]; then
                add_failure "${local_edited_basename} 文件为空"
            fi
        fi
    fi
    output_failures "产品文档完整性检查未通过（轻量检查）" "$FEATURE_DIR"
    exit 0
fi

# === 以下为全量校验（审查结论有 Verdict 后触发） ===

# --- brief.md 必需章节检查（20 个） ---

REQUIRED_BRIEF_SECTIONS=(
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

if [ -f "$BRIEF_FILE" ]; then
    for section in "${REQUIRED_BRIEF_SECTIONS[@]}"; do
        if ! grep -qF "$section" "$BRIEF_FILE"; then
            add_failure "brief.md 缺少章节：$section"
        fi
    done
fi

# --- phase-{N}/prd.md 必需章节检查（3 个） ---

REQUIRED_PHASE_PRD_SECTIONS=(
    "## 阶段目标"
    "## 入口与出口条件"
    "## 功能需求（UNIT 索引）"
)

PHASE_DIRS=$(find "$FEATURE_DIR" -mindepth 1 -maxdepth 1 -type d -name 'phase-*' 2>/dev/null | sort)

if [ -z "$PHASE_DIRS" ]; then
    add_failure "未找到任何 phase-{N}/ 目录"
fi

while IFS= read -r phase_dir; do
    [ -n "$phase_dir" ] || continue
    local_phase=$(basename "$phase_dir")
    phase_prd="${phase_dir}/prd.md"

    if [ ! -f "$phase_prd" ]; then
        add_failure "${local_phase}/prd.md 不存在"
        continue
    fi

    for section in "${REQUIRED_PHASE_PRD_SECTIONS[@]}"; do
        if ! grep -qF "$section" "$phase_prd"; then
            add_failure "${local_phase}/prd.md 缺少章节：$section"
        fi
    done
done <<< "$PHASE_DIRS"

# --- 已排查并排除的潜在问题至少 2 条 ---

if [ -f "$BRIEF_FILE" ]; then
    EP_COUNT=$({ grep -oE 'EP-[0-9]+' "$BRIEF_FILE" 2>/dev/null || true; } | sort -u | wc -l | tr -d ' ')
    if [ "$EP_COUNT" -lt 2 ]; then
        add_failure "「已排查并排除的潜在问题」不足 2 条（当前 ${EP_COUNT} 条），完成校验要求至少 2 条"
    fi
fi

# --- 影响范围必须有实质内容 ---

if [ -f "$BRIEF_FILE" ]; then
    IMPACT_SECTION=$(extract_markdown_section "$BRIEF_FILE" "## 影响范围")
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

if [ -f "$BRIEF_FILE" ]; then
    DECISION_SECTION=$(extract_markdown_section "$BRIEF_FILE" "## 待设计决策")
    DD_COUNT=$({ printf '%s\n' "$DECISION_SECTION" | grep -oE 'DD-[0-9]+' || true; } | sort -u | wc -l | tr -d ' ')
    if [ "$DD_COUNT" -lt 1 ]; then
        add_failure "「待设计决策」未定义任何 DD 编号，design 阶段无可追踪输入"
    fi
fi

# --- 前置约束必须为结构化对象或显式声明无前置约束 ---

if [ -f "$BRIEF_FILE" ]; then
    CONSTRAINT_ROWS=$(extract_prd_constraint_rows "$BRIEF_FILE")
    CONSTRAINT_COUNT=$(printf '%s\n' "$CONSTRAINT_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
    NO_CONSTRAINTS_DECLARED=false
    if has_explicit_no_constraints_declaration "$BRIEF_FILE"; then
        NO_CONSTRAINTS_DECLARED=true
    fi

    if [ "$CONSTRAINT_COUNT" -eq 0 ]; then
        if [ "$NO_CONSTRAINTS_DECLARED" != "true" ]; then
            add_failure "「前置约束」必须至少包含 1 条结构化约束，或显式声明"无前置约束（经评估）""
        fi
    else
        if [ "$NO_CONSTRAINTS_DECLARED" = "true" ]; then
            add_failure "「前置约束」不能同时包含结构化约束和"无前置约束（经评估）"声明"
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

# --- 共创摘要验证（7 阶段） ---
if [ -f "$BRIEF_FILE" ]; then
    CO_CREATE_SECTION=$(extract_markdown_section "$BRIEF_FILE" "## 共创摘要")
    CO_CREATE_DATA_ROWS=$(printf '%s\n' "$CO_CREATE_SECTION" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            c1=trim($2); c2=trim($3); c3=trim($4); c4=trim($5)
            if (c1 == "" || c1 == "阶段" || c1 ~ /^-+$/) next
            if (c1 != "" || c2 != "" || c3 != "" || c4 != "") count++
        }
        END { print count + 0 }
    ')
    if [ "$CO_CREATE_DATA_ROWS" -lt 7 ]; then
        add_failure "「共创摘要」数据行不足 7 条（当前 ${CO_CREATE_DATA_ROWS} 条），必须覆盖 7 个阶段"
    fi

    for stage in \
        "根问题澄清" \
        "目标与成功标准对齐" \
        "语义/范围收口" \
        "Phase 规划" \
        "PRD/UNIT 与 AC" \
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
# S11 期间（有 FAIL 视角）：允许确认状态为占位符，不阻断审查修复循环
# S11 完成后（全部 PASS/WARN）：强制要求 确认状态=确认 + 有效时间
if [ -f "$BRIEF_FILE" ]; then
    DELIVERY_SECTION=$(extract_markdown_section "$BRIEF_FILE" "## 交付确认")
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

        # 判断 S11 是否完成（所有审查视角均无 FAIL）
        _review_has_fail=false
        for _v in 产品 架构 测试; do
            _vrow=$(extract_review_summary_row "$BRIEF_FILE" "$_v")
            _vverdict=$(printf '%s\n' "$_vrow" | awk -F'\t' '{print $2}')
            if [ "$_vverdict" = "FAIL" ]; then
                _review_has_fail=true
                break
            fi
        done

        if [ -n "$delivery_status" ] && ! is_placeholder_text "$delivery_status"; then
            # 确认状态已填写（非占位）→ 校验状态值和时间
            if [ "$delivery_status" != "确认" ]; then
                add_failure "「交付确认」确认状态必须为「确认」"
            fi
            if ! is_valid_confirmation_time "$delivery_time"; then
                add_failure "「交付确认」缺少有效确认时间（需使用 YYYY-MM-DD HH:mm 且不可为模板占位）"
            fi
        elif [ "$_review_has_fail" = "false" ]; then
            # S11 完成（无 FAIL）但确认状态仍为占位 → 需要 S12 填写确认
            add_failure "审查已通过但「交付确认」尚未填写，请在 S12 步骤完成用户确认"
        fi
        # S11 仍有 FAIL 且确认状态为占位 → 正常审查循环，不阻断
    fi
fi

# --- 关键假设验证 ---
if [ -f "$BRIEF_FILE" ]; then
    KEY_ASSUMPTIONS=$(extract_markdown_section "$BRIEF_FILE" "## 关键假设")
    KA_ROWS=$(printf '%s\n' "$KEY_ASSUMPTIONS" | grep -cE '^\|[[:space:]]*[^-|]' || true)
    if [ "$KA_ROWS" -lt 2 ]; then
        add_failure "「关键假设」无数据行，至少需要 1 条假设"
    fi
fi

# --- AC 场景行验证函数 ---

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

# --- UNIT 检查（遍历所有 phase-{N}/units/） ---

ALL_UNIT_FILES=""
TOTAL_UNIT_COUNT=0

while IFS= read -r phase_dir; do
    [ -n "$phase_dir" ] || continue
    local_phase=$(basename "$phase_dir")
    units_dir="${phase_dir}/units"

    if [ ! -d "$units_dir" ]; then
        add_failure "${local_phase}/units/ 目录不存在"
        continue
    fi

    PHASE_UNIT_FILES=$(find "$units_dir" -maxdepth 1 -type f -name 'UNIT-*.md' 2>/dev/null | sort)
    PHASE_UNIT_COUNT=$(printf '%s\n' "$PHASE_UNIT_FILES" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$PHASE_UNIT_COUNT" -eq 0 ]; then
        add_failure "${local_phase}/units/ 目录下无 UNIT-*.md 文件（每个 Phase 至少包含一个 UNIT）"
        continue
    fi

    TOTAL_UNIT_COUNT=$((TOTAL_UNIT_COUNT + PHASE_UNIT_COUNT))
    ALL_UNIT_FILES="${ALL_UNIT_FILES:+${ALL_UNIT_FILES}
}${PHASE_UNIT_FILES}"

    while IFS= read -r unit_file; do
        [ -n "$unit_file" ] || continue
        unit_name=$(basename "$unit_file")

        if ! grep -qF "## 功能闭环定义" "$unit_file"; then
            add_failure "${local_phase}/${unit_name} 缺少「功能闭环定义」章节"
        fi

        if ! grep -qF "## 排除项" "$unit_file"; then
            add_failure "${local_phase}/${unit_name} 缺少「排除项」章节"
        else
            exclusion_content=$(extract_markdown_section "$unit_file" "## 排除项")
            exclusion_lines=$(printf '%s\n' "$exclusion_content" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
            if [ "$exclusion_lines" = "0" ]; then
                add_failure "${local_phase}/${unit_name}「排除项」章节为空，必须至少列出一条排除项"
            fi
        fi

        for ac_section in "### 正常场景" "### 异常场景" "### 边界条件"; do
            if ! grep -qF "$ac_section" "$unit_file"; then
                add_failure "${local_phase}/${unit_name} 缺少验收标准子章节：${ac_section}"
            else
                validate_ac_scenario_lines "$unit_file" "${local_phase}/${unit_name}" "$ac_section"
            fi
        done
    done <<< "$PHASE_UNIT_FILES"
done <<< "$PHASE_DIRS"

# --- UNIT ID 全局唯一性校验 ---
# UNIT 编号全局递增（不按 Phase 重置），重复 ID 会导致依赖和路由校验错误
_all_unit_ids_for_dup=""
while IFS= read -r phase_dir; do
    [ -n "$phase_dir" ] || continue
    local_phase=$(basename "$phase_dir")
    units_dir="${phase_dir}/units"
    [ -d "$units_dir" ] || continue
    while IFS= read -r unit_file; do
        [ -n "$unit_file" ] || continue
        uid=$(basename "$unit_file" .md)
        if printf '%s\n' "$_all_unit_ids_for_dup" | grep -qxF "$uid"; then
            add_failure "UNIT ID 跨 Phase 重复：$uid（${local_phase}/units/ 和之前的 Phase 中同时存在）"
        fi
        _all_unit_ids_for_dup="${_all_unit_ids_for_dup:+${_all_unit_ids_for_dup}
}${uid}"
    done < <(find "$units_dir" -maxdepth 1 -type f -name 'UNIT-*.md' 2>/dev/null | sort)
done <<< "$PHASE_DIRS"

# --- UNIT 交叉验证（3 层） ---

# 层 1: Phase 内校验 — phase-{N}/prd.md UNIT 索引 vs phase-{N}/units/ 文件一致
while IFS= read -r phase_dir; do
    [ -n "$phase_dir" ] || continue
    local_phase=$(basename "$phase_dir")
    phase_prd="${phase_dir}/prd.md"
    units_dir="${phase_dir}/units"

    [ -f "$phase_prd" ] || continue
    [ -d "$units_dir" ] || continue

    # 从定义文件列提取（units/UNIT-N.md），排除依赖列中的跨 Phase 引用
    PRD_UNITS=$(grep -oE 'units/UNIT-[0-9]+\.md' "$phase_prd" 2>/dev/null | sed -E 's|units/||; s|\.md||' | sort -u)
    FILE_UNITS=$(find "$units_dir" -maxdepth 1 -type f -name 'UNIT-*.md' -exec basename {} .md \; 2>/dev/null | sort -u)

    MISSING_IN_DIR=$(comm -23 <(printf '%s\n' "$PRD_UNITS" | sed '/^$/d') <(printf '%s\n' "$FILE_UNITS" | sed '/^$/d') | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
    EXTRA_IN_DIR=$(comm -13 <(printf '%s\n' "$PRD_UNITS" | sed '/^$/d') <(printf '%s\n' "$FILE_UNITS" | sed '/^$/d') | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')

    [ -z "$MISSING_IN_DIR" ] || add_failure "${local_phase}/prd.md 引用了但 ${local_phase}/units/ 缺失的 UNIT：$MISSING_IN_DIR"
    [ -z "$EXTRA_IN_DIR" ] || add_failure "${local_phase}/units/ 存在但 ${local_phase}/prd.md 未引用的 UNIT：$EXTRA_IN_DIR"
done <<< "$PHASE_DIRS"

# 层 2: 全局依赖校验 — 汇总所有 UNIT 的依赖字段，验证依赖目标存在且 Phase 顺序合法
ALL_UNIT_IDS=""
# Bash 3.2 兼容：用换行分隔的 "UNIT-N=phase_num" 列表替代 associative array
UNIT_PHASE_ENTRIES=""

while IFS= read -r phase_dir; do
    [ -n "$phase_dir" ] || continue
    local_phase=$(basename "$phase_dir")
    phase_num=$(printf '%s' "$local_phase" | grep -oE '[0-9]+')
    units_dir="${phase_dir}/units"
    [ -d "$units_dir" ] || continue

    while IFS= read -r unit_file; do
        [ -n "$unit_file" ] || continue
        unit_id=$(basename "$unit_file" .md)
        ALL_UNIT_IDS="${ALL_UNIT_IDS:+${ALL_UNIT_IDS}
}${unit_id}"
        UNIT_PHASE_ENTRIES="${UNIT_PHASE_ENTRIES:+${UNIT_PHASE_ENTRIES}
}${unit_id}=${phase_num}"
    done < <(find "$units_dir" -maxdepth 1 -type f -name 'UNIT-*.md' 2>/dev/null | sort)
done <<< "$PHASE_DIRS"

# 查询 UNIT 所在 Phase 编号（Bash 3.2 兼容）
get_unit_phase() {
    local target="$1"
    printf '%s\n' "$UNIT_PHASE_ENTRIES" | grep -F "${target}=" | head -1 | sed 's/.*=//'
}

# 依赖目标存在性 + Phase 顺序合法性校验
while IFS= read -r phase_dir; do
    [ -n "$phase_dir" ] || continue
    local_phase=$(basename "$phase_dir")
    phase_num=$(printf '%s' "$local_phase" | grep -oE '[0-9]+')
    phase_prd="${phase_dir}/prd.md"
    [ -f "$phase_prd" ] || continue

    # 从 UNIT 索引表的依赖列提取依赖 UNIT ID
    unit_index_section=$(extract_section_by_name "$phase_prd" "功能需求（UNIT 索引）" 2)
    dep_ids=$(printf '%s\n' "$unit_index_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            dep = trim($6)
            if (dep == "" || dep == "依赖" || dep ~ /^-+$/ || dep == "-") next
            n = split(dep, parts, /[,;[:space:]]+/)
            for (i = 1; i <= n; i++) {
                if (parts[i] ~ /^UNIT-[0-9]+$/) print parts[i]
            }
        }
    ' 2>/dev/null | sort -u || true)

    while IFS= read -r dep_id; do
        [ -n "$dep_id" ] || continue
        # 检查依赖目标是否存在
        if ! printf '%s\n' "$ALL_UNIT_IDS" | grep -qxF "$dep_id"; then
            add_failure "${local_phase}/prd.md 依赖了不存在的 UNIT：$dep_id"
            continue
        fi
        # 检查依赖 Phase 顺序合法（依赖目标所在 Phase <= 当前 Phase）
        dep_phase_num=$(get_unit_phase "$dep_id")
        if [ -n "$dep_phase_num" ] && [ "$dep_phase_num" -gt "$phase_num" ]; then
            add_failure "${local_phase}/prd.md 中 UNIT 依赖了后续 Phase 的 $dep_id（位于 phase-${dep_phase_num}）"
        fi
    done <<< "$dep_ids"
done <<< "$PHASE_DIRS"

# 层 3: 路由一致性 — brief.md 交付计划 vs phase-{N}/prd.md vs 实际文件 三方一致
if [ -f "$BRIEF_FILE" ]; then
    PLAN_SECTION_FOR_UNITS=$(extract_markdown_section "$BRIEF_FILE" "## 交付计划")
    PLAN_UNIT_IDS=$(printf '%s\n' "$PLAN_SECTION_FOR_UNITS" | grep -oE 'UNIT-[0-9]+' 2>/dev/null | sort -u)
    ACTUAL_UNIT_IDS=$(printf '%s\n' "$ALL_UNIT_IDS" | sed '/^$/d' | sort -u)

    PLAN_ONLY=$(comm -23 <(printf '%s\n' "$PLAN_UNIT_IDS" | sed '/^$/d') <(printf '%s\n' "$ACTUAL_UNIT_IDS" | sed '/^$/d') | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
    ACTUAL_ONLY=$(comm -13 <(printf '%s\n' "$PLAN_UNIT_IDS" | sed '/^$/d') <(printf '%s\n' "$ACTUAL_UNIT_IDS" | sed '/^$/d') | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')

    [ -z "$PLAN_ONLY" ] || add_failure "brief.md 交付计划引用了但实际文件缺失的 UNIT：$PLAN_ONLY"
    [ -z "$ACTUAL_ONLY" ] || add_failure "实际存在但 brief.md 交付计划未引用的 UNIT：$ACTUAL_ONLY"

    # Phase 归属一致性：brief.md 交付计划中每个 Phase 的 UNIT 定义文件 vs 实际 phase-{N}/units/ 文件
    while IFS= read -r phase_dir; do
        [ -n "$phase_dir" ] || continue
        local_phase=$(basename "$phase_dir")
        units_dir="${phase_dir}/units"
        [ -d "$units_dir" ] || continue

        # 从 brief.md 交付计划中提取该 Phase 的 UNIT 定义文件
        plan_phase_units=$(printf '%s\n' "$PLAN_SECTION_FOR_UNITS" \
            | grep -oE "${local_phase}/units/UNIT-[0-9]+\\.md" 2>/dev/null \
            | sed -E "s|${local_phase}/units/||; s|\\.md||" | sort -u)
        actual_phase_units=$(find "$units_dir" -maxdepth 1 -type f -name 'UNIT-*.md' -exec basename {} .md \; 2>/dev/null | sort -u)

        phase_mismatch=$(comm -3 \
            <(printf '%s\n' "$plan_phase_units" | sed '/^$/d') \
            <(printf '%s\n' "$actual_phase_units" | sed '/^$/d') \
            | tr '\t' ' ' | sed '/^$/d' | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
        [ -z "$phase_mismatch" ] || add_failure "brief.md 交付计划与 ${local_phase}/units/ 实际文件 Phase 归属不一致：$phase_mismatch"
    done <<< "$PHASE_DIRS"
fi

# --- 交付计划检查 ---

if [ -f "$BRIEF_FILE" ]; then
    if ! grep -qF "## 交付计划" "$BRIEF_FILE"; then
        add_failure "brief.md 缺少「交付计划」章节"
    else
        phase_section=$(extract_markdown_section "$BRIEF_FILE" "## 交付计划")
        phase_count=$(printf '%s\n' "$phase_section" | grep -cE '^### Phase [0-9]+' || true)
        if [ "$phase_count" -lt 1 ]; then
            add_failure "「交付计划」中未找到任何 Phase 定义"
        fi
        # 检查工作区映射表
        workspace_count=$(printf '%s\n' "$phase_section" | grep -cE 'phase-[0-9]+/unit-[0-9]+/' || true)
        if [ "$workspace_count" -lt 1 ]; then
            add_failure "「交付计划」缺少工作区路径映射（phase-{N}/unit-{M}/ 格式）"
        fi
        # 检查定义文件列
        def_file_count=$(printf '%s\n' "$phase_section" | grep -cE 'phase-[0-9]+/units/UNIT-[0-9]+\.md' || true)
        if [ "$def_file_count" -lt 1 ]; then
            add_failure "「交付计划」缺少定义文件列（phase-{N}/units/UNIT-{M}.md 格式）"
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
        phase_dir_refs=$(printf '%s\n' "$phase_section" | grep -oE 'phase-[0-9]+/' | sort -u || true)
        while IFS= read -r phase_path; do
            [ -n "$phase_path" ] || continue
            full_phase_dir="${FEATURE_DIR}/${phase_path%/}"
            if [ ! -d "$full_phase_dir" ]; then
                add_failure "「交付计划」定义了 ${phase_path} 但物理目录未创建：$full_phase_dir"
            fi
        done <<< "$phase_dir_refs"
    fi
fi

# --- 3+ UNIT 全 MVP 时需 MVP 说明（全局统计） ---

if [ "$TOTAL_UNIT_COUNT" -ge 3 ] && [ -n "$ALL_UNIT_FILES" ]; then
    MVP_COUNT=0
    while IFS= read -r unit_file; do
        [ -n "$unit_file" ] || continue
        if grep -qE '^\*\*优先级\*\*:[[:space:]]*MVP' "$unit_file"; then
            MVP_COUNT=$((MVP_COUNT + 1))
        fi
    done <<< "$ALL_UNIT_FILES"

    if [ "$MVP_COUNT" -eq "$TOTAL_UNIT_COUNT" ] && [ -f "$BRIEF_FILE" ]; then
        mvp_section=$(extract_markdown_section "$BRIEF_FILE" "## MVP 最小闭环说明")
        mvp_lines=$(printf '%s\n' "$mvp_section" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
        if [ "$mvp_lines" = "0" ]; then
            add_failure "UNIT 数量 >= 3 且全部为 MVP，但 brief.md 缺少非空的「MVP 最小闭环说明」"
        fi
    fi
fi

# --- brief.md 内嵌审查结论校验 ---

# 从 brief.md 审查结论章节提取 WARN 处理记录
BRIEF_HANDOFF_CONTENT=""
if [ -f "$BRIEF_FILE" ]; then
    BRIEF_HANDOFF_CONTENT=$(extract_markdown_section "$BRIEF_FILE" "## 审查结论")
fi

if [ -z "$(extract_section_content "$BRIEF_FILE" "### 审查汇总" 3)" ]; then
    add_failure "brief.md「审查结论」缺少「### 审查汇总」"
fi

BRIEF_REVIEW_LEDGER_ROWS=$(extract_review_issue_ledger_rows "$BRIEF_FILE")
if [ -z "$BRIEF_REVIEW_LEDGER_ROWS" ]; then
    add_failure "brief.md「审查结论」缺少可解析的「审查问题台账」"
fi

check_embedded_review_conclusion() {
    local label="$1" prefix="$2"
    local summary_row verdict issue_count issue_rows issue_row_count

    summary_row=$(extract_review_summary_row "$BRIEF_FILE" "$label")
    if [ -z "$summary_row" ]; then
        add_failure "brief.md「审查汇总」缺少${label}视角结论行"
        return
    fi

    verdict=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $2}')
    issue_count=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $3}')

    if ! printf '%s\n' "$verdict" | grep -qE '^(PASS|WARN|FAIL)$'; then
        add_failure "brief.md「审查汇总」${label}视角 Verdict 不可解析"
        return
    fi

    if ! printf '%s\n' "$issue_count" | grep -qE '^[0-9]+$'; then
        add_failure "brief.md「审查汇总」${label}视角 Issue Count 不可解析"
        return
    fi

    issue_rows=$(printf '%s\n' "$BRIEF_REVIEW_LEDGER_ROWS" | awk -F'\t' -v prefix="$prefix" '$1 ~ ("^" prefix "-[0-9]{3,}$") { print }')
    issue_row_count=$(printf '%s\n' "$issue_rows" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$verdict" = "PASS" ] && [ "$issue_count" != "0" ]; then
        add_failure "brief.md「审查汇总」${label}视角 Verdict=PASS 时 Issue Count 必须为 0"
    fi
    if [ "$verdict" != "PASS" ] && [ "$issue_count" = "0" ]; then
        add_failure "brief.md「审查汇总」${label}视角 Verdict=${verdict} 时 Issue Count 不得为 0"
    fi
    if [ "$issue_count" != "$issue_row_count" ]; then
        add_failure "brief.md「审查问题台账」${label}视角稳定 issue 数量=${issue_row_count} 与审查汇总 Issue Count=${issue_count} 不一致"
    fi
    if [ "$verdict" = "FAIL" ]; then
        add_failure "${label}审查 Verdict 为 FAIL，阻塞 /product 完成"
    fi

    while IFS=$'\t' read -r issue_id view severity status evidence_anchor handoff_target review_round resolution; do
        [ -n "$issue_id" ] || continue

        if is_placeholder_text "$view"; then
            add_failure "brief.md「审查问题台账」${issue_id} 缺少视角"
        fi
        if is_placeholder_text "$severity"; then
            add_failure "brief.md「审查问题台账」${issue_id} 缺少 Severity"
        fi
        if is_placeholder_text "$status"; then
            add_failure "brief.md「审查问题台账」${issue_id} 缺少 Status"
        fi
        if is_placeholder_text "$evidence_anchor"; then
            add_failure "brief.md「审查问题台账」${issue_id} 缺少 Evidence Anchor"
        fi
        if is_placeholder_text "$handoff_target"; then
            add_failure "brief.md「审查问题台账」${issue_id} 缺少 Handoff Target"
        fi
        if is_placeholder_text "$review_round"; then
            add_failure "brief.md「审查问题台账」${issue_id} 缺少 Review Round"
        fi
        if is_placeholder_text "$resolution"; then
            add_failure "brief.md「审查问题台账」${issue_id} 缺少处理摘要"
        fi

        if [ "$verdict" = "WARN" ]; then
            if ! printf '%s\n' "$BRIEF_HANDOFF_CONTENT" | grep -qF "$issue_id"; then
                add_failure "${label}审查 WARN 项 ${issue_id} 未在 brief.md 的「审查结论」中显式记录"
            elif ! validate_handoff_entry "$issue_id" "$BRIEF_HANDOFF_CONTENT"; then
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
