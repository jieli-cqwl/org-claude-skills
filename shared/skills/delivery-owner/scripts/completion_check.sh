#!/bin/bash
# 项目经理交付完整性自动检查脚本
# 执行时机: PostToolUse(Edit|Write) 收口门禁
# 功能: 精确定位当前 feature，按 UNIT/Phase 分层检查交付完整性（standard-chain canonical lane 优先，legacy markdown 仅兼容旧流程）
# 版本: v4.0 2026-03-24

set -euo pipefail

json_escape_local() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

emit_decision_json_local() {
    local decision="$1"
    local reason="$2"
    printf '{"decision":"%s","reason":"%s"}\n' "$decision" "$(json_escape_local "$reason")"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
delivery-owner/completion_check.sh — 项目经理交付完整性自动检查脚本
执行时机: PostToolUse(Edit|Write) 收口门禁
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

early_block() {
    local reason="$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "项目经理交付完整性检查初始化失败：" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  - $reason" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    emit_decision_json_local "block" "$reason"
    exit 2
}

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || early_block "无法解析 delivery-owner hook 脚本目录"
HOOKS_LIB="$SCRIPT_DIR/../../../hooks/lib"
[ -d "$HOOKS_LIB" ] || early_block "缺少 hooks 依赖目录：$HOOKS_LIB"

source "$HOOKS_LIB/common.sh" || early_block "无法加载公共 hook 库：$HOOKS_LIB/common.sh"
# shellcheck source=/dev/null
source "$HOOKS_LIB/constraint.sh" || early_block "无法加载约束库：$HOOKS_LIB/constraint.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/phase3-grade-matrix.sh" || early_block "无法加载 Phase 3 分级矩阵：$SCRIPT_DIR/phase3-grade-matrix.sh"
hook_init
export HOOK_STRICT_BLOCK=1

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

run_canonical_delivery_owner_gate() {
    local target phase_dir validator
    # canonical closeout artifacts: delivery-state.json / artifact-registry.json / signoff-package.json / user-decision.json
    target=$(first_matching_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/(delivery-state|artifact-registry|signoff-package|user-decision)\.json')
    [ -n "$target" ] || return 1

    phase_dir=$(dirname "$target")
    validator="$(cd "$SCRIPT_DIR/../../../.." 2>/dev/null && pwd)/tools/community/validate_standard_chain_readiness.py"
    if [ ! -x "$validator" ] && [ ! -f "$validator" ]; then
        add_failure "缺少 readiness validator：$validator"
        output_failures "项目经理交付完整性检查未通过（canonical）" "$target"
    fi
    if ! python3 "$validator" --phase-dir "$phase_dir" >/tmp/org_delivery_owner_canonical.out 2>&1; then
        cat /tmp/org_delivery_owner_canonical.out >&2 || true
        add_failure "canonical delivery-owner readiness gate 未通过：$phase_dir"
    fi

    output_failures "项目经理交付完整性检查未通过（canonical）" "$phase_dir"
    emit_decision_json_local "allow" "standard-chain canonical delivery-owner readiness gate passed"
    exit 0
}

run_canonical_delivery_owner_gate || true

if [ "${ORG_ENABLE_LEGACY_MARKDOWN_HOOKS:-0}" != "1" ]; then
    emit_decision_json_local "allow" "skip: legacy markdown delivery-owner hook disabled; standard-chain uses canonical JSON artifacts"
    exit 0
fi

skip_non_closeout_target() {
    if [ -z "${TOOL_NAME:-}" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "项目经理交付完整性检查初始化失败：" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "  - hook payload 缺少 tool_name，无法判断是否为 acceptance-summary.md 收口写入" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        emit_decision_json "block" "hook payload 缺少 tool_name，无法判断是否为 acceptance-summary.md 收口写入"
        exit 2
    fi
    if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
        emit_decision_json "allow" "skip: 当前工具不是 Write/Edit，delivery-owner 收口门禁本轮不适用"
        exit 0
    fi
    if [ -z "${TOOL_FILE_PATH:-}" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "项目经理交付完整性检查初始化失败：" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "  - hook payload 缺少 tool_input.file_path，无法判断是否为 acceptance-summary.md 收口写入" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        emit_decision_json "block" "hook payload 缺少 tool_input.file_path，无法判断是否为 acceptance-summary.md 收口写入"
        exit 2
    fi
    if [ "$(basename "$TOOL_FILE_PATH")" != "acceptance-summary.md" ]; then
        emit_decision_json "allow" "skip: 当前写入目标不是 acceptance-summary.md，delivery-owner 收口门禁本轮不适用"
        exit 0
    fi
}

skip_non_closeout_target

# --- D1: Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/unit-[0-9]+/)?(dev-report\.md|code-review-report\.md|qa-report\.md|waivers\.md|plan\.md|design\.md)'
resolve_feature_dir "docs/*/phase-*/unit-*/dev-report.md" "$TRANSCRIPT_PATTERN" "dev-report.md" "docs/*/phase-*/unit-*"
output_failures "项目经理交付完整性检查未通过" ""

# --- 当前 Phase / UNIT 工作区定位 ---

resolve_phase_work_dir "$FEATURE_DIR" "plan.md"
PHASE_DIR="$PHASE_WORK_DIR"

resolve_all_unit_work_dirs "$FEATURE_DIR"

# 兼容：如果当前 Phase 未解析出 UNIT 工作区，回退到单 UNIT 解析
if [ -z "$ALL_UNIT_WORK_DIRS" ]; then
    resolve_work_dir "$FEATURE_DIR" "dev-report.md"
    if printf '%s' "$UNIT_WORK_DIR" | grep -qE '/unit-[0-9]+/?$'; then
        ALL_UNIT_WORK_DIRS="$UNIT_WORK_DIR"
    fi
fi

# 兼容：如果 phase 未直接解析出来，则从首个 UNIT 反推
if [ -z "$PHASE_DIR" ] && [ -n "$ALL_UNIT_WORK_DIRS" ]; then
    FIRST_UNIT_DIR=$(printf '%s\n' "$ALL_UNIT_WORK_DIRS" | head -1)
    PHASE_DIR=$(derive_phase_dir "$FIRST_UNIT_DIR")
fi

while IFS= read -r resolved_unit_dir; do
    [ -n "$resolved_unit_dir" ] || continue
    resolved_phase_dir=$(derive_phase_dir "$resolved_unit_dir")
    if [ -n "$PHASE_DIR" ] && [ "$resolved_phase_dir" != "$PHASE_DIR" ]; then
        add_failure "D1: 当前 Phase 解析为 ${PHASE_DIR}，但检测到跨 Phase UNIT 工作区：${resolved_unit_dir}"
    fi
done <<< "$ALL_UNIT_WORK_DIRS"

# --- Phase 级变量 ---

PRD_FILE="$FEATURE_DIR/brief.md"
PHASE_PRD_FILE="$PHASE_DIR/prd.md"
PLAN_FILE="$PHASE_DIR/plan.md"
DESIGN_FILE="$PHASE_DIR/design.md"
CR_REPORT="$PHASE_DIR/code-review-report.md"
QA_REPORT="$PHASE_DIR/qa-report.md"
WAIVER_FILE="$PHASE_DIR/waivers.md"
ACCEPT_SUMMARY="$PHASE_DIR/acceptance-summary.md"
STATUS_SUMMARY="$PHASE_DIR/delivery-status-summary.md"
EVIDENCE_SUMMARY="$PHASE_DIR/evidence-summary.md"

trim() {
    local v="$1"
    # shellcheck disable=SC2001
    v=$(printf '%s' "$v" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    printf '%s' "$v"
}

normalize_check_item() {
    local item
    item=$(trim "$1")
    item=$(printf '%s' "$item" | tr '[:lower:]' '[:upper:]')
    if phase3_is_gate_stage "$item"; then
        printf '%s' "$item"
        return
    fi
    printf '%s' "$item"
}

normalize_stage_status() {
    local raw
    raw=$(trim "$1")
    raw=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]')

    # 模板占位值（如 "OK / ISSUE / N/A" 或 "{OK, ISSUE, N/A}"）不能被视为真实状态
    if [[ "$raw" == *"{"*"}"* ]]; then
        printf '%s' ""
        return 0
    fi
    if [[ "$raw" == *"OK / ISSUE"* ]] || [[ "$raw" == *"OK/ISSUE"* ]]; then
        printf '%s' ""
        return 0
    fi
    if [[ "$raw" == *"OK | ISSUE"* ]] || [[ "$raw" == *"OK|ISSUE"* ]]; then
        printf '%s' ""
        return 0
    fi
    if [[ "$raw" == *"PASS | FAIL"* ]] || [[ "$raw" == *"PASS|FAIL"* ]]; then
        printf '%s' ""
        return 0
    fi

    case "$raw" in
        *OK*)
            printf '%s' "OK"
            ;;
        *ISSUE*|*FAIL*)
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

release_decision_rank() {
    case "${1:-}" in
        阻塞) printf '%s' "1" ;;
        条件放行) printf '%s' "2" ;;
        放行) printf '%s' "3" ;;
        *) printf '%s' "" ;;
    esac
}

release_is_more_lenient_than() {
    local lhs rhs lhs_rank rhs_rank
    lhs="${1:-}"
    rhs="${2:-}"
    lhs_rank=$(release_decision_rank "$lhs")
    rhs_rank=$(release_decision_rank "$rhs")
    [ -n "$lhs_rank" ] && [ -n "$rhs_rank" ] && [ "$lhs_rank" -gt "$rhs_rank" ]
}

extract_metadata_json() {
    local report="$1"
    sed -nE 's#^[[:space:]]*<metadata>(.*)</metadata>[[:space:]]*$#\1#p' "$report" 2>/dev/null | tail -1
}

parse_report_grade() {
    local report_file="$1" metadata_json="$2"
    local grade line value

    if [ -n "$metadata_json" ]; then
        grade=$(printf '%s' "$metadata_json" | jq -r '.grade // .review_grade // empty' 2>/dev/null || true)
        grade=$(trim "$grade")
        if printf '%s' "$grade" | grep -qE '^(轻量|标准|完整|未指定)$'; then
            printf '%s' "$grade"
            return 0
        fi
    fi

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

parse_review_status() {
    local report_file="$1" metadata_json="$2" key="$3"
    local status

    if [ -n "$metadata_json" ]; then
        status=$(printf '%s' "$metadata_json" | jq -r --arg key "$key" '.review[$key] // .phases[$key] // empty' 2>/dev/null || true)
        status=$(normalize_stage_status "$status")
        if [ -n "$status" ]; then
            printf '%s' "$status"
            return 0
        fi
    fi

    parse_table_stage_status "$report_file" "$key"
}

parse_qa_status() {
    local report_file="$1" metadata_json="$2" key="$3"
    local status

    if [ -n "$metadata_json" ]; then
        status=$(printf '%s' "$metadata_json" | jq -r --arg key "$key" '.qa[$key] // .phases[$key] // empty' 2>/dev/null || true)
        status=$(normalize_stage_status "$status")
        if [ -n "$status" ]; then
            printf '%s' "$status"
            return 0
        fi
    fi

    parse_table_stage_status "$report_file" "$key"
}

extract_report_field() {
    local report_file="$1" key="$2"
    local line value

    line=$(grep -E "^[[:space:]]*[-*]?[[:space:]]*${key}[[:space:]]*[:：][[:space:]]*" "$report_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*[-*]?[[:space:]]*${key}[[:space:]]*[:：][[:space:]]*//")
    value=$(trim "$value")
    printf '%s' "$value"
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

extract_synthesis_status_from_report() {
    local report_file="$1" agent_label="$2"
    local summary_section

    [ -f "$report_file" ] || return 0
    summary_section=$(extract_markdown_section "$report_file" "## 汇总代理引用")
    printf '%s\n' "$summary_section" | awk -F'|' -v agent_label="$agent_label" '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            agent = trim($2)
            status = trim($NF)
            if (status == "") status = trim($(NF-1))
            if (agent == agent_label) {
                print status
                exit
            }
        }
    '
}

extract_replan_field_value() {
    local plan_file="$1" field_name="$2"
    local replan_section line value

    replan_section=$(extract_markdown_section "$plan_file" "## 再计划与解锁规则")
    line=$(printf '%s\n' "$replan_section" \
        | sed -nE "s/^[[:space:]]*[-*]?[[:space:]]*${field_name}[[:space:]]*[:：][[:space:]]*(.*)$/\\1/p" \
        | head -1)
    value=$(trim "$line")

    if is_placeholder_text "$value"; then
        printf '%s' ""
        return 0
    fi

    printf '%s' "$value"
}

extract_current_batch_task_ids_from_replan() {
    local plan_file="$1"
    local unlocked_value

    unlocked_value=$(extract_replan_field_value "$plan_file" "当前已解锁批次")
    printf '%s\n' "$unlocked_value" | grep -oE 'Task-[0-9]+' | sort -u || true
}

extract_parallel_batch_task_rows() {
    local plan_file="$1"
    local parallel_section

    parallel_section=$(extract_markdown_section "$plan_file" "## 并行策略")
    printf '%s\n' "$parallel_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^####[[:space:]]+Batch[[:space:]]+[0-9]+/ {
            current_batch = $0
            sub(/^.*Batch[[:space:]]+/, "", current_batch)
            sub(/[^0-9].*$/, "", current_batch)
            next
        }
        current_batch != "" && /^\|/ {
            task_id = trim($3)
            if (task_id == "" || task_id == "Task" || task_id ~ /^-+$/) next
            gsub(/Task[[:space:]]+/, "Task-", task_id)
            if (task_id ~ /^Task-[0-9]+$/) {
                print current_batch "|" task_id
            }
        }
    ' | sed '/^$/d' || true
}

extract_current_batch_task_ids_from_parallel_strategy() {
    local plan_file="$1"
    local batch_rows batch_id task_ids active_count

    batch_rows=$(extract_parallel_batch_task_rows "$plan_file")
    [ -n "$batch_rows" ] || return 0

    while IFS= read -r batch_id; do
        [ -n "$batch_id" ] || continue
        task_ids=$(printf '%s\n' "$batch_rows" | awk -F'|' -v batch_id="$batch_id" '$1 == batch_id { print $2 }' | sort -u || true)
        active_count=$(count_non_terminal_tasks_in_list "$task_ids")
        if [ "$active_count" -gt 0 ]; then
            printf '%s\n' "$task_ids"
            return 0
        fi
    done < <(printf '%s\n' "$batch_rows" | awk -F'|' '{print $1}' | sed '/^$/d' | uniq)
}

extract_current_batch_task_ids() {
    local plan_file="$1"
    local task_ids

    task_ids=$(extract_current_batch_task_ids_from_replan "$plan_file")
    if [ -n "$task_ids" ]; then
        printf '%s\n' "$task_ids"
        return 0
    fi

    extract_current_batch_task_ids_from_parallel_strategy "$plan_file"
}

count_list_items() {
    local values="$1"
    printf '%s\n' "$values" | sed '/^$/d' | wc -l | tr -d ' '
}

extract_task_status_from_unit_reports() {
    local task_id="$1"
    local unit_dir report_file status

    while IFS= read -r unit_dir; do
        [ -n "$unit_dir" ] || continue
        report_file="$unit_dir/dev-report.md"
        [ -f "$report_file" ] || continue
        status=$(extract_task_commit_status "$report_file" "$task_id")
        if [ -n "$status" ]; then
            printf '%s' "$status"
            return 0
        fi
    done <<< "$ALL_UNIT_WORK_DIRS"

    printf '%s' ""
}

is_terminal_task_commit_status() {
    local status
    status=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    case "$status" in
        DONE|CANCELED|CANCELLED)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

count_non_terminal_tasks_in_list() {
    local task_ids="$1"
    local task_id status count=0

    while IFS= read -r task_id; do
        [ -n "$task_id" ] || continue
        status=$(extract_task_status_from_unit_reports "$task_id")
        if [ -z "$status" ] || ! is_terminal_task_commit_status "$status"; then
            count=$((count + 1))
        fi
    done <<< "$task_ids"

    printf '%s' "$count"
}

collect_synthesis_statuses() {
    local agent_label="$1"
    local report_file status

    {
        while IFS= read -r unit_dir; do
            [ -n "$unit_dir" ] || continue
            report_file="$unit_dir/dev-report.md"
            status=$(extract_synthesis_status_from_report "$report_file" "$agent_label")
            [ -n "$status" ] && printf '%s\n' "$status"
        done <<< "$ALL_UNIT_WORK_DIRS"

        for report_file in "$CR_REPORT" "$ACCEPT_SUMMARY"; do
            status=$(extract_synthesis_status_from_report "$report_file" "$agent_label")
            [ -n "$status" ] && printf '%s\n' "$status"
        done
    } | sed '/^$/d' | sort -u || true
}

validate_synthesis_report_states() {
    local summary_label="$1"
    local states="$2"
    local required_state="$3"
    local invalid_states

    if printf '%s\n' "$states" | grep -qx 'STALE'; then
        add_failure "D12.2: ${summary_label} 的汇总状态不得为 STALE；旧 summary 必须在重跑后收敛为 TRIGGERED 或 N/A"
    fi

    if [ "$required_state" = "yes" ]; then
        if [ -z "$states" ]; then
            add_failure "D12.2: ${summary_label} 已满足触发条件（plan.md 当前批次并行 Task 数 >= 4），但相关报告未声明 TRIGGERED"
            return 0
        fi

        invalid_states=$(printf '%s\n' "$states" | awk 'NF && $0 != "TRIGGERED"' | sort -u | paste -sd, -)
        if [ -n "$invalid_states" ]; then
            add_failure "D12.2: ${summary_label} 已满足触发条件（plan.md 当前批次并行 Task 数 >= 4），但相关报告的汇总状态非法：${invalid_states}；必须统一为 TRIGGERED"
        fi
        return 0
    fi

    invalid_states=$(printf '%s\n' "$states" | awk 'NF && $0 != "N/A"' | sort -u | paste -sd, -)
    if [ -n "$invalid_states" ]; then
        add_failure "D12.2: ${summary_label} 未满足触发条件（plan.md 当前批次并行 Task 数 < 4），但相关报告的汇总状态为 ${invalid_states}"
    fi
}

is_synthesis_summary_required() {
    local agent_label="$1"
    local current_batch_parallel_task_count="${2:-0}"

    case "$agent_label" in
        "Status Synthesis Agent"|"Evidence Synthesis Agent")
            [ "$current_batch_parallel_task_count" -ge 4 ]
            ;;
        *)
            return 1
            ;;
    esac
}

