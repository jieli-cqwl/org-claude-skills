#!/bin/bash
# QA 验收报告完整性自动检查脚本
# 触发时机: qa skill-local Stop
# 功能: 检查 qa-report.md 的分级、阶段汇总与最终结论完整性

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
qa/completion_check.sh — QA 验收报告完整性自动检查脚本
触发时机: qa skill-local Stop
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
说明: 需校验审查分级、## 验收汇总、QA_A/QA_B/QA_C/QA_D 状态与 RESULT: PASS | FAIL
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
hook_init

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/)?qa-report\.md'
resolve_feature_dir "docs/*/phase-*/qa-report.md" "$TRANSCRIPT_PATTERN" "qa-report.md" "docs/*/phase-*"
output_failures "QA 验收报告完整性检查未通过" ""

resolve_phase_work_dir_from_prd "$FEATURE_DIR" "qa-report.md"
WORK_DIR="$PHASE_WORK_DIR"

REPORT_FILE="$WORK_DIR/qa-report.md"
PLAN_FILE="$WORK_DIR/plan.md"

trim() {
    local v="$1"
    v=$(printf '%s' "$v" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    printf '%s' "$v"
}

normalize_stage_status() {
    local raw
    raw=$(trim "$1")
    raw=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]')

    case "$raw" in
        OK)
            printf '%s' "OK"
            ;;
        ISSUE|FAIL)
            printf '%s' "ISSUE"
            ;;
        N/A|NA)
            printf '%s' "N/A"
            ;;
        *)
            printf '%s' "$raw"
            ;;
    esac
}

parse_report_grade() {
    local report_file="$1"
    local line value

    line=$(grep -E '审查分级:[[:space:]]*' "$report_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E 's/.*审查分级:[[:space:]]*//')
    value=$(trim "$value")

    if printf '%s' "$value" | grep -qE '[|/]'; then
        printf '%s' ""
        return 0
    fi
    if printf '%s' "$value" | grep -qE '\{.*\}'; then
        printf '%s' ""
        return 0
    fi

    if printf '%s' "$value" | grep -qE '^(轻量|标准|完整|未指定)$'; then
        printf '%s' "$value"
    else
        printf '%s' ""
    fi
}

parse_table_stage_status() {
    local report_file="$1" key="$2"
    local line status

    line=$(grep -E "\|[[:space:]]*${key}([（(]|[[:space:]]*\|)" "$report_file" 2>/dev/null | head -1 || true)
    if [ -z "$line" ]; then
        printf '%s' ""
        return 0
    fi

    status=$(printf '%s\n' "$line" | awk -F'|' '{s=$3; gsub(/^[ \t]+|[ \t]+$/, "", s); print s}')
    printf '%s' "$(normalize_stage_status "$status")"
}

extract_result() {
    local report_file="$1"
    grep -E '^RESULT:[[:space:]]*(PASS|FAIL)[[:space:]]*$' "$report_file" 2>/dev/null \
        | head -1 \
        | sed -E 's/^RESULT:[[:space:]]*//'
}

parse_plan_grade() {
    local plan_file="$1"
    local line value

    [ -f "$plan_file" ] || return 0

    line=$(grep -E '审查分级[[:space:]]*[:：]' "$plan_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E 's/.*[:：][[:space:]]*//')
    value=$(trim "$value")

    if printf '%s' "$value" | grep -qE '^(轻量|标准|完整)$'; then
        printf '%s' "$value"
    fi
}

parse_execution_scope() {
    local report_file="$1"
    local line value

    line=$(grep -E '执行范围:[[:space:]]*' "$report_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E 's/.*执行范围:[[:space:]]*//')
    value=$(trim "$value")
    value=$(printf '%s' "$value" | sed -E 's/[（(].*$//; s/[[:space:]]+$//')

    if printf '%s' "$value" | grep -qE '^(full|验证-A|验证-B|验证-C|验证-D)$'; then
        printf '%s' "$value"
    fi
}

if [ ! -f "$REPORT_FILE" ]; then
    add_failure "qa-report.md 不存在：$REPORT_FILE"
elif [ ! -s "$REPORT_FILE" ]; then
    add_failure "qa-report.md 为空：$REPORT_FILE"
fi

if [ ! -f "$REPORT_FILE" ] || [ ! -s "$REPORT_FILE" ]; then
    output_failures "QA 验收报告完整性检查未通过" "$WORK_DIR"
    exit 0
fi

if ! grep -qF "## 验收汇总" "$REPORT_FILE"; then
    add_failure "qa-report.md 缺少章节：## 验收汇总"
fi

REPORT_GRADE=$(parse_report_grade "$REPORT_FILE")
if [ -z "$REPORT_GRADE" ]; then
    add_failure "qa-report.md 缺少有效的审查分级（仅允许 轻量/标准/完整/未指定）"
fi

EXECUTION_SCOPE=$(parse_execution_scope "$REPORT_FILE")
if [ -z "$EXECUTION_SCOPE" ]; then
    add_failure "qa-report.md 缺少有效的执行范围（仅允许 full/验证-A/验证-B/验证-C/验证-D）"
fi

PLAN_GRADE=$(parse_plan_grade "$PLAN_FILE")
if [ -n "$PLAN_GRADE" ] && [ -n "$REPORT_GRADE" ] && [ "$REPORT_GRADE" != "未指定" ] && [ "$REPORT_GRADE" != "$PLAN_GRADE" ]; then
    add_failure "qa-report.md 审查分级与 plan.md 不一致（qa=${REPORT_GRADE}, plan=${PLAN_GRADE}）"
fi

QA_A_STATUS=""
QA_B_STATUS=""
QA_C_STATUS=""
QA_D_STATUS=""
for stage in QA_A QA_B QA_C QA_D; do
    status=$(parse_table_stage_status "$REPORT_FILE" "$stage")
    if [ -z "$status" ]; then
        add_failure "验收汇总缺少 ${stage} 状态（QA_A/QA_B/QA_C/QA_D 必须完整）"
        continue
    fi
    if [ "$status" != "OK" ] && [ "$status" != "ISSUE" ] && [ "$status" != "N/A" ]; then
        add_failure "验收汇总 ${stage} 状态非法：${status}（仅允许 OK/ISSUE/N/A）"
    fi
    case "$stage" in
        QA_A) QA_A_STATUS="$status" ;;
        QA_B) QA_B_STATUS="$status" ;;
        QA_C) QA_C_STATUS="$status" ;;
        QA_D) QA_D_STATUS="$status" ;;
    esac
