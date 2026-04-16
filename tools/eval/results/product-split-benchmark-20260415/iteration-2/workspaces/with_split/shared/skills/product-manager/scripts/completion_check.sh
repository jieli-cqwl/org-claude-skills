#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
product-manager/completion_check.sh — Manager handoff 与 PRD 完整性检查脚本
执行时机: PostToolUse(Edit|Write) 收口门禁
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
hook_init

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(brief\.md|phase-[0-9]+/prd\.md|phase-[0-9]+/units/UNIT-[0-9]+\.md)'
resolve_feature_dir "docs/*/brief.md" "$TRANSCRIPT_PATTERN" "brief.md"

_fc_count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
if [ -z "$FEATURE_DIR" ] || [ "$_fc_count" != "1" ]; then
    # shellcheck disable=SC2034
    FAILURES=""
    resolve_feature_dir "docs/*/phase-*/prd.md" "$TRANSCRIPT_PATTERN" "prd.md" "docs/*/phase-*"
fi

_fc_count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
if { [ -z "$FEATURE_DIR" ] || [ "$_fc_count" != "1" ]; } && [ -n "$TOOL_FILE_PATH" ]; then
    _path_candidate=$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^(docs/[^/]+)/.*#\1#p')
    if [ -n "$_path_candidate" ] && [ -d "$_path_candidate" ]; then
        # shellcheck disable=SC2034
        FAILURES=""
        FEATURE_DIR="$_path_candidate"
        FEATURE_CANDIDATES="$_path_candidate"
    fi
fi
output_failures "Product-manager handoff 检查未通过" ""

BRIEF_FILE="$FEATURE_DIR/brief.md"
BRIEF_LOCK_REQUIRED_HEADINGS=(
    "业务背景与根问题"
    "目标与成功标准"
    "范围 / 本期不交付"
    "前置约束"
    "产品总监确认"
    "交付计划"
)
PRD_LOCK_REQUIRED_HEADINGS=(
    "阶段目标"
    "入口与出口条件"
    "功能需求（UNIT 索引）"
)

should_run_gate() {
    if [ -z "${TOOL_NAME:-}" ]; then
        return 0
    fi
    if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
        return 0
    fi
    if [ -n "${TOOL_FILE_PATH:-}" ]; then
        local basename_file
        basename_file=$(basename "$TOOL_FILE_PATH")
        if [ "$basename_file" = "brief.md" ]; then
            return 0
        fi
        if printf '%s' "$TOOL_FILE_PATH" | grep -qE 'phase-[0-9]+/(prd\.md|units/UNIT-[0-9]+\.md)$'; then
            return 0
        fi
        return 1
    fi
    return 0
}

extract_confirmation_field() {
    local section="$1"
    local field="$2"
    printf '%s\n' "$section" | sed -nE "s/^- ${field}:[[:space:]]*(.*)$/\\1/p" | head -1
}

director_confirmation_section() {
    extract_section_by_name "$BRIEF_FILE" "产品总监确认" 2
}

validate_director_handoff_preconditions() {
    local section status confirm_time brief_lock prd_files prd_file prd_lock

    if [ ! -f "$BRIEF_FILE" ]; then
        add_failure "Brief 文档不存在：$BRIEF_FILE"
        return 0
    fi

    section=$(director_confirmation_section)
    if [ -z "$section" ]; then
        add_failure "缺少「产品总监确认」章节；legacy brief 必须先完成 migration candidate + re-signoff"
        return 0
    fi

    status=$(extract_confirmation_field "$section" "确认状态")
    confirm_time=$(extract_confirmation_field "$section" "确认时间")

    case "$status" in
        已通过|通过|确认)
            ;;
        *)
            add_failure "产品总监确认未通过，必须先回到 /product-director 完成 D-G1"
            ;;
    esac

    if ! is_valid_confirmation_time "$confirm_time"; then
        add_failure "产品总监确认时间缺少有效时间（需使用 YYYY-MM-DD HH:mm）"
    fi

    brief_lock="$FEATURE_DIR/brief.lock.json"
    if [ ! -f "$brief_lock" ]; then
        add_failure "缺少 brief.lock.json"
    elif ! jq -e . "$brief_lock" >/dev/null 2>&1; then
        add_failure "brief.lock.json 不是有效 JSON"
    fi

    prd_files=$(find "$FEATURE_DIR" -type f -name 'prd.md' | rg '/phase-[0-9]+/prd\.md$' || true)
    if [ -z "$prd_files" ]; then
        add_failure "缺少 phase-{N}/prd.md"
        return 0
    fi

    while IFS= read -r prd_file; do
        [ -n "$prd_file" ] || continue
        prd_lock="${prd_file%/prd.md}/prd.lock.json"
        if [ ! -f "$prd_lock" ]; then
            add_failure "缺少 $(printf '%s' "$prd_file" | grep -oE 'phase-[0-9]+/prd\.md' | sed 's#/prd\.md$#/prd.lock.json#')"
        elif ! jq -e . "$prd_lock" >/dev/null 2>&1; then
            add_failure "${prd_lock##*/} 不是有效 JSON"
        fi
    done <<< "$prd_files"

    return 0
}