validate_synthesis_sequence() {
    local status_required="$1"
    local evidence_required="$2"
    local status_states="$3"
    local evidence_states="$4"

    if [ "$evidence_required" != "yes" ] && ! printf '%s\n' "$evidence_states" | grep -qx 'TRIGGERED'; then
        return 0
    fi

    if ! printf '%s\n' "$status_states" | grep -qx 'TRIGGERED'; then
        add_failure "D12.2: Evidence Synthesis Agent 只能在 Status Synthesis Agent 结束或停止后进入；当前缺少 Status Synthesis Agent 的 TRIGGERED 记录"
    fi

    if [ ! -f "$STATUS_SUMMARY" ] || [ ! -s "$STATUS_SUMMARY" ]; then
        add_failure "D12.2: Evidence Synthesis Agent 只能在 Status Synthesis Agent 结束或停止后进入；当前缺少已产出的 delivery-status-summary.md"
    fi
}

validate_optional_synthesis_summary() {
    local summary_file="$1"
    local summary_label="$2"
    local anchor_pattern="$3"
    local topic_pattern="$4"
    local required_state="${5:-no}"
    local summary_text agent_kind current_judgment_type decision_state input_boundary evidence_anchor forbidden_action

    if [ "$required_state" != "yes" ]; then
        return 0
    fi
    if [ ! -f "$summary_file" ]; then
        add_failure "D12.2: ${summary_label} 已触发，但缺少 summary 文件：$summary_file"
        return 0
    fi
    if [ ! -s "$summary_file" ]; then
        add_failure "D12.2: ${summary_label} 为空：$summary_file"
        return 0
    fi

    summary_text=$(cat "$summary_file")
    if ! printf '%s\n' "$summary_text" | grep -qF "$summary_label"; then
        add_failure "D12.2: ${summary_label} 缺少显式 agent 名称：$summary_file"
    fi

    agent_kind=$(extract_report_field "$summary_file" "agent_kind")
    current_judgment_type=$(extract_report_field "$summary_file" "current_judgment_type")
    decision_state=$(extract_report_field "$summary_file" "decision_state")
    input_boundary=$(extract_report_field "$summary_file" "input_boundary")
    evidence_anchor=$(extract_report_field "$summary_file" "evidence_anchor")
    forbidden_action=$(extract_report_field "$summary_file" "forbidden_action")

    if [ -z "$agent_kind" ] || [ "$agent_kind" != "synthesis" ]; then
        add_failure "D12.2: ${summary_label} 的 agent_kind 非法（${agent_kind:-missing}），必须为 synthesis"
    fi
    if [ -z "$current_judgment_type" ] || [ "$current_judgment_type" != "summary" ]; then
        add_failure "D12.2: ${summary_label} 的 current_judgment_type 非法（${current_judgment_type:-missing}），必须为 summary"
    fi
    if [ -z "$decision_state" ] || [ "$decision_state" != "待裁决" ]; then
        add_failure "D12.2: ${summary_label} 的 decision_state 非法（${decision_state:-missing}），必须为 待裁决"
    fi
    if is_placeholder_text "$input_boundary"; then
        add_failure "D12.2: ${summary_label} 缺少 input_boundary"
    fi
    if is_placeholder_text "$evidence_anchor"; then
        add_failure "D12.2: ${summary_label} 缺少 evidence_anchor"
    elif ! printf '%s\n' "$summary_text" | grep -qE "$anchor_pattern"; then
        add_failure "D12.2: ${summary_label} 的 evidence_anchor 未引用有效报告锚点"
    fi
    if is_placeholder_text "$forbidden_action"; then
        add_failure "D12.2: ${summary_label} 缺少 forbidden_action"
    fi
    if ! printf '%s\n' "$summary_text" | grep -qE "$topic_pattern"; then
        add_failure "D12.2: ${summary_label} 缺少汇总主题词或作用域说明"
    fi
}

extract_acceptance_constraint_rows() {
    local acceptance_file="$1"
    local constraint_section

    constraint_section=$(extract_markdown_section "$acceptance_file" "## 前置约束验收状态")
    printf '%s\n' "$constraint_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            constraint_id = trim($2)
            constraint_type = trim($3)
            plan_status = trim($4)
            preflight_ref = trim($5)
            test_ref = trim($6)
            acceptance_result = trim($7)
            evidence = trim($8)
            note = trim($9)

            if (constraint_id == "" || constraint_id == "Constraint ID" || constraint_id ~ /^-+$/) next
            print constraint_id "|" constraint_type "|" plan_status "|" preflight_ref "|" test_ref "|" acceptance_result "|" evidence "|" note
        }
    '
}

extract_acceptance_issue_rows() {
    local acceptance_file="$1"
    local issue_section
    issue_section=$(extract_markdown_section "$acceptance_file" "## 已知问题")
    printf '%s\n' "$issue_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            issue_id = trim($2)
            source = trim($3)
            desc = trim($4)
            severity = trim($5)
            action = trim($6)
            if (issue_id == "" || issue_id == "Issue ID" || issue_id ~ /^-+$/) next
            print issue_id "|" source "|" desc "|" severity "|" action
        }
    '
}

extract_non_executed_rows() {
    local report_file="$1"
    extract_markdown_section "$report_file" "## 非执行项记录" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            stage = trim($2)
            reason = trim($3)
            if (stage == "" || stage == "stage_or_obligation" || stage ~ /^-+$/) next
            print stage "|" reason
        }
    '
}

extract_goal_closure_rows() {
    local acceptance_file="$1"
    local goal_section
    goal_section=$(extract_markdown_section "$acceptance_file" "## 目标闭环")
    printf '%s\n' "$goal_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            goal = trim($2)
            goal_source_ref = trim($3)
            execution_basis_ref = trim($4)
            evidence = trim($5)
            result = trim($6)
            remaining_gap = trim($7)
            if (goal == "" || goal == "目标" || goal ~ /^-+$/) next
            if (remaining_gap == "") {
                evidence = trim($4)
                result = trim($5)
                remaining_gap = trim($6)
                goal_source_ref = ""
                execution_basis_ref = ""
            }
            print goal "|" goal_source_ref "|" execution_basis_ref "|" evidence "|" result "|" remaining_gap
        }
    '
}

extract_brief_goal_rows() {
    local brief_file="$1"
    local goal_section
    goal_section=$(extract_markdown_section "$brief_file" "## 目标与成功标准")
    printf '%s\n' "$goal_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            goal = trim($2)
            success_standard = trim($3)
            if (goal == "" || goal == "目标" || goal ~ /^-+$/) next
            print goal "|" success_standard
        }
    '
}

extract_phase_goal_text() {
    local prd_file="$1"
    local goal_section
    goal_section=$(extract_markdown_section "$prd_file" "## 阶段目标")
    printf '%s\n' "$goal_section" \
        | sed '/^$/d' \
        | sed '/^## /d' \
        | paste -sd ' ' -
}

extract_qa_issue_ids() {
    local qa_report="$1"
    extract_markdown_section "$qa_report" "## FAIL 详情" | grep -oE 'QAR-[0-9]{3,}' | sort -u || true
}

extract_plan_task_ids() {
    local plan_file="$1"
    sed -nE 's/^### (Task-[0-9]+).*/\1/p' "$plan_file" 2>/dev/null | sed '/^$/d' | sort -u || true
}

compute_sha256() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    printf '%s' ""
}

parse_epoch_utc() {
    local ts="$1"
    local epoch=""
    local normalized_ts="$ts"

    if epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null); then
        printf '%s' "$epoch"
        return 0
    fi

    if printf '%s' "$ts" | grep -qE '[+-][0-9]{2}:[0-9]{2}$'; then
        normalized_ts=$(printf '%s' "$ts" | sed -E 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/')
    fi

    if epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "$normalized_ts" +%s 2>/dev/null); then
        printf '%s' "$epoch"
        return 0
    fi

    if epoch=$(date -u -d "$ts" +%s 2>/dev/null); then
        printf '%s' "$epoch"
        return 0
    fi

    printf '%s' ""
}

file_mtime_epoch() {
    local file="$1"
    [ -f "$file" ] || {
        printf '%s' ""
        return 0
    }

    stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || printf '%s' ""
}

extract_review_round_count() {
    local report_file="$1"
    [ -f "$report_file" ] || {
        printf '0'
        return 0
    }
    if ! grep -q '## 审查轮次记录' "$report_file" 2>/dev/null; then
        printf '0'
        return 0
    fi
    extract_section_content "$report_file" "## 审查轮次记录" 2 | grep -cE '^\|[[:space:]]*R[0-9]+' 2>/dev/null || printf '0'
}

extract_task_block() {
    local report_file="$1" task_id="$2"
    awk -v task_id="$task_id" '
        $0 ~ ("^### " task_id "(:|[[:space:]]|$)") { in_task=1; next }
        in_task && /^### Task-[0-9]+/ { exit }
        in_task && /^### Task-Commit 对照表/ { exit }
        in_task { print }
    ' "$report_file"
}

extract_plan_task_block() {
    local plan_file="$1" task_id="$2"
    awk -v task_id="$task_id" '
        $0 ~ ("^### " task_id "(:|[[:space:]]|$)") { in_task=1; next }
        in_task && /^### Task-[0-9]+/ { exit }
        in_task && /^## / { exit }
        in_task { print }
    ' "$plan_file"
}

extract_task_field_value() {
    local task_block="$1" field_name="$2"
    printf '%s\n' "$task_block" \
        | { grep -E "^[[:space:]]*-[[:space:]]*(\\*\\*)?${field_name}(\\*\\*)?[[:space:]]*[:：]" || true; } \
        | head -1 \
        | sed -E 's/^[^:：]*[:：][[:space:]]*//'
}

extract_labeled_fence_block() {
    local task_block="$1" label="$2"
    printf '%s\n' "$task_block" | awk -v target="$label" '
        $0 == target { in_label = 1; next }
        in_label && /^```/ {
            if (in_fence) exit
            in_fence = 1
            next
        }
        in_label && in_fence { print }
    '
}

contains_mock_only_acceptance() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE 'mock-only|仅依赖[[:space:]]*Mock|仅靠[[:space:]]*Mock|最终验收允许.{0,20}Mock|允许使用[[:space:]]*Mock[[:space:]]*作为|允许.{0,20}Mock.{0,20}(作为|充当)|Mock.{0,20}(作为|充当).{0,20}(完成证据|验收证据)'
}

is_obviously_non_verifying_command() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE '^[[:space:]]*(echo|printf|true|:)([[:space:];]|$)'
}

is_summary_only_output() {
    local value="$1"
    local compact
    compact=$(printf '%s\n' "$value" | sed '/^[[:space:]]*$/d')
    [ -n "$compact" ] || return 1
    if [ "$(printf '%s\n' "$compact" | wc -l | tr -d ' ')" -le 2 ] \
        && [ "$(printf '%s' "$compact" | wc -c | tr -d ' ')" -lt 80 ] \
        && printf '%s\n' "$compact" | grep -qiE '^(测试通过|测试已通过|已通过|PASS|OK|成功|全部通过|all tests passed|passed)$'; then
        return 0
    fi
    return 1
}

has_anchored_evidence_target() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE '(dev-report|qa-report|acceptance-summary|preflight-evidence)\.md#[^[:space:]]+'
}

has_unanchored_evidence_target() {
    local value="$1" base
    for base in dev-report qa-report acceptance-summary preflight-evidence; do
        if printf '%s\n' "$value" | grep -qi "${base}\.md" && ! printf '%s\n' "$value" | grep -qi "${base}\.md#"; then
            return 0
        fi
    done
    return 1
}

has_anchored_developer_report_ref() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE 'developer-report-Task-[0-9]+\.md#[^[:space:]]+'
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
    local file="$1" anchor="$2" anchor_slug unit_id constraint_id
    anchor_slug=$(normalize_anchor_slug "$anchor")

    case "$anchor_slug" in
        summary)
            grep -qE '^##[[:space:]]+审查汇总([[:space:]]|$)' "$file"
            return
            ;;
        fail-details)
            grep -qE '^##[[:space:]]+FAIL[[:space:]]+详情([[:space:]]|$)' "$file"
            return
            ;;
        qa-a-unit-*|qa-a-u*)
            unit_id=$(printf '%s' "$anchor_slug" | sed -E 's/^qa-a-unit-([0-9]+)$/UNIT-\1/; s/^qa-a-u([0-9]+)$/UNIT-\1/')
            if [ -n "$unit_id" ] \
                && grep -qE '^###[[:space:]]+QA_A[[:space:]]+UNIT[[:space:]]+执行汇总([[:space:]]|$)' "$file" \
                && grep -qE "^\|[[:space:]]*${unit_id}[[:space:]]*\|" "$file"; then
                return 0
            fi
            return 1
            ;;
        task-*)
            if grep -qE "^###[[:space:]]*$(printf '%s' "$anchor" | sed -E 's/^task-/Task-/I')([:[:space:]]|$)" "$file"; then
                return 0
            fi
            return 1
            ;;
        constraint-con-*)
            constraint_id=$(printf '%s' "$anchor_slug" | sed -E 's/^constraint-//')
            constraint_id=$(printf '%s' "$constraint_id" | tr '[:lower:]' '[:upper:]')
            grep -qE "^\|[[:space:]]*${constraint_id}[[:space:]]*\|" "$file"
            return
            ;;
        preflight-con-*)
            if grep -qE "^##[[:space:]]*${anchor_slug}([[:space:]]|$)" "$file"; then
                return 0
            fi
            constraint_id=$(printf '%s' "$anchor_slug" | sed -E 's/^preflight-//')
            constraint_id=$(printf '%s' "$constraint_id" | tr '[:lower:]' '[:upper:]')
            grep -qE "^\|[[:space:]]*${constraint_id}[[:space:]]*\|" "$file"
            return
            ;;
    esac

    return 1
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

extract_anchored_refs() {
    local value="$1"
    printf '%s\n' "$value" | grep -oE '[^[:space:]+,`|]+\.md#[^[:space:]+,`|]+' || true
}

validate_anchored_refs_exist() {
    local value="$1" base_dir="$2" label="$3" fallback_dirs="${4:-}"
    local ref ref_file fallback_file ref_anchor candidate_dir

    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        ref_file=$(resolve_ref_file_path "$ref" "$base_dir")
        ref_anchor=$(extract_ref_anchor "$ref")
        if [ ! -f "$ref_file" ] && [ -n "$fallback_dirs" ]; then
            while IFS= read -r candidate_dir; do
                [ -n "$candidate_dir" ] || continue
                fallback_file=$(resolve_ref_file_path "$ref" "$candidate_dir")
                if [ -f "$fallback_file" ]; then
                    ref_file="$fallback_file"
                    break
                fi
            done <<< "$fallback_dirs"
        fi
        if [ ! -f "$ref_file" ]; then
            add_failure "${label} 引用的文件不存在：${ref_file}"
            continue
        fi
        if ! ref_anchor_exists_in_file "$ref_file" "$ref_anchor"; then
            add_failure "${label} 引用的锚点不存在：${ref}"
        fi
    done <<< "$(extract_anchored_refs "$value")"
}

is_explicit_none() {
    [ "$(trim "${1:-}")" = "无" ]
}

has_runtime_anchor_ref() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE '((brief|prd|design|plan|test-cases|dev-report|developer-report-Task-[0-9]+|code-review-report|qa-report|acceptance-summary|preflight-evidence)\.md#[^[:space:]]+)'
}

validate_runtime_anchor_refs_exist() {
    local value="$1" base_dir="$2" label="$3" fallback_dirs="${4:-}"

    if ! has_runtime_anchor_ref "$value"; then
        add_failure "${label} 必须包含当前锚点引用"
        return 0
    fi

    validate_anchored_refs_exist "$value" "$base_dir" "$label" "$fallback_dirs"
}

has_plan_version_ref() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE '(^|.*/)plan\.md#计划版本$'
}

goal_source_refs_are_allowed() {
    local value="$1" ref found=0
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        found=1
        case "$ref" in
            *brief.md#目标与成功标准|*prd.md#阶段目标)
                ;;
            *)
                return 1
                ;;
        esac
    done <<< "$(extract_anchored_refs "$value")"
    [ "$found" -eq 1 ]
}

execution_basis_refs_are_allowed() {
    local value="$1" ref found=0
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        found=1
        case "$ref" in
            *design.md#*|*test-cases.md#*)
                ;;
            *)
                if ! is_current_plan_version_ref "$ref"; then
                    return 1
                fi
                ;;
        esac
    done <<< "$(extract_anchored_refs "$value")"
    [ "$found" -eq 1 ]
}

goal_evidence_refs_are_allowed() {
    local value="$1" ref found=0
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        found=1
        case "$ref" in
            *dev-report.md#*|*qa-report.md#*|*preflight-evidence.md#*)
                ;;
            *)
                return 1
                ;;
        esac
    done <<< "$(extract_anchored_refs "$value")"
    [ "$found" -eq 1 ]
}

is_current_plan_version_ref() {
    local ref="$1" ref_file expected_plan_file ref_anchor

    ref_file=$(resolve_ref_file_path "$ref" "$PHASE_DIR")
    expected_plan_file=$(resolve_ref_file_path "plan.md#计划版本" "$PHASE_DIR")
    ref_anchor=$(extract_ref_anchor "$ref")
    [ "$(basename "$ref_file")" = "plan.md" ] || return 1
    [ "$ref_anchor" = "计划版本" ] || return 1
    [ "$ref_file" = "$expected_plan_file" ]
}

resolve_ref_file_path() {
    local ref="$1" base_dir="$2"
    local path="${ref%%#*}"
    local dir
    local base
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

extract_scope_ids_from_text() {
    local text="$1"
    printf '%s\n' "$text" | grep -oE 'SCOPE-P[0-9]+U[0-9]+-[0-9]+' | sort -u || true
}

extract_task_scope_table_rows() {
    local report_file="$1"
    local scope_section
    scope_section=$(extract_section_content "$report_file" "### Task-scope 对照表" 3)
    printf '%s\n' "$scope_section" | awk -F'|' '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^\|/ {
            task = trim($2)
            scope_ref = trim($3)
            impact_files = trim($4)
            rollback_ref = trim($5)
            boundary = trim($6)
            if (task == "" || task == "Task" || task ~ /^-+$/) next
            gsub(/Task[ ]+/, "Task-", task)
            print task "|" scope_ref "|" impact_files "|" rollback_ref "|" boundary
        }
    '
}

extract_eq_matrix_rows() {
    local test_cases_file="$1"
    local eq_section
    eq_section=$(extract_markdown_section "$test_cases_file" "## 等价性对照矩阵")
    printf '%s\n' "$eq_section" | awk -F'|' '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^\|/ {
            scope_id = trim($2)
            status = trim($7)
            if (scope_id == "" || scope_id == "scope_item_id" || scope_id ~ /^-+$/) next
            print scope_id "|" status
        }
    '
}

