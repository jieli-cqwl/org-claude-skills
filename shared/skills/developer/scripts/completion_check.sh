#!/usr/bin/env bash
# Developer canonical gate: validates developer-report.json task evidence.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
developer/completion_check.sh — canonical developer report gate
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_ROOT="$(resolve_runtime_root "$SCRIPT_DIR")"

# Collect canonical developer-report.json paths from hook payload, transcript, and current git changes.
collect_report_paths() {
    local pattern explicit_paths
    pattern='(docs|tests/fixtures)/[^/"[:space:]*{}]+/phase-[0-9]+/unit-[0-9]+/tasks/[^/"[:space:]*{}]+/developer-report\.json'
    explicit_paths=""

    if [ -n "${TOOL_FILE_PATH:-}" ] && printf '%s' "$TOOL_FILE_PATH" | grep -qE "^${pattern}$"; then
        explicit_paths="${explicit_paths}${TOOL_FILE_PATH}
"
    fi
    if [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        explicit_paths="${explicit_paths}$(grep -oE "$pattern" "$TRANSCRIPT_PATH" 2>/dev/null || true)
"
    fi
    if [ -n "$(printf '%s' "$explicit_paths" | sed '/^$/d')" ]; then
        printf '%s' "$explicit_paths" | sed '/^$/d'
        return 0
    fi
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        {
            git diff --name-only HEAD -- 'docs/*/phase-*/unit-*/tasks/*/developer-report.json' 2>/dev/null || true
            git ls-files --others --exclude-standard -- 'docs/*/phase-*/unit-*/tasks/*/developer-report.json' 2>/dev/null || true
        } | grep -E "^${pattern}$" || true
    fi
}

# Validate one canonical artifact through the shared schema catalog.
validate_schema() {
    local file="$1"
    local label="$2"
    local fixture_file schema_out

    fixture_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical.XXXXXX")"
    schema_out="$(mktemp "${TMPDIR:-/tmp}/developer-canonical-schema.XXXXXX")"
    python3 - "$file" "$fixture_file" <<'PY'
import json
import sys
from pathlib import Path

artifact_path = Path(sys.argv[1])
fixture_path = Path(sys.argv[2])
payload = json.loads(artifact_path.read_text(encoding="utf-8"))
fixture_path.write_text(json.dumps({"artifacts": [payload]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

    if ! python3 "$RUNTIME_ROOT/tools/community/validate_canonical_schema.py" --fixture "$fixture_file" >"$schema_out" 2>&1; then
        add_failure "$label canonical schema validation failed"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,3p' "$schema_out")
    fi
    rm -f "$fixture_file" "$schema_out"
}

# Validate TDD evidence semantics and commit traceability.
validate_tdd_evidence() {
    local report="$1"
    local commit_sha

    if jq -e '.runtime_status == "BLOCKED" and ((.tdd_evidence_index // []) | length == 0)' "$report" >/dev/null 2>&1; then
        return 0
    fi

    if ! jq -e '
        all(.tdd_evidence_index[]?;
            (.phase == "RED" and .result == "FAIL_EXPECTED")
            or (.phase == "GREEN" and .result == "PASS")
        )
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json 的 RED 必须记录 FAIL_EXPECTED，GREEN 必须记录 PASS：$report"
    fi

    if ! jq -e '
        def ac_refs($phase; $result):
            [.tdd_evidence_index[]? | select(.phase == $phase and .result == $result) | .ac_refs[]?] | unique;
        ([.tdd_evidence_index[]? | .ac_refs[]?] | unique) as $all
        | (ac_refs("RED"; "FAIL_EXPECTED")) as $red
        | (ac_refs("GREEN"; "PASS")) as $green
        | (($all | length) > 0)
            and all($all[]; (. as $ac | (($red | index($ac)) != null and ($green | index($ac)) != null)))
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json 每个 AC 必须同时具备 RED FAIL_EXPECTED 与 GREEN PASS：$report"
    fi

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        while IFS= read -r commit_sha; do
            [ -n "$commit_sha" ] || continue
            if ! printf '%s' "$commit_sha" | grep -qE '^[0-9a-f]{7,40}$'; then
                add_failure "developer-report.json Commit SHA 格式无效：$commit_sha"
                continue
            fi
            if ! git cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1; then
                add_failure "developer-report.json Commit SHA 在 git 中不存在：$commit_sha"
            fi
        done < <(jq -r '.tdd_evidence_index[]?.commit_sha // empty' "$report")
    else
        add_failure "非 Git 环境，Commit SHA 无法验证：$report"
    fi
}

validate_runtime_status_contract() {
    local report="$1"

    if ! jq -e '
        if .runtime_status == "BLOCKED" then
            ((.blocked_reason // "") | type == "string" and length > 0)
            and ((.missing_inputs // []) | type == "array" and length > 0)
        else
            true
        end
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json BLOCKED 状态必须包含 blocked_reason 与 missing_inputs：$report"
    fi

    if ! jq -e '
        if .runtime_status == "VERIFIED" then
            ((.task_scope // []) | type == "array" and length > 0)
            and ((.file_changes // []) | type == "array" and length > 0)
        else
            true
        end
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json VERIFIED 状态必须包含非空 task_scope（Task.file_range 运行时快照）与 file_changes：$report"
    fi
}

validate_self_testing() {
    local report="$1"

    if ! jq -e '
        def nonempty_string: type == "string" and length > 0;
        ((.self_testing.coverage_review.status // "") | . == "PASS" or . == "FAIL" or . == "BLOCKED" or . == "PARTIAL")
        and ((.self_testing.coverage_review.evidence_ref // "") | nonempty_string)
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json self_testing.coverage_review 必须包含 status 与 evidence_ref：$report"
    fi

    if ! jq -e '
        def nonempty_string: type == "string" and length > 0;
        .runtime_status as $runtime
        | .self_testing.full_regression as $check
        | ($check.status == "PASS")
            or (($runtime == "BLOCKED" or $runtime == "PARTIAL") and (($check.reason // "") | nonempty_string))
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json self_testing.full_regression 必须 PASS；若 BLOCKED/PARTIAL 必须说明 reason：$report"
    fi

    if ! jq -e '
        def nonempty_string: type == "string" and length > 0;
        .runtime_status as $runtime
        | [.self_testing.static_analysis.lint, .self_testing.static_analysis.type_check, .self_testing.static_analysis.build]
        | all(.[];
            (.status == "PASS")
            or (($runtime == "BLOCKED" or $runtime == "PARTIAL") and ((.reason // "") | nonempty_string))
        )
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json self_testing.static_analysis lint/type_check/build 必须 PASS；若 BLOCKED/PARTIAL 必须说明 reason：$report"
    fi

    if ! jq -e '
        def nonempty_string: type == "string" and length > 0;
        [.self_testing.smoke, .self_testing.e2e]
        | all(.[];
            (.status == "PASS")
            or (.status == "NOT_APPLICABLE" and ((.reason // "") | nonempty_string))
        )
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json self_testing smoke/e2e 必须 PASS 或 NOT_APPLICABLE 且说明 reason：$report"
    fi
}

validate_runtime_contract_semantics() {
    local report="$1"
    local phase_dir task_id semantic_out

    phase_dir="$(dirname "$(dirname "$(dirname "$(dirname "$report")")")")"
    task_id="$(basename "$(dirname "$report")")"
    semantic_out="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-contract.XXXXXX")"

    if ! python3 "$RUNTIME_ROOT/tools/community/validate_developer_runtime_contract.py" \
        --phase-dir "$phase_dir" \
        --task-id "$task_id" \
        --report "$report" >"$semantic_out" 2>&1; then
        add_failure "developer runtime contract validation failed: $report"
        while IFS= read -r line; do
            [ -n "$line" ] && add_failure "$line"
        done < <(sed -n '1,6p' "$semantic_out")
    fi
    rm -f "$semantic_out"
}

# Validate developer-owned task evidence and active plan/task refs.
validate_developer_report() {
    local report="$1"

    if [ ! -f "$report" ]; then
        add_failure "developer-report.json not found: $report"
        return 0
    fi
    if ! jq -e . "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json is not valid JSON: $report"
        return 0
    fi

    validate_schema "$report" "developer-report.json"
    if ! jq -e '
        .artifact_type == "developer-report"
        and ((.task_id // "") | type == "string" and length > 0)
        and ((.runtime_status // "") | type == "string" and length > 0)
        and ((.active_plan_version_ref // "") | type == "string" and length > 0)
        and ((.active_tasks_version_ref // "") | type == "string" and length > 0)
        and ((.evidence_refs // []) | type == "array" and length > 0)
        and ((.reviewable_anchor // "") | type == "string" and length > 0)
        and ((.file_changes // []) | type == "array")
        and ((.task_scope // []) | type == "array")
        and ((.self_testing // {}) | type == "object")
        and ((.tdd_evidence_index // []) | type == "array")
        and all(.tdd_evidence_index[]; .phase and .test_ref and .result and ((.ac_refs // []) | type == "array" and length > 0))
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json missing task_id, runtime_status, active refs, evidence_refs, reviewable_anchor, task_scope, file_changes, self_testing, or TDD evidence structure: $report"
    fi
    validate_runtime_status_contract "$report"
    validate_tdd_evidence "$report"
    validate_self_testing "$report"
    validate_runtime_contract_semantics "$report"
}

# Run the canonical developer gate for each report found in the current context.
run_gate() {
    local reports report

    reports=$(collect_report_paths | sed '/^$/d' | sort -u)
    if [ -z "$reports" ]; then
        if is_stop_dispatch_context; then
            add_failure "developer-report.json path not found in hook context or git changes"
            output_failures "Canonical developer gate failed" ""
        fi
        emit_decision_json "allow" "canonical developer gate not targeted"
        return 0
    fi

    while IFS= read -r report; do
        [ -n "$report" ] && validate_developer_report "$report"
    done <<< "$reports"

    output_failures "Canonical developer gate failed" ""
    emit_decision_json "allow" "canonical developer report validated"
}

run_gate
