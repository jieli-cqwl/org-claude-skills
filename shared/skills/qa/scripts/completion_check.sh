#!/bin/bash
# QA 验收报告完整性自动检查脚本
# 触发时机: qa skill-local Stop
# 功能: 检查 qa-result.json（legacy qa-report.md 仅兼容旧流程）的分级、放行结论与证据完整性

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
qa/completion_check.sh — QA 验收报告完整性自动检查脚本
触发时机: qa skill-local Stop
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
说明: 需校验审查分级、执行范围、QA_A/QA_B/QA_C/QA_D、release_recommendation、residual_risk、uncovered_boundary、conditional_release_basis、not_executed_reason 与 FAIL triage 字段
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
hook_init

first_matching_hook_path() {
    local pattern="$1"
    if [ -n "${TOOL_FILE_PATH:-}" ] && printf '%s' "$TOOL_FILE_PATH" | grep -qE "^${pattern}$"; then
        printf '%s\n' "$TOOL_FILE_PATH"
        return 0
    fi
    if [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        grep -oE "$pattern" "$TRANSCRIPT_PATH" 2>/dev/null | head -1 || true
    fi
}

browser_tool_looks_browser_native() {
    local tool
    tool=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [ -n "$tool" ] || return 1
    if printf '%s' "$tool" | grep -Eq '(^|[^[:alnum:]])(curl|wget|httpie|grpcurl|postman|axios|requests?|api|fetch)($|[^[:alnum:]])'; then
        return 1
    fi
    printf '%s' "$tool" | grep -Eq 'playwright|browser|chrom(e|ium)|firefox|webkit|safari|puppeteer|cypress|selenium|webapp-testing|devtools'
}

browser_evidence_looks_browser_native() {
    local file="$1"
    jq -e '
        (.browser_evidence | type == "array" and length > 0)
        and all(.browser_evidence[]; type == "string" and ((gsub("^\\s+|\\s+$"; "")) | length > 0))
        and any(.browser_evidence[]; test("playwright|browser|screenshot|screen recording|video|trace|dom|locator|click|page|navigation|console|network|webapp-testing"; "i"))
        and all(.browser_evidence[]; (test("curl|wget|httpie|grpcurl|postman|api response|axios|requests|fetch\\("; "i") | not) or test("playwright|browser|page|screenshot|trace|video|webapp-testing"; "i"))
    ' "$file" >/dev/null 2>&1
}

browser_required_evidence_is_valid() {
    local file="$1"
    local browser_tool entry_url
    browser_tool=$(jq -r '.browser_tool // ""' "$file" 2>/dev/null || true)
    entry_url=$(jq -r '.entry_url // ""' "$file" 2>/dev/null || true)

    browser_tool_looks_browser_native "$browser_tool" || return 1
    printf '%s' "$entry_url" | grep -Eq '^https?://[^[:space:]]+$' || return 1
    browser_evidence_looks_browser_native "$file"
}

canonical_phase_requires_browser_evidence() {
    local phase_dir="$1"
    local test_cases
    while IFS= read -r test_cases; do
        [ -n "$test_cases" ] || continue
        if jq -e '
            (.qa_handoff_contract | type == "array")
            and any(.qa_handoff_contract[]; (.qa_stage // "") == "QA_B" and (.execution_mode // "") == "browser_required")
        ' "$test_cases" >/dev/null 2>&1; then
            return 0
        fi
    done < <(find "$phase_dir" -type f -path '*/unit-*/test-cases.json' 2>/dev/null | sort || true)
    return 1
}

run_canonical_qa_gate() {
    local target phase_dir
    target=$(first_matching_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/qa-result\.json')
    if [ -z "$target" ]; then
        if is_stop_dispatch_context && [ "${ORG_ENABLE_LEGACY_MARKDOWN_HOOKS:-0}" != "1" ]; then
            add_failure "qa-result.json 路径未命中，无法确认 canonical QA 工件是否已落盘"
            output_failures "QA 验收报告完整性检查未通过（canonical）" ""
        fi
        return 1
    fi

    phase_dir=$(dirname "$target")
    if [ ! -f "$target" ]; then
        add_failure "qa-result.json 不存在：$target"
        output_failures "QA 验收报告完整性检查未通过（canonical）" "$target"
    fi
    if ! jq -e '
        .baseline_plan_version_ref
        and .baseline_tasks_version_ref
        and .gate_result
        and .release_recommendation
        and (.residual_risk | type == "array")
        and has("uncovered_boundary")
        and has("conditional_release_basis")
        and has("not_executed_reason")
        and (.ruled_out_issues | type == "array" and length >= 2)
    ' "$target" >/dev/null 2>&1; then
        add_failure "qa-result.json 缺少 canonical 必填字段（baseline refs / gate_result / release_recommendation / residual_risk / uncovered_boundary / conditional_release_basis / not_executed_reason / ruled_out_issues>=2）：$target"
    fi
    if ! jq -e '
        if .gate_result == "FAIL" then
            (.issue_ledger | type == "array" and length > 0)
            and all(.issue_ledger[]; .severity and .priority and .impact_scope and .user_impact and .environment_or_build and .regression_flag and .temporary_workaround and .owner_hint and .expected_behavior and .actual_behavior and .reproduction)
        else
            true
        end
    ' "$target" >/dev/null 2>&1; then
        add_failure "qa-result.json 在 gate_result=FAIL 时必须提供完整 triage issue_ledger：$target"
    fi
    if canonical_phase_requires_browser_evidence "$phase_dir" && ! browser_required_evidence_is_valid "$target"; then
        add_failure "qa-result.json 命中 browser_required 时必须提供真实浏览器工具与浏览器证据（browser_tool / entry_url / browser_evidence）：$target"
    fi
    if [ -f "$phase_dir/plan.json" ] && ! jq -e . "$phase_dir/plan.json" >/dev/null 2>&1; then
        add_failure "plan.json 不是合法 JSON：$phase_dir/plan.json"
    fi

    output_failures "QA 验收报告完整性检查未通过（canonical）" "$target"
    emit_decision_json "allow" "standard-chain canonical qa artifact valid"
    exit 0
}

run_canonical_qa_gate || true

if [ "${ORG_ENABLE_LEGACY_MARKDOWN_HOOKS:-0}" != "1" ]; then
    emit_decision_json "allow" "skip: legacy markdown qa hook disabled; standard-chain uses canonical JSON artifacts"
    exit 0
fi

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/)?qa-report\.md'
resolve_feature_dir "docs/*/phase-*/qa-report.md" "$TRANSCRIPT_PATTERN" "qa-report.md" "docs/*/phase-*"
output_failures "QA 验收报告完整性检查未通过" ""

resolve_phase_work_dir "$FEATURE_DIR" "qa-report.md"
PHASE_DIR="$PHASE_WORK_DIR"
REPORT_FILE="$PHASE_DIR/qa-report.md"
PLAN_FILE="$PHASE_DIR/plan.md"

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

extract_scalar_field() {
    local report_file="$1" key="$2"
    local line value
    line=$(grep -E "^[[:space:]]*${key}:[[:space:]]*" "$report_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//")
    printf '%s' "$(trim "$value")"
}

extract_plan_version() {
    local plan_file="$1" version_section line value
    [ -f "$plan_file" ] || return 0
    version_section=$(extract_markdown_section "$plan_file" "## 计划版本")
    line=$(printf '%s\n' "$version_section" | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*plan_version[[:space:]]*:[[:space:]]*(.*)$/\1/p' | head -1)
    value=$(trim "$line")
    if is_placeholder_text "$value"; then
        printf '%s' ""
        return 0
    fi
    printf '%s' "$value"
}

has_plan_version_ref() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE '(^|.*/)plan\.md#计划版本$'
}

has_issue_ledger_anchor() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE '(^|.*/)qa-report\.md#fail-details$'
}

extract_ref_anchor() {
    local ref="$1"
    if [ "${ref#*#}" = "$ref" ]; then
        printf '%s' ""
        return 0
    fi
    printf '%s' "${ref#*#}"
}

normalize_anchor_slug() {
    local value="$1"
    value=$(trim "$value")
    value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    value=$(printf '%s' "$value" | sed -E 's/[`"'\''‘’“”]//g; s/[[:space:]_]+/-/g; s/[^[:alnum:][:space:]\x80-\xFF-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//')
    printf '%s' "$value"
}

file_has_heading_anchor_slug() {
    local file="$1" expected_anchor="$2"
    local expected_slug heading_text heading_slug
    expected_slug=$(normalize_anchor_slug "$expected_anchor")
    [ -n "$expected_slug" ] || return 1

    while IFS= read -r heading_text; do
        heading_text=$(printf '%s' "$heading_text" | sed -E 's/^#{1,6}[[:space:]]*//')
        heading_slug=$(normalize_anchor_slug "$heading_text")
        if [ "$heading_slug" = "$expected_slug" ]; then
            return 0
        fi
    done < <(grep -E '^#{1,6}[[:space:]]+' "$file" 2>/dev/null || true)

    return 1
}

file_has_special_anchor_alias() {
    local file="$1" anchor="$2" anchor_slug
    anchor_slug=$(normalize_anchor_slug "$anchor")
    case "$anchor_slug" in
        fail-details)
            grep -qE '^##[[:space:]]+FAIL[[:space:]]+详情([[:space:]]|$)' "$file"
            return
            ;;
    esac
    return 1
}

resolve_ref_file_path() {
    local ref="$1" base_dir="$2"
    local path="${ref%%#*}"
    local dir base
    if [[ "$path" != /* ]]; then
        path="${base_dir}/$(printf '%s' "$path" | sed -E 's#^\./##')"
    fi
    dir=$(dirname "$path")
    base=$(basename "$path")
    if [ -d "$dir" ]; then
        dir=$(cd "$dir" 2>/dev/null && pwd)
        printf '%s/%s' "$dir" "$base"
    else
        printf '%s' "$path"
    fi
}

ref_anchor_exists_in_file() {
    local file="$1" anchor="$2"
    [ -f "$file" ] || return 1
    [ -n "$anchor" ] || return 1

    if grep -qF "<a id=\"$anchor\">" "$file" 2>/dev/null || grep -qF "<a id='$anchor'>" "$file" 2>/dev/null; then
        return 0
    fi
    if file_has_special_anchor_alias "$file" "$anchor"; then
        return 0
    fi
    if file_has_heading_anchor_slug "$file" "$anchor"; then
        return 0
    fi
    return 1
}

parse_report_grade() {
    local value
    value=$(extract_scalar_field "$1" "审查分级")
    if printf '%s' "$value" | grep -qE '^(轻量|标准|完整|未指定)$'; then
        printf '%s' "$value"
    fi
}

parse_plan_grade() {
    local value
    [ -f "$1" ] || return 0
    value=$(extract_scalar_field "$1" "审查分级")
    if printf '%s' "$value" | grep -qE '^(轻量|标准|完整)$'; then
        printf '%s' "$value"
    fi
}

parse_execution_scope() {
    local value
    value=$(extract_scalar_field "$1" "执行范围")
    value=$(printf '%s' "$value" | sed -E 's/[（(].*$//; s/[[:space:]]+$//')
    if printf '%s' "$value" | grep -qE '^(full|验证-A|验证-B|验证-C|验证-D)$'; then
        printf '%s' "$value"
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

extract_non_executed_rows() {
    local report_file="$1"
    extract_markdown_section "$report_file" "## 非执行项记录" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            target = trim($2)
            reason = trim($3)
            if (target == "" || target == "stage_or_obligation" || target ~ /^-+$/) next
            print target "|" reason
        }
    '
}

normalize_report_test_cases_ref() {
    local raw_ref="$1" phase_dir="$2"
    local normalized

    normalized=$(trim "$raw_ref")
    normalized=$(printf '%s' "$normalized" | sed -E 's/^[`"]+//; s/[`",]+$//')
    if [[ "$normalized" == "{phase_dir}"* ]]; then
        normalized="${phase_dir}${normalized#\{phase_dir\}}"
    elif [[ "$normalized" == "phase_dir/"* ]]; then
        normalized="${phase_dir}/${normalized#phase_dir/}"
    fi

    if [[ "$normalized" != /* ]]; then
        normalized="$phase_dir/$normalized"
    fi

    printf '%s\n' "$normalized"
}

extract_report_test_case_refs() {
    local report_file="$1" phase_dir="$2"
    local qa_b_section ref_line raw_ref normalized

    qa_b_section=$(extract_markdown_section "$report_file" "## 验证-B: E2E 用户旅程")
    [ -n "$qa_b_section" ] || return 0

    while IFS= read -r ref_line; do
        [ -n "$ref_line" ] || continue
        while IFS= read -r raw_ref; do
            [ -n "$raw_ref" ] || continue
            normalized=$(normalize_report_test_cases_ref "$raw_ref" "$phase_dir")
            printf '%s\n' "$normalized"
        done < <(printf '%s\n' "$ref_line" | grep -oE '`[^`]+test-cases\.md`|\{phase_dir\}/[^`,} ]+test-cases\.md|[^`,{} ]+test-cases\.md' || true)
    done <<< "$(printf '%s\n' "$qa_b_section" | grep -E 'test_cases_refs?:' || true)" | sort -u
}

extract_browser_required_handoffs() {
    local test_case_refs="$1"
    local test_cases_file handoff_section

    while IFS= read -r test_cases_file; do
        [ -f "$test_cases_file" ] || continue
        handoff_section=$(extract_markdown_section "$test_cases_file" "## QA 交接契约")
        [ -n "$handoff_section" ] || continue
        printf '%s\n' "$handoff_section" | awk -F'|' -v tc_file="$test_cases_file" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            /^\|/ {
                test_obligation = trim($2)
                trigger_source = trim($3)
                qa_stage = trim($4)
                execution_mode = trim($6)
                if (test_obligation == "" || test_obligation == "test_obligation" || test_obligation ~ /^-+$/) next
                if (qa_stage == "QA_B" && execution_mode == "browser_required") {
                    print tc_file "|" test_obligation "|" trigger_source
                }
            }
        '
    done <<< "$test_case_refs"
}

has_valid_browser_evidence_anchor() {
    local browser_evidence="$1"
    local anchor value

    while IFS= read -r anchor; do
        anchor=$(trim "$anchor")
        [ -n "$anchor" ] || continue

        if printf '%s' "$anchor" | grep -qiE '^(screenshot|trace/video|trace|video|browser[_ -]?log|webapp-testing|Playwright|playwright)[[:space:]]*[:=]'; then
            value=$(printf '%s' "$anchor" | sed -E 's/^[^:=]+[:=][[:space:]]*//')
            if ! is_placeholder_text "$value"; then
                return 0
            fi
            continue
        fi

        if printf '%s' "$anchor" | grep -qiE '^(webapp-testing|Playwright|playwright)[[:space:]]+.+$'; then
            value=$(printf '%s' "$anchor" | sed -E 's/^(webapp-testing|Playwright|playwright)[[:space:]]+//')
            if ! is_placeholder_text "$value"; then
                return 0
            fi
        fi
    done < <(printf '%s' "$browser_evidence" | tr ';' '\n')

    return 1
}

validate_qa_b_journey_body() {
    local report_file="$1" qa_b_status="$2"
    local journey_design_section journey_exec_section data_flow_section journey_design_rows data_flow_rows

    [ "$qa_b_status" = "N/A" ] && return 0

    journey_design_section=$(extract_section_content "$report_file" "### 旅程设计" 3)
    if [ -z "$journey_design_section" ]; then
        add_failure "QA_B 已执行，但 qa-report.md 缺少 ### 旅程设计"
    else
        journey_design_rows=$(parse_table_by_header "$journey_design_section" "#" "旅程名称" "类型" "涉及 AC" "execution_mode" "步骤数")
        if [ "$(printf '%s\n' "$journey_design_rows" | sed '/^$/d' | wc -l | tr -d ' ')" -eq 0 ]; then
            add_failure "QA_B 已执行，但 ### 旅程设计 缺少数据行"
        fi
    fi

    journey_exec_section=$(extract_section_content "$report_file" "### 旅程执行" 3)
    if [ -z "$journey_exec_section" ]; then
        add_failure "QA_B 已执行，但 qa-report.md 缺少 ### 旅程执行"
    else
        if ! printf '%s\n' "$journey_exec_section" | grep -qE '^####[[:space:]]+旅程[[:space:]]+[0-9]+'; then
            add_failure "QA_B 已执行，但 ### 旅程执行 缺少旅程步骤块"
        fi
        if ! printf '%s\n' "$journey_exec_section" | grep -qE '^\|[[:space:]]*[0-9]+[[:space:]]*\|'; then
            add_failure "QA_B 已执行，但 ### 旅程执行 缺少步骤数据行"
        fi
    fi

    data_flow_section=$(extract_section_content "$report_file" "#### 数据流转验证" 4)
    if [ -z "$data_flow_section" ]; then
        add_failure "QA_B 已执行，但 qa-report.md 缺少 #### 数据流转验证"
    else
        data_flow_rows=$(parse_table_by_header "$data_flow_section" "步骤" "前序输出" "后续输入" "一致性")
        if [ "$(printf '%s\n' "$data_flow_rows" | sed '/^$/d' | wc -l | tr -d ' ')" -eq 0 ]; then
            add_failure "QA_B 已执行，但 #### 数据流转验证 缺少数据行"
        fi
    fi
}

validate_browser_required_evidence() {
    local report_file="$1" phase_dir="$2" qa_b_status="$3"
    local test_case_refs browser_required_handoffs browser_tool entry_url browser_evidence journey_design_section journey_rows report_browser_required_rows

    [ "$qa_b_status" = "N/A" ] && return 0

    test_case_refs=$(extract_report_test_case_refs "$report_file" "$phase_dir")
    if [ -z "$test_case_refs" ]; then
        add_failure "QA_B 已执行，但 qa-report.md 缺少可解析的 test_cases_refs"
        return 0
    fi

    browser_required_handoffs=$(extract_browser_required_handoffs "$test_case_refs")

    journey_design_section=$(extract_section_content "$report_file" "### 旅程设计" 3)
    if [ -n "$journey_design_section" ]; then
        journey_rows=$(parse_table_by_header "$journey_design_section" "#" "旅程名称" "类型" "涉及 AC" "execution_mode" "步骤数")
        report_browser_required_rows=$(printf '%s\n' "$journey_rows" | awk -F'\t' '$5 == "browser_required" { print }')
        if [ -n "$browser_required_handoffs" ] && [ -z "$report_browser_required_rows" ]; then
            add_failure "test_cases_ref 交接契约已触发 browser_required，但 qa-report.md 旅程设计 未同步标记 browser_required，不能自报降级"
        fi
        if [ -z "$browser_required_handoffs" ] && [ -n "$report_browser_required_rows" ]; then
            add_failure "qa-report.md 自报 browser_required，但引用的 test_cases_ref 交接契约未触发 browser_required"
        fi
    fi

    [ -n "$browser_required_handoffs" ] || return 0

    browser_tool=$(extract_scalar_field "$report_file" "browser_tool")
    entry_url=$(extract_scalar_field "$report_file" "entry_url")
    browser_evidence=$(extract_scalar_field "$report_file" "browser_evidence")

    if is_placeholder_text "$browser_tool"; then
        add_failure "QA_B 命中 browser_required，但 qa-report.md 缺少 browser_tool"
    fi
    if is_placeholder_text "$entry_url"; then
        add_failure "QA_B 命中 browser_required，但 qa-report.md 缺少 entry_url"
    fi
    if is_placeholder_text "$browser_evidence"; then
        add_failure "QA_B 命中 browser_required，但 qa-report.md 缺少 browser_evidence"
        return 0
    fi

    if ! has_valid_browser_evidence_anchor "$browser_evidence"; then
        if printf '%s' "$browser_evidence" | grep -qiE '(api|curl|http)'; then
            add_failure "QA_B 命中 browser_required，但 browser_evidence 只有 API/CLI 证据，不能替代浏览器证据"
        else
            add_failure "QA_B 命中 browser_required，但 browser_evidence 缺少有效浏览器证据锚点（screenshot/trace/video/browser log/Playwright/webapp-testing）"
        fi
    fi
}

validate_obligation_table() {
    local report_file="$1" heading="$2" label="$3" key_idx="$4" status_idx="$5" evidence_idx="$6" reason_idx="$7"
    local section rows

    section=$(extract_markdown_section "$report_file" "$heading")
    [ -n "$section" ] || return 0

    rows=$(printf '%s\n' "$section" | awk -F'|' -v key_idx="$key_idx" -v status_idx="$status_idx" -v evidence_idx="$evidence_idx" -v reason_idx="$reason_idx" '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            key = trim($(key_idx))
            status = trim($(status_idx))
            evidence = trim($(evidence_idx))
            reason = trim($(reason_idx))
            if (key == "" || key ~ /^-+$/ || key == "test_obligation" || key == "obligation") next
            print key "|" status "|" evidence "|" reason
        }
    ')

    while IFS='|' read -r item status evidence reason; do
        [ -n "$item" ] || continue
        case "$status" in
            DONE|ISSUE|N/A)
                ;;
            *)
                add_failure "${label} ${item} 的状态非法：${status}"
                continue
                ;;
        esac
        if [ "$status" = "N/A" ] && is_placeholder_text "$reason"; then
            add_failure "${label} ${item} 标记为 N/A，但缺少 not_executed_reason"
        fi
        if [ "$status" != "N/A" ] && is_placeholder_text "$evidence"; then
            add_failure "${label} ${item} 缺少有效 evidence"
        fi
    done <<< "$rows"
}

validate_fail_details() {
    local report_file="$1" result="$2"
    local fail_section fail_rows fail_count
    fail_section=$(extract_markdown_section "$report_file" "## FAIL 详情")
    fail_rows=$(printf '%s\n' "$fail_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            issue_id = trim($2)
            stage = trim($3)
            severity = trim($4)
            priority = trim($5)
            impact_scope = trim($6)
            user_impact = trim($7)
            environment_or_build = trim($8)
            regression_flag = trim($9)
            temporary_workaround = trim($10)
            owner_hint = trim($11)
            expected = trim($12)
            actual = trim($13)
            reproduce = trim($14)
            if (issue_id == "" || issue_id == "Issue ID" || issue_id ~ /^-+$/) next
            print issue_id "|" stage "|" severity "|" priority "|" impact_scope "|" user_impact "|" environment_or_build "|" regression_flag "|" temporary_workaround "|" owner_hint "|" expected "|" actual "|" reproduce
        }
    ')
    fail_count=$(printf '%s\n' "$fail_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    FAIL_DETAIL_COUNT="$fail_count"

    if [ "$result" = "FAIL" ] && [ "$fail_count" -eq 0 ]; then
        add_failure "RESULT=FAIL 时，FAIL 详情至少需要 1 条 QAR-XXX 记录"
        return
    fi

    [ "$fail_count" -eq 0 ] && return

    if ! printf '%s\n' "$fail_section" | grep -Fq '| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |'; then
        add_failure "FAIL 详情缺少完整 triage 表头（severity/priority/impact_scope/user_impact 等）"
    fi

    while IFS='|' read -r issue_id stage severity priority impact_scope user_impact environment_or_build regression_flag temporary_workaround owner_hint expected actual reproduce; do
        [ -n "$issue_id" ] || continue
        if ! printf '%s' "$issue_id" | grep -qE '^QAR-[0-9]{3,}$'; then
            add_failure "FAIL 详情存在非法 Issue ID：${issue_id}"
        fi
        temp_workaround_missing=0
        if is_placeholder_text "$temporary_workaround" && [ "$temporary_workaround" != "无" ] && [ "$temporary_workaround" != "none" ]; then
            temp_workaround_missing=1
        fi
        if is_placeholder_text "$stage" || is_placeholder_text "$severity" || is_placeholder_text "$priority" \
            || is_placeholder_text "$impact_scope" || is_placeholder_text "$user_impact" \
            || is_placeholder_text "$environment_or_build" || is_placeholder_text "$regression_flag" \
            || [ "$temp_workaround_missing" -eq 1 ] || is_placeholder_text "$owner_hint" \
            || is_placeholder_text "$expected" || is_placeholder_text "$actual" || is_placeholder_text "$reproduce"; then
            add_failure "${issue_id} 缺少完整 triage 字段（severity/priority/impact_scope/user_impact/environment_or_build/regression_flag/temporary_workaround/owner_hint/期望行为/实际行为/复现命令）"
        fi
    done <<< "$fail_rows"
}

if [ ! -f "$REPORT_FILE" ]; then
    add_failure "qa-report.md 不存在：$REPORT_FILE"
elif [ ! -s "$REPORT_FILE" ]; then
    add_failure "qa-report.md 为空：$REPORT_FILE"
fi

if [ ! -f "$REPORT_FILE" ] || [ ! -s "$REPORT_FILE" ]; then
    output_failures "QA 验收报告完整性检查未通过" "$PHASE_DIR"
    exit 0
fi

if ! grep -qF "## 验收汇总" "$REPORT_FILE"; then
    add_failure "qa-report.md 缺少章节：## 验收汇总"
fi

REPORT_GRADE=$(parse_report_grade "$REPORT_FILE")
PLAN_GRADE=$(parse_plan_grade "$PLAN_FILE")
EXECUTION_SCOPE=$(parse_execution_scope "$REPORT_FILE")
RESULT=$(extract_result "$REPORT_FILE")
RELEASE_RECOMMENDATION=$(extract_scalar_field "$REPORT_FILE" "release_recommendation")
RESIDUAL_RISK=$(extract_scalar_field "$REPORT_FILE" "residual_risk")
UNCOVERED_BOUNDARY=$(extract_scalar_field "$REPORT_FILE" "uncovered_boundary")
CONDITIONAL_RELEASE_BASIS=$(extract_scalar_field "$REPORT_FILE" "conditional_release_basis")
PLAN_VERSION_REF=$(extract_scalar_field "$REPORT_FILE" "plan_version_ref")
PLAN_VERSION_VALUE=$(extract_scalar_field "$REPORT_FILE" "plan_version_value")
ISSUE_LEDGER_ANCHOR=$(extract_scalar_field "$REPORT_FILE" "issue_ledger_anchor")
CURRENT_PLAN_VERSION=$(extract_plan_version "$PLAN_FILE")

if [ -z "$REPORT_GRADE" ]; then
    add_failure "qa-report.md 缺少有效的审查分级（仅允许 轻量/标准/完整/未指定）"
fi
if [ -z "$EXECUTION_SCOPE" ]; then
    add_failure "qa-report.md 缺少有效的执行范围（仅允许 full/验证-A/验证-B/验证-C/验证-D）"
fi
if ! has_plan_version_ref "$PLAN_VERSION_REF"; then
    add_failure "qa-report.md 缺少有效的 plan_version_ref"
else
    plan_version_ref_file=$(resolve_ref_file_path "$PLAN_VERSION_REF" "$PHASE_DIR")
    if [ ! -f "$plan_version_ref_file" ]; then
        add_failure "qa-report.md 的 plan_version_ref 指向的文件不存在：${plan_version_ref_file}"
    elif ! ref_anchor_exists_in_file "$plan_version_ref_file" "$(extract_ref_anchor "$PLAN_VERSION_REF")"; then
        add_failure "qa-report.md 的 plan_version_ref 引用的锚点不存在：${PLAN_VERSION_REF}"
    fi
fi
if is_placeholder_text "$PLAN_VERSION_VALUE"; then
    add_failure "qa-report.md 缺少有效的 plan_version_value"
elif is_placeholder_text "$CURRENT_PLAN_VERSION"; then
    add_failure "当前 plan.md 缺少有效的 plan_version，qa-report.md 无法确认最新消费版本"
elif [ "$PLAN_VERSION_VALUE" != "$CURRENT_PLAN_VERSION" ]; then
    add_failure "qa-report.md 的 plan_version_value 与当前 plan.md 不一致（qa=${PLAN_VERSION_VALUE}, plan=${CURRENT_PLAN_VERSION}）"
fi
if is_placeholder_text "$ISSUE_LEDGER_ANCHOR"; then
    add_failure "qa-report.md 缺少有效的 issue_ledger_anchor"
elif ! has_issue_ledger_anchor "$ISSUE_LEDGER_ANCHOR"; then
    add_failure "qa-report.md 的 issue_ledger_anchor 必须固定指向 qa-report.md#fail-details"
else
    issue_ledger_file=$(resolve_ref_file_path "$ISSUE_LEDGER_ANCHOR" "$PHASE_DIR")
    if [ ! -f "$issue_ledger_file" ]; then
        add_failure "qa-report.md 的 issue_ledger_anchor 指向的文件不存在：${issue_ledger_file}"
    elif ! ref_anchor_exists_in_file "$issue_ledger_file" "$(extract_ref_anchor "$ISSUE_LEDGER_ANCHOR")"; then
        add_failure "qa-report.md 的 issue_ledger_anchor 引用的锚点不存在：${ISSUE_LEDGER_ANCHOR}"
    fi
fi
if [ -n "$PLAN_GRADE" ] && [ -n "$REPORT_GRADE" ] && [ "$REPORT_GRADE" != "未指定" ] && [ "$REPORT_GRADE" != "$PLAN_GRADE" ]; then
    add_failure "qa-report.md 审查分级与 plan.md 不一致（qa=${REPORT_GRADE}, plan=${PLAN_GRADE}）"
fi

case "$RELEASE_RECOMMENDATION" in
    放行|条件放行|阻塞)
        ;;
    *)
        add_failure "qa-report.md 缺少有效的 release_recommendation（仅允许 放行/条件放行/阻塞）"
        ;;