extract_blocked_rows() {
    local report_file="$1"
    local blocked_section
    blocked_section=$(extract_section_content "$report_file" "### BLOCKED 任务" 3)

    printf '%s\n' "$blocked_section" | awk -F'|' '
        /^\|/ {
            task=$2
            reason=$3
            gsub(/^[ \t]+|[ \t]+$/, "", task)
            gsub(/^[ \t]+|[ \t]+$/, "", reason)

            if (task == "" || task == "Task" || task ~ /^-+$/) next
            if (task ~ /^Task[ -]?[0-9]+$/) {
                gsub(/Task[ ]+/, "Task-", task)
                print task "|" reason
            }
        }
    '
}

normalize_task_commit_status() {
    local raw
    raw=$(trim "$1")
    raw=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]')

    case "$raw" in
        DONE|COMPLETED|完成|已完成)
            printf '%s' "DONE"
            ;;
        BLOCKED|阻塞|已阻塞)
            printf '%s' "BLOCKED"
            ;;
        IN_PROGRESS|DOING|进行中)
            printf '%s' "IN_PROGRESS"
            ;;
        *)
            printf '%s' "$raw"
            ;;
    esac
}

extract_task_commit_status() {
    local report_file="$1" task_id="$2"
    local table_section raw_status

    table_section=$(extract_section_content "$report_file" "### Task-Commit 对照表" 3)
    raw_status=$(printf '%s\n' "$table_section" | awk -F'|' -v target="$task_id" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^\|/ {
            task = trim($2)
            status = trim($(NF - 1))
            if (task == "" || task == "Task" || task ~ /^-+$/) next
            gsub(/Task[ ]+/, "Task-", task)
            if (task == target) {
                print status
                found = 1
                exit
            }
        }
        END { if (!found) exit 1 }
    ' || true)

    normalize_task_commit_status "$raw_status"
}

extract_task_commit_hash() {
    local report_file="$1" task_id="$2"
    local table_section raw_commit

    table_section=$(extract_section_content "$report_file" "### Task-Commit 对照表" 3)
    raw_commit=$(printf '%s\n' "$table_section" | awk -F'|' -v target="$task_id" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^\|/ {
            task = trim($2)
            commit = trim($3)
            if (task == "" || task == "Task" || task ~ /^-+$/) next
            gsub(/Task[ ]+/, "Task-", task)
            if (task == target) {
                print commit
                found = 1
                exit
            }
        }
        END { if (!found) exit 1 }
    ' || true)

    printf '%s' "$(trim "$raw_commit")"
}

has_valid_waiver_for() {
    local item="$1"
    [ -f "$WAIVER_FILE" ] && [ -s "$WAIVER_FILE" ] || return 1

    while IFS='|' read -r _ c_id c_item c_issue_ids c_reason c_risk c_controls c_approver c_approved_at c_expires _; do
        local waiver_id check_item issue_ids reason risk controls approver approved_at expires_at

        waiver_id=$(trim "$c_id")
        check_item=$(normalize_check_item "$c_item")
        issue_ids=$(trim "$c_issue_ids")
        reason=$(trim "$c_reason")
        risk=$(trim "$c_risk")
        controls=$(trim "$c_controls")
        approver=$(trim "$c_approver")
        approved_at=$(trim "$c_approved_at")
        expires_at=$(trim "$c_expires")

        if [ -z "$waiver_id" ] || [ "$waiver_id" = "Waiver ID" ] || printf '%s' "$waiver_id" | grep -qE '^-+$'; then
            continue
        fi

        [ "$check_item" = "$item" ] || continue

        if ! printf '%s' "$waiver_id" | grep -qE '^PMW-[0-9]{3,}$'; then
            continue
        fi
        if ! printf '%s' "$issue_ids" | grep -qE '[A-Z]{2,}-[0-9]+'; then
            continue
        fi
        if is_placeholder_text "$reason" || is_placeholder_text "$risk" || is_placeholder_text "$controls" || is_placeholder_text "$approver" || is_placeholder_text "$approved_at" || is_placeholder_text "$expires_at"; then
            continue
        fi

        return 0
    done < <(grep -E '^\|' "$WAIVER_FILE" 2>/dev/null || true)

    return 1
}

# check_waiver_file_sanity: 验证 waiver 文件格式完整性
# $1: dev_report_files — 换行分隔的 dev-report.md 路径列表，用于交叉验证豁免记录
check_waiver_file_sanity() {
    local dev_report_files="$1"
    [ -f "$WAIVER_FILE" ] && [ -s "$WAIVER_FILE" ] || return 0

    local has_table=0
    local has_invalid=0

    while IFS='|' read -r _ c_id c_item c_issue_ids c_reason c_risk c_controls c_approver c_approved_at c_expires _; do
        local waiver_id check_item issue_ids reason risk controls approver approved_at expires_at

        waiver_id=$(trim "$c_id")
        check_item=$(normalize_check_item "$c_item")
        issue_ids=$(trim "$c_issue_ids")
        reason=$(trim "$c_reason")
        risk=$(trim "$c_risk")
        controls=$(trim "$c_controls")
        approver=$(trim "$c_approver")
        approved_at=$(trim "$c_approved_at")
        expires_at=$(trim "$c_expires")

        if [ -z "$waiver_id" ] || [ "$waiver_id" = "Waiver ID" ] || printf '%s' "$waiver_id" | grep -qE '^-+$'; then
            continue
        fi

        has_table=1

        if ! printf '%s' "$waiver_id" | grep -qE '^PMW-[0-9]{3,}$'; then
            add_failure "D10: waivers.md 中存在非法 Waiver ID：${waiver_id}"
            has_invalid=1
            continue
        fi

        if ! phase3_is_gate_stage "$check_item"; then
            add_failure "D10: ${waiver_id} 的检查项非法：${check_item}"
            has_invalid=1
            continue
        fi

        if phase3_is_non_waivable_stage "$check_item"; then
            add_failure "D10: ${waiver_id} 试图豁免不可豁免项（${check_item}）"
            has_invalid=1
            continue
        fi

        if ! printf '%s' "$issue_ids" | grep -qE '[A-Z]{2,}-[0-9]+'; then
            add_failure "D10: ${waiver_id} 缺少关联 Issue IDs"
            has_invalid=1
        fi

        if is_placeholder_text "$reason" || is_placeholder_text "$risk" || is_placeholder_text "$controls" || is_placeholder_text "$approver" || is_placeholder_text "$approved_at" || is_placeholder_text "$expires_at"; then
            add_failure "D10: ${waiver_id} 豁免记录字段不完整（原因/风险/补偿控制/批准人/批准时间/到期时间）"
            has_invalid=1
        fi
    done < <(grep -E '^\|' "$WAIVER_FILE" 2>/dev/null || true)

    if [ "$has_table" -eq 0 ]; then
        add_failure "D10: waivers.md 存在但未解析到任何豁免记录行"
    fi

    if [ "$has_invalid" -eq 0 ]; then
        # 检查每个 UNIT 的 dev-report.md 是否记录了豁免 ID
        local found_waiver_ref=0
        while IFS= read -r dr; do
            [ -n "$dr" ] || continue
            [ -f "$dr" ] || continue
            local waiver_section
            waiver_section=$(extract_markdown_section "$dr" "### 用户豁免（如有）")
            if [ -n "$waiver_section" ] && printf '%s' "$waiver_section" | grep -qE 'PMW-[0-9]{3,}'; then
                found_waiver_ref=1
                break
            fi
        done <<< "$dev_report_files"
        if [ "$found_waiver_ref" -eq 0 ]; then
            add_failure "D10: 存在 waivers.md，但所有 UNIT 的 dev-report.md 均未在「用户豁免（如有）」章节记录豁免 ID"
        fi
    fi
}

check_required_stage() {
    local stage="$1" status="$2" report_label="$3"

    if [ -z "$status" ]; then
        add_failure "${report_label}: 缺少 ${stage} 状态"
        return
    fi

    case "$status" in
        OK)
            return
            ;;
        ISSUE)
            if phase3_is_non_waivable_stage "$stage"; then
                add_failure "${report_label}: ${stage} 为 ISSUE，属于不可豁免项"
                return
            fi

            if ! has_valid_waiver_for "$stage"; then
                add_failure "${report_label}: ${stage} 为 ISSUE，但未找到有效用户豁免"
            fi
            ;;
        N/A)
            add_failure "${report_label}: ${stage} 为 N/A，但当前分级要求必须执行"
            ;;
        *)
            add_failure "${report_label}: ${stage} 状态非法（${status}）"
            ;;
    esac
}

normalize_dir_path() {
    local dir="$1"
    if [ -d "$dir" ]; then
        (cd "$dir" 2>/dev/null && pwd)
    else
        printf '%s' "$dir"
    fi
}

