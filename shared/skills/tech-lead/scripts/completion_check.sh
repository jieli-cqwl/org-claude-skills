#!/bin/bash
# 技术负责人实施计划完整性自动检查脚本
# 执行时机: PostToolUse(Edit|Write) 收口门禁
# 功能: standard-chain canonical lane 优先；legacy markdown 仅兼容旧流程

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
tech-lead/completion_check.sh — 技术负责人实施计划完整性自动检查脚本
执行时机: PostToolUse(Edit|Write) 收口门禁
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
# shellcheck source=/dev/null
source "$HOOKS_LIB/constraint.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/../../delivery-owner/scripts" && pwd)/phase3-grade-matrix.sh"
hook_init

normalize_hook_path() {
    local path_value="$1"
    path_value="${path_value#${REPO_ROOT}/}"
    path_value="${path_value#./}"
    printf '%s\n' "$path_value"
}

# standard-chain 计划收口只接受 canonical JSON 工件；命中时直接委托 phase validator。
run_canonical_tech_lead_gate() {
    local target phase_dir validator gate_output
    if [ -z "${TOOL_FILE_PATH:-}" ]; then
        return 1
    fi
    target=$(normalize_hook_path "$TOOL_FILE_PATH")
    if ! printf '%s' "$target" | grep -qE '^docs/[^/"[:space:]*{}]+/phase-[0-9]+/(plan|tasks)\.json$'; then
        return 1
    fi
    [ -n "$target" ] || return 1

    phase_dir=$(dirname "$target")
    validator="$(cd "$REPO_ROOT" 2>/dev/null && pwd)/tools/community/validate_standard_chain_phase.py"
    gate_output="/tmp/org_tech_lead_canonical.out"
    if [ ! -f "$phase_dir/plan.json" ]; then
        add_failure "缺少 canonical plan.json：$phase_dir/plan.json"
        output_failures "技术负责人实施计划完整性检查未通过（canonical）" "$phase_dir"
    fi
    if [ ! -f "$phase_dir/tasks.json" ]; then
        add_failure "缺少 canonical tasks.json：$phase_dir/tasks.json"
        output_failures "技术负责人实施计划完整性检查未通过（canonical）" "$phase_dir"
    fi
    if [ ! -f "$phase_dir/design.json" ]; then
        add_failure "缺少 canonical design.json：$phase_dir/design.json"
        output_failures "技术负责人实施计划完整性检查未通过（canonical）" "$phase_dir"
    fi
    if ! find "$phase_dir" -type f -path '*/unit-*/test-cases.json' -print -quit 2>/dev/null | grep -q .; then
        add_failure "缺少 canonical test-cases.json：$phase_dir/unit-*/test-cases.json"
        output_failures "技术负责人实施计划完整性检查未通过（canonical）" "$phase_dir"
    fi
    if [ ! -x "$validator" ] && [ ! -f "$validator" ]; then
        add_failure "缺少 standard-chain phase validator：$validator"
        output_failures "技术负责人实施计划完整性检查未通过（canonical）" "$target"
    fi
    if ! python3 "$validator" --phase-dir "$phase_dir" --enforce-canonical-only >"$gate_output" 2>&1; then
        cat "$gate_output" >&2 || true
        add_failure "canonical tech-lead phase gate 未通过：$phase_dir"
        output_failures "技术负责人实施计划完整性检查未通过（canonical）" "$phase_dir"
    fi

    emit_decision_json "allow" "standard-chain canonical tech-lead phase gate passed"
    exit 0
}

run_canonical_tech_lead_gate || true

if [ "${ORG_ENABLE_LEGACY_MARKDOWN_HOOKS:-0}" != "1" ]; then
    if { [ "${TOOL_NAME:-}" = "Write" ] || [ "${TOOL_NAME:-}" = "Edit" ]; } && [ -z "${TOOL_FILE_PATH:-}" ]; then
        add_failure "hook payload 缺少 tool_input.file_path，无法确认是否命中 canonical tech-lead gate"
        output_failures "技术负责人实施计划完整性检查未通过（canonical）" ""
    fi
    emit_decision_json "allow" "skip: legacy markdown tech-lead hook disabled; standard-chain uses canonical JSON artifacts"
    exit 0
fi

# --- Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/(unit-[0-9]+/)?)?(plan\.md|design-review-[0-9]+\.md)'
resolve_feature_dir "docs/*/phase-*/plan.md" "$TRANSCRIPT_PATTERN" "plan.md" "docs/*/phase-*"
output_failures "技术负责人实施计划完整性检查未通过" ""

# --- brief.md 驱动工作区定位（Phase 级：plan.md + design.md 在 Phase 目录） ---
resolve_phase_work_dir "$FEATURE_DIR" "plan.md"
WORK_DIR="$PHASE_WORK_DIR"

PLAN_FILE="$WORK_DIR/plan.md"
PRD_FILE="$FEATURE_DIR/brief.md"
PHASE_PRD_FILE="$WORK_DIR/prd.md"
UNITS_DIR="$WORK_DIR/units"
PHASE_DIR="$WORK_DIR"
DESIGN_FILE="$WORK_DIR/design.md"