normalize_text() {
    printf '%s' "$1" | perl -0pe 's/[[:blank:]\r]+$//mg; s/\n+\z//'
}

strip_snapshot_heading() {
    local heading="$1"
    local snapshot="$2"
    local first_line

    first_line=$(printf '%s\n' "$snapshot" | head -n 1)
    if [ "$first_line" = "## $heading" ]; then
        printf '%s\n' "$snapshot" | tail -n +2
        return 0
    fi

    printf '%s' "$snapshot"
}

normalize_locked_section_for_comparison() {
    local heading="$1"
    local content="$2"

    case "$heading" in
        "交付计划")
            printf '%s\n' "$content" | awk '
                /^### Phase / { print; next }
                /^- (入口条件|出口条件|交付价值):/ { print }
            '
            ;;
        "前置约束")
            if printf '%s\n' "$content" | grep -q '^|'; then
                printf '%s\n' "$content" | awk -F'|' '
                    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
                    /^\|/ {
                        id = trim($2)
                        if (id == "" || id == "Constraint ID" || id ~ /^-+$/) next
                        print id "|" trim($3) "|" trim($4) "|" trim($5) "|" trim($6) "|" trim($8)
                    }
                '
                return 0
            fi
            printf '%s' "$content"
            ;;
        "功能需求（UNIT 索引）")
            printf '%s\n' "$content" | awk '
                /^\|/ {
                    print
                    count++
                    if (count == 2) exit
                }
            '
            ;;
        *)
            printf '%s' "$content"
            ;;
    esac
}

validate_lock_file_schema() {
    local lock_file="$1"
    local lock_kind="$2"
    local heading

    if ! jq -e '.sections and (.sections | type == "object") and ((.sections | keys | length) > 0)' "$lock_file" >/dev/null 2>&1; then
        return 1
    fi

    case "$lock_kind" in
        brief)
            for heading in "${BRIEF_LOCK_REQUIRED_HEADINGS[@]}"; do
                jq -e --arg heading "$heading" '.sections[$heading] | strings | length > 0' "$lock_file" >/dev/null 2>&1 || return 1
            done
            ;;
        prd)
            for heading in "${PRD_LOCK_REQUIRED_HEADINGS[@]}"; do
                jq -e --arg heading "$heading" '.sections[$heading] | strings | length > 0' "$lock_file" >/dev/null 2>&1 || return 1
            done
            ;;
    esac

    return 0
}

validate_locked_sections_against_file() {
    local lock_file="$1"
    local target_file="$2"
    local label="$3"
    local lock_kind="$4"
    local heading heading_alias expected actual

    if ! validate_lock_file_schema "$lock_file" "$lock_kind"; then
        add_failure "${label} 缺少可校验的 sections 快照"
        return 0
    fi

    while IFS= read -r heading; do
        [ -n "$heading" ] || continue
        expected=$(jq -r --arg heading "$heading" '.sections[$heading]' "$lock_file")
        expected=$(strip_snapshot_heading "$heading" "$expected")
        heading_alias=$(printf '%s' "$heading" | sed -E 's/[[:space:]]*[（(].*[)）][[:space:]]*$//')
        actual=$(extract_section_by_name "$target_file" "$heading" 2 "$heading_alias")
        expected=$(normalize_locked_section_for_comparison "$heading" "$expected")
        actual=$(normalize_locked_section_for_comparison "$heading" "$actual")
        if [ "$(normalize_text "$expected")" != "$(normalize_text "$actual")" ]; then
            add_failure "${label} 与当前文档不一致：${heading}"
        fi
    done < <(jq -r '.sections | keys[]' "$lock_file")

    return 0
}