done

RESULT=$(extract_result "$REPORT_FILE")
if [ -z "$RESULT" ]; then
    add_failure "qa-report.md 缺少最终结果（RESULT: PASS | FAIL）"
fi

if [ -n "$EXECUTION_SCOPE" ]; then
    case "$EXECUTION_SCOPE" in
        full)
            for scope_status in "$QA_A_STATUS" "$QA_B_STATUS" "$QA_C_STATUS" "$QA_D_STATUS"; do
                if [ "$scope_status" = "N/A" ]; then
                    add_failure "执行范围=full 时，QA_A/QA_B/QA_C/QA_D 均不得为 N/A"
                    break
                fi
            done
            ;;
        验证-A)
            [ "$QA_A_STATUS" = "N/A" ] && add_failure "执行范围=验证-A 时，QA_A 不得为 N/A"
            for scope_status in "$QA_B_STATUS" "$QA_C_STATUS" "$QA_D_STATUS"; do
                [ "$scope_status" != "N/A" ] && add_failure "执行范围=验证-A 时，非目标阶段必须标记为 N/A" && break
            done
            ;;
        验证-B)
            [ "$QA_B_STATUS" = "N/A" ] && add_failure "执行范围=验证-B 时，QA_B 不得为 N/A"
            for scope_status in "$QA_A_STATUS" "$QA_C_STATUS" "$QA_D_STATUS"; do
                [ "$scope_status" != "N/A" ] && add_failure "执行范围=验证-B 时，非目标阶段必须标记为 N/A" && break
            done
            ;;
        验证-C)
            [ "$QA_C_STATUS" = "N/A" ] && add_failure "执行范围=验证-C 时，QA_C 不得为 N/A"
            for scope_status in "$QA_A_STATUS" "$QA_B_STATUS" "$QA_D_STATUS"; do
                [ "$scope_status" != "N/A" ] && add_failure "执行范围=验证-C 时，非目标阶段必须标记为 N/A" && break
            done
            ;;
        验证-D)
            [ "$QA_D_STATUS" = "N/A" ] && add_failure "执行范围=验证-D 时，QA_D 不得为 N/A"
            for scope_status in "$QA_A_STATUS" "$QA_B_STATUS" "$QA_C_STATUS"; do
                [ "$scope_status" != "N/A" ] && add_failure "执行范围=验证-D 时，非目标阶段必须标记为 N/A" && break
            done
            ;;
    esac
fi

if [ "$RESULT" = "PASS" ]; then
    for scope_status in "$QA_A_STATUS" "$QA_B_STATUS" "$QA_C_STATUS" "$QA_D_STATUS"; do
        if [ "$scope_status" = "ISSUE" ]; then
            add_failure "RESULT=PASS 时，验收汇总中不得存在 ISSUE 阶段"
            break
        fi
    done
elif [ "$RESULT" = "FAIL" ]; then
    if [ "$QA_A_STATUS" != "ISSUE" ] && [ "$QA_B_STATUS" != "ISSUE" ] && [ "$QA_C_STATUS" != "ISSUE" ] && [ "$QA_D_STATUS" != "ISSUE" ]; then
        add_failure "RESULT=FAIL 时，验收汇总至少需要 1 个 ISSUE 阶段"
    fi
fi

POTENTIAL_ISSUE_ROWS=$(extract_markdown_section "$REPORT_FILE" "## 已排除潜在问题" | grep -cE '^\|[[:space:]]*[0-9]+' || true)
if [ "$POTENTIAL_ISSUE_ROWS" -lt 2 ]; then
    add_failure "已排除潜在问题不足 2 条"
fi

FAIL_DETAIL_ROWS=0
if grep -qF "## FAIL 详情" "$REPORT_FILE"; then
    FAIL_DETAIL_ROWS=$(extract_markdown_section "$REPORT_FILE" "## FAIL 详情" | grep -cE '^\|[[:space:]]*QAR-[0-9]+' || true)
    if [ "$FAIL_DETAIL_ROWS" -eq 0 ] && [ "$RESULT" = "FAIL" ]; then
        add_failure "RESULT=FAIL 时，FAIL 详情至少需要 1 条 QAR-XXX 记录"
    fi
fi

if [ "$RESULT" = "FAIL" ] && [ "$FAIL_DETAIL_ROWS" -eq 0 ]; then
    add_failure "RESULT=FAIL 时，FAIL 详情至少需要 1 条 QAR-XXX 记录"
fi

output_failures "QA 验收报告完整性检查未通过" "$WORK_DIR"
exit 0