esac

if is_placeholder_text "$RESIDUAL_RISK"; then
    add_failure "qa-report.md 缺少有效的 residual_risk"
fi
if [ -z "$UNCOVERED_BOUNDARY" ] || { is_placeholder_text "$UNCOVERED_BOUNDARY" && [ "$UNCOVERED_BOUNDARY" != "无" ]; }; then
    add_failure "qa-report.md 缺少有效的 uncovered_boundary"
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
    if [ "$RELEASE_RECOMMENDATION" = "阻塞" ]; then
        add_failure "RESULT=PASS 时，release_recommendation 不得为 阻塞"
    fi
elif [ "$RESULT" = "FAIL" ]; then
    if [ "$QA_A_STATUS" != "ISSUE" ] && [ "$QA_B_STATUS" != "ISSUE" ] && [ "$QA_C_STATUS" != "ISSUE" ] && [ "$QA_D_STATUS" != "ISSUE" ]; then
        add_failure "RESULT=FAIL 时，验收汇总至少需要 1 个 ISSUE 阶段"
    fi
    if [ "$RELEASE_RECOMMENDATION" != "阻塞" ]; then
        add_failure "RESULT=FAIL 时，release_recommendation 必须为 阻塞"
    fi
fi

NON_EXECUTED_ROWS=$(extract_non_executed_rows "$REPORT_FILE")
NON_EXECUTED_COUNT=$(printf '%s\n' "$NON_EXECUTED_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$QA_A_STATUS" = "N/A" ] || [ "$QA_B_STATUS" = "N/A" ] || [ "$QA_C_STATUS" = "N/A" ] || [ "$QA_D_STATUS" = "N/A" ]; then
    if [ "$NON_EXECUTED_COUNT" -eq 0 ]; then
        add_failure "存在 N/A 阶段时，必须填写 ## 非执行项记录（stage_or_obligation + not_executed_reason）"
    else
        for stage in QA_A QA_B QA_C QA_D; do
            stage_status_var="${stage}_STATUS"
            stage_status="${!stage_status_var:-}"
            if [ "$stage_status" = "N/A" ]; then
                reason=$(printf '%s\n' "$NON_EXECUTED_ROWS" | awk -F'|' -v target="$stage" '$1 == target { print $2; exit }')
                if is_placeholder_text "$reason"; then
                    add_failure "${stage} 标记为 N/A，但缺少 not_executed_reason"
                fi
            fi
        done
    fi
