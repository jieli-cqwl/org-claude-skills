#!/usr/bin/env bash
# Codex 文档审查报告完整性自动检查脚本
# 触发时机: codex-doc-review skill-local Stop
# 功能: 解析 reviewed docs + scope -> canonical work_dir，并严格校验报告落点与内容

set -euo pipefail

source "$(dirname "$0")/../../../hooks/lib/common.sh"
hook_init

# codex-doc-review 的路径/内容错误必须持续阻断，不能被熔断放行。
HOOK_STRICT_BLOCK=1

resolve_codex_doc_review_context

if [ -z "$FEATURE_DIR" ] || [ -z "${CODEX_DOC_REVIEW_CANONICAL_WORK_DIR:-}" ]; then
    output_failures "Codex 文档审查报告完整性检查未通过" "${CODEX_DOC_REVIEW_CANONICAL_WORK_DIR:-<unresolved>}"
    exit 0
fi

REPORT_FILE="${CODEX_DOC_REVIEW_CANONICAL_WORK_DIR}/codex-doc-review-report.md"

# R1: canonical 报告存在且非空
if [ ! -f "$REPORT_FILE" ]; then
    add_failure "R1: canonical 报告不存在：$REPORT_FILE"
elif [ ! -s "$REPORT_FILE" ]; then
    add_failure "R1: canonical 报告为空：$REPORT_FILE"
fi

# R2: 报告只允许出现在 canonical work_dir
MISPLACED_REPORTS=""
while IFS= read -r report; do
    [ -n "$report" ] || continue
    [ "$report" = "$REPORT_FILE" ] && continue
    MISPLACED_REPORTS="${MISPLACED_REPORTS:+${MISPLACED_REPORTS}
}${report}"
done <<< "${CODEX_DOC_REVIEW_REPORT_CANDIDATES:-}"

if [ -n "$MISPLACED_REPORTS" ]; then
    add_failure "R2: 发现 misplaced/duplicate 报告，codex-doc-review-report.md 只能存在于 canonical 目录：$(printf '%s' "$MISPLACED_REPORTS" | tr '\n' ' ')"
fi

if [ ! -f "$REPORT_FILE" ] || [ ! -s "$REPORT_FILE" ]; then
    output_failures "Codex 文档审查报告完整性检查未通过" "$CODEX_DOC_REVIEW_CANONICAL_WORK_DIR"
    exit 0
fi

# R3: 4 个必需 section 完整性检查
REQUIRED_SECTIONS=("## Findings" "## DECEPTION" "## Dimensions" "## Summary")
for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -qF "$section" "$REPORT_FILE" 2>/dev/null; then
        add_failure "R3: 报告缺少必需 section：${section}"
    fi
done

# R4: 报告包含状态码
if ! grep -qE '(REVIEW_OK|REVIEW_ISSUE|CODEX_NOT_AVAILABLE|CODEX_OUTPUT_INVALID|DOCUMENT_TOO_LARGE|DOCUMENT_EMPTY)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R4: 报告缺少状态码（REVIEW_OK/REVIEW_ISSUE/CODEX_NOT_AVAILABLE/CODEX_OUTPUT_INVALID/DOCUMENT_TOO_LARGE/DOCUMENT_EMPTY）"
fi

# R5: 报告包含元信息
if ! grep -qE '(审查文件|file)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R5: 报告缺少审查文件元信息"
fi

if ! grep -qE '(审查阶段|stage|scope)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R5: 报告缺少审查阶段元信息"
fi

if ! grep -qE '(审查时间|time|timestamp|reviewed_at)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R5: 报告缺少审查时间元信息"
fi

# R6: DECEPTION 章节检查
if grep -qF "## DECEPTION" "$REPORT_FILE" 2>/dev/null; then
    DECEPTION_SECTION=$(sed -n '/^## DECEPTION/,/^## /p' "$REPORT_FILE" | sed '$d')
    if [ -z "$DECEPTION_SECTION" ]; then
        DECEPTION_SECTION=$(sed -n '/^## DECEPTION/,$p' "$REPORT_FILE")
    fi
    DECEPTION_LINE_COUNT=$(printf '%s\n' "$DECEPTION_SECTION" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    if [ "$DECEPTION_LINE_COUNT" -lt 2 ]; then
        add_failure "R6: DECEPTION 章节缺少内容（至少需要表头或标注）"
    fi
fi

output_failures "Codex 文档审查报告完整性检查未通过" "$CODEX_DOC_REVIEW_CANONICAL_WORK_DIR"
exit 0