should_run_gate() {
    if [ -z "${TOOL_NAME:-}" ]; then
        return 0
    fi
    if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
        return 0
    fi
    if [ -n "$TOOL_FILE_PATH" ] && [ "$(basename "$TOOL_FILE_PATH")" != "plan.md" ]; then
        return 1
    fi

    local confirm_section confirm_status
    confirm_section=$(extract_markdown_section "$PLAN_FILE" "## 用户确认记录")
    if [ -n "$confirm_section" ]; then
        confirm_status=$(printf '%s\n' "$confirm_section" \
            | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*确认状态[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
            | head -1 \
            | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if [ "$confirm_status" = "确认" ]; then
            return 0
        fi
    fi

    if grep -qF "## 独立审查收敛" "$PLAN_FILE" || grep -qF "## 交接项" "$PLAN_FILE"; then
        return 0
    fi

    return 1
}

if ! should_run_gate; then
    exit 0
fi




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
            rollback_ref = trim($7)
            status = trim($8)

            if (scope_id == "" || scope_id == "scope_item_id" || scope_id ~ /^-+$/) next
            gsub(/Task[ ]+/, "Task-", mapped_task)
            print scope_id "|" change_type "|" risk "|" mapped_task "|" test_ref "|" rollback_ref "|" status
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

trim() {
    printf '%s' "${1:-}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

normalize_goal_text() {
    printf '%s' "$(trim "${1:-}")" | sed -E 's/[[:space:]]+/ /g'
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

extract_ref_anchor() {
    local ref="$1"
    if [ "${ref#*#}" = "$ref" ]; then
        printf '%s' ""
        return 0
    fi
    printf '%s' "${ref#*#}"
}

extract_anchored_refs() {
    local value="$1"
    printf '%s\n' "$value" | grep -oE '[^[:space:]+,`|]+\.md#[^[:space:]+,`|]+' || true
}

normalize_anchor_slug() {
    local value="$1"
    value=$(trim "$value")
    value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    value=$(printf '%s' "$value" | sed -E 's/[`"'\''‘’“”]//g; s/[:：/]+/-/g; s/[(){}\[\],.;!?]+/-/g; s/[[:space:]_]+/-/g; s/-+/-/g; s/^-+//; s/-+$//')
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
    local file="$1" anchor="$2"
    local anchor_slug
    anchor_slug=$(normalize_anchor_slug "$anchor")

    case "$anchor_slug" in
        task-*)
            grep -qiE "^###[[:space:]]*$(printf '%s' "$anchor" | sed -E 's/^task-/Task-/I')([:[:space:]]|$)" "$file"
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

is_current_plan_version_ref() {
    local ref="$1" ref_file expected_plan_file ref_anchor
    ref_file=$(resolve_ref_file_path "$ref" "$PHASE_DIR")
    expected_plan_file=$(resolve_ref_file_path "plan.md#计划版本" "$PHASE_DIR")
    ref_anchor=$(extract_ref_anchor "$ref")
    [ "$(basename "$ref_file")" = "plan.md" ] || return 1
    [ "$ref_anchor" = "计划版本" ] || return 1
    [ "$ref_file" = "$expected_plan_file" ]
}

is_plan_task_ref() {
    local ref="$1" ref_file ref_anchor
    ref_file=$(resolve_ref_file_path "$ref" "$PHASE_DIR")
    ref_anchor=$(extract_ref_anchor "$ref")
    [ "$(basename "$ref_file")" = "plan.md" ] || return 1
    printf '%s' "$ref_anchor" | grep -qiE '^task-[0-9]+$'
}

validate_anchored_refs_exist() {
    local value="$1" base_dir="$2" label="$3" fallback_dirs="${4:-}"
    local ref ref_file ref_anchor fallback_file candidate_dir

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
            continue
        fi

        if is_current_plan_version_ref "$ref" && ! grep -qF "## 计划版本" "$ref_file"; then
            add_failure "${label} 引用的 plan.md#计划版本 不存在：${ref}"
            continue
        fi

        if is_plan_task_ref "$ref"; then
            if ! grep -qiE "^###[[:space:]]*$(printf '%s' "$ref_anchor" | sed -E 's/^task-/Task-/I')([:[:space:]]|$)" "$ref_file"; then
                add_failure "${label} 引用的 Task 锚点不存在：${ref}"
            fi
        fi
    done <<< "$(extract_anchored_refs "$value")"
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

extract_phase_goal_rows() {
    local prd_file="$1"
    local goal_section table_rows bullet_rows paragraph_row
    goal_section=$(extract_markdown_section "$prd_file" "## 阶段目标")

    table_rows=$(printf '%s\n' "$goal_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            c1 = trim($2)
            if (c1 == "" || c1 == "阶段目标" || c1 == "目标" || c1 ~ /^-+$/) next
            print c1
        }
    ')
    if [ -n "$(printf '%s\n' "$table_rows" | sed '/^$/d')" ]; then
        printf '%s\n' "$table_rows"
        return 0
    fi

    bullet_rows=$(printf '%s\n' "$goal_section" | sed -nE 's/^[[:space:]]*[-*][[:space:]]+//p')
    if [ -n "$(printf '%s\n' "$bullet_rows" | sed '/^$/d')" ]; then
        printf '%s\n' "$bullet_rows"
        return 0
    fi

    paragraph_row=$(printf '%s\n' "$goal_section" | sed '/^$/d' | sed '/^## /d' | paste -sd ' ' -)
    if [ -n "$(trim "$paragraph_row")" ]; then
        printf '%s\n' "$paragraph_row"
    fi
}

find_matching_goal_in_list() {
    local goals="$1" target="$2"
    local normalized_target candidate
    normalized_target=$(normalize_goal_text "$target")

    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if [ "$(normalize_goal_text "$candidate")" = "$normalized_target" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done <<< "$goals"

    return 1
}

extract_goal_fidelity_rows() {
    local plan_file="$1"
    local goal_section
    goal_section=$(extract_markdown_section "$plan_file" "## 目标闭环与执行度量")
    printf '%s\n' "$goal_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            goal = trim($2)
            goal_source_ref = trim($3)
            task_ref = trim($4)
            execution_basis_ref = trim($5)
            success_signal = trim($6)
            baseline = trim($7)
            guardrail = trim($8)
            note = trim($9)
            if (goal == "" || goal == "目标" || goal ~ /^-+$/) next
            print goal "|" goal_source_ref "|" task_ref "|" execution_basis_ref "|" success_signal "|" baseline "|" guardrail "|" note
        }
    '
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
            *design.md#*|*test-cases.md#*|*plan.md#Task-*|*plan.md#task-*)
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

validate_goal_fidelity_review() {
    local goal_section goal_rows goal_row_count
    local brief_goal_rows brief_goal_texts brief_goal_count phase_goal_rows phase_goal_count
    local matched_brief_goals matched_phase_goals brief_source_seen phase_source_seen
    local goal goal_source_ref task_ref execution_basis_ref success_signal baseline guardrail note task_targets matched_goal

    goal_section=$(extract_markdown_section "$PLAN_FILE" "## 目标闭环与执行度量")
    goal_rows=$(extract_goal_fidelity_rows "$PLAN_FILE")
    goal_row_count=$(printf '%s\n' "$goal_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$goal_row_count" -eq 0 ]; then
        add_failure "T2.3: plan.md「目标闭环与执行度量」缺少数据行，无法完成 goal_fidelity_review"
        return 0
    fi

    brief_goal_rows=$(extract_brief_goal_rows "$PRD_FILE")
    brief_goal_count=$(printf '%s\n' "$brief_goal_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    brief_goal_texts=$(printf '%s\n' "$brief_goal_rows" | awk -F'|' '{print $1}')
    phase_goal_rows=$(extract_phase_goal_rows "$PHASE_PRD_FILE")
    phase_goal_count=$(printf '%s\n' "$phase_goal_rows" | sed '/^$/d' | wc -l | tr -d ' ')

    matched_brief_goals=""
    matched_phase_goals=""
    brief_source_seen=0
    phase_source_seen=0
    while IFS='|' read -r goal goal_source_ref task_ref execution_basis_ref success_signal baseline guardrail note; do
        [ -n "$goal" ] || continue

        if is_placeholder_text "$goal"; then
            add_failure "T2.3: 目标闭环与执行度量存在缺少 goal 的数据行"
        fi
        if is_placeholder_text "$goal_source_ref"; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 缺少 goal_source_ref"
        elif ! goal_source_refs_are_allowed "$goal_source_ref"; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 的 goal_source_ref 只能引用 brief.md#目标与成功标准 或 prd.md#阶段目标"
        else
            validate_anchored_refs_exist "$goal_source_ref" "$FEATURE_DIR" "T2.3: 目标闭环与执行度量 ${goal} 的 goal_source_ref" "$PHASE_DIR"
            if printf '%s\n' "$goal_source_ref" | grep -q 'brief.md#目标与成功标准'; then
                brief_source_seen=1
                if [ "$brief_goal_count" -gt 1 ]; then
                    matched_goal=$(find_matching_goal_in_list "$brief_goal_texts" "$goal" || true)
                    if [ -z "$matched_goal" ]; then
                        add_failure "T2.3: 目标闭环与执行度量 ${goal} 未对应任何 brief 上游目标；存在多个 brief 目标时必须逐项承接"
                    else
                        matched_brief_goals="${matched_brief_goals}${matched_brief_goals:+
}${matched_goal}"
                    fi
                fi
            fi
            if printf '%s\n' "$goal_source_ref" | grep -q 'prd.md#阶段目标'; then
                phase_source_seen=1
                if [ "$phase_goal_count" -gt 1 ]; then
                    matched_goal=$(find_matching_goal_in_list "$phase_goal_rows" "$goal" || true)
                    if [ -z "$matched_goal" ]; then
                        add_failure "T2.3: 目标闭环与执行度量 ${goal} 未对应任何 phase 上游目标；存在多个 phase 目标时必须逐项承接"
                    else
                        matched_phase_goals="${matched_phase_goals}${matched_phase_goals:+
}${matched_goal}"
                    fi
                fi
            fi
        fi

        task_targets=$(printf '%s\n' "$task_ref" | grep -oE 'Task-[0-9]+' | sort -u || true)
        if [ -z "$task_targets" ]; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 缺少有效的承接 Task"
        else
            while IFS= read -r task_id; do
                [ -n "$task_id" ] || continue
                if ! printf '%s\n' "$TASK_IDS" | grep -qx "$task_id"; then
                    add_failure "T2.3: 目标闭环与执行度量 ${goal} 引用了未定义 Task：${task_id}"
                fi
            done <<< "$task_targets"
        fi

        if is_placeholder_text "$execution_basis_ref"; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 缺少 execution_basis_ref"
        elif ! execution_basis_refs_are_allowed "$execution_basis_ref"; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 的 execution_basis_ref 只能引用 design.md / test-cases.md / plan.md#Task-N / plan.md#计划版本"
        else
            validate_anchored_refs_exist "$execution_basis_ref" "$PHASE_DIR" "T2.3: 目标闭环与执行度量 ${goal} 的 execution_basis_ref" "$UNIT_WORK_DIRS"
        fi

        if is_placeholder_text "$success_signal" || [ "$success_signal" = "无" ]; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 缺少成功信号"
        fi
        if is_placeholder_text "$baseline" || [ "$baseline" = "无" ]; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 缺少基线"
        fi
        if is_placeholder_text "$guardrail" || [ "$guardrail" = "无" ]; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 缺少护栏"
        fi
        if is_placeholder_text "$note"; then
            add_failure "T2.3: 目标闭环与执行度量 ${goal} 缺少说明"
        fi
    done <<< "$goal_rows"

    if [ "$brief_goal_count" -eq 0 ]; then
        add_failure "T2.3: brief.md 缺少「目标与成功标准」有效数据，无法校验 goal_fidelity_review"
    elif [ "$brief_goal_count" -eq 1 ]; then
        if [ "$brief_source_seen" -eq 0 ]; then
            add_failure "T2.3: brief.md#目标与成功标准 未在 plan.md「目标闭环与执行度量」中承接"
        fi
    else
        while IFS='|' read -r brief_goal _success_standard; do
            [ -n "$brief_goal" ] || continue
            if ! newline_list_contains_literal "$matched_brief_goals" "$brief_goal"; then
                add_failure "T2.3: brief 目标未完整承接到 plan.md「目标闭环与执行度量」：${brief_goal}"
            fi
        done <<< "$brief_goal_rows"
    fi

    if [ "$phase_goal_count" -eq 0 ]; then
        add_failure "T2.3: phase prd.md 缺少有效「阶段目标」，无法校验 goal_fidelity_review"
    elif [ "$phase_goal_count" -eq 1 ]; then
        if [ "$phase_source_seen" -eq 0 ]; then
            add_failure "T2.3: prd.md#阶段目标 未在 plan.md「目标闭环与执行度量」中承接"
        fi
    else
        while IFS= read -r phase_goal; do
            [ -n "$phase_goal" ] || continue
            if ! newline_list_contains_literal "$matched_phase_goals" "$phase_goal"; then
                add_failure "T2.3: phase 目标未完整承接到 plan.md「目标闭环与执行度量」：${phase_goal}"
            fi
        done <<< "$phase_goal_rows"
    fi
}

task_requires_metric_guardrail() {
    local task_type="$1" task_block="$2"
    if [ "$task_type" = "探索" ]; then
        return 0
    fi

    printf '%s\n' "$task_block" | grep -qiE '优化|重构|性能|调优|治理|迁移|压测'
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

contains_mock_only_acceptance() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE 'mock-only|仅依赖[[:space:]]*Mock|仅靠[[:space:]]*Mock|最终验收允许.{0,20}Mock|允许使用[[:space:]]*Mock[[:space:]]*作为|允许.{0,20}Mock.{0,20}(作为|充当)|Mock.{0,20}(作为|充当).{0,20}(完成证据|验收证据)'
}

is_obviously_non_verifying_command() {
    local value="$1"
    printf '%s\n' "$value" | grep -qiE '^[[:space:]]*(echo|printf|true|:|pwd|ls|cat|grep|rg|sed|awk|head|tail)([[:space:];]|$)'
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

extract_planning_mode() {
    local plan_file="$1"
    local planning_section line value

    planning_section=$(extract_markdown_section "$plan_file" "## 计划模式")
    line=$(printf '%s\n' "$planning_section" \
        | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*计划模式[[:space:]]*[:：][[:space:]]*(.*)$/\1/p' \
        | head -1)
    value=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    if printf '%s' "$value" | grep -qE '[|/]'; then
        printf '%s' ""
        return 0
    fi
    if printf '%s' "$value" | grep -qE '\{.*\}'; then
        printf '%s' ""
        return 0
    fi

    case "$value" in
        标准实施|探索优先)
            printf '%s' "$value"
            ;;
        *)
            printf '%s' ""
            ;;
    esac
}

extract_planning_section_field() {
    local plan_file="$1" field_name="$2"
    local planning_section line value

    planning_section=$(extract_markdown_section "$plan_file" "## 计划模式")
    line=$(printf '%s\n' "$planning_section" \
        | sed -nE "s/^[[:space:]]*[-*]?[[:space:]]*${field_name}[[:space:]]*[:：][[:space:]]*(.*)$/\\1/p" \
        | head -1)
    value=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    if is_placeholder_text "$value"; then
        printf '%s' ""
        return 0
    fi

    printf '%s' "$value"
}

extract_design_decision_status() {
    local plan_file="$1"
    extract_planning_section_field "$plan_file" "设计决策状态"
}

extract_replan_field_value() {
    local replan_section="$1" field_name="$2"
    local line value

    line=$(printf '%s\n' "$replan_section" \
        | sed -nE "s/^[[:space:]]*[-*]?[[:space:]]*${field_name}[[:space:]]*[:：][[:space:]]*(.*)$/\\1/p" \
        | head -1)
    value=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    if is_placeholder_text "$value"; then
        printf '%s' ""
        return 0
    fi

    printf '%s' "$value"
}

extract_replan_unlocked_task_ids() {
    local replan_section="$1"
    local unlocked_value

    unlocked_value=$(extract_replan_field_value "$replan_section" "当前已解锁批次")
    printf '%s\n' "$unlocked_value" | grep -oE 'Task-[0-9]+' | sort -u || true
}

extract_plan_version() {
    local plan_file="$1"
    local version_section version

    version_section=$(extract_markdown_section "$plan_file" "## 计划版本")
    version=$(printf '%s\n' "$version_section" \
        | sed -nE 's/^[[:space:]]*[-*]?[[:space:]]*plan_version[[:space:]]*:[[:space:]]*(.*)$/\1/p' \
        | head -1 \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    printf '%s' "$version"
}

extract_plan_revision_rows() {
    local plan_file="$1"
    local revision_section

    revision_section=$(extract_markdown_section "$plan_file" "## 计划修订记录")
    printf '%s\n' "$revision_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            version = trim($2)
            trigger_reason = trim($3)
            summary = trim($4)
            reconfirmed = trim($5)

            if (version == "" || version == "版本" || version == "plan_version" || version ~ /^-+$/) next
            print version "|" trigger_reason "|" summary "|" reconfirmed
        }
    '
}

validate_plan_revision_rows() {
    local plan_file="$1"
    local revision_rows revision_count version trigger_reason summary reconfirmed

    revision_rows=$(extract_plan_revision_rows "$plan_file")
    revision_count=$(printf '%s\n' "$revision_rows" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$revision_count" -eq 0 ]; then
        add_failure "T2.2: 计划修订记录缺少有效数据行"
        return 0
    fi

    while IFS='|' read -r version trigger_reason summary reconfirmed; do
        [ -n "$version" ] || continue

        if is_placeholder_text "$version" || is_placeholder_text "$trigger_reason" || is_placeholder_text "$summary" || is_placeholder_text "$reconfirmed"; then
            add_failure "T2.2: 计划修订记录存在占位或空字段（version=${version:-<empty>}）"
            continue
        fi
        if ! printf '%s' "$reconfirmed" | grep -qE '^(是|否)$'; then
            add_failure "T2.2: 计划修订记录的「是否已重新确认」仅允许填写 是/否（version=${version}）"
        fi
    done <<< "$revision_rows"
}

validate_plan_version_truth_source() {
    local plan_file="$1"
    local plan_version revision_rows latest_revision_version revision_versions

    plan_version=$(extract_plan_version "$plan_file")
    if ! printf '%s' "$plan_version" | grep -qE '^v[0-9]+$'; then
        add_failure "T2.2: plan.md 缺少有效的 plan_version（仅允许 v1 / v2 ...）"
        return 0
    fi

    revision_rows=$(extract_plan_revision_rows "$plan_file")
    revision_versions=$(printf '%s\n' "$revision_rows" | awk -F'|' '{print $1}' | sed '/^$/d')
    latest_revision_version=$(printf '%s\n' "$revision_versions" | tail -1)

    if [ -z "$latest_revision_version" ]; then
        add_failure "T2.2: 计划修订记录缺少可解析的版本行"
        return 0
    fi

    if ! printf '%s\n' "$revision_versions" | grep -qx "$plan_version"; then
        add_failure "T2.2: plan_version=${plan_version} 未在计划修订记录中声明"
    fi
    if [ "$plan_version" != "$latest_revision_version" ]; then
        add_failure "T2.2: plan_version=${plan_version} 必须与计划修订记录中的最新版本一致（latest=${latest_revision_version}）"
    fi
}

has_residual_draft_markers() {
    local plan_file="$1"

    if grep -qiE '(Traceability Draft Agent|Task Decomposition Draft Agent|Evidence Field Draft Agent|草稿回收记录|RECOVERED|冻结版本锚点|待收敛|未收敛|候选追踪链|候选 Task 列表|候选字段|草稿 agent)' "$plan_file"; then
        return 0
    fi

    return 1
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
        if printf '%s\n' "$line" | grep -qiE '不可豁免|不得豁免|non-waivable|not waivable'; then
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
    local unit requirement_type requirement_ref _requirement_desc scope_id design_ref status task_ref test_ref _impact coverage_status design_status

    design_rows=$(extract_design_coverage_rows "$design_file")
    design_keys=$(build_design_coverage_keys "$design_file")
    plan_keys=$(build_plan_matrix_keys "$matrix_section")

    while IFS='|' read -r unit requirement_type requirement_ref _requirement_desc scope_id design_ref status; do
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
    while IFS='|' read -r unit requirement_type requirement_ref _requirement_desc scope_id design_ref task_ref test_ref _impact coverage_status; do
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

# T1: plan.md 存在且非空
if [ ! -f "$PLAN_FILE" ]; then
    add_failure "T1: plan.md 不存在：$PLAN_FILE"
elif [ ! -s "$PLAN_FILE" ]; then
    add_failure "T1: plan.md 为空：$PLAN_FILE"
fi

# T0: 前置输入存在性校验（brief.md + units/ + design.md）
if [ ! -f "$PRD_FILE" ]; then
    add_failure "T0: 缺少前置文档 brief.md：$PRD_FILE"
elif [ ! -s "$PRD_FILE" ]; then
    add_failure "T0: 前置文档 brief.md 为空：$PRD_FILE"
fi

if [ ! -f "$PHASE_PRD_FILE" ]; then
    add_failure "T0: 缺少前置文档 phase prd.md：$PHASE_PRD_FILE"
elif [ ! -s "$PHASE_PRD_FILE" ]; then
    add_failure "T0: 前置文档 phase prd.md 为空：$PHASE_PRD_FILE"
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
UNIT_WORK_DIRS=$(printf '%s\n' "$UNIT_TC_FILES" | while IFS= read -r tc_file; do
    [ -n "$tc_file" ] || continue
    dirname "$tc_file"
done | sed '/^$/d' | sort -u)
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
    "## 计划模式"
    "## Design 评审结论"
    "## PRD 前置约束映射"
    "## PRD / Design 覆盖矩阵|## PRD 覆盖矩阵"
    "## Scope Freeze 与映射矩阵"
    "## 目标闭环与执行度量"
    "## Task 清单|## Task 列表"
    "## 依赖关系"
    "## 并行策略|## 执行策略"
    "## 计划版本"
    "## 计划修订记录"
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

# T2.2: 计划模式与再计划规则
PLANNING_MODE=$(extract_planning_mode "$PLAN_FILE")
if [ -z "$PLANNING_MODE" ]; then
    add_failure "T2.2: plan.md 缺少有效的计划模式（仅允许 标准实施 / 探索优先）"
fi

DESIGN_DECISION_STATUS=$(extract_design_decision_status "$PLAN_FILE")
if [ "$DESIGN_DECISION_STATUS" != "已收口" ]; then
    add_failure "T2.2: 设计决策状态必须为「已收口」，未收口设计应回退 /design"
fi

PLAN_REVISION_SECTION=$(extract_markdown_section "$PLAN_FILE" "## 计划修订记录")
if [ -z "$PLAN_REVISION_SECTION" ]; then
    add_failure "T2.2: plan.md 缺少「计划修订记录」章节"
else
    validate_plan_revision_rows "$PLAN_FILE"
fi
validate_plan_version_truth_source "$PLAN_FILE"

if has_residual_draft_markers "$PLAN_FILE"; then
    add_failure "T2.1: 最终 plan.md 不得保留草稿 agent 过程痕迹、候选字段或未收敛标识"
fi

REPLAN_SECTION=$(extract_markdown_section "$PLAN_FILE" "## 再计划与解锁规则")
UNLOCKED_TASK_IDS=""
if [ "$PLANNING_MODE" = "探索优先" ]; then
    if [ -z "$REPLAN_SECTION" ]; then
        add_failure "T2.2: 探索优先模式缺少「再计划与解锁规则」章节"
    else
        replan_required_fields="当前已解锁批次
再计划触发条件
必须回到用户确认的条件
停止条件
解锁方式"
        while IFS= read -r field_name; do
            [ -n "$field_name" ] || continue
            field_value=$(extract_replan_field_value "$REPLAN_SECTION" "$field_name")
            if [ -z "$field_value" ]; then
                add_failure "T2.2: 探索优先模式缺少有效的 ${field_name}"
            fi
        done <<< "$replan_required_fields"

        UNLOCKED_TASK_IDS=$(extract_replan_unlocked_task_ids "$REPLAN_SECTION")
        if [ -z "$UNLOCKED_TASK_IDS" ]; then
            add_failure "T2.2: 探索优先模式的当前已解锁批次未声明任何有效 Task"
        fi
    fi
fi

# T3-T5: Task 结构验证（逐 Task 强校验）
PLAN_MATRIX_SECTION=$(extract_plan_matrix_section "$PLAN_FILE")
PLAN_MATRIX_ROWS=$(printf '%s\n' "$PLAN_MATRIX_SECTION" | grep -E '^\|' || true)

TASK_IDS=$(sed -nE 's/^### (Task-[0-9]+).*/\1/p' "$PLAN_FILE")
TASK_COUNT=$(printf '%s\n' "$TASK_IDS" | sed '/^$/d' | wc -l | tr -d ' ')
TASK_SCOPE_PAIRS=""
TASK_CONSTRAINT_PAIRS=""
EXPLORATION_TASK_COUNT=0
if [ "$TASK_COUNT" -eq 0 ]; then
    add_failure "T3: plan.md 未解析到任何 Task（需包含 ### Task-N 标题）"
else
    while IFS= read -r task_id; do
        [ -n "$task_id" ] || continue
        TASK_BLOCK=$(extract_task_block "$PLAN_FILE" "$task_id")

        task_block_has_field "$TASK_BLOCK" '文件|file_path' \
            || add_failure "T3: ${task_id} 缺少 文件/file_path 字段"
        task_block_has_field "$TASK_BLOCK" 'task_type' \
            || add_failure "T3: ${task_id} 缺少 task_type 字段"

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
        task_block_has_field "$TASK_BLOCK" 'proving_command' \
            || add_failure "T4: ${task_id} 缺少 proving_command 字段"
        task_block_has_field "$TASK_BLOCK" 'real_dependency_note' \
            || add_failure "T4: ${task_id} 缺少 real_dependency_note 字段"
        task_block_has_field "$TASK_BLOCK" 'evidence_target' \
            || add_failure "T4: ${task_id} 缺少 evidence_target 字段"
        task_block_has_field "$TASK_BLOCK" 'mock_boundary_note' \
            || add_failure "T4: ${task_id} 缺少 mock_boundary_note 字段"

        task_block_has_field "$TASK_BLOCK" 'depends_on' \
            || add_failure "T5: ${task_id} 缺少 depends_on 字段"
        task_block_has_field "$TASK_BLOCK" 'shared_files' \
            || add_failure "T5: ${task_id} 缺少 shared_files 字段"

        task_type_value=$(extract_task_field_value "$TASK_BLOCK" "task_type")
        task_type_value=$(printf '%s' "$task_type_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        case "$task_type_value" in
            探索)
                EXPLORATION_TASK_COUNT=$((EXPLORATION_TASK_COUNT + 1))
                task_block_has_field "$TASK_BLOCK" 'hypothesis' \
                    || add_failure "T5: ${task_id} 为探索任务但缺少 hypothesis 字段"
                task_block_has_field "$TASK_BLOCK" 'success_signal' \
                    || add_failure "T5: ${task_id} 为探索任务但缺少 success_signal 字段"
                task_block_has_field "$TASK_BLOCK" 'failure_signal' \
                    || add_failure "T5: ${task_id} 为探索任务但缺少 failure_signal 字段"
                task_block_has_field "$TASK_BLOCK" 'unlock_condition' \
                    || add_failure "T5: ${task_id} 为探索任务但缺少 unlock_condition 字段"

                hypothesis_value=$(extract_task_field_value "$TASK_BLOCK" "hypothesis")
                success_signal_value=$(extract_task_field_value "$TASK_BLOCK" "success_signal")
                failure_signal_value=$(extract_task_field_value "$TASK_BLOCK" "failure_signal")
                unlock_condition_value=$(extract_task_field_value "$TASK_BLOCK" "unlock_condition")

                normalized_hypothesis_value=$(printf '%s' "$hypothesis_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
                normalized_success_signal_value=$(printf '%s' "$success_signal_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
                normalized_failure_signal_value=$(printf '%s' "$failure_signal_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
                normalized_unlock_condition_value=$(printf '%s' "$unlock_condition_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

                if is_placeholder_text "$hypothesis_value" || [ "$normalized_hypothesis_value" = "无" ]; then
                    add_failure "T5: ${task_id} hypothesis 不能为空或无"
                fi
                if is_placeholder_text "$success_signal_value" || [ "$normalized_success_signal_value" = "无" ]; then
                    add_failure "T5: ${task_id} success_signal 不能为空或无"
                fi
                if is_placeholder_text "$failure_signal_value" || [ "$normalized_failure_signal_value" = "无" ]; then
                    add_failure "T5: ${task_id} failure_signal 不能为空或无"
                fi
                if is_placeholder_text "$unlock_condition_value" || [ "$normalized_unlock_condition_value" = "无" ]; then
                    add_failure "T5: ${task_id} unlock_condition 不能为空或无"
                fi
                ;;
            实施)
                :
                ;;
            *)
                add_failure "T3: ${task_id} task_type 非法（仅允许 探索 / 实施）"
                ;;
        esac

        if task_requires_metric_guardrail "$task_type_value" "$TASK_BLOCK"; then
            task_block_has_field "$TASK_BLOCK" 'success_signal' \
                || add_failure "T5: ${task_id} 缺少 success_signal 字段"
            task_block_has_field "$TASK_BLOCK" 'baseline_note' \
                || add_failure "T5: ${task_id} 缺少 baseline_note 字段"
            task_block_has_field "$TASK_BLOCK" 'guardrail_note' \
                || add_failure "T5: ${task_id} 缺少 guardrail_note 字段"

            metric_success_signal_value=$(trim "$(extract_task_field_value "$TASK_BLOCK" "success_signal")")
            baseline_note_value=$(trim "$(extract_task_field_value "$TASK_BLOCK" "baseline_note")")
            guardrail_note_value=$(trim "$(extract_task_field_value "$TASK_BLOCK" "guardrail_note")")

            if is_placeholder_text "$metric_success_signal_value" || [ "$metric_success_signal_value" = "无" ]; then
                add_failure "T5: ${task_id} success_signal 不能为空或无"
            fi
            if is_placeholder_text "$baseline_note_value" || [ "$baseline_note_value" = "无" ] || printf '%s' "$baseline_note_value" | grep -qiE '^N/?A$'; then
                add_failure "T5: ${task_id} baseline_note 不能为空或无"
            fi
            if is_placeholder_text "$guardrail_note_value" || [ "$guardrail_note_value" = "无" ] || printf '%s' "$guardrail_note_value" | grep -qiE '^N/?A$'; then
                add_failure "T5: ${task_id} guardrail_note 不能为空或无"
            fi
        fi

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
                    task_col = trim($8)
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
                        task_col = trim($8)
                        if (task_col ~ /^Task-[0-9]+$/) {
                            ref_col = trim($9)
                        } else {
                            task_col = trim($7)
                            if (!(task_col ~ /^Task-[0-9]+$/)) next
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

        proving_command_value=$(extract_task_field_value "$TASK_BLOCK" "proving_command")
        proving_command_value=$(printf '%s' "$proving_command_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$proving_command_value"; then
            add_failure "T4: ${task_id} proving_command 缺少可执行的 fresh 验证命令"
        elif printf '%s\n' "$proving_command_value" | grep -qiE '见上次|上次输出|口头|待补|TODO|TBD'; then
            add_failure "T4: ${task_id} proving_command 不得引用历史结果或占位说明，必须是执行阶段 fresh 重跑命令"
        elif is_obviously_non_verifying_command "$proving_command_value"; then
            add_failure "T4: ${task_id} proving_command 不能是空心命令，必须执行真实验证"
        fi

        real_dependency_note_value=$(extract_task_field_value "$TASK_BLOCK" "real_dependency_note")
        real_dependency_note_value=$(printf '%s' "$real_dependency_note_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$real_dependency_note_value"; then
            add_failure "T4: ${task_id} real_dependency_note 缺少真实依赖说明"
        fi
        if contains_mock_only_acceptance "$real_dependency_note_value"; then
            add_failure "T4: ${task_id} real_dependency_note 不得把 Mock 作为最终验收或完成证据"
        fi

        evidence_target_value=$(extract_task_field_value "$TASK_BLOCK" "evidence_target")
        evidence_target_value=$(printf '%s' "$evidence_target_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$evidence_target_value"; then
            add_failure "T4: ${task_id} evidence_target 缺少下游证据承接位置"
        elif ! has_anchored_evidence_target "$evidence_target_value"; then
            add_failure "T4: ${task_id} evidence_target 必须指向带锚点的 dev-report.md / qa-report.md / acceptance-summary.md / preflight-evidence.md"
        elif has_unanchored_evidence_target "$evidence_target_value"; then
            add_failure "T4: ${task_id} evidence_target 中每个证据文件都必须带锚点（#...）"
        fi

        mock_boundary_note_value=$(extract_task_field_value "$TASK_BLOCK" "mock_boundary_note")
        mock_boundary_note_value=$(printf '%s' "$mock_boundary_note_value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_text "$mock_boundary_note_value"; then
            add_failure "T4: ${task_id} mock_boundary_note 缺少 Mock 边界说明"
        elif ! printf '%s\n' "$mock_boundary_note_value" | grep -qi 'Mock'; then
            add_failure "T4: ${task_id} mock_boundary_note 必须说明 Mock 仅可用于分层隔离测试"
        fi
        if contains_mock_only_acceptance "$mock_boundary_note_value"; then
            add_failure "T4: ${task_id} mock_boundary_note 不得声明 Mock 可用于最终验收或完成证据"
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

validate_goal_fidelity_review

if [ "$PLANNING_MODE" = "探索优先" ] && [ "$EXPLORATION_TASK_COUNT" -eq 0 ]; then
    add_failure "T5: 探索优先模式至少需要一个探索任务"
fi
if [ "$PLANNING_MODE" = "标准实施" ] && [ "$EXPLORATION_TASK_COUNT" -gt 0 ]; then
    add_failure "T5: 标准实施模式不得包含探索任务"
fi
if [ "$PLANNING_MODE" = "探索优先" ] && [ -n "$TASK_IDS" ] && [ -n "$UNLOCKED_TASK_IDS" ]; then
    undefined_unlocked_tasks=$(comm -23 \
        <(printf '%s\n' "$UNLOCKED_TASK_IDS" | sed '/^$/d' | sort -u) \
        <(printf '%s\n' "$TASK_IDS" | sed '/^$/d' | sort -u) \
        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
    out_of_batch_tasks=$(comm -13 \
        <(printf '%s\n' "$UNLOCKED_TASK_IDS" | sed '/^$/d' | sort -u) \
        <(printf '%s\n' "$TASK_IDS" | sed '/^$/d' | sort -u) \
        | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')

    [ -z "$undefined_unlocked_tasks" ] || add_failure "T5: 探索优先模式的当前已解锁批次引用未定义 Task：${undefined_unlocked_tasks}"
    [ -z "$out_of_batch_tasks" ] || add_failure "T5: 探索优先模式存在当前已解锁批次之外的 Task：${out_of_batch_tasks}"
fi

# T6.1: 覆盖矩阵不得引用 Task 清单未定义的任务（反向一致性）
MATRIX_TASK_IDS=$(printf '%s\n' "$PLAN_MATRIX_ROWS" | awk -F'|' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^\|/ {
        task_col = trim($8)
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
    dup_freeze_scope_ids=$(printf '%s\n' "$FREEZE_ROWS" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
    if [ -n "$dup_freeze_scope_ids" ]; then
        add_failure "T6.2: Scope Freeze 存在重复 scope_item_id：$(printf '%s' "$dup_freeze_scope_ids" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
    fi

    while IFS='|' read -r scope_id _change_type _risk mapped_task test_ref rollback_ref status; do
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

extract_plan_review_summary_row() {
    local file="$1" view_label="$2"
    [ -f "$file" ] || return 0

    local summary_section summary_rows
    summary_section=$(extract_section_content "$file" "### 审查汇总" 3)
    [ -n "$summary_section" ] || return 0

    summary_rows=$(parse_table_by_header \
        "$summary_section" \
        "视角" \
        "Verdict" \
        "Review Round" \
        "Issue Count" \
        "结论摘要")
    printf '%s\n' "$summary_rows" | awk -F'\t' -v target="$view_label" '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        {
            view = trim($1)
            if (view == target) {
                print trim($1) "\t" trim($2) "\t" trim($3) "\t" trim($4) "\t" trim($5)
                exit
            }
        }
    '
}

extract_plan_review_issue_rows() {
    local file="$1"
    [ -f "$file" ] || return 0

    local ledger_section
    ledger_section=$(extract_section_content "$file" "### 审查问题台账" 3)
    [ -n "$ledger_section" ] || return 0

    parse_table_by_header \
        "$ledger_section" \
        "Issue ID" \
        "视角" \
        "Severity" \
        "Status" \
        "Evidence Anchor" \
        "Handoff Target" \
        "Review Round" \
        "风险接受记录" \
        "处理摘要"
}

# T9: 独立审查已执行（plan.md 必须填写结构化收敛状态）
INDEPENDENT_REVIEW_STATUS=$(extract_independent_review_status "$PLAN_FILE")
if [ -z "$INDEPENDENT_REVIEW_STATUS" ]; then
    add_failure "T9: plan.md 缺少有效的独立审查收敛状态（仅允许 REVIEW_PASS / FAIL 已修正）"
fi

if ! grep -qF "### 审查汇总" "$PLAN_FILE"; then
    add_failure "T9: 独立审查收敛缺少「审查汇总」章节"
fi
if ! grep -qF "### 审查问题台账" "$PLAN_FILE"; then
    add_failure "T9: 独立审查收敛缺少「审查问题台账」章节"
fi
if ! grep -qF "### 收敛轮次摘要" "$PLAN_FILE"; then
    add_failure "T9: 独立审查收敛缺少「收敛轮次摘要」章节"
fi
if ! grep -qF "### 用户裁决记录" "$PLAN_FILE"; then
    add_failure "T9: 独立审查收敛缺少「用户裁决记录」章节"
fi

PLAN_REVIEW_LEDGER_ROWS=$(extract_plan_review_issue_rows "$PLAN_FILE")
PLAN_TOTAL_STABLE_ISSUES=0
PLAN_TEST_REVIEW_ISSUE_COUNT=0
HAS_TEST_COVERAGE_GAP=0
if [ -n "$MATRIX_ROWS" ] && printf '%s\n' "$MATRIX_ROWS" | grep -qE '\|[[:space:]]*(COVERED-NO-TEST|EX-NO-TEST)[[:space:]]*\|[[:space:]]*$'; then
    HAS_TEST_COVERAGE_GAP=1
fi

check_plan_embedded_review_conclusion() {
    local label="$1" prefix="$2"
    local summary_row verdict review_round issue_count summary_text issue_rows issue_row_count

    summary_row=$(extract_plan_review_summary_row "$PLAN_FILE" "$label")
    if [ -z "$summary_row" ]; then
        add_failure "T9: plan.md「审查汇总」缺少${label}视角结论行"
        return
    fi

    verdict=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $2}')
    review_round=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $3}')
    issue_count=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $4}')
    summary_text=$(printf '%s\n' "$summary_row" | awk -F'\t' '{print $5}')

    if ! printf '%s\n' "$verdict" | grep -qE '^(PASS|WARN|FAIL)$'; then
        add_failure "T9: plan.md「审查汇总」${label}视角 Verdict 不可解析"
        return
    fi
    if is_placeholder_text "$review_round"; then
        add_failure "T9: plan.md「审查汇总」${label}视角缺少 Review Round"
    fi
    if ! printf '%s\n' "$issue_count" | grep -qE '^[0-9]+$'; then
        add_failure "T9: plan.md「审查汇总」${label}视角 Issue Count 不可解析"
        return
    fi
    if is_placeholder_text "$summary_text"; then
        add_failure "T9: plan.md「审查汇总」${label}视角缺少结论摘要"
    fi

    issue_rows=$(printf '%s\n' "$PLAN_REVIEW_LEDGER_ROWS" | awk -F'\t' -v prefix="$prefix" '$1 ~ ("^" prefix "-[0-9]{3,}$") { print }')
    issue_row_count=$(printf '%s\n' "$issue_rows" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$verdict" = "PASS" ] && [ "$issue_count" != "0" ]; then
        add_failure "T9: plan.md「审查汇总」${label}视角 Verdict=PASS 时 Issue Count 必须为 0"
    fi
    if [ "$verdict" != "PASS" ] && [ "$issue_count" = "0" ]; then
        add_failure "T9: plan.md「审查汇总」${label}视角 Verdict=${verdict} 时 Issue Count 不得为 0"
    fi
    if [ "$issue_count" != "$issue_row_count" ]; then
        add_failure "T9: plan.md「审查问题台账」${label}视角稳定 issue 数量=${issue_row_count} 与审查汇总 Issue Count=${issue_count} 不一致"
    fi
    PLAN_TOTAL_STABLE_ISSUES=$((PLAN_TOTAL_STABLE_ISSUES + issue_count))

    if [ "$verdict" = "FAIL" ]; then
        add_failure "T9: ${label}视角审查 Verdict 为 FAIL，阻塞 /tech-lead 完成"
    fi

    if [ "$prefix" = "PLT" ]; then
        PLAN_TEST_REVIEW_ISSUE_COUNT="$issue_row_count"
        if [ "$HAS_TEST_COVERAGE_GAP" -eq 1 ] && [ "$verdict" = "PASS" ]; then
            add_failure "T9: PRD 覆盖矩阵存在 COVERED-NO-TEST / EX-NO-TEST，但测试验收视角仍为 PASS"
        fi
    fi

    while IFS=$'\t' read -r issue_id view severity status evidence_anchor handoff_target review_round_value risk_accept_record resolution; do
        [ -n "$issue_id" ] || continue

        if is_placeholder_text "$view"; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 缺少视角"
        fi
        if is_placeholder_text "$severity"; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 缺少 Severity"
        fi
        if is_placeholder_text "$status"; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 缺少 Status"
        elif printf '%s' "$status" | grep -qiE '^(OPEN|PENDING|DRAFT|UNRESOLVED)$|待.*收敛|未.*收敛|冲突'; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 仍存在未收敛状态（${status}）"
        fi
        if is_placeholder_text "$evidence_anchor"; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 缺少 Evidence Anchor"
        fi
        if is_placeholder_text "$handoff_target"; then
            add_failure "T9: WARN 项 ${issue_id} 缺少 Handoff Target"
        fi
        if is_placeholder_text "$review_round_value"; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 缺少 Review Round"
        fi
        if is_placeholder_text "$risk_accept_record"; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 缺少风险接受记录"
        fi
        if is_placeholder_text "$resolution"; then
            add_failure "T9: plan.md「审查问题台账」${issue_id} 缺少处理摘要"
        fi
    done <<< "$issue_rows"
}

for review_args in \
    "产品|PLP" \
    "架构|PLA" \
    "测试验收|PLT"; do
    IFS='|' read -r r_label r_prefix <<< "$review_args"
    check_plan_embedded_review_conclusion "$r_label" "$r_prefix"
done

if [ "$HAS_TEST_COVERAGE_GAP" -eq 1 ] && [ "$PLAN_TEST_REVIEW_ISSUE_COUNT" -eq 0 ]; then
    add_failure "T9: PRD 覆盖矩阵存在 COVERED-NO-TEST / EX-NO-TEST，但测试验收视角未留下 PLT 问题台账"
fi

validate_review_convergence_policy "$PLAN_FILE" "plan.md" "$PLAN_TOTAL_STABLE_ISSUES"

output_failures "技术负责人实施计划完整性检查未通过" "$WORK_DIR"
exit 0
