#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
product-manager/completion_check.sh — Manager handoff 与 PRD 完整性检查脚本
执行时机: PostToolUse(Edit|Write) 收口门禁
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

HOOKS_LIB="$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)"
# shellcheck source=/dev/null
source "$HOOKS_LIB/common.sh"
hook_init

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(brief\.md|phase-[0-9]+/prd\.md|phase-[0-9]+/units/UNIT-[0-9]+\.md)'
resolve_feature_dir "docs/*/brief.md" "$TRANSCRIPT_PATTERN" "brief.md"

_fc_count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
if [ -z "$FEATURE_DIR" ] || [ "$_fc_count" != "1" ]; then
    # shellcheck disable=SC2034
    FAILURES=""
    resolve_feature_dir "docs/*/phase-*/prd.md" "$TRANSCRIPT_PATTERN" "prd.md" "docs/*/phase-*"
fi

_fc_count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
if { [ -z "$FEATURE_DIR" ] || [ "$_fc_count" != "1" ]; } && [ -n "$TOOL_FILE_PATH" ]; then
    _path_candidate=$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^(docs/[^/]+)/.*#\1#p')
    if [ -n "$_path_candidate" ] && [ -d "$_path_candidate" ]; then
        # shellcheck disable=SC2034
        FAILURES=""
        FEATURE_DIR="$_path_candidate"
        FEATURE_CANDIDATES="$_path_candidate"
    fi
fi
output_failures "Product-manager handoff 检查未通过" ""

BRIEF_FILE="$FEATURE_DIR/brief.md"
LEGACY_PRODUCT_CHECK="$REPO_ROOT/shared/skills/product/scripts/completion_check.sh"

should_run_gate() {
    if [ -z "${TOOL_NAME:-}" ]; then
        return 0
    fi
    if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
        return 0
    fi
    if [ -n "${TOOL_FILE_PATH:-}" ]; then
        local basename_file
        basename_file=$(basename "$TOOL_FILE_PATH")
        if [ "$basename_file" = "brief.md" ]; then
            return 0
        fi
        if printf '%s' "$TOOL_FILE_PATH" | grep -qE 'phase-[0-9]+/(prd\.md|units/UNIT-[0-9]+\.md)$'; then
            return 0
        fi
        return 1
    fi
    return 0
}

extract_confirmation_field() {
    local section="$1"
    local field="$2"
    printf '%s\n' "$section" | sed -nE "s/^- ${field}:[[:space:]]*(.*)$/\\1/p" | head -1
}

director_confirmation_section() {
    extract_section_by_name "$BRIEF_FILE" "产品总监确认" 2
}

validate_director_handoff_preconditions() {
    local section status confirm_time brief_lock prd_files prd_file prd_lock

    if [ ! -f "$BRIEF_FILE" ]; then
        add_failure "Brief 文档不存在：$BRIEF_FILE"
        return 0
    fi

    section=$(director_confirmation_section)
    if [ -z "$section" ]; then
        add_failure "缺少「产品总监确认」章节；legacy brief 必须先完成 migration candidate + re-signoff"
        return 0
    fi

    status=$(extract_confirmation_field "$section" "确认状态")
    confirm_time=$(extract_confirmation_field "$section" "确认时间")

    case "$status" in
        已通过|通过|确认)
            ;;
        *)
            add_failure "产品总监确认未通过，必须先回到 /product-director 完成 D-G1"
            ;;
    esac

    if ! is_valid_confirmation_time "$confirm_time"; then
        add_failure "产品总监确认时间缺少有效时间（需使用 YYYY-MM-DD HH:mm）"
    fi

    brief_lock="$FEATURE_DIR/brief.lock.json"
    if [ ! -f "$brief_lock" ]; then
        add_failure "缺少 brief.lock.json"
    elif ! jq -e . "$brief_lock" >/dev/null 2>&1; then
        add_failure "brief.lock.json 不是有效 JSON"
    fi

    prd_files=$(find "$FEATURE_DIR" -type f -name 'prd.md' | rg '/phase-[0-9]+/prd\.md$' || true)
    if [ -z "$prd_files" ]; then
        add_failure "缺少 phase-{N}/prd.md"
        return 0
    fi

    while IFS= read -r prd_file; do
        [ -n "$prd_file" ] || continue
        prd_lock="${prd_file%/prd.md}/prd.lock.json"
        if [ ! -f "$prd_lock" ]; then
            add_failure "缺少 $(printf '%s' "$prd_file" | grep -oE 'phase-[0-9]+/prd\.md' | sed 's#/prd\.md$#/prd.lock.json#')"
        elif ! jq -e . "$prd_lock" >/dev/null 2>&1; then
            add_failure "${prd_lock##*/} 不是有效 JSON"
        fi
    done <<< "$prd_files"

    return 0
}

normalize_text() {
    printf '%s' "$1" | sed -E 's/[[:space:]]+$//' | sed ':a;N;$!ba;s/\n+$//'
}

validate_lock_file_schema() {
    local lock_file="$1"
    jq -e '.sections and (.sections | type == "object")' "$lock_file" >/dev/null 2>&1
}

validate_locked_sections_against_file() {
    local lock_file="$1"
    local target_file="$2"
    local label="$3"
    local heading expected actual

    if ! validate_lock_file_schema "$lock_file"; then
        add_failure "${label} 缺少可校验的 sections 快照"
        return 0
    fi

    while IFS= read -r heading; do
        [ -n "$heading" ] || continue
        expected=$(jq -r --arg heading "$heading" '.sections[$heading]' "$lock_file")
        actual=$(extract_section_by_name "$target_file" "$heading" 2)
        if [ "$(normalize_text "$expected")" != "$(normalize_text "$actual")" ]; then
            add_failure "${label} 与当前文档不一致：${heading}"
        fi
    done < <(jq -r '.sections | keys[]' "$lock_file")

    return 0
}

validate_locked_field_drift() {
    local brief_lock prd_files prd_file prd_lock

    brief_lock="$FEATURE_DIR/brief.lock.json"
    [ -f "$brief_lock" ] && validate_locked_sections_against_file "$brief_lock" "$BRIEF_FILE" "brief.lock.json"

    prd_files=$(find "$FEATURE_DIR" -type f -name 'prd.md' | rg '/phase-[0-9]+/prd\.md$' || true)
    while IFS= read -r prd_file; do
        [ -n "$prd_file" ] || continue
        prd_lock="${prd_file%/prd.md}/prd.lock.json"
        [ -f "$prd_lock" ] && validate_locked_sections_against_file "$prd_lock" "$prd_file" "${prd_lock##*/}"
    done <<< "$prd_files"

    return 0
}

if ! should_run_gate; then
    exit 0
fi

validate_director_handoff_preconditions
validate_locked_field_drift
output_failures "Product-manager handoff 检查未通过" "$FEATURE_DIR"

printf '%s' "$INPUT" | bash "$LEGACY_PRODUCT_CHECK"