validate_locked_field_drift() {
    local brief_lock prd_files prd_file prd_lock

    brief_lock="$FEATURE_DIR/brief.lock.json"
    [ -f "$brief_lock" ] && validate_locked_sections_against_file "$brief_lock" "$BRIEF_FILE" "brief.lock.json" "brief"

    prd_files=$(find "$FEATURE_DIR" -type f -name 'prd.md' | rg '/phase-[0-9]+/prd\.md$' || true)
    while IFS= read -r prd_file; do
        [ -n "$prd_file" ] || continue
        prd_lock="${prd_file%/prd.md}/prd.lock.json"
        [ -f "$prd_lock" ] && validate_locked_sections_against_file "$prd_lock" "$prd_file" "${prd_lock##*/}" "prd"
    done <<< "$prd_files"

    return 0
}

has_manager_review_verdict() {
    local view row verdict issue_count
    [ -f "$BRIEF_FILE" ] || return 1

    for view in 产品 架构 测试; do
        row=$(extract_review_summary_row "$BRIEF_FILE" "$view")
        [ -n "$row" ] || return 1
        verdict=$(printf '%s\n' "$row" | awk -F'\t' '{print $2}')
        issue_count=$(printf '%s\n' "$row" | awk -F'\t' '{print $3}')
        case "$verdict" in
            PASS|WARN|FAIL) ;;
            *) return 1 ;;
        esac
        if ! printf '%s' "$issue_count" | grep -qE '^[0-9]+$'; then
            return 1
        fi
    done

    return 0
}

validate_unit_ac_section() {
    local unit_file="$1"
    local unit_label="$2"
    local heading="$3"
    local section_content scenario_lines scenario_expr left_part right_part

    section_content=$(extract_section_content "$unit_file" "$heading" 3)
    scenario_lines=$(printf '%s\n' "$section_content" | grep -E '^[[:space:]]*[-*][[:space:]]+' || true)
    if [ -z "$scenario_lines" ]; then
        add_failure "${unit_label} ${heading} 无可解析的验收条目"
        return 0
    fi

    while IFS= read -r scenario_line; do
        [ -n "$scenario_line" ] || continue
        scenario_expr=$(printf '%s' "$scenario_line" | sed -E 's/^[[:space:]]*[-*][[:space:]]+//; s/^[[:space:]]+//; s/[[:space:]]+$//')

        if ! printf '%s' "$scenario_expr" | grep -qE '(->|→)'; then
            add_failure "${unit_label} ${heading} 条目格式不符合「输入/操作 -> 可观察结果」：${scenario_expr}"
            continue
        fi

        left_part=$(printf '%s' "$scenario_expr" | sed -E 's/(->|→).*//; s/^[[:space:]]+//; s/[[:space:]]+$//')
        right_part=$(printf '%s' "$scenario_expr" | sed -E 's/.*(->|→)[[:space:]]*//; s/^[[:space:]]+//; s/[[:space:]]+$//')
        if [ -z "$left_part" ] || [ -z "$right_part" ]; then
            add_failure "${unit_label} ${heading} 条目箭头两侧不能为空：${scenario_expr}"
        fi
    done <<< "$scenario_lines"
}