# --- 从 UNIT 工作区路径提取 phase 和 unit 编号 ---
extract_phase_num() {
    local dir="$1"
    if [[ "$dir" =~ phase-([0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' ""
    fi
}

extract_unit_num() {
    local dir="$1"
    if [[ "$dir" =~ unit-([0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' ""
    fi
}

# --- 按 UNIT 过滤 plan.md 中的 Task ---
filter_tasks_by_unit() {
    local plan_file="$1" unit_num="$2" phase_num="$3"
    [ -f "$plan_file" ] || return 0
    awk -v unit="UNIT-$unit_num" -v scope_prefix="SCOPE-P${phase_num}U${unit_num}-" '
        /^### Task-[0-9]+/ {
            if (in_task && matched) print task_id
            task_id = $0
            sub(/^### /, "", task_id)
            sub(/[^A-Za-z0-9-].*$/, "", task_id)
            in_task = 1
            matched = 0
            next
        }
        /^## / {
            if (in_task && matched) print task_id
            in_task = 0
            next
        }
        in_task && /unit_ref:/ && index($0, unit) > 0 { matched = 1 }
        in_task && /scope_item_ref:/ && index($0, scope_prefix) > 0 { matched = 1 }
        END { if (in_task && matched) print task_id }
    ' "$plan_file" 2>/dev/null || true
}

# ============================================================
# Phase 级前置检查：plan.md + design.md
# ============================================================

if [ ! -f "$PLAN_FILE" ]; then
    add_failure "D2: plan.md 不存在：$PLAN_FILE"
elif [ ! -s "$PLAN_FILE" ]; then
    add_failure "D2: plan.md 为空：$PLAN_FILE"
fi

# Phase PRD 存在性校验
if [ -n "$PHASE_PRD_FILE" ] && [ ! -f "$PHASE_PRD_FILE" ]; then
    add_failure "缺少前置文档 phase prd.md：$PHASE_PRD_FILE"
fi

PRD_CONSTRAINT_ROWS=""
PLAN_CONSTRAINT_ROWS=""
PRD_CONSTRAINT_COUNT=0
PLAN_CONSTRAINT_COUNT=0
PLAN_TASK_IDS=""
if [ -f "$PRD_FILE" ] && [ -s "$PRD_FILE" ]; then
    PRD_CONSTRAINT_ROWS=$(extract_prd_constraint_rows "$PRD_FILE")
    PRD_CONSTRAINT_COUNT=$(printf '%s\n' "$PRD_CONSTRAINT_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
fi
if [ -f "$PLAN_FILE" ] && [ -s "$PLAN_FILE" ]; then
    PLAN_CONSTRAINT_ROWS=$(extract_plan_constraint_rows "$PLAN_FILE")
    PLAN_CONSTRAINT_COUNT=$(printf '%s\n' "$PLAN_CONSTRAINT_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')
    PLAN_TASK_IDS=$(extract_plan_task_ids "$PLAN_FILE")
fi

# D-PRE: preflight-evidence 文件检查（有 CON-NNN 约束时必须存在并可核对）
if [ "$PLAN_CONSTRAINT_COUNT" -gt 0 ] && [ -n "$PHASE_DIR" ]; then
    PREFLIGHT_EVIDENCE_FILE="$PHASE_DIR/preflight-evidence.md"
    if [ ! -f "$PREFLIGHT_EVIDENCE_FILE" ]; then
        add_failure "D-PRE: plan.md 存在 ${PLAN_CONSTRAINT_COUNT} 个前置约束，但缺少 preflight-evidence.md：${PREFLIGHT_EVIDENCE_FILE}"
    elif [ ! -s "$PREFLIGHT_EVIDENCE_FILE" ]; then
        add_failure "D-PRE: preflight-evidence.md 存在但为空：${PREFLIGHT_EVIDENCE_FILE}"
    else
        PREFLIGHT_CONSTRAINT_IDS=$(grep -oE 'CON-[0-9]{3,}' "$PREFLIGHT_EVIDENCE_FILE" 2>/dev/null | sort -u || true)
        if [ -z "$PREFLIGHT_CONSTRAINT_IDS" ]; then
            add_failure "D-PRE: preflight-evidence.md 未记录任何 CON-XXX 结果，无法证明 readiness"
        fi
        while IFS='|' read -r constraint_id _; do
            [ -n "$constraint_id" ] || continue
            if ! printf '%s\n' "$PREFLIGHT_CONSTRAINT_IDS" | grep -qx "$constraint_id"; then
                add_failure "D-PRE: preflight-evidence.md 未覆盖 ${constraint_id}"
            fi
        done <<< "$PLAN_CONSTRAINT_ROWS"
    fi
fi

if [ "$PRD_CONSTRAINT_COUNT" -gt 0 ] && [ "$PLAN_CONSTRAINT_COUNT" -eq 0 ]; then
    add_failure "D2.1: PRD 存在前置约束，但 plan.md 缺少「PRD 前置约束映射」数据行"
elif [ "$PRD_CONSTRAINT_COUNT" -eq 0 ] && [ "$PLAN_CONSTRAINT_COUNT" -gt 0 ]; then
    add_failure "D2.1: plan.md 存在前置约束映射，但 PRD 未声明任何前置约束"
elif [ "$PLAN_CONSTRAINT_COUNT" -gt 0 ]; then
    prd_constraint_pairs=$(build_prd_constraint_pairs "$PRD_CONSTRAINT_ROWS")
    plan_constraint_pairs=$(build_plan_constraint_pairs "$PLAN_CONSTRAINT_ROWS")
    dup_plan_constraint_ids=$(printf '%s\n' "$PLAN_CONSTRAINT_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
    if [ -n "$dup_plan_constraint_ids" ]; then
        add_failure "D2.1: PRD 前置约束映射存在重复 Constraint ID：$(printf '%s' "$dup_plan_constraint_ids" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
    fi

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref mapped_task acceptance_evidence status; do
        [ -n "$constraint_id" ] || continue

        if ! printf '%s' "$constraint_id" | grep -qE '^CON-[0-9]{3,}$'; then
            add_failure "D2.1: 存在非法 Constraint ID：${constraint_id}"
        fi
        if is_placeholder_text "$constraint_type"; then
            add_failure "D2.1: ${constraint_id} 缺少约束类型"
        fi
        if is_placeholder_text "$description"; then
            add_failure "D2.1: ${constraint_id} 缺少约束内容"
        fi
        if is_placeholder_text "$owner"; then
            add_failure "D2.1: ${constraint_id} 缺少 Owner"
        fi
        if is_placeholder_text "$affected_unit"; then
            add_failure "D2.1: ${constraint_id} 缺少影响 UNIT"
        elif ! printf '%s' "$affected_unit" | grep -qE '(UNIT-[0-9]+|全局)'; then
            add_failure "D2.1: ${constraint_id} 的影响 UNIT 必须包含 UNIT-N 或 全局"
        fi
        if is_placeholder_text "$scope_id" || ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
            add_failure "D2.1: ${constraint_id} 缺少有效 scope_item_id"
        fi
        if is_placeholder_text "$preflight_ref"; then
            add_failure "D2.1: ${constraint_id} 缺少 preflight_ref"
        fi
        normalized_test_ref=$(printf '%s' "$test_ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$normalized_test_ref" && ! printf '%s' "$normalized_test_ref" | grep -qiE '^N/?A$'; then
            add_failure "D2.1: ${constraint_id} 缺少 test_ref"
        fi
        if is_placeholder_text "$mapped_task" || ! printf '%s' "$mapped_task" | grep -qE '^Task-[0-9]+$'; then
            add_failure "D2.1: ${constraint_id} 缺少有效映射 Task"
        elif ! printf '%s\n' "$PLAN_TASK_IDS" | grep -qx "$mapped_task"; then
            add_failure "D2.1: ${constraint_id} 映射到未定义 Task：${mapped_task}"
        fi
        if is_placeholder_text "$acceptance_evidence"; then
            add_failure "D2.1: ${constraint_id} 缺少验收证据"
        fi
        if [ "$status" != "MAPPED" ] && [ "$status" != "VERIFIED" ]; then
            add_failure "D2.1: ${constraint_id} 状态为 ${status}（仅允许 MAPPED/VERIFIED）"
        fi
    done <<< "$PLAN_CONSTRAINT_ROWS"

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref status; do
        [ -n "$constraint_id" ] || continue
        prd_pair="${constraint_id}|${constraint_type}|${description}|${owner}|${affected_unit}|${scope_id}|${preflight_ref}|${test_ref}"
        if ! newline_list_contains_literal "$plan_constraint_pairs" "$prd_pair"; then
            add_failure "D2.1: PRD 前置约束 ${constraint_id} 未在 plan 映射表中按 type/description/owner/affected_unit/scope_item_id/preflight_ref/test_ref 完整承接"
        fi
    done <<< "$PRD_CONSTRAINT_ROWS"

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref mapped_task acceptance_evidence status; do
        [ -n "$constraint_id" ] || continue
        plan_pair="${constraint_id}|${constraint_type}|${description}|${owner}|${affected_unit}|${scope_id}|${preflight_ref}|${test_ref}"
        if ! newline_list_contains_literal "$prd_constraint_pairs" "$plan_pair"; then
            add_failure "D2.1: plan 前置约束映射 ${constraint_id} 引用了 PRD 未声明的 type/description/owner/affected_unit/scope_item_id/preflight_ref/test_ref 组合"
        fi
    done <<< "$PLAN_CONSTRAINT_ROWS"
fi

if [ ! -f "$DESIGN_FILE" ]; then
    add_failure "D2: design.md 不存在：$DESIGN_FILE"
elif [ ! -s "$DESIGN_FILE" ]; then
    add_failure "D2: design.md 为空：$DESIGN_FILE"
fi

# ============================================================
# UNIT 级循环检查
# ============================================================

# 收集所有 UNIT 的 dev-report 路径（供 D10 交叉验证）
ALL_DEV_REPORTS=""
# 收集所有 UNIT 的 test-cases.md 中的 TC 编号（供 D12.1）
ALL_TC_IDS=""
LATEST_PROVING_EPOCH=0
LATEST_TEST_EPOCH=0
LATEST_FIX_EPOCH=0
CURRENT_PLAN_VERSION=$(extract_plan_version "$PLAN_FILE")
HIGH_RISK_DEVIATION_TRIGGERS=""
LATEST_FIX_FILE=""
FIX_COUNT=0

if [ -n "$PHASE_DIR" ] && [ -d "$PHASE_DIR" ]; then
    FIX_FILES=$(find "$PHASE_DIR" -maxdepth 2 -name 'fix-[0-9]*.md' -type f 2>/dev/null || true)
    FIX_COUNT=$(printf '%s\n' "$FIX_FILES" | sed '/^$/d' | wc -l | tr -d ' ')
    while IFS= read -r fix_file; do
        [ -n "$fix_file" ] || continue
        fix_epoch=$(file_mtime_epoch "$fix_file")
        if [ -n "$fix_epoch" ] && [ "$fix_epoch" -gt "$LATEST_FIX_EPOCH" ]; then
            LATEST_FIX_EPOCH="$fix_epoch"
            LATEST_FIX_FILE="$fix_file"
        fi
    done <<< "$FIX_FILES"
fi

while IFS= read -r UNIT_WORK_DIR; do
    [ -n "$UNIT_WORK_DIR" ] || continue

    UNIT_LABEL=$(basename "$UNIT_WORK_DIR")
    DEV_REPORT="$UNIT_WORK_DIR/dev-report.md"
    TEST_CASES_FILE="$UNIT_WORK_DIR/test-cases.md"

    ALL_DEV_REPORTS="${ALL_DEV_REPORTS:+${ALL_DEV_REPORTS}
}${DEV_REPORT}"

    phase_num=$(extract_phase_num "$UNIT_WORK_DIR")
    unit_num=$(extract_unit_num "$UNIT_WORK_DIR")
    unit_scope_prefix="SCOPE-P${phase_num}U${unit_num}-"

    # --- D2: dev-report.md 存在且非空（UNIT 级） ---

    if [ ! -f "$DEV_REPORT" ]; then
        add_failure "D2[${UNIT_LABEL}]: dev-report.md 不存在：$DEV_REPORT"
        continue
    elif [ ! -s "$DEV_REPORT" ]; then
        add_failure "D2[${UNIT_LABEL}]: dev-report.md 为空：$DEV_REPORT"
        continue
    fi

    # --- D3: dev-report.md 必需章节（UNIT 级） ---

    REQUIRED_SECTIONS=(
        "## 输入分析"
        "## 决策"
        "### 运行态状态感知"
        "### 执行编排状态"
        "## 产出"
        "### Task-Commit 对照表"
        "### Task-scope 对照表"
        "### 全量测试结果"
        "### 交接项"
    )

    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -qF "$section" "$DEV_REPORT"; then
            add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少章节：$section"
        fi
    done

    dev_last_observed_at=$(extract_report_field "$DEV_REPORT" "last_observed_at")
    dev_runtime_snapshot=$(extract_report_field "$DEV_REPORT" "runtime_snapshot")
    dev_active_blocker=$(extract_report_field "$DEV_REPORT" "active_blocker")
    dev_blocker_owner=$(extract_report_field "$DEV_REPORT" "blocker_owner")
    dev_takeover_note=$(extract_report_field "$DEV_REPORT" "takeover_note")
    dev_decision_basis=$(extract_report_field "$DEV_REPORT" "decision_basis")
    dev_dispatch_mode=$(extract_report_field "$DEV_REPORT" "dispatch_mode")
    dev_current_batch=$(extract_report_field "$DEV_REPORT" "current_batch")
    dev_batch_unlock_condition=$(extract_report_field "$DEV_REPORT" "batch_unlock_condition")
    dev_merge_readiness=$(extract_report_field "$DEV_REPORT" "merge_readiness")
    dev_next_action=$(extract_report_field "$DEV_REPORT" "next_action")
    dev_plan_version_ref=$(extract_report_field "$DEV_REPORT" "plan_version_ref")
    dev_plan_version_value=$(extract_report_field "$DEV_REPORT" "plan_version_value")
    dev_replan_request=$(extract_report_field "$DEV_REPORT" "replan_request")
    dev_batch_freeze_reason=$(extract_report_field "$DEV_REPORT" "batch_freeze_reason")
    dev_unlock_resolution=$(extract_report_field "$DEV_REPORT" "unlock_resolution")
    dev_last_observed_epoch=""
    unit_requires_blocked_context=0
    unit_requires_escalate_context=0
    unit_requires_replan_context=0

    if is_placeholder_text "$dev_last_observed_at"; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 last_observed_at"
    else
        dev_last_observed_epoch=$(parse_epoch_utc "$dev_last_observed_at")
        if [ -z "$dev_last_observed_epoch" ]; then
            add_failure "D3[${UNIT_LABEL}]: last_observed_at 必须为有效时间戳"
        fi
    fi
    if is_placeholder_text "$dev_runtime_snapshot"; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 runtime_snapshot"
    fi
    if [ -z "$dev_active_blocker" ]; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 active_blocker"
    fi
    if ! is_explicit_none "$dev_active_blocker"; then
        if is_placeholder_text "$dev_blocker_owner" || is_explicit_none "$dev_blocker_owner"; then
            add_failure "D3[${UNIT_LABEL}]: active_blocker 非 无 时，必须填写有效的 blocker_owner"
        fi
    fi
    if is_placeholder_text "$dev_takeover_note"; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 takeover_note"
    fi
    if is_placeholder_text "$dev_decision_basis"; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 decision_basis"
    else
        validate_runtime_anchor_refs_exist "$dev_decision_basis" "$UNIT_WORK_DIR" "D3[${UNIT_LABEL}]: decision_basis" "$PHASE_DIR"
    fi

    case "$dev_dispatch_mode" in
        SERIAL|PARALLEL|EXPLORE_BATCH)
            ;;
        *)
            add_failure "D3[${UNIT_LABEL}]: dispatch_mode 非法（${dev_dispatch_mode:-missing}）"
            ;;
    esac
    if is_placeholder_text "$dev_current_batch"; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 current_batch"
    elif ! printf '%s\n' "$dev_current_batch" | grep -qE '^(SERIAL|Batch-[0-9]+|Explore-Batch-[0-9]+)$'; then
        add_failure "D3[${UNIT_LABEL}]: current_batch 格式非法（${dev_current_batch}）"
    fi
    if is_placeholder_text "$dev_batch_unlock_condition"; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 batch_unlock_condition"
    fi
    case "$dev_merge_readiness" in
        READY|PENDING|BLOCKED)
            ;;
        *)
            add_failure "D3[${UNIT_LABEL}]: merge_readiness 非法（${dev_merge_readiness:-missing}）"
            ;;
    esac
    case "$dev_next_action" in
        REQUEST_REVIEW|WAIT_BATCH|ESCALATE|REPLAN_REQUEST|HOLD)
            ;;
        *)
            add_failure "D3[${UNIT_LABEL}]: next_action 非法（${dev_next_action:-missing}）"
            ;;
    esac
    if ! has_plan_version_ref "$dev_plan_version_ref"; then
        add_failure "D3[${UNIT_LABEL}]: plan_version_ref 必须指向 plan.md#计划版本"
    else
        validate_anchored_refs_exist "$dev_plan_version_ref" "$UNIT_WORK_DIR" "D3[${UNIT_LABEL}]: plan_version_ref" "$PHASE_DIR"
    fi
    if is_placeholder_text "$dev_plan_version_value"; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 缺少 plan_version_value"
    elif [ -n "$CURRENT_PLAN_VERSION" ] && [ "$dev_plan_version_value" != "$CURRENT_PLAN_VERSION" ]; then
        add_failure "D3[${UNIT_LABEL}]: dev-report.md 的 plan_version_value 与当前 plan.md 不一致（report=${dev_plan_version_value}, plan=${CURRENT_PLAN_VERSION}）"
    fi
    if [ "$dev_dispatch_mode" = "SERIAL" ] && [ "$dev_current_batch" != "SERIAL" ]; then
        add_failure "D3[${UNIT_LABEL}]: dispatch_mode=SERIAL 时 current_batch 必须为 SERIAL"
    fi
    if [ "$dev_dispatch_mode" = "PARALLEL" ] && ! printf '%s\n' "$dev_current_batch" | grep -qE '^Batch-[0-9]+$'; then
        add_failure "D3[${UNIT_LABEL}]: dispatch_mode=PARALLEL 时 current_batch 必须为 Batch-N"
    fi
    if [ "$dev_dispatch_mode" = "EXPLORE_BATCH" ] && ! printf '%s\n' "$dev_current_batch" | grep -qE '^Explore-Batch-[0-9]+$'; then
        add_failure "D3[${UNIT_LABEL}]: dispatch_mode=EXPLORE_BATCH 时 current_batch 必须为 Explore-Batch-N"
    fi

    # --- D4/D5: 每个 Task 的 TDD 证据 + SPEC/2A/2B/2C 状态（UNIT 级） ---

    task_ids=$(grep -oE '^### Task-[0-9]+' "$DEV_REPORT" 2>/dev/null | sed -E 's/^### (Task-[0-9]+)$/\1/' || true)
    task_count=$(printf '%s\n' "$task_ids" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$task_count" = "0" ]; then
        add_failure "D4[${UNIT_LABEL}]: dev-report.md 未解析到任何 Task 章节（需存在 ### Task-N）"
    fi

    # D4: Task 完整性——按 UNIT 过滤 plan 中的 Task
    plan_task_ids=""
    if [ -f "$PLAN_FILE" ] && [ -s "$PLAN_FILE" ]; then
        if [ -n "$unit_num" ] && [ -n "$phase_num" ]; then
            plan_task_ids=$(filter_tasks_by_unit "$PLAN_FILE" "$unit_num" "$phase_num")
        fi
        # 兜底：如果按 UNIT 过滤无结果（如单 UNIT 项目或 plan 无 unit_ref），取全量
        if [ -z "$plan_task_ids" ]; then
            plan_task_ids=$(sed -nE 's/^### (Task-[0-9]+).*/\1/p' "$PLAN_FILE" | sort -u || true)
        fi

        if [ -n "$plan_task_ids" ]; then
            missing_plan_tasks=$(comm -23 \
                <(printf '%s\n' "$plan_task_ids" | sed '/^$/d' | sort -u) \
                <(printf '%s\n' "$task_ids" | sed '/^$/d' | sort -u) \
                | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
            extra_report_tasks=$(comm -13 \
                <(printf '%s\n' "$plan_task_ids" | sed '/^$/d' | sort -u) \
                <(printf '%s\n' "$task_ids" | sed '/^$/d' | sort -u) \
                | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')

            [ -z "$missing_plan_tasks" ] || add_failure "D4[${UNIT_LABEL}]: dev-report.md 缺少 plan.md 中声明的 Task：${missing_plan_tasks}"
            [ -z "$extra_report_tasks" ] || add_failure "D4[${UNIT_LABEL}]: dev-report.md 存在 plan.md 未声明的 Task：${extra_report_tasks}"
        fi
    fi

    # D9: BLOCKED 一致性（UNIT 级）
    blocked_rows=$(extract_blocked_rows "$DEV_REPORT")
    blocked_tasks=$(printf '%s\n' "$blocked_rows" | sed -nE 's/^([^|]+)\|.*/\1/p' | sed '/^$/d' || true)

    while IFS='|' read -r blocked_task blocked_reason; do
        [ -n "$blocked_task" ] || continue
        if is_placeholder_text "$blocked_reason"; then
            add_failure "D9[${UNIT_LABEL}]: ${blocked_task} 标记为 BLOCKED 但原因为空或占位"
        fi
        if ! printf '%s\n' "$task_ids" | grep -qx "$blocked_task"; then
            add_failure "D9[${UNIT_LABEL}]: ${blocked_task} 标记为 BLOCKED，但 dev-report.md 中不存在对应 Task 章节"
        fi
    done <<< "$blocked_rows"

    # D5: TDD 证据 + SPEC/2A/2B/2C 状态（UNIT 级）
    while IFS= read -r task_id; do
        [ -n "$task_id" ] || continue

        task_block=$(extract_task_block "$DEV_REPORT" "$task_id")
        if [ -z "$task_block" ]; then
            add_failure "D4[${UNIT_LABEL}]: ${task_id} 缺少内容块"
            continue
        fi

        commit_status=$(extract_task_commit_status "$DEV_REPORT" "$task_id")
        if [ -z "$commit_status" ]; then
            add_failure "D4[${UNIT_LABEL}]: ${task_id} 未在「Task-Commit 对照表」中声明状态"
            continue
        fi

        commit_hash=$(extract_task_commit_hash "$DEV_REPORT" "$task_id")
        if is_placeholder_text "$commit_hash"; then
            add_failure "D4[${UNIT_LABEL}]: ${task_id} 在「Task-Commit 对照表」缺少有效 Commit 字段"
        fi

        if printf '%s\n' "$blocked_tasks" | grep -qx "$task_id"; then
            if [ "$commit_status" != "BLOCKED" ]; then
                add_failure "D9[${UNIT_LABEL}]: ${task_id} 在 BLOCKED 列表中，但 Task-Commit 状态为 ${commit_status}（应为 BLOCKED）"
            fi
            continue
        fi

        if [ "$commit_status" = "BLOCKED" ]; then
            add_failure "D9[${UNIT_LABEL}]: ${task_id} 未在 BLOCKED 列表中登记，却在 Task-Commit 对照表中标记为 BLOCKED"
        fi

        red_count=$(printf '%s\n' "$task_block" | grep -cE 'RED 阶段' 2>/dev/null || true)
        green_count=$(printf '%s\n' "$task_block" | grep -cE 'GREEN 阶段' 2>/dev/null || true)
        if [ "$red_count" -lt 1 ] || [ "$green_count" -lt 1 ]; then
            developer_report_ref_for_tdd=$(extract_task_field_value "$task_block" "developer_report_ref")
            developer_report_ref_for_tdd=$(printf '%s' "$developer_report_ref_for_tdd" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
            if has_anchored_developer_report_ref "$developer_report_ref_for_tdd"; then
                developer_report_file_for_tdd=$(resolve_ref_file_path "$developer_report_ref_for_tdd" "$UNIT_WORK_DIR")
                if [ -f "$developer_report_file_for_tdd" ]; then
                    dev_red_count=$(grep -cE '^\|[[:space:]]*RED[[:space:]]*\|' "$developer_report_file_for_tdd" 2>/dev/null || true)
                    dev_green_count=$(grep -cE '^\|[[:space:]]*GREEN[[:space:]]*\|' "$developer_report_file_for_tdd" 2>/dev/null || true)
                    if [ "$dev_red_count" -lt 1 ] || [ "$dev_green_count" -lt 1 ]; then
                        add_failure "D4[${UNIT_LABEL}]: ${task_id} TDD 证据不完整（RED=${red_count}, GREEN=${green_count}；developer-report RED=${dev_red_count}, GREEN=${dev_green_count}）"
                    fi
                else
                    add_failure "D4[${UNIT_LABEL}]: ${task_id} TDD 证据缺少可读取的 developer-report 文件"
                fi
            else
                add_failure "D4[${UNIT_LABEL}]: ${task_id} TDD 证据不完整（RED=${red_count}, GREEN=${green_count}）"
            fi
        fi

        spec_status=$(printf '%s\n' "$task_block" | sed -nE 's/^[[:space:]]*-[[:space:]]*Spec Review:[[:space:]]*(SPEC_OK|SPEC_ISSUE).*/\1/p' | head -1)
        phase2a_status=$(printf '%s\n' "$task_block" | sed -nE 's/^[[:space:]]*-[[:space:]]*Phase2A:[[:space:]]*(2A_OK|2A_ISSUE).*/\1/p' | head -1)
        phase2b_status=$(printf '%s\n' "$task_block" | sed -nE 's/^[[:space:]]*-[[:space:]]*Phase2B:[[:space:]]*(2B_OK|2B_ISSUE).*/\1/p' | head -1)
        phase2c_status=$(printf '%s\n' "$task_block" | sed -nE 's/^[[:space:]]*-[[:space:]]*Phase2C:[[:space:]]*(2C_OK|2C_ISSUE).*/\1/p' | head -1)

        [ -n "$spec_status" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 Spec Review 状态"
        [ -n "$phase2a_status" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 Phase2A 状态"
        [ -n "$phase2b_status" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 Phase2B 状态"
        [ -n "$phase2c_status" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 Phase2C 状态"

        [ "$spec_status" = "SPEC_OK" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} Spec Review 未通过（${spec_status:-missing}）"
        [ "$phase2a_status" = "2A_OK" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} Phase2A 未通过（${phase2a_status:-missing}）"
        [ "$phase2b_status" = "2B_OK" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} Phase2B 未通过（${phase2b_status:-missing}）"
        [ "$phase2c_status" = "2C_OK" ] || add_failure "D5[${UNIT_LABEL}]: ${task_id} Phase2C 未通过（${phase2c_status:-missing}）"

        plan_task_block=""
        if [ -f "$PLAN_FILE" ] && [ -s "$PLAN_FILE" ]; then
            plan_task_block=$(extract_plan_task_block "$PLAN_FILE" "$task_id")
            if [ -z "$plan_task_block" ]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} 在 plan.md 中缺少对应 Task 定义，无法核对执行证据"
            fi
        fi

        report_proving_command=$(extract_task_field_value "$task_block" "proving_command")
        report_proving_command=$(printf '%s' "$report_proving_command" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$report_proving_command"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 proving_command"
        elif printf '%s\n' "$report_proving_command" | grep -qiE '见上次|上次输出|口头|待补|TODO|TBD'; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} proving_command 不得引用历史结果或占位说明，必须 fresh 重跑"
        elif is_obviously_non_verifying_command "$report_proving_command"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} proving_command 不能是空心命令，必须执行真实验证"
        fi

        report_real_dependency_note=$(extract_task_field_value "$task_block" "real_dependency_note")
        report_real_dependency_note=$(printf '%s' "$report_real_dependency_note" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$report_real_dependency_note"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 real_dependency_note"
        elif contains_mock_only_acceptance "$report_real_dependency_note"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} real_dependency_note 不得把 Mock 当最终验收或完成证据"
        fi

        report_evidence_target=$(extract_task_field_value "$task_block" "evidence_target")
        report_evidence_target=$(printf '%s' "$report_evidence_target" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$report_evidence_target"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 evidence_target"
        elif ! has_anchored_evidence_target "$report_evidence_target"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} evidence_target 必须指向带锚点的 dev-report.md / qa-report.md / acceptance-summary.md / preflight-evidence.md"
        elif has_unanchored_evidence_target "$report_evidence_target"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} evidence_target 中每个证据文件都必须带锚点（#...）"
        else
            validate_anchored_refs_exist "$report_evidence_target" "$UNIT_WORK_DIR" "D5[${UNIT_LABEL}]: ${task_id} evidence_target" "$PHASE_DIR"
        fi

        report_mock_boundary_note=$(extract_task_field_value "$task_block" "mock_boundary_note")
        report_mock_boundary_note=$(printf '%s' "$report_mock_boundary_note" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$report_mock_boundary_note"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 mock_boundary_note"
        elif ! printf '%s\n' "$report_mock_boundary_note" | grep -qi 'Mock'; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} mock_boundary_note 必须说明 Mock 仅可用于分层隔离测试"
        elif contains_mock_only_acceptance "$report_mock_boundary_note"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} mock_boundary_note 不得声明 Mock 可用于最终验收或完成证据"
        fi

        developer_report_ref=$(extract_task_field_value "$task_block" "developer_report_ref")
        developer_report_ref=$(printf '%s' "$developer_report_ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$developer_report_ref"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 developer_report_ref"
        elif ! has_anchored_developer_report_ref "$developer_report_ref"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} developer_report_ref 必须指向带锚点的 developer-report-Task-N.md"
        else
            developer_report_file=$(resolve_ref_file_path "$developer_report_ref" "$UNIT_WORK_DIR")
            normalized_unit_work_dir=$(normalize_dir_path "$UNIT_WORK_DIR")
            if [ ! -f "$developer_report_file" ]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} developer_report_ref 指向的文件不存在：${developer_report_file}"
            elif [[ "$developer_report_file" != "$normalized_unit_work_dir/"* ]]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} developer_report_ref 必须留在当前 UNIT 工作区内：${developer_report_file}"
            else
                validate_anchored_refs_exist "$developer_report_ref" "$UNIT_WORK_DIR" "D5[${UNIT_LABEL}]: ${task_id} developer_report_ref"
            fi
        fi

        deviation_trigger=$(extract_task_field_value "$task_block" "deviation_trigger")
        deviation_trigger=$(printf '%s' "$deviation_trigger" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        case "$deviation_trigger" in
            NONE|COMPLEXITY_DRIFT|INTERFACE_TWEAK|INTERFACE_BREAK|SHARED_FILES_EXPANSION|DEPENDENCY_DRIFT|NON_CONVERGENCE|BLOCKED_ACCUMULATION)
                ;;
            *)
                add_failure "D5[${UNIT_LABEL}]: ${task_id} deviation_trigger 非法（${deviation_trigger:-missing}）"
                ;;
        esac

        control_action=$(extract_task_field_value "$task_block" "control_action")
        control_action=$(printf '%s' "$control_action" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        case "$control_action" in
            CONTINUE|ESCALATE|REPLAN|BLOCK)
                ;;
            *)
                add_failure "D5[${UNIT_LABEL}]: ${task_id} control_action 非法（${control_action:-missing}）"
                ;;
        esac
        case "$control_action" in
            ESCALATE)
                unit_requires_escalate_context=1
                ;;
            REPLAN)
                unit_requires_replan_context=1
                ;;
            BLOCK)
                unit_requires_blocked_context=1
                ;;
        esac
        if [ "$deviation_trigger" = "BLOCKED_ACCUMULATION" ] || [ "$commit_status" = "BLOCKED" ]; then
            unit_requires_blocked_context=1
        fi
        if phase3_is_high_risk_deviation_trigger "$deviation_trigger"; then
            HIGH_RISK_DEVIATION_TRIGGERS="${HIGH_RISK_DEVIATION_TRIGGERS}${deviation_trigger}
"
            case "$control_action" in
                ESCALATE|REPLAN|BLOCK)
                    ;;
                *)
                    add_failure "D5[${UNIT_LABEL}]: ${task_id} 命中高风险 deviation_trigger=${deviation_trigger} 时，control_action 不能为 ${control_action:-missing}"
                    ;;
            esac
        fi

        fresh_proving_output=$(extract_labeled_fence_block "$task_block" "Fresh proving command:")
        fresh_proving_output=$(printf '%s\n' "$fresh_proving_output" | sed '/^[[:space:]]*$/{$d;}')
        if is_placeholder_text "$fresh_proving_output"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 Fresh proving command 完整输出"
        elif printf '%s\n' "$fresh_proving_output" | grep -qiE '见上次|同上|略|摘要|summary|口头'; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} Fresh proving command 不能只写摘要或引用历史结果"
        elif is_summary_only_output "$fresh_proving_output"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} Fresh proving command 不能只写 测试通过/PASS/OK 等摘要，需保留完整输出"
        fi

        proving_executed_at=$(extract_task_field_value "$task_block" "proving_command_executed_at")
        proving_executed_at=$(printf '%s' "$proving_executed_at" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        proving_epoch=""
        if is_placeholder_text "$proving_executed_at"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 proving_command_executed_at"
        else
            proving_epoch=$(parse_epoch_utc "$proving_executed_at")
        fi
        if [ -n "$proving_executed_at" ] && [ -z "$proving_epoch" ] && ! is_placeholder_text "$proving_executed_at"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} proving_command_executed_at 必须为有效时间戳"
        elif [ -n "$proving_epoch" ]; then
            if [ "$proving_epoch" -gt "$LATEST_PROVING_EPOCH" ]; then
                LATEST_PROVING_EPOCH="$proving_epoch"
            fi
            if [ "$LATEST_FIX_EPOCH" -gt 0 ] && [ "$proving_epoch" -lt "$LATEST_FIX_EPOCH" ]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} proving_command_executed_at 早于最近 fix 报告，必须在修复后 fresh 重跑 proving command（latest_fix=${LATEST_FIX_FILE}）"
            fi
        fi

        proving_exit_code=$(extract_task_field_value "$task_block" "proving_command_exit_code")
        proving_exit_code=$(printf '%s' "$proving_exit_code" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$proving_exit_code"; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} 缺少 proving_command_exit_code"
        elif [ "$proving_exit_code" != "0" ]; then
            add_failure "D5[${UNIT_LABEL}]: ${task_id} proving_command_exit_code 必须为 0（当前 ${proving_exit_code}）"
        fi

        if [ -n "$plan_task_block" ]; then
            plan_proving_command=$(extract_task_field_value "$plan_task_block" "proving_command")
            plan_proving_command=$(printf '%s' "$plan_proving_command" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
            if ! is_placeholder_text "$plan_proving_command" && [ "$report_proving_command" != "$plan_proving_command" ]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} proving_command 与 plan.md 不一致"
            fi

            plan_real_dependency_note=$(extract_task_field_value "$plan_task_block" "real_dependency_note")
            plan_real_dependency_note=$(printf '%s' "$plan_real_dependency_note" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
            if ! is_placeholder_text "$plan_real_dependency_note" && [ "$report_real_dependency_note" != "$plan_real_dependency_note" ]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} real_dependency_note 与 plan.md 不一致"
            fi

            plan_evidence_target=$(extract_task_field_value "$plan_task_block" "evidence_target")
            plan_evidence_target=$(printf '%s' "$plan_evidence_target" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
            if ! is_placeholder_text "$plan_evidence_target" && [ "$report_evidence_target" != "$plan_evidence_target" ]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} evidence_target 与 plan.md 不一致"
            fi

            plan_mock_boundary_note=$(extract_task_field_value "$plan_task_block" "mock_boundary_note")
            plan_mock_boundary_note=$(printf '%s' "$plan_mock_boundary_note" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
            if ! is_placeholder_text "$plan_mock_boundary_note" && [ "$report_mock_boundary_note" != "$plan_mock_boundary_note" ]; then
                add_failure "D5[${UNIT_LABEL}]: ${task_id} mock_boundary_note 与 plan.md 不一致"
            fi
        fi
    done <<< "$task_ids"

    # --- D5.1: Task-scope 对照表与 plan 映射一致性（UNIT 级，按 scope 前缀过滤） ---

    if [ -f "$PLAN_FILE" ] && [ -s "$PLAN_FILE" ]; then
        task_scope_rows=$(extract_task_scope_table_rows "$DEV_REPORT")
        task_scope_count=$(printf '%s\n' "$task_scope_rows" | sed '/^$/d' | wc -l | tr -d ' ')
        if [ "$task_scope_count" -eq 0 ]; then
            add_failure "D5.1[${UNIT_LABEL}]: dev-report.md 缺少 Task-scope 对照表数据行"
        fi

        if [ -n "${plan_task_ids:-}" ]; then
            while IFS= read -r plan_task_id; do
                [ -n "$plan_task_id" ] || continue

                plan_task_block=$(extract_plan_task_block "$PLAN_FILE" "$plan_task_id")
                plan_scope_line=$(printf '%s\n' "$plan_task_block" | { grep -E '^[[:space:]]*-[[:space:]]*(\*\*)?scope_item_ref(\*\*)?[[:space:]]*[:：]' || true; } | head -1)
                plan_scope_ref=$(printf '%s' "$plan_scope_line" | sed -E 's/^[^:：]*[:：][[:space:]]*//')
                # 按 UNIT 过滤 scope：只取当前 UNIT 的 scope
                all_plan_scope_ids=$(extract_scope_ids_from_text "$plan_scope_ref")
                if [ -n "$unit_scope_prefix" ] && [ -n "$unit_num" ]; then
                    plan_scope_ids=$(printf '%s\n' "$all_plan_scope_ids" | grep "^${unit_scope_prefix}" || true)
                    # 兜底：如果按前缀过滤无结果（兼容单 UNIT），取全量
                    [ -n "$plan_scope_ids" ] || plan_scope_ids="$all_plan_scope_ids"
                else
                    plan_scope_ids="$all_plan_scope_ids"
                fi
                if [ -z "$plan_scope_ids" ]; then
                    add_failure "D5.1[${UNIT_LABEL}]: ${plan_task_id} 在 plan.md 缺少有效 scope_item_ref"
                fi

                scope_row=$(printf '%s\n' "$task_scope_rows" | awk -F'|' -v target="$plan_task_id" '$1==target {print; exit}')
                if [ -z "$scope_row" ]; then
                    add_failure "D5.1[${UNIT_LABEL}]: ${plan_task_id} 未在 dev-report.md「Task-scope 对照表」登记"
                    continue
                fi

                IFS='|' read -r row_task row_scope_ref row_impact_files row_rollback_ref row_boundary <<< "$scope_row"
                report_scope_ids=$(extract_scope_ids_from_text "$row_scope_ref")
                if [ -z "$report_scope_ids" ]; then
                    add_failure "D5.1[${UNIT_LABEL}]: ${row_task} 在 Task-scope 对照表缺少有效 scope_item_ref"
                fi

                missing_scope_ids=$(comm -23 \
                    <(printf '%s\n' "$plan_scope_ids" | sed '/^$/d' | sort -u) \
                    <(printf '%s\n' "$report_scope_ids" | sed '/^$/d' | sort -u) \
                    | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
                extra_scope_ids=$(comm -13 \
                    <(printf '%s\n' "$plan_scope_ids" | sed '/^$/d' | sort -u) \
                    <(printf '%s\n' "$report_scope_ids" | sed '/^$/d' | sort -u) \
                    | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
                [ -z "$missing_scope_ids" ] || add_failure "D5.1[${UNIT_LABEL}]: ${row_task} Task-scope 对照表缺少 plan 映射的 scope_item_id：${missing_scope_ids}"
                [ -z "$extra_scope_ids" ] || add_failure "D5.1[${UNIT_LABEL}]: ${row_task} Task-scope 对照表多出 plan 未声明的 scope_item_id：${extra_scope_ids}"

                if is_placeholder_text "$row_impact_files"; then
                    add_failure "D5.1[${UNIT_LABEL}]: ${row_task} Task-scope 对照表缺少 impact_files"
                fi
                if is_placeholder_text "$row_rollback_ref"; then
                    add_failure "D5.1[${UNIT_LABEL}]: ${row_task} Task-scope 对照表缺少 rollback_ref"
                fi

                row_boundary_norm=$(printf '%s' "$row_boundary" | tr '[:lower:]' '[:upper:]')
                if [ "$row_boundary_norm" != "OK" ] && [ "$row_boundary_norm" != "PASS" ]; then
                    add_failure "D5.1[${UNIT_LABEL}]: ${row_task} 边界校验状态非 OK/PASS（当前 ${row_boundary:-missing}）"
                fi
            done <<< "$plan_task_ids"

            extra_scope_rows=$(comm -13 \
                <(printf '%s\n' "$plan_task_ids" | sed '/^$/d' | sort -u) \
                <(printf '%s\n' "$task_scope_rows" | awk -F'|' '{print $1}' | sed '/^$/d' | sort -u) \
                | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
            [ -z "$extra_scope_rows" ] || add_failure "D5.1[${UNIT_LABEL}]: dev-report.md「Task-scope 对照表」存在 plan.md 未声明的 Task：${extra_scope_rows}"
        fi
    fi

    # --- D6: 全量测试结果存在且通过（UNIT 级） ---

    test_section=$(extract_section_content "$DEV_REPORT" "### 全量测试结果" 3)
    test_lines=$(printf '%s\n' "$test_section" | grep -cvE '^[[:space:]]*$' 2>/dev/null || true)
    if [ "$test_lines" -eq 0 ]; then
        add_failure "D6[${UNIT_LABEL}]: 全量测试结果章节无实质内容"
    else
        test_executed_at=$(printf '%s\n' "$test_section" | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*TEST_EXECUTED_AT[[:space:]]*:[[:space:]]*(.*)$/\1/p' | head -1)
        test_executed_at=$(printf '%s' "$test_executed_at" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        test_epoch=""
        if is_placeholder_text "$test_executed_at"; then
            add_failure "D6[${UNIT_LABEL}]: 全量测试结果缺少 TEST_EXECUTED_AT"
        else
            test_epoch=$(parse_epoch_utc "$test_executed_at")
        fi
        if [ -n "$test_executed_at" ] && [ -z "$test_epoch" ] && ! is_placeholder_text "$test_executed_at"; then
            add_failure "D6[${UNIT_LABEL}]: TEST_EXECUTED_AT 必须为有效时间戳"
        elif [ -n "$test_epoch" ]; then
            if [ "$test_epoch" -gt "$LATEST_TEST_EPOCH" ]; then
                LATEST_TEST_EPOCH="$test_epoch"
            fi
            if [ "$LATEST_FIX_EPOCH" -gt 0 ] && [ "$test_epoch" -lt "$LATEST_FIX_EPOCH" ]; then
                add_failure "D6[${UNIT_LABEL}]: 全量测试结果的 TEST_EXECUTED_AT 早于最近 fix 报告，必须在修复后 fresh 重跑全量测试（latest_fix=${LATEST_FIX_FILE}）"
            fi
        fi

        test_exit_code=$(printf '%s\n' "$test_section" | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*TEST_EXIT_CODE[[:space:]]*:[[:space:]]*(.*)$/\1/p' | head -1)
        test_exit_code=$(printf '%s' "$test_exit_code" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$test_exit_code"; then
            add_failure "D6[${UNIT_LABEL}]: 全量测试结果缺少 TEST_EXIT_CODE"
        elif [ "$test_exit_code" != "0" ]; then
            add_failure "D6[${UNIT_LABEL}]: TEST_EXIT_CODE 必须为 0（当前 ${test_exit_code}）"
        fi

        test_section_clean=$(printf '%s\n' "$test_section" | sed -E 's/[`*_]//g')
        test_section_no_zero_fail=$(printf '%s\n' "$test_section_clean" \
            | sed -E 's/0[[:space:]]+failed//Ig; s/0[[:space:]]+failures//Ig; s/no[[:space:]]+failures?//Ig; s/无失败//g; s/未发现失败//g')

        if printf '%s\n' "$test_section_no_zero_fail" | grep -qiE '(^|[^A-Za-z])(failed|failures?|error|errors|失败|未通过)([^A-Za-z]|$)'; then
            add_failure "D6[${UNIT_LABEL}]: 全量测试结果包含失败信号，未通过质量门禁"
        fi

        if ! printf '%s\n' "$test_section_clean" | grep -qiE '(passed|pass|全部通过|通过|ok)'; then
            add_failure "D6[${UNIT_LABEL}]: 全量测试结果未检测到通过信号（如 passed/通过/OK）"
        fi
    fi

    if [ -n "$dev_last_observed_epoch" ]; then
        if [ "$LATEST_PROVING_EPOCH" -gt 0 ] && [ "$dev_last_observed_epoch" -lt "$LATEST_PROVING_EPOCH" ]; then
            add_failure "D6[${UNIT_LABEL}]: last_observed_at 早于最新 proving_command_executed_at，运行态快照已过期"
        fi
        if [ "$LATEST_TEST_EPOCH" -gt 0 ] && [ "$dev_last_observed_epoch" -lt "$LATEST_TEST_EPOCH" ]; then
            add_failure "D6[${UNIT_LABEL}]: last_observed_at 早于最新 TEST_EXECUTED_AT，运行态快照已过期"
        fi
        if [ "$LATEST_FIX_EPOCH" -gt 0 ] && [ "$dev_last_observed_epoch" -lt "$LATEST_FIX_EPOCH" ]; then
            add_failure "D6[${UNIT_LABEL}]: last_observed_at 早于最近 fix 报告，运行态快照已过期"
        fi
    fi
    if [ "$unit_requires_blocked_context" -eq 1 ] && is_explicit_none "$dev_active_blocker"; then
        add_failure "D6[${UNIT_LABEL}]: 存在 BLOCKED / BLOCK 信号时，active_blocker 不能为 无"
    fi
    if [ "$unit_requires_escalate_context" -eq 1 ] && [ "$dev_next_action" != "ESCALATE" ] && [ "$dev_next_action" != "HOLD" ]; then
        add_failure "D6[${UNIT_LABEL}]: 命中 ESCALATE 时，next_action 必须为 ESCALATE 或 HOLD"
    fi
    if [ "$unit_requires_replan_context" -eq 1 ]; then
        if [ "$dev_next_action" != "REPLAN_REQUEST" ]; then
            add_failure "D6[${UNIT_LABEL}]: 命中 REPLAN 时，next_action 必须为 REPLAN_REQUEST"
        fi
        if is_explicit_none "$dev_active_blocker"; then
            add_failure "D6[${UNIT_LABEL}]: 命中 REPLAN 时，active_blocker 不能为 无"
        fi
        if is_placeholder_text "$dev_replan_request" || is_explicit_none "$dev_replan_request"; then
            add_failure "D6[${UNIT_LABEL}]: 命中 REPLAN 时，必须记录 replan_request"
        else
            validate_runtime_anchor_refs_exist "$dev_replan_request" "$UNIT_WORK_DIR" "D6[${UNIT_LABEL}]: replan_request" "$PHASE_DIR"
        fi
        if is_placeholder_text "$dev_batch_freeze_reason" || is_explicit_none "$dev_batch_freeze_reason"; then
            add_failure "D6[${UNIT_LABEL}]: 命中 REPLAN 时，必须记录 batch_freeze_reason"
        fi
        if is_placeholder_text "$dev_unlock_resolution" || is_explicit_none "$dev_unlock_resolution"; then
            add_failure "D6[${UNIT_LABEL}]: 命中 REPLAN 时，必须记录 unlock_resolution"
        fi
    fi

    # --- D11.1: 清单驱动等价性门禁（UNIT 级，按 scope 前缀过滤） ---
    if [ ! -f "$TEST_CASES_FILE" ]; then
        add_failure "D11.1[${UNIT_LABEL}]: 缺少 test-cases.md：$TEST_CASES_FILE"
    elif [ ! -s "$TEST_CASES_FILE" ]; then
        add_failure "D11.1[${UNIT_LABEL}]: test-cases.md 为空：$TEST_CASES_FILE"
    else
        eq_rows=$(extract_eq_matrix_rows "$TEST_CASES_FILE")
        eq_count=$(printf '%s\n' "$eq_rows" | sed '/^$/d' | wc -l | tr -d ' ')
        if [ "$eq_count" -eq 0 ]; then
            add_failure "D11.1[${UNIT_LABEL}]: test-cases.md 缺少等价性对照矩阵数据行"
        else
            eq_covered_scope_ids=""
            while IFS='|' read -r eq_scope_id eq_status; do
                [ -n "$eq_scope_id" ] || continue
                if [ "$eq_status" != "EQ-COVERED" ] && [ "$eq_status" != "DESIGN-GAP(EQ)" ]; then
                    add_failure "D11.1[${UNIT_LABEL}]: 等价性状态非法（${eq_scope_id}=${eq_status}），仅允许 EQ-COVERED 或 DESIGN-GAP(EQ)"
                    continue
                fi
                if [ "$eq_status" = "DESIGN-GAP(EQ)" ]; then
                    add_failure "D11.1[${UNIT_LABEL}]: 存在 DESIGN-GAP(EQ)（${eq_scope_id}），阻断 /delivery-owner 收口"
                else
                    eq_covered_scope_ids="${eq_covered_scope_ids}${eq_scope_id}
"
                fi
            done <<< "$eq_rows"

            # 按 UNIT 过滤 plan 中的 scope
            all_plan_scope_ids=$(grep -oE 'SCOPE-P[0-9]+U[0-9]+-[0-9]+' "$PLAN_FILE" 2>/dev/null | sort -u || true)
            if [ -n "$unit_scope_prefix" ] && [ -n "$unit_num" ]; then
                plan_scope_ids=$(printf '%s\n' "$all_plan_scope_ids" | grep "^${unit_scope_prefix}" || true)
                # 兜底：如果按前缀过滤无结果（兼容单 UNIT），取全量
                [ -n "$plan_scope_ids" ] || plan_scope_ids="$all_plan_scope_ids"
            else
                plan_scope_ids="$all_plan_scope_ids"
            fi
            while IFS= read -r plan_scope_id; do
                [ -n "$plan_scope_id" ] || continue
                if ! printf '%s\n' "$eq_covered_scope_ids" | grep -qx "$plan_scope_id"; then
                    add_failure "D11.1[${UNIT_LABEL}]: ${plan_scope_id} 未达到 EQ-COVERED（或未出现在等价性对照矩阵）"
                fi
            done <<< "$plan_scope_ids"
        fi

        # 收集 TC 编号供 D12.1 使用
        unit_tc_ids=$(grep -oE 'TC(-[A-Z][0-9]+)?-[0-9]+' "$TEST_CASES_FILE" 2>/dev/null | sort -u || true)
        if [ -n "$unit_tc_ids" ]; then
            ALL_TC_IDS="${ALL_TC_IDS:+${ALL_TC_IDS}
}${unit_tc_ids}"
        fi
    fi

done <<< "$ALL_UNIT_WORK_DIRS"

# ============================================================
# Phase 级检查
# ============================================================

# --- D7: 分级真源来自 plan.md（Phase 级） ---

plan_grade=""
if [ -f "$PLAN_FILE" ] && [ -s "$PLAN_FILE" ]; then
    plan_grade=$(parse_plan_grade "$PLAN_FILE")
fi

if [ -z "$plan_grade" ]; then
    add_failure "D7: plan.md 缺少可解析的 Phase 3 审查分级（轻量/标准/完整）"
fi
if [ -z "$CURRENT_PLAN_VERSION" ]; then
    add_failure "D7: plan.md 缺少可解析的 plan_version"
fi

# --- D8: code-review-report.md / qa-report.md 状态校验（Phase 级） ---

if [ ! -f "$CR_REPORT" ]; then
    add_failure "D8: code-review-report.md 不存在：$CR_REPORT"
elif [ ! -s "$CR_REPORT" ]; then
    add_failure "D8: code-review-report.md 为空：$CR_REPORT"
fi

if [ ! -f "$QA_REPORT" ]; then
    add_failure "D8: qa-report.md 不存在：$QA_REPORT"
elif [ ! -s "$QA_REPORT" ]; then
    add_failure "D8: qa-report.md 为空：$QA_REPORT"
fi

# --- D10: waiver 校验（Phase 级） ---
check_waiver_file_sanity "$ALL_DEV_REPORTS"

if [ -f "$CR_REPORT" ] && [ -s "$CR_REPORT" ] && [ -f "$QA_REPORT" ] && [ -s "$QA_REPORT" ] && [ -n "$plan_grade" ]; then
    cr_metadata=$(extract_metadata_json "$CR_REPORT")
    qa_metadata=$(extract_metadata_json "$QA_REPORT")

    cr_grade=$(parse_report_grade "$CR_REPORT" "$cr_metadata")
    qa_grade=$(parse_report_grade "$QA_REPORT" "$qa_metadata")
    effective_qa_grade="$qa_grade"
    qa_plan_version_ref=$(extract_report_field "$QA_REPORT" "plan_version_ref")
    qa_plan_version_value=$(extract_report_field "$QA_REPORT" "plan_version_value")

    if [ -z "$cr_grade" ]; then
        add_failure "D8: code-review-report.md 缺少可解析的审查分级"
    elif [ "$cr_grade" != "$plan_grade" ]; then
        add_failure "D8: code-review-report.md 审查分级（${cr_grade}）与 plan.md（${plan_grade}）不一致"
    fi

    if [ "$qa_grade" = "未指定" ]; then
        effective_qa_grade="$plan_grade"
    fi

    if [ -z "$qa_grade" ]; then
        add_failure "D8: qa-report.md 缺少可解析的审查分级"
    elif [ -z "$effective_qa_grade" ] || [ "$effective_qa_grade" != "$plan_grade" ]; then
        add_failure "D8: qa-report.md 审查分级（${qa_grade}）与 plan.md（${plan_grade}）不一致"
    fi
    if ! has_plan_version_ref "$qa_plan_version_ref"; then
        add_failure "D8: qa-report.md 缺少有效的 plan_version_ref"
    else
        validate_anchored_refs_exist "$qa_plan_version_ref" "$PHASE_DIR" "D8: qa-report.md 的 plan_version_ref"
    fi
    if is_placeholder_text "$qa_plan_version_value"; then
        add_failure "D8: qa-report.md 缺少 plan_version_value"
    elif [ -n "$CURRENT_PLAN_VERSION" ] && [ "$qa_plan_version_value" != "$CURRENT_PLAN_VERSION" ]; then
        add_failure "D8: qa-report.md 的 plan_version_value 与当前 plan.md 不一致（qa=${qa_plan_version_value}, plan=${CURRENT_PLAN_VERSION}）"
    fi

    review_required=()
    qa_required=()
    review_stage_lines=""
    qa_stage_lines=""
    if review_stage_lines=$(phase3_required_review_stages "$plan_grade"); then
        while IFS= read -r stage; do
            [ -n "$stage" ] || continue
            review_required+=("$stage")
        done <<EOF
$review_stage_lines
EOF
    else
        add_failure "D8: plan.md 审查分级非法：${plan_grade}"
        review_required=()
    fi
    if qa_stage_lines=$(phase3_required_qa_stages "$plan_grade"); then
        while IFS= read -r stage; do
            [ -n "$stage" ] || continue
            qa_required+=("$stage")
        done <<EOF
$qa_stage_lines
EOF
    else
        add_failure "D8: plan.md 审查分级非法：${plan_grade}"
        qa_required=()
    fi

    for stage in "${review_required[@]}"; do
        stage_status=$(parse_review_status "$CR_REPORT" "$cr_metadata" "$stage")
        check_required_stage "$stage" "$stage_status" "D8: code-review-report.md"
    done

    for stage in "${qa_required[@]}"; do
        stage_status=$(parse_qa_status "$QA_REPORT" "$qa_metadata" "$stage")
        check_required_stage "$stage" "$stage_status" "D8: qa-report.md"
    done

    if [ -n "$HIGH_RISK_DEVIATION_TRIGGERS" ]; then
        extra_review_stage_lines=""
        extra_qa_stage_lines=""
        while IFS= read -r trigger; do
            [ -n "$trigger" ] || continue
            extra_review_stage_lines="${extra_review_stage_lines}
$(phase3_escalation_review_stages "$trigger")"
            extra_qa_stage_lines="${extra_qa_stage_lines}
$(phase3_escalation_qa_stages "$trigger")"
        done <<< "$(printf '%s\n' "$HIGH_RISK_DEVIATION_TRIGGERS" | sed '/^$/d' | sort -u)"

        while IFS= read -r stage; do
            [ -n "$stage" ] || continue
            stage_status=$(parse_review_status "$CR_REPORT" "$cr_metadata" "$stage")
            if [ "$stage_status" != "OK" ] && [ "$stage_status" != "ISSUE" ]; then
                add_failure "D8: 命中高风险 drift 时必须执行 ${stage}，当前状态为 ${stage_status:-missing}"
            fi
        done <<< "$(printf '%s\n' "$extra_review_stage_lines" | sed '/^$/d' | sort -u)"

        while IFS= read -r stage; do
            [ -n "$stage" ] || continue
            stage_status=$(parse_qa_status "$QA_REPORT" "$qa_metadata" "$stage")
            if [ "$stage_status" != "OK" ] && [ "$stage_status" != "ISSUE" ]; then
                add_failure "D8: 命中高风险 drift 时必须执行 ${stage}，当前状态为 ${stage_status:-missing}"
            fi
        done <<< "$(printf '%s\n' "$extra_qa_stage_lines" | sed '/^$/d' | sort -u)"
    fi
fi

# --- D12: QA_A UNIT 汇总 + AC 追踪表存在性（Phase 级，qa-report 在 PHASE_DIR） ---

if [ -f "$QA_REPORT" ] && [ -s "$QA_REPORT" ]; then
    qa_a_section=$(extract_markdown_section "$QA_REPORT" "### QA_A UNIT 执行汇总")
    qa_a_lines=$(printf '%s\n' "$qa_a_section" | grep -cvE '^[[:space:]]*$' 2>/dev/null || true)
    if [ "$qa_a_lines" -eq 0 ]; then
        add_failure "D12: qa-report.md 缺少 QA_A UNIT 执行汇总或内容为空"
    else
        qa_a_rows=$(printf '%s\n' "$qa_a_section" | awk -F'|' '
            function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
            /^\|/ {
                unit = trim($2)
                unit_work_dir = trim($3)
                test_cases_ref = trim($4)
                status = trim($5)
                issue_ids = trim($6)
                note = trim($7)
                if (unit == "" || unit == "UNIT" || unit ~ /^-+$/) next
                print unit "|" unit_work_dir "|" test_cases_ref "|" status "|" issue_ids "|" note
            }
        ')
        qa_a_count=$(printf '%s\n' "$qa_a_rows" | sed '/^$/d' | wc -l | tr -d ' ')
        if [ "$qa_a_count" -eq 0 ]; then
            add_failure "D12: qa-report.md QA_A UNIT 执行汇总仅有表头，缺少 UNIT 数据行"
        else
            expected_unit_dirs=$(printf '%s\n' "$ALL_UNIT_WORK_DIRS" | sed '/^$/d' | sort -u)
            actual_unit_dirs=""
            while IFS='|' read -r qa_unit qa_unit_work_dir qa_test_cases_ref qa_status qa_issue_ids qa_note; do
                [ -n "$qa_unit" ] || continue

                if ! printf '%s\n' "$qa_unit" | grep -qE '^UNIT-[0-9]+'; then
                    add_failure "D12: QA_A UNIT 执行汇总存在非法 UNIT 编号：${qa_unit}"
                fi

                resolved_unit_work_dir="$qa_unit_work_dir"
                if [[ "$resolved_unit_work_dir" != /* ]]; then
                    resolved_unit_work_dir="${PHASE_DIR}/$(printf '%s' "$resolved_unit_work_dir" | sed -E 's#^\./##; s#/$##')"
                fi
                resolved_unit_work_dir=$(printf '%s' "$resolved_unit_work_dir" | sed -E 's#/$##')
                actual_unit_dirs="${actual_unit_dirs:+${actual_unit_dirs}
}${resolved_unit_work_dir}"

                if ! newline_list_contains_literal "$expected_unit_dirs" "$resolved_unit_work_dir"; then
                    add_failure "D12: QA_A UNIT 执行汇总引用了当前 Phase 之外的 unit_work_dir：${qa_unit_work_dir}"
                fi

                resolved_test_cases_ref="$qa_test_cases_ref"
                if [[ "$resolved_test_cases_ref" != /* ]]; then
                    resolved_test_cases_ref="${PHASE_DIR}/$(printf '%s' "$resolved_test_cases_ref" | sed -E 's#^\./##')"
                fi
                expected_test_cases_ref="${resolved_unit_work_dir}/test-cases.md"
                if [ "$resolved_test_cases_ref" != "$expected_test_cases_ref" ]; then
                    add_failure "D12: ${qa_unit} 的 test_cases_ref 与 unit_work_dir 不一致（${qa_test_cases_ref}）"
                fi

                qa_status_norm=$(normalize_stage_status "$qa_status")
                if [ "$qa_status_norm" != "OK" ] && [ "$qa_status_norm" != "ISSUE" ]; then
                    add_failure "D12: ${qa_unit} 的 QA_A 状态非法（${qa_status:-missing}），仅允许 OK/ISSUE"
                fi

                if [ "$qa_status_norm" = "ISSUE" ] && ! printf '%s\n' "$qa_issue_ids" | grep -qE 'QAR-[0-9]{3,}'; then
                    add_failure "D12: ${qa_unit} 标记为 ISSUE，但 issue_ids 缺少有效 QAR-XXX"
                fi

                if [ "$qa_status_norm" = "OK" ] && ! is_placeholder_text "$qa_issue_ids"; then
                    add_failure "D12: ${qa_unit} 标记为 OK，但 issue_ids 不应填写问题编号"
                fi

                if is_placeholder_text "$qa_note"; then
                    add_failure "D12: ${qa_unit} 在 QA_A UNIT 执行汇总缺少有效说明"
                fi
            done <<< "$qa_a_rows"

            missing_unit_dirs=$(comm -23 \
                <(printf '%s\n' "$expected_unit_dirs") \
                <(printf '%s\n' "$actual_unit_dirs" | sed '/^$/d' | sort -u) \
                | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
            extra_unit_dirs=$(comm -13 \
                <(printf '%s\n' "$expected_unit_dirs") \
                <(printf '%s\n' "$actual_unit_dirs" | sed '/^$/d' | sort -u) \
                | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
            [ -z "$missing_unit_dirs" ] || add_failure "D12: QA_A UNIT 执行汇总缺少当前 Phase UNIT：${missing_unit_dirs}"
            [ -z "$extra_unit_dirs" ] || add_failure "D12: QA_A UNIT 执行汇总多出非当前 Phase UNIT：${extra_unit_dirs}"
        fi
    fi

    ac_trace_section=$(extract_markdown_section "$QA_REPORT" "### AC 追踪表")
    ac_trace_lines=$(printf '%s\n' "$ac_trace_section" | grep -cvE '^[[:space:]]*$' 2>/dev/null || true)
    if [ "$ac_trace_lines" -eq 0 ]; then
        add_failure "D12: qa-report.md 缺少 AC 追踪表或内容为空"
    else
        ac_trace_data_rows=$(printf '%s\n' "$ac_trace_section" | awk -F'|' '
            function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
            /^\|/ {
                unit = trim($2)
                ac_id = trim($4)
                if (unit == "" || unit == "UNIT" || unit ~ /^-+$/) next
                if (ac_id == "" || ac_id == "AC ID" || ac_id ~ /^-+$/) next
                print $0
            }
        ')
        ac_trace_data_count=$(printf '%s\n' "$ac_trace_data_rows" | sed '/^$/d' | wc -l | tr -d ' ')
        if [ "$ac_trace_data_count" -eq 0 ]; then
            add_failure "D12: qa-report.md AC 追踪表仅有表头，缺少 AC 数据行"
        else
            ac_trace_entries=$(printf '%s\n' "$ac_trace_data_rows" | awk -F'|' '
                function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
                {
                    unit = trim($2)
                    unit_work_dir = trim($3)
                    ac_id = trim($4)
                    test_ref = trim($6)
                    result = trim($8)
                    evidence = trim($9)
                    print unit "|" unit_work_dir "|" ac_id "|" test_ref "|" result "|" evidence
                }
            ')

            while IFS='|' read -r row_unit row_unit_work_dir row_ac_id row_test_ref row_result row_evidence; do
                [ -n "$row_unit" ] || continue

                if ! printf '%s\n' "$row_unit" | grep -qE '^UNIT-[0-9]+'; then
                    add_failure "D12: AC 追踪表存在非法 UNIT 编号：${row_unit}"
                fi

                resolved_row_unit_work_dir="$row_unit_work_dir"
                if [[ "$resolved_row_unit_work_dir" != /* ]]; then
                    resolved_row_unit_work_dir="${PHASE_DIR}/$(printf '%s' "$resolved_row_unit_work_dir" | sed -E 's#^\./##; s#/$##')"
                fi
                resolved_row_unit_work_dir=$(printf '%s' "$resolved_row_unit_work_dir" | sed -E 's#/$##')
                if ! newline_list_contains_literal "$ALL_UNIT_WORK_DIRS" "$resolved_row_unit_work_dir"; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 引用了当前 Phase 之外的 unit_work_dir：${row_unit_work_dir}"
                fi

                if ! printf '%s\n' "$row_ac_id" | grep -qE '^G?AC(-[A-Z][0-9]+)?-[0-9]+$'; then
                    add_failure "D12: AC 追踪表存在非法 AC 编号：${row_ac_id}"
                fi

                if is_placeholder_text "$row_test_ref" || ! printf '%s\n' "$row_test_ref" | grep -qE 'TC(-[A-Z][0-9]+)?-[0-9]+'; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 的 test_ref 缺少有效 TC 编号"
                fi

                row_result_norm=$(printf '%s' "$row_result" | tr '[:lower:]' '[:upper:]')
                if [ -z "$row_result_norm" ] || ! printf '%s\n' "$row_result_norm" | grep -qE '^PASS$'; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 在 AC 追踪表结果不是 PASS（${row_result:-missing}）"
                fi

                if is_placeholder_text "$row_evidence"; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 缺少有效证据摘要"
                fi
            done <<< "$ac_trace_entries"

            if [ -n "$ALL_TC_IDS" ]; then
                tc_ids_in_test_cases_norm=$(printf '%s\n' "$ALL_TC_IDS" | sed -E 's/^TC-0*([0-9]+)$/TC-\1/' | sort -u || true)
                while IFS='|' read -r d121_unit _ d121_ac d121_tref _ _; do
                    [ -n "$d121_unit" ] || continue
                    d121_tc_refs=$(printf '%s' "$d121_tref" | grep -oE 'TC(-[A-Z][0-9]+)?-[0-9]+' | sort -u || true)
                    while IFS= read -r d121_tc; do
                        [ -n "$d121_tc" ] || continue
                        d121_tc_norm=$(printf '%s' "$d121_tc" | sed -E 's/^TC-0*([0-9]+)$/TC-\1/')
                        if ! printf '%s\n' "$tc_ids_in_test_cases_norm" | grep -qx "$d121_tc_norm"; then
                            add_failure "D12.1: ${d121_unit}/${d121_ac} 的 test_ref 引用 ${d121_tc}，但 test-cases.md 中不存在"
                        fi
                    done <<< "$d121_tc_refs"
                done <<< "$ac_trace_entries"
            else
                add_failure "D12.1: 所有 UNIT 的 test-cases.md 未解析到任何 TC 编号，无法执行 AC->TC 交叉校验"
            fi
        fi
    fi
fi

# --- D12.2: 条件触发的汇总代理 summary 文件（Phase 级） ---

STATUS_SUMMARY_REQUIRED="no"
EVIDENCE_SUMMARY_REQUIRED="no"
CURRENT_BATCH_TASK_IDS=""
CURRENT_BATCH_PARALLEL_TASK_COUNT="0"
STATUS_SUMMARY_STATES=""
EVIDENCE_SUMMARY_STATES=""

if [ -f "$PLAN_FILE" ] && [ -s "$PLAN_FILE" ]; then
    CURRENT_BATCH_TASK_IDS=$(extract_current_batch_task_ids "$PLAN_FILE")
    CURRENT_BATCH_PARALLEL_TASK_COUNT=$(count_non_terminal_tasks_in_list "$CURRENT_BATCH_TASK_IDS")
fi

if is_synthesis_summary_required "Status Synthesis Agent" "$CURRENT_BATCH_PARALLEL_TASK_COUNT"; then
    STATUS_SUMMARY_REQUIRED="yes"
fi
if is_synthesis_summary_required "Evidence Synthesis Agent" "$CURRENT_BATCH_PARALLEL_TASK_COUNT"; then
    EVIDENCE_SUMMARY_REQUIRED="yes"
fi

STATUS_SUMMARY_STATES=$(collect_synthesis_statuses "Status Synthesis Agent")
EVIDENCE_SUMMARY_STATES=$(collect_synthesis_statuses "Evidence Synthesis Agent")

validate_synthesis_report_states "Status Synthesis Agent" "$STATUS_SUMMARY_STATES" "$STATUS_SUMMARY_REQUIRED"
validate_synthesis_report_states "Evidence Synthesis Agent" "$EVIDENCE_SUMMARY_STATES" "$EVIDENCE_SUMMARY_REQUIRED"
validate_synthesis_sequence "$STATUS_SUMMARY_REQUIRED" "$EVIDENCE_SUMMARY_REQUIRED" "$STATUS_SUMMARY_STATES" "$EVIDENCE_SUMMARY_STATES"

validate_optional_synthesis_summary \
    "$STATUS_SUMMARY" \
    "Status Synthesis Agent" \
    '(dev-report|qa-report|plan)\.md#[^[:space:]]+' \
    '(BLOCKED|升级信号|批次顺序|Task 状态)' \
    "$STATUS_SUMMARY_REQUIRED"

validate_optional_synthesis_summary \
    "$EVIDENCE_SUMMARY" \
    "Evidence Synthesis Agent" \
    '(dev-report|code-review-report|qa-report|acceptance-summary)\.md#[^[:space:]]+' \
    '(证据锚点|风险承接|签收前缺口)' \
    "$EVIDENCE_SUMMARY_REQUIRED"

# --- D13: acceptance-summary.md 签收状态 + 前置约束验收状态（Phase 级） ---

if [ ! -f "$ACCEPT_SUMMARY" ]; then
    add_failure "D13: acceptance-summary.md 不存在：$ACCEPT_SUMMARY"
elif [ ! -s "$ACCEPT_SUMMARY" ]; then
    add_failure "D13: acceptance-summary.md 为空：$ACCEPT_SUMMARY"
else
    if ! grep -qF "## 最新状态摘要" "$ACCEPT_SUMMARY"; then
        add_failure "D13: acceptance-summary.md 缺少章节：## 最新状态摘要"
    fi
    signoff_status=$(extract_report_field "$ACCEPT_SUMMARY" "sign_off_status")
    if [ -z "$signoff_status" ]; then
        signoff_status=$(grep -E '签收状态[[:space:]]*[:：]' "$ACCEPT_SUMMARY" 2>/dev/null | head -1 | sed -E 's/.*[:：][[:space:]]*//' || true)
    fi
    signoff_status=$(trim "$signoff_status")
    signoff_time=$(extract_report_field "$ACCEPT_SUMMARY" "sign_off_at")
    if [ -z "$signoff_time" ]; then
        signoff_time=$(extract_report_field "$ACCEPT_SUMMARY" "签收时间")
    fi
    business_risk_acceptance_status=$(extract_report_field "$ACCEPT_SUMMARY" "business_risk_acceptance_status")
    risk_acceptance_basis=$(extract_report_field "$ACCEPT_SUMMARY" "risk_acceptance_basis")
    signoff_epoch=""
    if [ -z "$signoff_status" ] || [ "$signoff_status" = "待签收" ]; then
        add_failure "D13: acceptance-summary.md 签收状态为空或待签收"
    elif [ "$signoff_status" = "拒绝" ]; then
        add_failure "D13: acceptance-summary.md 签收状态为「拒绝」，需用户重新确认或记录处理方案"
    fi
    if [ "$signoff_status" = "确认" ]; then
        if is_placeholder_text "$signoff_time"; then
            add_failure "D13: 签收状态为「确认」时必须填写有效的签收时间"
        else
            signoff_epoch=$(parse_epoch_utc "$signoff_time")
            if [ -z "$signoff_epoch" ]; then
                add_failure "D13: 签收时间必须为有效时间戳"
            fi
        fi
    fi

    qa_release_recommendation=$(extract_report_field "$QA_REPORT" "release_recommendation")
    qa_residual_risk=$(extract_report_field "$QA_REPORT" "residual_risk")
    qa_uncovered_boundary=$(extract_report_field "$QA_REPORT" "uncovered_boundary")
    qa_conditional_release_basis=$(extract_report_field "$QA_REPORT" "conditional_release_basis")
    qa_non_executed_rows=$(extract_non_executed_rows "$QA_REPORT")
    qa_non_executed_count=$(printf '%s\n' "$qa_non_executed_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    acceptance_qa_release=$(extract_report_field "$ACCEPT_SUMMARY" "qa_report_release_recommendation")
    acceptance_release=$(extract_report_field "$ACCEPT_SUMMARY" "acceptance_release_recommendation")
    acceptance_residual_risk=$(extract_report_field "$ACCEPT_SUMMARY" "residual_risk")
    acceptance_uncovered_boundary=$(extract_report_field "$ACCEPT_SUMMARY" "uncovered_boundary")
    acceptance_conditional_release_basis=$(extract_report_field "$ACCEPT_SUMMARY" "conditional_release_basis")
    acceptance_not_executed_reason=$(extract_report_field "$ACCEPT_SUMMARY" "not_executed_reason")
    kickoff_status=$(extract_report_field "$ACCEPT_SUMMARY" "kickoff_status")
    accept_plan_version_ref=$(extract_report_field "$ACCEPT_SUMMARY" "plan_version_ref")
    preflight_evidence_ref=$(extract_report_field "$ACCEPT_SUMMARY" "preflight_evidence_ref")
    environment_ready=$(extract_report_field "$ACCEPT_SUMMARY" "environment_ready")
    dependency_ready=$(extract_report_field "$ACCEPT_SUMMARY" "dependency_ready")
    risk_owner_ready=$(extract_report_field "$ACCEPT_SUMMARY" "risk_owner_ready")
    qa_handoff_ready=$(extract_report_field "$ACCEPT_SUMMARY" "qa_handoff_ready")
    readiness_waiver=$(extract_report_field "$ACCEPT_SUMMARY" "readiness_waiver")
    accept_last_observed_at=$(extract_report_field "$ACCEPT_SUMMARY" "last_observed_at")
    accept_runtime_snapshot=$(extract_report_field "$ACCEPT_SUMMARY" "runtime_snapshot")
    accept_active_blocker=$(extract_report_field "$ACCEPT_SUMMARY" "active_blocker")
    accept_blocker_owner=$(extract_report_field "$ACCEPT_SUMMARY" "blocker_owner")
    accept_takeover_note=$(extract_report_field "$ACCEPT_SUMMARY" "takeover_note")
    accept_decision_basis=$(extract_report_field "$ACCEPT_SUMMARY" "decision_basis")
    accept_current_plan_version_ref=$(extract_report_field "$ACCEPT_SUMMARY" "current_plan_version_ref")
    accept_current_plan_version_value=$(extract_report_field "$ACCEPT_SUMMARY" "current_plan_version_value")
    accept_last_observed_epoch=""
    if [ -z "$qa_release_recommendation" ]; then
        add_failure "D13: qa-report.md 缺少 release_recommendation"
    fi
    if is_placeholder_text "$qa_residual_risk"; then
        add_failure "D13: qa-report.md 缺少 residual_risk"
    fi
    if [ "$acceptance_uncovered_boundary" != "无" ] && is_placeholder_text "$acceptance_uncovered_boundary"; then
        add_failure "D13: acceptance-summary.md 缺少 uncovered_boundary"
    elif [ -n "$qa_uncovered_boundary" ] && [ "$acceptance_uncovered_boundary" != "$qa_uncovered_boundary" ]; then
        add_failure "D13: acceptance-summary.md 的 uncovered_boundary 与 qa-report.md 不一致"
    fi
    if [ "$acceptance_conditional_release_basis" != "无" ] && is_placeholder_text "$acceptance_conditional_release_basis"; then
        add_failure "D13: acceptance-summary.md 缺少 conditional_release_basis"
    elif [ -n "$qa_conditional_release_basis" ] && [ "$acceptance_conditional_release_basis" != "$qa_conditional_release_basis" ]; then
        add_failure "D13: acceptance-summary.md 的 conditional_release_basis 与 qa-report.md 不一致"
    fi
    if [ "$qa_non_executed_count" -gt 0 ]; then
        if [ "$acceptance_not_executed_reason" = "无" ] || is_placeholder_text "$acceptance_not_executed_reason"; then
            add_failure "D13: 存在 QA 非执行项时，acceptance-summary.md 必须承接 not_executed_reason"
        else
            while IFS='|' read -r stage reason; do
                [ -n "$stage" ] || continue
                if ! printf '%s' "$acceptance_not_executed_reason" | grep -qF "$stage"; then
                    add_failure "D13: acceptance-summary.md 的 not_executed_reason 必须承接 ${stage}"
                fi
            done <<< "$qa_non_executed_rows"
        fi
    elif [ "$acceptance_not_executed_reason" != "无" ] && is_placeholder_text "$acceptance_not_executed_reason"; then
        add_failure "D13: acceptance-summary.md 缺少 not_executed_reason"
    fi
    case "$acceptance_qa_release" in
        放行|条件放行|阻塞)
            ;;
        *)
            add_failure "D13: acceptance-summary.md 缺少有效的 qa_report_release_recommendation"
            ;;
    esac
    case "$acceptance_release" in
        放行|条件放行|阻塞)
            ;;
        *)
            add_failure "D13: acceptance-summary.md 缺少有效的 acceptance_release_recommendation"
            ;;
    esac
    case "$business_risk_acceptance_status" in
        接受|拒绝|不适用|待确认)
            ;;
        *)
            add_failure "D13: acceptance-summary.md 缺少有效的 business_risk_acceptance_status"
            ;;
    esac
    if [ -n "$qa_release_recommendation" ] && [ -n "$acceptance_qa_release" ] && [ "$acceptance_qa_release" != "$qa_release_recommendation" ]; then
        add_failure "D13: acceptance-summary.md 的 qa_report_release_recommendation 与 qa-report.md 不一致"
    fi
    if [ -n "$qa_release_recommendation" ] && [ -n "$acceptance_release" ] && release_is_more_lenient_than "$acceptance_release" "$qa_release_recommendation"; then
        add_failure "D13: acceptance-summary.md 的 acceptance_release_recommendation 不得比 qa-report.md 更宽松"
    fi
    if is_placeholder_text "$acceptance_residual_risk"; then
        add_failure "D13: acceptance-summary.md 缺少 residual_risk"
    fi
    if { [ "$acceptance_release" = "条件放行" ] || [ "$qa_release_recommendation" = "条件放行" ]; } && is_placeholder_text "$risk_acceptance_basis"; then
        add_failure "D13: 条件放行时必须记录 risk_acceptance_basis"
    fi
    if [ "$qa_release_recommendation" = "阻塞" ] && [ "$signoff_status" = "确认" ]; then
        add_failure "D13: qa-report.md 建议阻塞时，acceptance-summary.md 不得直接确认签收"
    fi

    case "$kickoff_status" in
        READY|WAIVED|BLOCKED)
            ;;
        *)
            add_failure "D13: acceptance-summary.md 缺少有效的 kickoff_status"
            ;;
    esac
    if ! has_plan_version_ref "$accept_plan_version_ref"; then
        add_failure "D13: acceptance-summary.md 缺少有效的 plan_version_ref"
    else
        validate_anchored_refs_exist "$accept_plan_version_ref" "$PHASE_DIR" "D13: acceptance-summary.md 的 plan_version_ref"
    fi
    if ! printf '%s\n' "$preflight_evidence_ref" | grep -qiE 'preflight-evidence\.md#[^[:space:]]+'; then
        add_failure "D13: acceptance-summary.md 缺少有效的 preflight_evidence_ref"
    else
        validate_anchored_refs_exist "$preflight_evidence_ref" "$PHASE_DIR" "D13: acceptance-summary.md 的 preflight_evidence_ref"
    fi
    for readiness_field in environment_ready dependency_ready risk_owner_ready qa_handoff_ready; do
        readiness_value=$(extract_report_field "$ACCEPT_SUMMARY" "$readiness_field")
        case "$readiness_value" in
            yes|no)
                ;;
            *)
                add_failure "D13: acceptance-summary.md 的 ${readiness_field} 仅允许 yes/no"
                ;;
        esac
    done
    if [ "$kickoff_status" = "READY" ]; then
        [ "$environment_ready" = "yes" ] || add_failure "D13: kickoff_status=READY 时 environment_ready 必须为 yes"
        [ "$dependency_ready" = "yes" ] || add_failure "D13: kickoff_status=READY 时 dependency_ready 必须为 yes"
        [ "$risk_owner_ready" = "yes" ] || add_failure "D13: kickoff_status=READY 时 risk_owner_ready 必须为 yes"
        [ "$qa_handoff_ready" = "yes" ] || add_failure "D13: kickoff_status=READY 时 qa_handoff_ready 必须为 yes"
    fi
    if [ "$kickoff_status" = "WAIVED" ] && is_placeholder_text "$readiness_waiver"; then
        add_failure "D13: kickoff_status=WAIVED 时必须记录 readiness_waiver"
    fi
    if [ "$kickoff_status" = "BLOCKED" ] && [ "$signoff_status" = "确认" ]; then
        add_failure "D13: kickoff_status=BLOCKED 时不得直接确认签收"
    fi

    if is_placeholder_text "$accept_last_observed_at"; then
        add_failure "D13: acceptance-summary.md 缺少 last_observed_at"
    else
        accept_last_observed_epoch=$(parse_epoch_utc "$accept_last_observed_at")
        if [ -z "$accept_last_observed_epoch" ]; then
            add_failure "D13: latest status summary 的 last_observed_at 必须为有效时间戳"
        fi
    fi
    if is_placeholder_text "$accept_runtime_snapshot"; then
        add_failure "D13: acceptance-summary.md 缺少 runtime_snapshot"
    fi
    if [ -z "$accept_active_blocker" ]; then
        add_failure "D13: acceptance-summary.md 缺少 active_blocker"
    fi
    if ! is_explicit_none "$accept_active_blocker"; then
        if is_placeholder_text "$accept_blocker_owner" || is_explicit_none "$accept_blocker_owner"; then
            add_failure "D13: active_blocker 非 无 时，必须填写有效的 blocker_owner"
        fi
    fi
    if is_placeholder_text "$accept_takeover_note"; then
        add_failure "D13: acceptance-summary.md 缺少 takeover_note"
    fi
    if is_placeholder_text "$accept_decision_basis"; then
        add_failure "D13: acceptance-summary.md 缺少 decision_basis"
    else
        validate_runtime_anchor_refs_exist "$accept_decision_basis" "$PHASE_DIR" "D13: acceptance-summary.md 的 decision_basis" "$ALL_UNIT_WORK_DIRS"
    fi
    if ! has_plan_version_ref "$accept_current_plan_version_ref"; then
        add_failure "D13: acceptance-summary.md 缺少有效的 current_plan_version_ref"
    else
        validate_anchored_refs_exist "$accept_current_plan_version_ref" "$PHASE_DIR" "D13: acceptance-summary.md 的 current_plan_version_ref"
    fi
    if is_placeholder_text "$accept_current_plan_version_value"; then
        add_failure "D13: acceptance-summary.md 缺少 current_plan_version_value"
    elif [ -n "$CURRENT_PLAN_VERSION" ] && [ "$accept_current_plan_version_value" != "$CURRENT_PLAN_VERSION" ]; then
        add_failure "D13: acceptance-summary.md 的 current_plan_version_value 与当前 plan.md 不一致（acceptance=${accept_current_plan_version_value}, plan=${CURRENT_PLAN_VERSION}）"
    fi
    if [ "$signoff_status" = "确认" ] && ! is_explicit_none "$accept_active_blocker"; then
        add_failure "D13: sign_off_status=确认 时，latest status summary 的 active_blocker 必须为 无"
    fi

    qa_issue_ids=$(extract_qa_issue_ids "$QA_REPORT")
    acceptance_issue_rows=$(extract_acceptance_issue_rows "$ACCEPT_SUMMARY")
    acceptance_issue_ids=$(printf '%s\n' "$acceptance_issue_rows" | awk -F'|' '{print $1}' | sed '/^$/d' | sort -u || true)
    while IFS= read -r qa_issue_id; do
        [ -n "$qa_issue_id" ] || continue
        if ! printf '%s\n' "$acceptance_issue_ids" | grep -qx "$qa_issue_id"; then
            add_failure "D13: qa-report.md 的问题 ${qa_issue_id} 未在 acceptance-summary.md 已知问题中承接"
        fi
    done <<< "$qa_issue_ids"

    constraint_rows=$(extract_acceptance_constraint_rows "$ACCEPT_SUMMARY")
    constraint_count=$(printf '%s\n' "$constraint_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$constraint_count" -eq 0 ]; then
        if [ "$PRD_CONSTRAINT_COUNT" -gt 0 ]; then
            add_failure "D13: acceptance-summary.md 缺少「前置约束验收状态」章节、内容为空或仅有表头"
        elif ! has_explicit_no_constraints_declaration "$PRD_FILE"; then
            add_failure "D13: acceptance-summary.md 未声明前置约束验收状态，且 PRD 也未显式声明 无前置约束（经评估）"
        fi
    else
        if [ "$PLAN_CONSTRAINT_COUNT" -eq 0 ]; then
            add_failure "D13: plan.md 未解析到「PRD 前置约束映射」数据行，无法核对 acceptance-summary"
        else
            acceptance_constraint_pairs=$(printf '%s\n' "$constraint_rows" | awk -F'|' '
                function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
                {
                    constraint_id = trim($1)
                    constraint_type = trim($2)
                    plan_status = trim($3)
                    preflight_ref = trim($4)
                    test_ref = trim($5)
                    acceptance_result = trim($6)
                    evidence = trim($7)
                    note = trim($8)
                    print constraint_id "|" constraint_type "|" plan_status "|" preflight_ref "|" test_ref
                }
            ' | sed '/^$/d' | sort -u)
            plan_constraint_ids=$(printf '%s\n' "$PLAN_CONSTRAINT_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort -u || true)
            dup_accept_constraint_ids=$(printf '%s\n' "$constraint_rows" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
            if [ -n "$dup_accept_constraint_ids" ]; then
                add_failure "D13: acceptance-summary.md 前置约束验收状态存在重复 Constraint ID：$(printf '%s' "$dup_accept_constraint_ids" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
            fi

            while IFS='|' read -r constraint_id constraint_type plan_status preflight_ref test_ref acceptance_result evidence note; do
                [ -n "$constraint_id" ] || continue

                if ! printf '%s\n' "$constraint_id" | grep -qE '^CON-[0-9]{3,}$'; then
                    add_failure "D13: 前置约束验收状态存在非法 Constraint ID：${constraint_id}"
                fi

                if ! printf '%s\n' "$plan_constraint_ids" | grep -qx "$constraint_id"; then
                    add_failure "D13: ${constraint_id} 未在 plan.md 的「PRD 前置约束映射」中声明"
                fi

                if is_placeholder_text "$constraint_type"; then
                    add_failure "D13: ${constraint_id} 缺少约束类型"
                fi

                case "$plan_status" in
                    MAPPED|VERIFIED)
                        ;;
                    *)
                        add_failure "D13: ${constraint_id} 的 Plan 状态非法（${plan_status:-missing}），仅允许 MAPPED/VERIFIED"
                        ;;
                esac

                if is_placeholder_text "$preflight_ref"; then
                    add_failure "D13: ${constraint_id} 缺少 preflight_ref"
                fi

                normalized_test_ref=$(printf '%s' "$test_ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
                if is_placeholder_text "$normalized_test_ref" && ! printf '%s' "$normalized_test_ref" | grep -qiE '^N/?A$'; then
                    add_failure "D13: ${constraint_id} 缺少 test_ref（可为 N/A，但不能留空）"
                fi

                case "$acceptance_result" in
                    OK|ISSUE|N/A)
                        ;;
                    *)
                        add_failure "D13: ${constraint_id} 的验收结果非法（${acceptance_result:-missing}），仅允许 OK/ISSUE/N/A"
                        ;;
                esac

                if [ "$acceptance_result" = "OK" ]; then
                    if is_placeholder_text "$evidence"; then
                        add_failure "D13: ${constraint_id} 验收结果为 OK，但缺少证据"
                    fi
                else
                    if is_placeholder_text "$note"; then
                        add_failure "D13: ${constraint_id} 验收结果为 ${acceptance_result}，备注必须说明原因"
                    fi
                fi

                matched_plan_row=$(printf '%s\n' "$PLAN_CONSTRAINT_ROWS" | awk -F'|' -v target="$constraint_id" '
                    $1 == target { print; exit }
                ')
                if [ -z "$matched_plan_row" ]; then
                    continue
                fi

                matched_plan_type=$(printf '%s' "$matched_plan_row" | awk -F'|' '{print $2}')
                matched_plan_scope=$(printf '%s' "$matched_plan_row" | awk -F'|' '{print $6}')
                matched_plan_preflight=$(printf '%s' "$matched_plan_row" | awk -F'|' '{print $7}')
                matched_plan_test_ref=$(printf '%s' "$matched_plan_row" | awk -F'|' '{print $8}')
                matched_plan_task=$(printf '%s' "$matched_plan_row" | awk -F'|' '{print $9}')
                matched_plan_status=$(printf '%s' "$matched_plan_row" | awk -F'|' '{print $11}')

                if [ "$constraint_type" != "$matched_plan_type" ]; then
                    add_failure "D13: ${constraint_id} 的类型与 plan.md 不一致（acceptance=${constraint_type}，plan=${matched_plan_type}）"
                fi
                if [ "$plan_status" != "$matched_plan_status" ]; then
                    add_failure "D13: ${constraint_id} 的 Plan 状态与 plan.md 不一致（acceptance=${plan_status}，plan=${matched_plan_status}）"
                fi
                if [ "$preflight_ref" != "$matched_plan_preflight" ]; then
                    add_failure "D13: ${constraint_id} 的 preflight_ref 与 plan.md 不一致（acceptance=${preflight_ref}，plan=${matched_plan_preflight}）"
                fi
                if [ "$test_ref" != "$matched_plan_test_ref" ]; then
                    add_failure "D13: ${constraint_id} 的 test_ref 与 plan.md 不一致（acceptance=${test_ref}，plan=${matched_plan_test_ref}）"
                fi
                if is_placeholder_text "$matched_plan_task" || ! printf '%s\n' "$PLAN_TASK_IDS" | grep -qx "$matched_plan_task"; then
                    add_failure "D13: ${constraint_id} 在 plan.md 中缺少有效映射 Task，无法形成 acceptance 闭环"
                fi
                if is_placeholder_text "$matched_plan_scope" || ! printf '%s' "$matched_plan_scope" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
                    add_failure "D13: ${constraint_id} 在 plan.md 中缺少有效 scope_item_id，无法形成 acceptance 闭环"
                fi
            done <<< "$constraint_rows"

            while IFS='|' read -r plan_constraint_id plan_constraint_type description owner affected_unit scope_id preflight_ref test_ref mapped_task acceptance_evidence plan_status; do
                [ -n "$plan_constraint_id" ] || continue
                plan_pair="${plan_constraint_id}|${plan_constraint_type}|${plan_status}|${preflight_ref}|${test_ref}"
                if ! newline_list_contains_literal "$acceptance_constraint_pairs" "$plan_pair"; then
                    add_failure "D13: plan.md 前置约束 ${plan_constraint_id} 未在 acceptance-summary.md 中按 type/plan_status/preflight_ref/test_ref 完整承接"
                fi
            done <<< "$PLAN_CONSTRAINT_ROWS"
        fi
    fi

    goal_rows=$(extract_goal_closure_rows "$ACCEPT_SUMMARY")
    goal_count=$(printf '%s\n' "$goal_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$goal_count" -eq 0 ]; then
        add_failure "D13: acceptance-summary.md 缺少「目标闭环」章节、内容为空或仅有表头"
    else
        brief_goal_rows=$(extract_brief_goal_rows "$PRD_FILE")
        brief_goal_expected_count=$(printf '%s\n' "$brief_goal_rows" | sed '/^$/d' | wc -l | tr -d ' ')
        phase_goal_text=$(extract_phase_goal_text "$PHASE_PRD_FILE")
        phase_goal_expected_count=0
        goal_row_count=0
        goal_brief_source_count=0
        goal_phase_source_count=0

        if [ "$brief_goal_expected_count" -eq 0 ]; then
            add_failure "D13: brief.md 缺少「目标与成功标准」有效数据，无法校验目标闭环来源"
        fi
        if is_placeholder_text "$phase_goal_text"; then
            add_failure "D13: phase prd.md 缺少有效「阶段目标」，无法校验目标闭环来源"
        else
            phase_goal_expected_count=1
        fi

        goal_has_partial=0
        goal_has_fail=0
        while IFS='|' read -r goal goal_source_ref execution_basis_ref evidence result remaining_gap; do
            [ -n "$goal" ] || continue
            goal_row_count=$((goal_row_count + 1))
            if is_placeholder_text "$goal"; then
                add_failure "D13: 目标闭环缺少 goal"
            fi
            if is_placeholder_text "$goal_source_ref"; then
                add_failure "D13: 目标闭环 ${goal} 缺少 goal_source_ref"
            elif ! goal_source_refs_are_allowed "$goal_source_ref"; then
                add_failure "D13: 目标闭环 ${goal} 的 goal_source_ref 只能引用 brief.md#目标与成功标准 或 prd.md#阶段目标"
            else
                validate_anchored_refs_exist "$goal_source_ref" "$FEATURE_DIR" "D13: 目标闭环 ${goal} 的 goal_source_ref" "$PHASE_DIR"
            fi
            case "$goal_source_ref" in
                *brief.md#目标与成功标准)
                    goal_brief_source_count=$((goal_brief_source_count + 1))
                    ;;
                *prd.md#阶段目标)
                    goal_phase_source_count=$((goal_phase_source_count + 1))
                    ;;
            esac
            if is_placeholder_text "$execution_basis_ref"; then
                add_failure "D13: 目标闭环 ${goal} 缺少 execution_basis_ref"
            elif ! execution_basis_refs_are_allowed "$execution_basis_ref"; then
                add_failure "D13: 目标闭环 ${goal} 的 execution_basis_ref 只能引用 design.md / plan.md / test-cases.md"
            else
                validate_anchored_refs_exist "$execution_basis_ref" "$PHASE_DIR" "D13: 目标闭环 ${goal} 的 execution_basis_ref" "$ALL_UNIT_WORK_DIRS"
            fi
            if is_placeholder_text "$evidence"; then
                add_failure "D13: 目标闭环 ${goal} 缺少 evidence"
            elif ! goal_evidence_refs_are_allowed "$evidence"; then
                add_failure "D13: 目标闭环 ${goal} 的 evidence 只能引用 dev-report.md / qa-report.md / preflight-evidence.md 的可回溯锚点"
            else
                validate_anchored_refs_exist "$evidence" "$PHASE_DIR" "D13: 目标闭环 ${goal} 的 evidence_ref" "$ALL_UNIT_WORK_DIRS"
            fi
            case "$result" in
                已达成)
                    if is_placeholder_text "$remaining_gap" && ! printf '%s\n' "$remaining_gap" | grep -qiE '^(无|none|n/a)$'; then
                        add_failure "D13: 目标闭环 ${goal} 缺少 remaining_gap（可填 无）"
                    fi
                    ;;
                部分达成)
                    goal_has_partial=1
                    if is_placeholder_text "$remaining_gap"; then
                        add_failure "D13: 目标闭环 ${goal} 为部分达成时必须记录 remaining_gap"
                    fi
                    ;;
                未达成)
                    goal_has_fail=1
                    if is_placeholder_text "$remaining_gap"; then
                        add_failure "D13: 目标闭环 ${goal} 为未达成时必须记录 remaining_gap"
                    fi
                    ;;
                *)
                    add_failure "D13: 目标闭环 ${goal} 的 result 非法（${result:-missing}）"
                    ;;
            esac
        done <<< "$goal_rows"

        if [ "$goal_row_count" -ne $((brief_goal_expected_count + phase_goal_expected_count)) ]; then
            add_failure "D13: acceptance-summary.md「目标闭环」行数与 brief/phase 目标数不一致（acceptance=${goal_row_count}, expected=$((brief_goal_expected_count + phase_goal_expected_count))）"
        fi
        if [ "$goal_brief_source_count" -ne "$brief_goal_expected_count" ]; then
            add_failure "D13: brief 目标未完整承接到 acceptance-summary.md「目标闭环」"
        fi
        if [ "$goal_phase_source_count" -ne "$phase_goal_expected_count" ]; then
            add_failure "D13: phase 目标未完整承接到 acceptance-summary.md「目标闭环」"
        fi

        if [ "$goal_has_fail" -eq 1 ] && [ "$signoff_status" = "确认" ]; then
            add_failure "D13: 存在未达成目标时不得确认签收"
        fi
        if [ "$goal_has_partial" -eq 1 ] && [ "$acceptance_release" = "放行" ]; then
            add_failure "D13: 存在部分达成目标时，acceptance_release_recommendation 不能为 放行"
        fi
        if [ "$goal_has_fail" -eq 1 ] && [ "$acceptance_release" = "放行" ]; then
            add_failure "D13: 存在未达成目标时，acceptance_release_recommendation 不能为 放行"
        fi
        if [ "$goal_has_partial" -eq 1 ] && is_placeholder_text "$risk_acceptance_basis"; then
            add_failure "D13: 存在部分达成目标时，必须记录 risk_acceptance_basis"
        fi
    fi

    if [ -n "$signoff_epoch" ]; then
        if [ -n "$accept_last_observed_epoch" ] && [ "$signoff_epoch" -lt "$accept_last_observed_epoch" ]; then
            add_failure "D13: 签收时间早于 latest status summary 的 last_observed_at"
        fi
        if [ "$LATEST_PROVING_EPOCH" -gt 0 ] && [ "$signoff_epoch" -lt "$LATEST_PROVING_EPOCH" ]; then
            add_failure "D13: 签收时间早于最新 proving_command_executed_at，不能复用旧 proving 结果签收"
        fi
        if [ "$LATEST_TEST_EPOCH" -gt 0 ] && [ "$signoff_epoch" -lt "$LATEST_TEST_EPOCH" ]; then
            add_failure "D13: 签收时间早于最新 TEST_EXECUTED_AT，不能复用旧全量测试结果签收"
        fi
        if [ "$LATEST_FIX_EPOCH" -gt 0 ] && [ "$signoff_epoch" -lt "$LATEST_FIX_EPOCH" ]; then
            add_failure "D13: 签收时间早于最近 fix 报告，必须在修复与复审完成后重新签收"
        fi
    fi
    if [ -n "$accept_last_observed_epoch" ]; then
        if [ "$LATEST_PROVING_EPOCH" -gt 0 ] && [ "$accept_last_observed_epoch" -lt "$LATEST_PROVING_EPOCH" ]; then
            add_failure "D13: latest status summary 的 last_observed_at 早于最新 proving_command_executed_at"
        fi
        if [ "$LATEST_TEST_EPOCH" -gt 0 ] && [ "$accept_last_observed_epoch" -lt "$LATEST_TEST_EPOCH" ]; then
            add_failure "D13: latest status summary 的 last_observed_at 早于最新 TEST_EXECUTED_AT"
        fi
        if [ "$LATEST_FIX_EPOCH" -gt 0 ] && [ "$accept_last_observed_epoch" -lt "$LATEST_FIX_EPOCH" ]; then
            add_failure "D13: latest status summary 的 last_observed_at 早于最近 fix 报告"
        fi
    fi
