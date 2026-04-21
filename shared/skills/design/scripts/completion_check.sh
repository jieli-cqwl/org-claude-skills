#!/usr/bin/env bash
# Design canonical gate: validates the frozen standard-chain design.json artifact.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
design/completion_check.sh — canonical design artifact gate
Execution: PostToolUse(Edit|Write) or skill-local Stop
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

# Validate a canonical artifact through the shared schema catalog.
validate_schema() {
    local file="$1"
    local label="$2"
    local fixture_file schema_out

    fixture_file="$(mktemp "${TMPDIR:-/tmp}/design-canonical.XXXXXX")"
    schema_out="$(mktemp "${TMPDIR:-/tmp}/design-canonical-schema.XXXXXX")"
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

# Validate the design-specific required semantic fields.
validate_design_artifact() {
    local target="$1"

    if [ ! -f "$target" ]; then
        add_failure "design.json not found: $target"
        output_failures "Canonical design gate failed" "$target"
    fi
    if ! jq -e . "$target" >/dev/null 2>&1; then
        add_failure "design.json is not valid JSON: $target"
        output_failures "Canonical design gate failed" "$target"
    fi

    validate_schema "$target" "design.json"
    if ! jq -e '
        ((.input_analysis // "") | type == "string" and length > 0)
        and (.key_decisions | type == "array" and length > 0)
        and (.interface_boundary | type == "array" and length > 0)
        and (.quality_attributes | type == "array" and length > 0)
    ' "$target" >/dev/null 2>&1; then
        add_failure "design.json missing input_analysis / key_decisions / interface_boundary / quality_attributes: $target"
    fi
}

# Run the canonical design gate or allow non-design hook events.
run_gate() {
    local target

    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/design\.json' 'design.json'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "Canonical design gate failed" ""
        fi
        if is_stop_dispatch_context; then
            add_failure "design.json path not found in hook context"
            output_failures "Canonical design gate failed" ""
        fi
        emit_decision_json "allow" "canonical design gate not targeted"
        return 0
    fi

    validate_design_artifact "$target"
    output_failures "Canonical design gate failed" "$target"
    emit_decision_json "allow" "canonical design artifact validated"
}

run_gate
