#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
product-director/completion_check.sh — Director 基线冻结检查脚本
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

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(brief\.md|phase-[0-9]+/prd\.md)'
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
output_failures "Director 基线检查未通过" ""

BRIEF_FILE="$FEATURE_DIR/brief.md"
REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PRODUCT_ARTIFACT_CONTRACT="$REPO_ROOT/contracts/product-artifacts.yaml"

load_product_artifact_contract() {
    local contract_key="$1"
    [ -f "$PRODUCT_ARTIFACT_CONTRACT" ] || return 0

    awk -v key="$contract_key" '
        $0 ~ "^[[:space:]]{2}" key ":" { in_key = 1; next }
        in_key && $0 ~ "^[[:space:]]{2}[A-Za-z0-9_-]+:" { exit }
        in_key && $0 ~ "^[[:space:]]{6}-[[:space:]]+" {
            sub(/^[[:space:]]{6}-[[:space:]]+/, "", $0)
            gsub(/^"|"$/, "", $0)
            print
        }
    ' "$PRODUCT_ARTIFACT_CONTRACT"
}

BRIEF_LOCK_REQUIRED_HEADINGS=()
while IFS= read -r _heading; do
    [ -n "$_heading" ] && BRIEF_LOCK_REQUIRED_HEADINGS+=("$_heading")
done < <(load_product_artifact_contract "brief_lock")

PRD_LOCK_REQUIRED_HEADINGS=()
while IFS= read -r _heading; do
    [ -n "$_heading" ] && PRD_LOCK_REQUIRED_HEADINGS+=("$_heading")
done < <(load_product_artifact_contract "prd_lock")

if [ ! -f "$PRODUCT_ARTIFACT_CONTRACT" ]; then
    add_failure "缺少 product artifact contract：contracts/product-artifacts.yaml"
elif [ "${#BRIEF_LOCK_REQUIRED_HEADINGS[@]}" -eq 0 ] || [ "${#PRD_LOCK_REQUIRED_HEADINGS[@]}" -eq 0 ]; then
    add_failure "product artifact contract 缺少可用的 lock sections"
fi

should_run_gate() {
    if [ -z "${TOOL_NAME:-}" ]; then
        return 0
    fi
    if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
        return 1
    fi
    if [ -z "${TOOL_FILE_PATH:-}" ]; then
        return 0
    fi
    if [ "$(basename "$TOOL_FILE_PATH")" = "brief.md" ]; then
        return 0
    fi
    printf '%s' "$TOOL_FILE_PATH" | grep -qE 'phase-[0-9]+/prd\.md$'
}

director_confirmation_is_passed() {
    local section status
    section=$(extract_section_by_name "$BRIEF_FILE" "产品总监确认" 2)
    [ -n "$section" ] || return 1
    status=$(printf '%s\n' "$section" | sed -nE 's/^- 确认状态:[[:space:]]*(.*)$/\1/p' | head -1)
    case "$status" in
        已通过|通过|确认)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

validate_director_sections() {
    local section
    for section in "${BRIEF_LOCK_REQUIRED_HEADINGS[@]}"; do
        if ! grep -qF "## $section" "$BRIEF_FILE"; then
            add_failure "brief.md 缺少章节：## $section"
        fi
    done
}

validate_phase_prd_structure() {
    local prd_file="$1"
    local section
    for section in "${PRD_LOCK_REQUIRED_HEADINGS[@]}"; do
        if ! grep -qF "## $section" "$prd_file"; then
            add_failure "$(printf '%s' "$prd_file" | grep -oE 'phase-[0-9]+/prd\.md') 缺少章节：## $section"
        fi
    done
}

validate_director_confirmation() {
    local section status confirm_time
    section=$(extract_section_by_name "$BRIEF_FILE" "产品总监确认" 2)
    if [ -z "$section" ]; then
        add_failure "brief.md 缺少产品总监确认节"
        return 0
    fi

    status=$(printf '%s\n' "$section" | sed -nE 's/^- 确认状态:[[:space:]]*(.*)$/\1/p' | head -1)
    confirm_time=$(printf '%s\n' "$section" | sed -nE 's/^- 确认时间:[[:space:]]*(.*)$/\1/p' | head -1)

    case "$status" in
        已通过|通过|确认)
            ;;
        *)
            add_failure "产品总监确认状态非法（需为 已通过/通过/确认）"
            ;;
    esac

    if ! is_valid_confirmation_time "$confirm_time"; then
        add_failure "产品总监确认时间缺少有效时间（需使用 YYYY-MM-DD HH:mm）"
    fi
}

validate_brief_lock_snapshot() {
    local brief_lock="$FEATURE_DIR/brief.lock.json"
    [ -f "$brief_lock" ] || add_failure "缺少 brief.lock.json"
    [ -s "$brief_lock" ] || add_failure "brief.lock.json 为空"
}

validate_phase_prd_lock_snapshots() {
    local prd_files prd_file lock_file
    prd_files=$(find "$FEATURE_DIR" -type f -name 'prd.md' | rg '/phase-[0-9]+/prd\.md$' || true)
    if [ -z "$prd_files" ]; then
        add_failure "缺少 phase-{N}/prd.md"
        return 0
    fi

    while IFS= read -r prd_file; do
        [ -n "$prd_file" ] || continue
        validate_phase_prd_structure "$prd_file"
        lock_file="${prd_file%/prd.md}/prd.lock.json"
        [ -f "$lock_file" ] || add_failure "缺少 $(printf '%s' "$prd_file" | grep -oE 'phase-[0-9]+/prd\.md' | sed 's#/prd\.md$#/prd.lock.json#')"
        [ -s "$lock_file" ] || add_failure "${lock_file##*/} 为空"
    done <<< "$prd_files"
}

if ! should_run_gate; then
    exit 0
fi

if [ ! -f "$BRIEF_FILE" ]; then
    add_failure "Brief 文档不存在：$BRIEF_FILE"
elif [ ! -s "$BRIEF_FILE" ]; then
    add_failure "Brief 文档为空：$BRIEF_FILE"
else
    validate_director_sections
fi

if [ -n "${TOOL_FILE_PATH:-}" ] && [ -f "$TOOL_FILE_PATH" ] && printf '%s' "$TOOL_FILE_PATH" | grep -qE 'phase-[0-9]+/prd\.md$'; then
    validate_phase_prd_structure "$TOOL_FILE_PATH"
fi

output_failures "Director 基线检查未通过（轻量检查）" "$FEATURE_DIR"

if ! director_confirmation_is_passed; then
    exit 0
fi

validate_director_confirmation
validate_brief_lock_snapshot
validate_phase_prd_lock_snapshots

output_failures "Director 基线检查未通过" "$FEATURE_DIR"
