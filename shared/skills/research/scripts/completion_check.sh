#!/bin/bash
# research/completion_check.sh — 调研报告呈现模式完整性检查脚本
# 触发时机: research skill-local Stop
# 功能: 检查 research-report.md 是否声明调研/呈现模式，并满足 profile 关键章节顺序

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
research/completion_check.sh — 调研报告呈现模式完整性检查脚本
触发时机: research skill-local Stop
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

# shellcheck source=shared/hooks/lib/common.sh
source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
hook_init

resolve_feature_dir "docs/*/research-report.md" 'docs/[^"[:space:]{}]+/research-report\.md' "research-report.md"
output_failures "research 调研报告完整性检查未通过" ""

REPORT_FILE="$FEATURE_DIR/research-report.md"

if [ ! -f "$REPORT_FILE" ]; then
    add_failure "RS1: research-report.md 不存在：$REPORT_FILE"
elif [ ! -s "$REPORT_FILE" ]; then
    add_failure "RS1: research-report.md 为空：$REPORT_FILE"
fi

if [ ! -f "$REPORT_FILE" ] || [ ! -s "$REPORT_FILE" ]; then
    output_failures "research 调研报告完整性检查未通过" "$FEATURE_DIR"
    exit 0
fi

RESEARCH_MODE=$(grep -E '^> 调研模式：' "$REPORT_FILE" 2>/dev/null | head -1 | sed -E 's/^> 调研模式：[[:space:]]*//')
PRESENTATION_PROFILE=$(grep -E '^> 呈现模式：' "$REPORT_FILE" 2>/dev/null | head -1 | sed -E 's/^> 呈现模式：[[:space:]]*//')

[ -n "$RESEARCH_MODE" ] || add_failure "RS2: 缺少调研模式声明（格式：> 调研模式：selection|analysis|discovery）"
[ -n "$PRESENTATION_PROFILE" ] || add_failure "RS2: 缺少呈现模式声明（格式：> 呈现模式：decision|understanding|audit）"

if [ -n "$RESEARCH_MODE" ] && ! printf '%s' "$RESEARCH_MODE" | grep -qE '^(selection|analysis|discovery)$'; then
    add_failure "RS2: 调研模式非法：$RESEARCH_MODE"
fi

if [ -n "$PRESENTATION_PROFILE" ] && ! printf '%s' "$PRESENTATION_PROFILE" | grep -qE '^(decision|understanding|audit)$'; then
    add_failure "RS2: 呈现模式非法：$PRESENTATION_PROFILE"
fi

section_line() {
    local file="$1"
    local section="$2"
    local line
    line=$(grep -n "^## ${section}\$" "$file" 2>/dev/null | head -1 | cut -d: -f1 || true)
    if [ -n "$line" ]; then
        printf '%s\n' "$line"
    else
        printf '0\n'
    fi
}

require_order() {
    local file="$1"
    local label="$2"
    shift 2

    local prev=0 current section
    for section in "$@"; do
        current=$(section_line "$file" "$section")
        if [ "$current" -eq 0 ]; then
            add_failure "RS3: ${label} 缺少章节：## ${section}"
            continue
        fi
        if [ "$prev" -ne 0 ] && [ "$current" -le "$prev" ]; then
            add_failure "RS3: ${label} 章节顺序错误：## ${section}"
        fi
        prev="$current"
    done
}

require_after() {
    local anchor="$1"
    local current="$2"
    local label="$3"
    if [ "$anchor" -ne 0 ] && [ "$current" -ne 0 ] && [ "$current" -lt "$anchor" ]; then
        add_failure "RS3: ${label}"
    fi
}

require_order "$REPORT_FILE" "shared audit appendix" \
    "独立挑战记录" \
    "检索路径与覆盖证明" \
    "项目上下文"

appendix_start=$(section_line "$REPORT_FILE" "独立挑战记录")

case "${PRESENTATION_PROFILE:-}" in
    decision)
        require_order "$REPORT_FILE" "decision profile" \
            "这次要回答的问题" \
            "当前判断" \
            "决定性理由" \
            "最大风险与保留意见" \
            "建议动作"
        action_line=$(section_line "$REPORT_FILE" "建议动作")
        require_after "$action_line" "$appendix_start" "decision profile 章节顺序错误：共享审计层 不能早于 建议动作"
        ;;
    understanding)
        require_order "$REPORT_FILE" "understanding profile" \
            "这是什么" \
            "为什么值得关注" \
            "核心机制与关键差异" \
            "适用边界" \
            "如果只记住三件事"
        recap_line=$(section_line "$REPORT_FILE" "如果只记住三件事")
        require_after "$recap_line" "$appendix_start" "understanding profile 章节顺序错误：共享审计层 不能早于 如果只记住三件事"
        ;;
    audit)
        require_order "$REPORT_FILE" "audit profile" \
            "当前判断" \
            "关键论点挑战表"
        challenge_line=$(section_line "$REPORT_FILE" "关键论点挑战表")
        require_after "$challenge_line" "$appendix_start" "audit profile 章节顺序错误：共享审计层 不能早于 关键论点挑战表"
        ;;
esac

output_failures "research 调研报告完整性检查未通过" "$REPORT_FILE"
exit 0