validate_unit_file() {
    local unit_file="$1"
    local unit_label="$2"
    local section_name
    local exclusion_section exclusion_lines

    for section_name in \
        "## 优先级依据" \
        "## 功能闭环定义" \
        "## 验收标准" \
        "### 正常场景" \
        "### 异常场景" \
        "### 边界条件" \
        "## 依赖" \
        "## 排除项"; do
        if ! grep -qF "$section_name" "$unit_file"; then
            add_failure "${unit_label} 缺少章节：${section_name}"
        fi
    done

    if ! grep -qE '^\*\*优先级\*\*:[[:space:]]*(MVP|增强|扩展)$' "$unit_file"; then
        add_failure "${unit_label} 缺少有效优先级（仅允许 MVP/增强/扩展）"
    fi

    if ! grep -qF -- '- 输入/触发:' "$unit_file"; then
        add_failure "${unit_label} 缺少「输入/触发」闭环定义"
    fi
    if ! grep -qF -- '- 核心行为:' "$unit_file"; then
        add_failure "${unit_label} 缺少「核心行为」闭环定义"
    fi
    if ! grep -qF -- '- 可观察结果:' "$unit_file"; then
        add_failure "${unit_label} 缺少「可观察结果」闭环定义"
    fi

    if grep -qF '### 正常场景' "$unit_file"; then
        validate_unit_ac_section "$unit_file" "$unit_label" "### 正常场景"
    fi
    if grep -qF '### 异常场景' "$unit_file"; then
        validate_unit_ac_section "$unit_file" "$unit_label" "### 异常场景"
    fi
    if grep -qF '### 边界条件' "$unit_file"; then
        validate_unit_ac_section "$unit_file" "$unit_label" "### 边界条件"
    fi

    if ! grep -qF -- '- 依赖 UNIT:' "$unit_file"; then
        add_failure "${unit_label} 缺少「依赖 UNIT」声明"
    fi

    if grep -qF '## 排除项' "$unit_file"; then
        exclusion_section=$(extract_markdown_section "$unit_file" "## 排除项")
        exclusion_lines=$(printf '%s\n' "$exclusion_section" | grep -cE '^[[:space:]]*[-*][[:space:]]+[^[:space:]]' || true)
        if [ "$exclusion_lines" -eq 0 ]; then
            add_failure "${unit_label}「排除项」章节为空，必须至少列出 1 条"
        fi
    fi
}

