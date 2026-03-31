#!/bin/bash
# 项目经理交付完整性自动检查脚本
# 触发时机: project-manager skill-local Stop
# 功能: 精确定位当前 feature，按 UNIT/Phase 分层检查交付完整性
# 版本: v4.0 2026-03-24

set -euo pipefail

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/phase3-grade-matrix.sh"
hook_init
export HOOK_STRICT_BLOCK=1

# --- D1: Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/unit-[0-9]+/)?(dev-report\.md|code-review-report\.md|qa-report\.md|waivers\.md|plan\.md|design\.md)'
resolve_feature_dir "docs/*/phase-*/unit-*/dev-report.md" "$TRANSCRIPT_PATTERN" "dev-report.md" "docs/*/phase-*/unit-*"
output_failures "项目经理交付完整性检查未通过" ""

# --- 当前 Phase / UNIT 工作区定位 ---

resolve_phase_work_dir_from_prd "$FEATURE_DIR" "plan.md"
PHASE_DIR="$PHASE_WORK_DIR"

resolve_all_unit_work_dirs "$FEATURE_DIR"

# 兼容：如果当前 Phase 未解析出 UNIT 工作区，回退到单 UNIT 解析
if [ -z "$ALL_UNIT_WORK_DIRS" ]; then
    resolve_work_dir_from_prd "$FEATURE_DIR" "dev-report.md"
    ALL_UNIT_WORK_DIRS="$UNIT_WORK_DIR"
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

PLAN_FILE="$PHASE_DIR/plan.md"
DESIGN_FILE="$PHASE_DIR/design.md"
CR_REPORT="$PHASE_DIR/code-review-report.md"
QA_REPORT="$PHASE_DIR/qa-report.md"
WAIVER_FILE="$PHASE_DIR/waivers.md"
ACCEPT_SUMMARY="$PHASE_DIR/acceptance-summary.md"