fi

# --- D15: 审查轮次记录校验（存在 fix-N.md 且报告包含轮次记录表时，校验 ≥2 轮） ---

if [ -n "$PHASE_DIR" ] && [ -d "$PHASE_DIR" ]; then
    review_reround_detected=0
    for review_report in "$CR_REPORT" "$QA_REPORT"; do
        [ -f "$review_report" ] || continue
        local_label=$(basename "$review_report" .md)
        round_rows=$(extract_review_round_count "$review_report")

        if [ "$round_rows" -ge 2 ]; then
            review_reround_detected=1
        fi

        if [ "$FIX_COUNT" -ge 1 ]; then
            if [ "$round_rows" -lt 2 ]; then
                add_failure "D15: [${local_label}] 存在 ${FIX_COUNT} 个 fix 报告，但审查轮次记录不足 2 轮（当前 ${round_rows} 轮）"
            fi
        elif [ "$round_rows" -ge 2 ]; then
            add_failure "D15: [${local_label}] 已出现复审轮次（${round_rows} 轮），但 Phase 缺少 fix-N.md，不能省略修复工件"
        fi
    done

    if [ "$review_reround_detected" -eq 1 ] && [ "$FIX_COUNT" -eq 0 ]; then
        add_failure "D15: 审查报告显示已发生复审，但未发现任何 fix-N.md，无法证明修复链路完整"
    fi
fi

# --- 输出结果 ---

output_failures "项目经理交付完整性检查未通过" "$PHASE_DIR"
emit_decision_json "allow" "pass: delivery-owner acceptance-summary contract satisfied"
exit 0