validate_manager_unit_artifacts() {
    local phase_dirs phase_dir phase_label phase_prd units_dir prd_units file_units missing_in_dir extra_in_dir unit_file unit_label

    phase_dirs=$(find "$FEATURE_DIR" -mindepth 1 -maxdepth 1 -type d -name 'phase-*' 2>/dev/null | sort)
    if [ -z "$phase_dirs" ]; then
        add_failure "缺少 phase-{N}/ 目录"
        return 0
    fi

    while IFS= read -r phase_dir; do
        [ -n "$phase_dir" ] || continue
        phase_label=$(basename "$phase_dir")
        phase_prd="${phase_dir}/prd.md"
        units_dir="${phase_dir}/units"

        if [ ! -f "$phase_prd" ]; then
            add_failure "${phase_label}/prd.md 不存在"
            continue
        fi
        if [ ! -d "$units_dir" ]; then
            add_failure "${phase_label}/units/ 目录不存在"
            continue
        fi

        prd_units=$({ grep -oE 'units/UNIT-[0-9]+\.md' "$phase_prd" 2>/dev/null || true; } | sed -E 's|units/||; s|\.md||' | sort -u)
        file_units=$(find "$units_dir" -maxdepth 1 -type f -name 'UNIT-*.md' -exec basename {} .md \; 2>/dev/null | sort -u)

        if [ -z "$file_units" ]; then
            add_failure "${phase_label}/units/ 目录下无 UNIT-*.md 文件"
            continue
        fi

        missing_in_dir=$(comm -23 <(printf '%s\n' "$prd_units" | sed '/^$/d') <(printf '%s\n' "$file_units" | sed '/^$/d') | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
        extra_in_dir=$(comm -13 <(printf '%s\n' "$prd_units" | sed '/^$/d') <(printf '%s\n' "$file_units" | sed '/^$/d') | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
        [ -z "$missing_in_dir" ] || add_failure "${phase_label}/prd.md 引用了但 ${phase_label}/units/ 缺失的 UNIT：$missing_in_dir"
        [ -z "$extra_in_dir" ] || add_failure "${phase_label}/units/ 存在但 ${phase_label}/prd.md 未引用的 UNIT：$extra_in_dir"

        while IFS= read -r unit_file; do
            [ -n "$unit_file" ] || continue
            unit_label="${phase_label}/$(basename "$unit_file")"
            validate_unit_file "$unit_file" "$unit_label"
        done < <(find "$units_dir" -maxdepth 1 -type f -name 'UNIT-*.md' 2>/dev/null | sort)
    done <<< "$phase_dirs"

    return 0
}

validate_manager_review_gate() {
    local view row verdict issue_count stable_issue_count ledger_rows

    ledger_rows=$(extract_review_issue_ledger_rows "$BRIEF_FILE")
    if [ -z "$ledger_rows" ]; then
        add_failure "审查结论缺少可解析的审查问题台账"
    fi

    for view in 产品 架构 测试; do
        row=$(extract_review_summary_row "$BRIEF_FILE" "$view")
        if [ -z "$row" ]; then
            add_failure "审查结论缺少 ${view} 视角汇总"
            continue
        fi

        verdict=$(printf '%s\n' "$row" | awk -F'\t' '{print $2}')
        issue_count=$(printf '%s\n' "$row" | awk -F'\t' '{print $3}')

        case "$verdict" in
            PASS|WARN|FAIL)
                ;;
            *)
                add_failure "审查结论 ${view} 视角 Verdict 非法：${verdict}"
                continue
                ;;
        esac

        if ! printf '%s' "$issue_count" | grep -qE '^[0-9]+$'; then
            add_failure "审查结论 ${view} 视角 Issue Count 非法：${issue_count}"
        fi

        stable_issue_count=$(printf '%s\n' "$ledger_rows" | awk -F'\t' -v target="$view" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            {
                issue_id = trim($1)
                issue_view = trim($2)
                if (issue_id == "" || issue_id ~ /^HIS-/) next
                if (issue_view == target) count++
            }
            END { print count + 0 }
        ')

        if [ "$verdict" = "FAIL" ]; then
            add_failure "审查结论存在未关闭 FAIL：${view} 视角"
        fi

        if [ "$verdict" = "PASS" ] && [ "$issue_count" != "0" ]; then
            add_failure "审查结论 ${view} 视角为 PASS 时，Issue Count 必须为 0"
        fi

        if [ "$verdict" = "PASS" ] && [ "$stable_issue_count" != "0" ]; then
            add_failure "审查结论 ${view} 视角为 PASS 时，审查问题台账中不能残留稳定 issue"
        fi

        if { [ "$verdict" = "WARN" ] || [ "$verdict" = "FAIL" ]; } && [ "$issue_count" = "0" ]; then
            add_failure "审查结论 ${view} 视角为 ${verdict} 时，Issue Count 必须大于 0"
        fi

        if { [ "$verdict" = "WARN" ] || [ "$verdict" = "FAIL" ]; } && [ "$stable_issue_count" = "0" ]; then
            add_failure "审查结论 ${view} 视角为 ${verdict} 时，审查问题台账必须保留稳定 issue"
        fi

        if [ "$stable_issue_count" != "$issue_count" ]; then
            add_failure "审查结论 ${view} 视角 Issue Count 与审查问题台账不一致"
        fi
    done

    return 0
}

manager_review_has_fail() {
    local view row verdict
    for view in 产品 架构 测试; do
        row=$(extract_review_summary_row "$BRIEF_FILE" "$view")
        verdict=$(printf '%s\n' "$row" | awk -F'\t' '{print $2}')
        if [ "$verdict" = "FAIL" ]; then
            return 0
        fi
    done
    return 1
}

validate_manager_delivery_confirmation() {
    local delivery_section delivery_status delivery_time

    delivery_section=$(extract_markdown_section "$BRIEF_FILE" "## 交付确认")
    if [ -z "$delivery_section" ]; then
        add_failure "缺少「交付确认」章节"
        return 0
    fi

    delivery_status=$(printf '%s\n' "$delivery_section" \
        | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认状态[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
        | head -1 \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    delivery_time=$(printf '%s\n' "$delivery_section" \
        | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认时间[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
        | head -1 \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    if is_placeholder_text "$delivery_status"; then
        add_failure "审查已通过但「交付确认」尚未填写，请在 M-S9 完成用户确认"
        return 0
    fi
    if [ "$delivery_status" != "确认" ]; then
        add_failure "「交付确认」确认状态必须为「确认」"
    fi
    if ! is_valid_confirmation_time "$delivery_time"; then
        add_failure "「交付确认」缺少有效确认时间（需使用 YYYY-MM-DD HH:mm）"
    fi

    return 0
}

validate_manager_completion_contract() {
    local section_name

    for section_name in "## 共创摘要" "## 审查结论"; do
        if ! grep -qF "$section_name" "$BRIEF_FILE"; then
            add_failure "brief.md 缺少章节：${section_name}"
        fi
    done

    validate_manager_unit_artifacts
    validate_manager_review_gate
    if ! manager_review_has_fail; then
        validate_manager_delivery_confirmation
    fi

    return 0
}

if ! should_run_gate; then
    exit 0
fi

validate_director_handoff_preconditions
validate_locked_field_drift
if has_manager_review_verdict; then
    validate_manager_completion_contract
fi
output_failures "Product-manager handoff 检查未通过" "$FEATURE_DIR"
