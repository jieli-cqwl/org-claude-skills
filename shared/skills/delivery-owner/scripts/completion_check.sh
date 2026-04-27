#!/bin/bash
# delivery-owner/completion_check.sh — canonical delivery readiness gate.
# Boundary: read hook payload, locate current Phase canonical artifacts, run readiness validation, emit hook decision.

set -euo pipefail

# Escape text so hook decisions remain valid JSON.
json_escape_local() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

# Emit the minimal hook decision contract when common.sh is not available yet.
emit_decision_json_local() {
    local decision="$1"
    local reason="$2"
    printf '{"decision":"%s","reason":"%s"}\n' "$decision" "$(json_escape_local "$reason")"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
delivery-owner/completion_check.sh — canonical delivery readiness gate
Input: stdin JSON hook payload (cwd, session_id, transcript_path, tool_name, tool_input.file_path)
Output: stdout JSON decision (allow/block) + stderr diagnostics
USAGE
    exit 0
fi

# Fail closed before shared hook helpers have initialized.
early_block() {
    local reason="$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "delivery-owner canonical readiness gate 初始化失败：" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  - $reason" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    emit_decision_json_local "block" "$reason"
    exit 2
}

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || early_block "无法解析 delivery-owner hook 脚本目录"
HOOKS_LIB="$SCRIPT_DIR/../../../hooks/lib"
[ -d "$HOOKS_LIB" ] || early_block "缺少 hooks 依赖目录：$HOOKS_LIB"

# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh" || early_block "无法加载公共 hook 库：$HOOKS_LIB/common.sh"

hook_init
export HOOK_STRICT_BLOCK=1

# Validate the current Phase through the canonical standard-chain readiness gate.
run_canonical_delivery_owner_gate() {
    local target phase_dir validator runtime_root

    # Trigger artifacts: delivery-state.json, artifact-registry.json, signoff-package.json, user-decision.json.
    select_unique_hook_path 'docs/[^/"[:space:]*{}]+/phase-[0-9]+/(delivery-state|artifact-registry|signoff-package|user-decision)\.json' 'delivery-owner closeout artifact'
    target="$HOOK_MATCHED_PATH"
    if [ -z "$target" ]; then
        if [ -n "$FAILURES" ]; then
            output_failures "delivery-owner canonical readiness gate 未通过" ""
        fi
        if is_stop_dispatch_context || [ "${TOOL_NAME:-}" = "Write" ] || [ "${TOOL_NAME:-}" = "Edit" ]; then
            add_failure "canonical closeout 工件路径未命中，无法确认 delivery-state / artifact-registry / signoff-package / user-decision 是否已落盘"
            output_failures "delivery-owner canonical readiness gate 未通过" ""
        fi
        emit_decision_json_local "allow" "skip: delivery-owner canonical closeout gate not applicable"
        exit 0
    fi

    phase_dir=$(dirname "$target")
    runtime_root="$(resolve_runtime_root "$SCRIPT_DIR")"
    validator="$runtime_root/tools/community/validate_standard_chain_readiness.py"
    if [ ! -x "$validator" ] && [ ! -f "$validator" ]; then
        add_failure "缺少 readiness validator：$validator"
        output_failures "delivery-owner canonical readiness gate 未通过" "$target"
    fi

    if ! python3 "$validator" --phase-dir "$phase_dir" >/tmp/org_delivery_owner_canonical.out 2>&1; then
        cat /tmp/org_delivery_owner_canonical.out >&2 || true
        add_failure "canonical delivery-owner readiness gate 未通过：$phase_dir"
    fi

    output_failures "delivery-owner canonical readiness gate 未通过" "$phase_dir"
    emit_decision_json_local "allow" "delivery-owner canonical readiness gate passed"
}

run_canonical_delivery_owner_gate
