#!/bin/bash
# delivery-owner Phase 3 审查分级矩阵
# 唯一可执行规则源：completion_check.sh 与一致性测试都从这里读取。

phase3_required_review_stages() {
    case "${1:-}" in
        轻量)
            printf '%s\n' "REVIEW_A"
            ;;
        标准|完整)
            printf '%s\n' "REVIEW_A" "REVIEW_B"
            ;;
        *)
            return 1
            ;;
    esac
}

phase3_required_qa_stages() {
    case "${1:-}" in
        轻量)
            printf '%s\n' "QA_A"
            ;;
        标准)
            printf '%s\n' "QA_A" "QA_C"
            ;;
        完整)
            printf '%s\n' "QA_A" "QA_B" "QA_C" "QA_D"
            ;;
        *)
            return 1
            ;;
    esac
}

phase3_is_gate_stage() {
    case "${1:-}" in
        REVIEW_A|REVIEW_B|QA_A|QA_B|QA_C|QA_D)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

phase3_is_non_waivable_stage() {
    case "${1:-}" in
        REVIEW_A|QA_A)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

phase3_optional_review_stage() {
    printf '%s\n' "REVIEW_C"
}

phase3_is_high_risk_deviation_trigger() {
    case "${1:-}" in
        INTERFACE_BREAK|SHARED_FILES_EXPANSION|NON_CONVERGENCE|BLOCKED_ACCUMULATION)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

phase3_escalation_review_stages() {
    case "${1:-}" in
        INTERFACE_BREAK|SHARED_FILES_EXPANSION|NON_CONVERGENCE|BLOCKED_ACCUMULATION)
            printf '%s\n' "REVIEW_B"
            ;;
        *)
            return 0
            ;;
    esac
}

phase3_escalation_qa_stages() {
    case "${1:-}" in
        INTERFACE_BREAK)
            printf '%s\n' "QA_B" "QA_C"
            ;;
        SHARED_FILES_EXPANSION)
            printf '%s\n' "QA_C"
            ;;
        NON_CONVERGENCE|BLOCKED_ACCUMULATION)
            printf '%s\n' "QA_C" "QA_D"
            ;;
        *)
            return 0
            ;;
    esac
}
