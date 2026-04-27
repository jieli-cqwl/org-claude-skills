#!/usr/bin/env bash
# Review canonical gate: validates code-review-result.json as the standard-chain review fact source.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
review/completion_check.sh — canonical code review result gate
Execution: skill-local Stop or PostToolUse(Edit|Write)
Input: stdin JSON (cwd, session_id, transcript_path, optional tool_input.file_path)
Output: stdout JSON decision + stderr diagnostics
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
hook_init

# Validate required review dimensions, findings, exclusions, and active plan/task refs.
validate_review_result() {
    local target="$1"

    if [ ! -f "$target" ]; then
        add_failure "code-review-result.json not found: $target"
        output_failures "Canonical review gate failed" "$target"
    fi
    if ! jq -e . "$target" >/dev/null 2>&1; then
        add_failure "code-review-result.json is not valid JSON: $target"
        output_failures "Canonical review gate failed" "$target"
    fi
    if ! jq -e '
        .gate_result
        and .active_plan_version_ref
        and .active_tasks_version_ref
        and (.review_round | type == "number" and . >= 1)
        and (.dimension_verdicts | type == "object")
        and ((.dimension_verdicts.review_a // "") | test("^REVIEW_A_(OK|ISSUE)$"))
        and ((.dimension_verdicts.review_b // "") | test("^REVIEW_B_(OK|ISSUE)$"))
        and ((.dimension_verdicts.review_c // "") | test("^REVIEW_C_(OK|ISSUE)$"))
        and ((.dimension_verdicts.correctness // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.safety // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.error_handling // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.concurrency_state // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.design // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.test_coverage // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.backward_compatibility // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.comment_accuracy // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.performance // "") | test("^(OK|ISSUE)$"))
        and ((.dimension_verdicts.observability // "") | test("^(OK|ISSUE)$"))
        and (.findings | type == "array")
        and all(.findings[]?;
            ((.file_path // "") | type == "string" and length > 0)
            and ((.line_number // 0) | type == "number" and . >= 1 and floor == .)
            and ((.confidence // 0) | type == "number" and . >= 80)
            and ((.verification_status // "") | test("^(Verified|False Positive|Inconclusive|NOT_REQUIRED)$"))
        )
        and (.excluded | type == "array" and length >= 2)
        and all(.excluded[]?;
            ((.issue_id // "") | type == "string" and length > 0)
            and ((.summary // "") | type == "string" and length > 0)
            and ((.evidence_ref // "") | type == "string" and length > 0)
        )
        and ((.review_conclusion // "") | test("^(APPROVE|REQUEST_CHANGES|COMMENT)$"))
    ' "$target" >/dev/null 2>&1; then
        add_failure "code-review-result.json missing active refs, dimensions, findings, excluded issues, or review_conclusion: $target"
    fi
    if ! jq -e '
        all(.findings[]?;
            if (.severity == "S0" or .severity == "S1") then
                .verification_status != "NOT_REQUIRED"
            else
                true
            end
        )
    ' "$target" >/dev/null 2>&1; then
        add_failure "code-review-result.json S0/S1 findings require a real verification status: $target"
    fi
    validate_conclusion_gate_alignment "$target"
    validate_finding_locations "$target"
}

# Review approval semantics are stricter than the shared gate_result enum.
validate_conclusion_gate_alignment() {
    local target="$1"

    if ! jq -e '
        (.review_conclusion == "APPROVE" and .gate_result == "PASS")
        or (.review_conclusion != "APPROVE" and .gate_result == "FAIL")
    ' "$target" >/dev/null 2>&1; then
        add_failure "code-review-result gate_result must align with review_conclusion: APPROVE => PASS, REQUEST_CHANGES/COMMENT => FAIL: $target"
    fi
}

# Findings must point at concrete repo-local files and existing one-based lines.
validate_finding_locations() {
    local target="$1"
    local row finding_index file_path line_number finding_path line_count

    while IFS= read -r row; do
        finding_index="$(printf '%s' "$row" | jq -r '.idx')"
        file_path="$(printf '%s' "$row" | jq -r '.file_path')"
        line_number="$(printf '%s' "$row" | jq -r '.line_number')"

        if ! is_repo_local_finding_path "$file_path"; then
            add_failure "code-review-result finding file_path must be repo-local at findings[$finding_index]: $file_path"
            continue
        fi

        finding_path="$REPO_ROOT/$file_path"
        if [ ! -f "$finding_path" ]; then
            add_failure "code-review-result finding file_path does not exist at findings[$finding_index]: $file_path"
            continue
        fi

        if ! [[ "$line_number" =~ ^[0-9]+$ ]]; then
            add_failure "code-review-result finding line_number must be a positive integer at findings[$finding_index]: $file_path:$line_number"
            continue
        fi

        line_count="$(awk 'END {print NR}' "$finding_path")"
        if [ "$line_number" -gt "$line_count" ]; then
            add_failure "code-review-result finding line_number exceeds file length at findings[$finding_index]: $file_path:$line_number (file has $line_count lines)"
        fi
    done < <(jq -c '
        if (.findings | type) == "array" then
            .findings | to_entries[]? | {idx: .key, file_path: .value.file_path, line_number: .value.line_number}
        else
            empty
        end
    ' "$target")
}

is_repo_local_finding_path() {
    local file_path="$1"

    if [ -z "$file_path" ] || [ "${file_path#/}" != "$file_path" ]; then
        return 1
    fi
    case "/$file_path/" in
        *"/../"*) return 1 ;;
    esac
    return 0
}

# Run the canonical review gate or allow non-review hook events.
run_gate() {
    local target

    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/code-review-result\.json' 'code-review-result.json'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "Canonical review gate failed" ""
        fi
        if is_stop_dispatch_context; then
            add_failure "code-review-result.json path not found in hook context"
            output_failures "Canonical review gate failed" ""
        fi
        emit_decision_json "allow" "canonical review gate not targeted"
        return 0
    fi

    validate_review_result "$target"
    output_failures "Canonical review gate failed" "$target"
    emit_decision_json "allow" "canonical code review result validated"
}

run_gate
