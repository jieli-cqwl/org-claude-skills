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

run_canonical_verify_gate() {
    local target task_dir
    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/unit-[0-9]+/tasks/[^/"[:space:]*{}]+/verify-result\.json' 'verify-result.json'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "Task 级 verify 完整性检查未通过（canonical）" ""
        fi
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
    elif ! jq -e '
        ((.task_id // "") | type == "string" and length > 0)
        and ((.runtime_status // "") | type == "string" and length > 0)
        and ((.summary_text // "") | type == "string" and length > 0)
        and (.task_scope | type == "array" and length > 0)
        and ((.reviewable_anchor // "") | type == "string" and length > 0)
        and (.file_changes | type == "array" and length > 0)
        and all(.file_changes[]; type == "string" and length > 0)
        and (.tdd_evidence_index | type == "array" and length >= 2)
        and any(.tdd_evidence_index[]; (.phase // "") == "RED")
        and any(.tdd_evidence_index[]; (.phase // "") == "GREEN")
        and all(.tdd_evidence_index[];
            ((.phase // "") | test("^(RED|GREEN)$"))
            and ((.commit_sha // "") | test("^[0-9a-f]{7,40}$"))
            and ((.test_ref // "") | type == "string" and length > 0)
            and ((.result // "") | test("^(FAIL_EXPECTED|PASS)$"))
            and (.ac_refs | type == "array" and length > 0)
        )
    ' "$task_dir/developer-report.json" >/dev/null 2>&1; then
        add_failure "developer-report.json 缺少 canonical TDD 证据字段（reviewable_anchor / file_changes / tdd_evidence_index[RED,GREEN,commit_sha,test_ref,ac_refs]）：$task_dir/developer-report.json"
    fi

    if ! jq -e '
        ((.task_id // "") | type == "string" and length > 0)
        and ((.gate_result // "") | test("^(PASS|ISSUE|BLOCKED)$"))
        and ((.baseline_tasks_version_ref // "") | type == "string" and length > 0)
        and ((.baseline_tasks_version_ref // "") | type == "string" and length > 0)
        and ((.developer_report_ref // "") | type == "string" and length > 0)
        and (.phase_verdicts | type == "object")
        and ((.phase_verdicts.spec_review.status // "") | test("^(SPEC_OK|SPEC_ISSUE)$"))
        and ((.phase_verdicts.spec_review.evidence_ref // "") | type == "string" and length > 0)
        and ((.phase_verdicts.phase2a.status // "") | test("^(2A_OK|2A_ISSUE)$"))
        and ((.phase_verdicts.phase2a.evidence_ref // "") | type == "string" and length > 0)
        and ((.phase_verdicts.phase2b.status // "") | test("^(2B_OK|2B_ISSUE)$"))
        and ((.phase_verdicts.phase2b.evidence_ref // "") | type == "string" and length > 0)
        and ((.phase_verdicts.phase2c.status // "") | test("^(2C_OK|2C_ISSUE)$"))
        and ((.phase_verdicts.phase2c.evidence_ref // "") | type == "string" and length > 0)
        and (.ac_verification | type == "array" and length > 0)
        and all(.ac_verification[];
            ((.ac_ref // "") | type == "string" and length > 0)
            and ((.file_path // "") | type == "string" and length > 0)
            and ((.line_number // 0) | type == "number" and . >= 1)
            and ((.status // "") | test("^(PASS|ISSUE)$"))
            and ((.boundary_check // "") | type == "string" and length > 0)
        )
        and (.goal_closure | type == "array")
        and (.evidence_refs | type == "array" and length > 0)
    ' "$target" >/dev/null 2>&1; then
        add_failure "verify-result.json 缺少 canonical 必填字段（task_id / gate_result / baseline refs / developer_report_ref / phase_verdicts / ac_verification / goal_closure / evidence_refs）：$target"
    fi
    if ! jq -e '
        if .gate_result == "PASS" then
            (.phase_verdicts.spec_review.status == "SPEC_OK")
            and (.phase_verdicts.phase2a.status == "2A_OK")
            and (.phase_verdicts.phase2b.status == "2B_OK")
            and (.phase_verdicts.phase2c.status == "2C_OK")
        else
            true
        end
    ' "$target" >/dev/null 2>&1; then
        add_failure "verify-result.json 在 gate_result=PASS 时必须同时声明 SPEC_OK + 2A_OK + 2B_OK + 2C_OK：$target"
    fi

    output_failures "Task 级 verify 完整性检查未通过（canonical）" "$target"
    emit_decision_json "allow" "standard-chain canonical verify artifact valid"
    exit 0
}

run_canonical_verify_gate