fi

POTENTIAL_ISSUE_ROWS=$(extract_markdown_section "$REPORT_FILE" "## 已排除潜在问题" | grep -cE '^\|[[:space:]]*[0-9]+' || true)
if [ "$POTENTIAL_ISSUE_ROWS" -lt 2 ]; then
    add_failure "已排除潜在问题不足 2 条"
fi

validate_fail_details "$REPORT_FILE" "$RESULT"
validate_obligation_table "$REPORT_FILE" "### QA_A 交接义务承接" "QA_A 交接义务" 3 6 7 8
validate_obligation_table "$REPORT_FILE" "#### UX / 异常恢复检查点" "QA_B 交接义务" 2 4 5 6
validate_obligation_table "$REPORT_FILE" "### NFR / 影响面补充" "QA_C/NFR 交接义务" 2 3 4 5
validate_qa_b_journey_body "$REPORT_FILE" "$QA_B_STATUS"
validate_browser_required_evidence "$REPORT_FILE" "$PHASE_DIR" "$QA_B_STATUS"

if [ "$RELEASE_RECOMMENDATION" = "条件放行" ]; then
    if is_placeholder_text "$CONDITIONAL_RELEASE_BASIS" || [ "$CONDITIONAL_RELEASE_BASIS" = "无" ]; then
        add_failure "release_recommendation=条件放行 时，必须填写 conditional_release_basis"
    fi
    if [ "${FAIL_DETAIL_COUNT:-0}" -eq 0 ] && [ "$NON_EXECUTED_COUNT" -eq 0 ] && { [ -z "$UNCOVERED_BOUNDARY" ] || [ "$UNCOVERED_BOUNDARY" = "无" ]; }; then
        add_failure "release_recommendation=条件放行 时，必须有已记录的未执行项、QAR 缺陷或其他条件性风险依据"
    fi
fi

output_failures "QA 验收报告完整性检查未通过" "$PHASE_DIR"
exit 0
