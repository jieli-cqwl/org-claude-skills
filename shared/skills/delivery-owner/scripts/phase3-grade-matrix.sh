#!/bin/bash
# delivery-owner Phase 3 fixed full gate helper.
# Keep this legacy file name and function names for hook compatibility.

phase3_required_review_stages() {
    printf '%s\n' "REVIEW_A" "REVIEW_B" "REVIEW_C"
}

phase3_required_qa_stages() {
    printf '%s\n' "QA_A" "QA_B" "QA_C" "QA_D"
}

phase3_is_gate_stage() {
    case "${1:-}" in
        REVIEW_A|REVIEW_B|REVIEW_C|QA_A|QA_B|QA_C|QA_D)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

phase3_is_non_waivable_stage() {
    case "${1:-}" in
        REVIEW_A|REVIEW_B|REVIEW_C|QA_A|QA_B|QA_C|QA_D)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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
    # Fixed full gates make extra-stage escalation unnecessary.
    return 0
}

phase3_escalation_qa_stages() {
    # Fixed full gates make extra-stage escalation unnecessary.
    return 0
}
