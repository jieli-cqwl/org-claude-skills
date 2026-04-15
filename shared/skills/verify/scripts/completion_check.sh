#!/bin/bash
# 任务级 verify 结果完整性自动检查脚本
# 触发时机: verify skill-local Stop
# 功能: 只消费 canonical verify-result.json，并校验 developer-report / task gate 结果完整性

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
verify/completion_check.sh — Task 级 verify 结果完整性自动检查脚本
触发时机: verify skill-local Stop
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
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
        grep -oE "$pattern" "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || true
    fi
}

run_canonical_verify_gate() {
    local target task_dir
    target=$(first_matching_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/unit-[0-9]+/tasks/[^/"[:space:]*{}]+/verify-result\.json')
    if [ -z "$target" ]; then
        add_failure "verify-result.json 路径未命中，无法确认 Task 级验收结果是否已落盘"
        output_failures "Task 级 verify 完整性检查未通过（canonical）" ""
    fi

    if [ ! -f "$target" ]; then
        add_failure "verify-result.json 不存在：$target"
        output_failures "Task 级 verify 完整性检查未通过（canonical）" "$target"
    fi
    if ! jq -e . "$target" >/dev/null 2>&1; then
        add_failure "verify-result.json 不是合法 JSON：$target"
        output_failures "Task 级 verify 完整性检查未通过（canonical）" "$target"
    fi

    task_dir=$(dirname "$target")
    if [ ! -f "$task_dir/developer-report.json" ]; then
        add_failure "developer-report.json 不存在：$task_dir/developer-report.json"
    elif ! jq -e . "$task_dir/developer-report.json" >/dev/null 2>&1; then
        add_failure "developer-report.json 不是合法 JSON：$task_dir/developer-report.json"
    fi

    if ! jq -e '
        ((.task_id // "") | type == "string" and length > 0)
        and ((.gate_result // "") | type == "string" and length > 0)
        and (.goal_closure | type == "array")
        and (.evidence_refs | type == "array" and length > 0)
    ' "$target" >/dev/null 2>&1; then
        add_failure "verify-result.json 缺少 canonical 必填字段（task_id / gate_result / goal_closure / evidence_refs）：$target"
    fi

    output_failures "Task 级 verify 完整性检查未通过（canonical）" "$target"
    emit_decision_json "allow" "standard-chain canonical verify artifact valid"
    exit 0
}

run_canonical_verify_gate
