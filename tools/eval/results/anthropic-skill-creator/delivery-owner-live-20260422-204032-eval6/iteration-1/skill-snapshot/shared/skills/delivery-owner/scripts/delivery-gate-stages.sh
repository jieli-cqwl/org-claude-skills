#!/bin/bash
# delivery-owner delivery gate fixed full gate helper.

# Print the fixed code-review stages required before sign-off.
delivery_gate_required_review_stages() {
    printf '%s\n' "REVIEW_A" "REVIEW_B" "REVIEW_C"
}

# Print the fixed QA stages required before sign-off.
delivery_gate_required_qa_stages() {
    printf '%s\n' "QA_A" "QA_B" "QA_C" "QA_D"
}

# Return success when the given stage belongs to the fixed delivery gate set.
delivery_gate_is_gate_stage() {
    case "${1:-}" in
        REVIEW_A|REVIEW_B|REVIEW_C|QA_A|QA_B|QA_C|QA_D)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Return success when the given stage cannot be waived at stage level.
delivery_gate_is_non_waivable_stage() {
    case "${1:-}" in
        REVIEW_A|REVIEW_B|REVIEW_C|QA_A|QA_B|QA_C|QA_D)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Return success for deviations that force owner control action.
delivery_gate_is_high_risk_deviation_trigger() {
    case "${1:-}" in
        INTERFACE_BREAK|SHARED_FILES_EXPANSION|NON_CONVERGENCE|BLOCKED_ACCUMULATION)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