trim() {
    local v="$1"
    # shellcheck disable=SC2001
    v=$(printf '%s' "$v" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    printf '%s' "$v"
}

is_placeholder_value() {
    local v
    v=$(trim "$1")
    if [ -z "$v" ]; then
        return 0
    fi
    if printf '%s' "$v" | grep -qiE '^(待补|TBD|TODO|N/?A|无|未填写|\[.*\]|\{.*\}|-|—)$'; then
        return 0
    fi
    return 1
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

extract_metadata_json() {
    local report="$1"
    sed -nE 's#^[[:space:]]*<metadata>(.*)</metadata>[[:space:]]*$#\1#p' "$report" 2>/dev/null | tail -1
}

parse_plan_grade() {
    local plan_file="$1"
    local line value

    line=$(grep -E '(Phase[[:space:]]*3[[:space:]]*审查分级|审查分级)[[:space:]]*[:：]' "$plan_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E 's/.*[:：][[:space:]]*//')
    value=$(trim "$value")

    # 拒绝模板占位值（如 "轻量 | 标准 | 完整" 或 "{轻量, 标准, 完整}"）
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

has_explicit_no_constraints_declaration() {
    local prd_file="$1"
    local constraint_section

    constraint_section=$(extract_markdown_section "$prd_file" "## 前置约束")
    printf '%s\n' "$constraint_section" | grep -qE '^[[:space:]]*[-*]?[[:space:]]*无前置约束（经评估）[[:space:]]*$|^[[:space:]]*[-*]?[[:space:]]*无前置约束\(经评估\)[[:space:]]*$'
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
            print constraint_id "|" constraint_type "|" scope_id "|" preflight_ref "|" test_ref
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
            print constraint_id "|" constraint_type "|" scope_id "|" preflight_ref "|" test_ref
        }
    ' | sed '/^$/d' | sort -u
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

    if epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null); then
        printf '%s' "$epoch"
        return 0
    fi

    if epoch=$(date -u -d "$ts" +%s 2>/dev/null); then
        printf '%s' "$epoch"
        return 0
    fi

    printf '%s' ""
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
    blocked_section=$(extract_markdown_section "$report_file" "### BLOCKED 任务")

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
        if is_placeholder_value "$reason" || is_placeholder_value "$risk" || is_placeholder_value "$controls" || is_placeholder_value "$approver" || is_placeholder_value "$approved_at" || is_placeholder_value "$expires_at"; then
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

        if is_placeholder_value "$reason" || is_placeholder_value "$risk" || is_placeholder_value "$controls" || is_placeholder_value "$approver" || is_placeholder_value "$approved_at" || is_placeholder_value "$expires_at"; then
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
        if is_placeholder_value "$constraint_type"; then
            add_failure "D2.1: ${constraint_id} 缺少约束类型"
        fi
        if is_placeholder_value "$scope_id" || ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
            add_failure "D2.1: ${constraint_id} 缺少有效 scope_item_id"
        fi
        if is_placeholder_value "$preflight_ref"; then
            add_failure "D2.1: ${constraint_id} 缺少 preflight_ref"
        fi
        normalized_test_ref=$(printf '%s' "$test_ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if is_placeholder_value "$normalized_test_ref" && ! printf '%s' "$normalized_test_ref" | grep -qiE '^N/?A$'; then
            add_failure "D2.1: ${constraint_id} 缺少 test_ref"
        fi
        if is_placeholder_value "$mapped_task" || ! printf '%s' "$mapped_task" | grep -qE '^Task-[0-9]+$'; then
            add_failure "D2.1: ${constraint_id} 缺少有效映射 Task"
        elif ! printf '%s\n' "$PLAN_TASK_IDS" | grep -qx "$mapped_task"; then
            add_failure "D2.1: ${constraint_id} 映射到未定义 Task：${mapped_task}"
        fi
        if is_placeholder_value "$acceptance_evidence"; then
            add_failure "D2.1: ${constraint_id} 缺少验收证据"
        fi
        if [ "$status" != "MAPPED" ] && [ "$status" != "VERIFIED" ]; then
            add_failure "D2.1: ${constraint_id} 状态为 ${status}（仅允许 MAPPED/VERIFIED）"
        fi
    done <<< "$PLAN_CONSTRAINT_ROWS"

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref status; do
        [ -n "$constraint_id" ] || continue
        prd_pair="${constraint_id}|${constraint_type}|${scope_id}|${preflight_ref}|${test_ref}"
        if ! printf '%s\n' "$plan_constraint_pairs" | grep -qx "$prd_pair"; then
            add_failure "D2.1: PRD 前置约束 ${constraint_id} 未在 plan 映射表中按 type/scope_item_id/preflight_ref/test_ref 完整承接"
        fi
    done <<< "$PRD_CONSTRAINT_ROWS"

    while IFS='|' read -r constraint_id constraint_type description owner affected_unit scope_id preflight_ref test_ref mapped_task acceptance_evidence status; do
        [ -n "$constraint_id" ] || continue
        plan_pair="${constraint_id}|${constraint_type}|${scope_id}|${preflight_ref}|${test_ref}"
        if ! printf '%s\n' "$prd_constraint_pairs" | grep -qx "$plan_pair"; then
            add_failure "D2.1: plan 前置约束映射 ${constraint_id} 引用了 PRD 未声明的 type/scope_item_id/preflight_ref/test_ref 组合"
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
        if is_placeholder_value "$blocked_reason"; then
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
        if is_placeholder_value "$commit_hash"; then
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
            add_failure "D4[${UNIT_LABEL}]: ${task_id} TDD 证据不完整（RED=${red_count}, GREEN=${green_count}）"
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

                if is_placeholder_value "$row_impact_files"; then
                    add_failure "D5.1[${UNIT_LABEL}]: ${row_task} Task-scope 对照表缺少 impact_files"
                fi
                if is_placeholder_value "$row_rollback_ref"; then
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
                    add_failure "D11.1[${UNIT_LABEL}]: 存在 DESIGN-GAP(EQ)（${eq_scope_id}），阻断 /project-manager 收口"
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

                if ! printf '%s\n' "$expected_unit_dirs" | grep -qx "$resolved_unit_work_dir"; then
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

                if [ "$qa_status_norm" = "OK" ] && ! is_placeholder_value "$qa_issue_ids"; then
                    add_failure "D12: ${qa_unit} 标记为 OK，但 issue_ids 不应填写问题编号"
                fi

                if is_placeholder_value "$qa_note"; then
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
                if ! printf '%s\n' "$ALL_UNIT_WORK_DIRS" | sed '/^$/d' | grep -qx "$resolved_row_unit_work_dir"; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 引用了当前 Phase 之外的 unit_work_dir：${row_unit_work_dir}"
                fi

                if ! printf '%s\n' "$row_ac_id" | grep -qE '^G?AC(-[A-Z][0-9]+)?-[0-9]+$'; then
                    add_failure "D12: AC 追踪表存在非法 AC 编号：${row_ac_id}"
                fi

                if is_placeholder_value "$row_test_ref" || ! printf '%s\n' "$row_test_ref" | grep -qE 'TC(-[A-Z][0-9]+)?-[0-9]+'; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 的 test_ref 缺少有效 TC 编号"
                fi

                row_result_norm=$(printf '%s' "$row_result" | tr '[:lower:]' '[:upper:]')
                if [ -z "$row_result_norm" ] || ! printf '%s\n' "$row_result_norm" | grep -qE '^PASS$'; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 在 AC 追踪表结果不是 PASS（${row_result:-missing}）"
                fi

                if is_placeholder_value "$row_evidence"; then
                    add_failure "D12: ${row_unit}/${row_ac_id} 缺少有效证据摘要"
                fi
            done <<< "$ac_trace_entries"

            if [ -n "$ALL_TC_IDS" ]; then
                tc_ids_in_test_cases_norm=$(printf '%s\n' "$ALL_TC_IDS" | sed -E 's/^TC-0*([0-9]+)$/TC-\1/' | sort -u || true)
                while IFS='|' read -r d121_unit d121_unit_work_dir d121_ac d121_tref d121_result d121_evidence; do
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

# --- D13: acceptance-summary.md 签收状态 + 前置约束验收状态（Phase 级） ---

if [ ! -f "$ACCEPT_SUMMARY" ]; then
    add_failure "D13: acceptance-summary.md 不存在：$ACCEPT_SUMMARY"
elif [ ! -s "$ACCEPT_SUMMARY" ]; then
    add_failure "D13: acceptance-summary.md 为空：$ACCEPT_SUMMARY"
else
    signoff_status=$(grep -E '签收状态[[:space:]]*[:：]' "$ACCEPT_SUMMARY" 2>/dev/null | head -1 | sed -E 's/.*[:：][[:space:]]*//' || true)
    signoff_status=$(trim "$signoff_status")
    if [ -z "$signoff_status" ] || [ "$signoff_status" = "待签收" ]; then
        add_failure "D13: acceptance-summary.md 签收状态为空或待签收"
    elif [ "$signoff_status" = "拒绝" ]; then
        add_failure "D13: acceptance-summary.md 签收状态为「拒绝」，需用户重新确认或记录处理方案"
    fi

    constraint_rows=$(extract_acceptance_constraint_rows "$ACCEPT_SUMMARY")
    constraint_count=$(printf '%s\n' "$constraint_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$constraint_count" -eq 0 ]; then
        if [ "$PRD_CONSTRAINT_COUNT" -gt 0 ]; then
            add_failure "D13: acceptance-summary.md 缺少「前置约束验收状态」章节、内容为空或仅有表头"
        elif ! has_explicit_no_constraints_declaration "$PRD_FILE"; then
            add_failure "D13: acceptance-summary.md 未声明前置约束验收状态，且 PRD 也未显式声明“无前置约束（经评估）”"
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

                if is_placeholder_value "$constraint_type"; then
                    add_failure "D13: ${constraint_id} 缺少约束类型"
                fi

                case "$plan_status" in
                    MAPPED|VERIFIED)
                        ;;
                    *)
                        add_failure "D13: ${constraint_id} 的 Plan 状态非法（${plan_status:-missing}），仅允许 MAPPED/VERIFIED"
                        ;;
                esac

                if is_placeholder_value "$preflight_ref"; then
                    add_failure "D13: ${constraint_id} 缺少 preflight_ref"
                fi

                normalized_test_ref=$(printf '%s' "$test_ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
                if is_placeholder_value "$normalized_test_ref" && ! printf '%s' "$normalized_test_ref" | grep -qiE '^N/?A$'; then
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
                    if is_placeholder_value "$evidence"; then
                        add_failure "D13: ${constraint_id} 验收结果为 OK，但缺少证据"
                    fi
                else
                    if is_placeholder_value "$note"; then
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
                if is_placeholder_value "$matched_plan_task" || ! printf '%s\n' "$PLAN_TASK_IDS" | grep -qx "$matched_plan_task"; then
                    add_failure "D13: ${constraint_id} 在 plan.md 中缺少有效映射 Task，无法形成 acceptance 闭环"
                fi
                if is_placeholder_value "$matched_plan_scope" || ! printf '%s' "$matched_plan_scope" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
                    add_failure "D13: ${constraint_id} 在 plan.md 中缺少有效 scope_item_id，无法形成 acceptance 闭环"
                fi
            done <<< "$constraint_rows"

            while IFS='|' read -r plan_constraint_id plan_constraint_type description owner affected_unit scope_id preflight_ref test_ref mapped_task acceptance_evidence plan_status; do
                [ -n "$plan_constraint_id" ] || continue
                plan_pair="${plan_constraint_id}|${plan_constraint_type}|${plan_status}|${preflight_ref}|${test_ref}"
                if ! printf '%s\n' "$acceptance_constraint_pairs" | grep -qx "$plan_pair"; then
                    add_failure "D13: plan.md 前置约束 ${plan_constraint_id} 未在 acceptance-summary.md 中按 type/plan_status/preflight_ref/test_ref 完整承接"
                fi
            done <<< "$PLAN_CONSTRAINT_ROWS"
        fi
    fi
fi

# --- 输出结果 ---

output_failures "项目经理交付完整性检查未通过" "$PHASE_DIR"
exit 0
