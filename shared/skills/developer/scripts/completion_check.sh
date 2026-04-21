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
    local pattern
    pattern='docs/[^/"[:space:]*{}]+/phase-[0-9]+/unit-[0-9]+/tasks/[^/"[:space:]*{}]+/developer-report\.json'

    if [ -n "${TOOL_FILE_PATH:-}" ] && printf '%s' "$TOOL_FILE_PATH" | grep -qE "^${pattern}$"; then
        printf '%s\n' "$TOOL_FILE_PATH"
    fi
    if [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        grep -oE "$pattern" "$TRANSCRIPT_PATH" 2>/dev/null || true
    fi
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        {
            git diff --name-only HEAD -- 'docs/*/phase-*/unit-*/tasks/*/developer-report.json' 2>/dev/null || true
            git ls-files --others --exclude-standard -- 'docs/*/phase-*/unit-*/tasks/*/developer-report.json' 2>/dev/null || true
        }
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
        and ((.active_plan_version_ref // "") | type == "string" and length > 0)
        and ((.active_tasks_version_ref // "") | type == "string" and length > 0)
        and ((.evidence_refs // []) | type == "array" and length > 0)
        and ((.reviewable_anchor // "") | type == "string" and length > 0)
        and ((.file_changes // []) | type == "array" and length > 0)
        and ((.tdd_evidence_index // []) | type == "array" and length > 0)
        and all(.tdd_evidence_index[]; .phase and .test_ref and .result and ((.ac_refs // []) | type == "array" and length > 0))
    ' "$report" >/dev/null 2>&1; then
        add_failure "developer-report.json missing task_id, active refs, evidence_refs, reviewable_anchor, file_changes, or TDD evidence: $report"
    fi
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
