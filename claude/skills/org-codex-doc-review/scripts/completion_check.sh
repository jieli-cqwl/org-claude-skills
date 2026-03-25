#!/usr/bin/env bash
# Codex 文档审查报告完整性自动检查脚本
# 触发时机: codex-doc-review skill-local Stop
# 功能: 检查 codex-doc-review-report.md 的存在性与 4 个必需 section 完整性

set -euo pipefail

source "$(dirname "$0")/../../../hooks/lib/common.sh"
hook_init

# --- Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/unit-[0-9]+/)?codex-doc-review-report\.md'
resolve_feature_dir "docs/*/phase-*/unit-*/codex-doc-review-report.md" "$TRANSCRIPT_PATTERN" "codex-doc-review-report.md" "docs/*/phase-*/unit-*"
output_failures "Codex 文档审查报告完整性检查未通过" ""

# --- PRD 驱动工作区定位 ---
resolve_work_dir_from_prd "$FEATURE_DIR" "codex-doc-review-report.md"
WORK_DIR="$UNIT_WORK_DIR"

REPORT_FILE="$WORK_DIR/codex-doc-review-report.md"

# R1: codex-doc-review-report.md 存在且非空
if [ ! -f "$REPORT_FILE" ]; then
    add_failure "R1: codex-doc-review-report.md 不存在：$REPORT_FILE"
elif [ ! -s "$REPORT_FILE" ]; then
    add_failure "R1: codex-doc-review-report.md 为空：$REPORT_FILE"
fi

if [ ! -f "$REPORT_FILE" ] || [ ! -s "$REPORT_FILE" ]; then
    output_failures "Codex 文档审查报告完整性检查未通过" "$WORK_DIR"
    exit 0
fi

# R2: 4 个必需 section 完整性检查
REQUIRED_SECTIONS=("## Findings" "## DECEPTION" "## Dimensions" "## Summary")

for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -qF "$section" "$REPORT_FILE" 2>/dev/null; then
        add_failure "R2: 报告缺少必需 section：${section}"
    fi
done

# R3: 报告包含状态码
if ! grep -qE '(REVIEW_OK|REVIEW_ISSUE|CODEX_NOT_AVAILABLE|CODEX_OUTPUT_INVALID|DOCUMENT_TOO_LARGE|DOCUMENT_EMPTY)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R3: 报告缺少状态码（REVIEW_OK/REVIEW_ISSUE/CODEX_NOT_AVAILABLE/CODEX_OUTPUT_INVALID/DOCUMENT_TOO_LARGE/DOCUMENT_EMPTY）"
fi

# R4: 报告包含元信息
if ! grep -qE '(审查文件|file)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R4: 报告缺少审查文件元信息"
fi

if ! grep -qE '(审查阶段|stage)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R4: 报告缺少审查阶段元信息"
fi

if ! grep -qE '(审查时间|time|timestamp)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R4: 报告缺少审查时间元信息"
fi

# R5: DECEPTION 章节检查
if grep -qF "## DECEPTION" "$REPORT_FILE" 2>/dev/null; then
    # DECEPTION 章节存在时，必须有内容（表格行或"无"或"DECEPTION 维度未覆盖"标注）
    DECEPTION_SECTION=$(sed -n '/^## DECEPTION/,/^## /p' "$REPORT_FILE" | head -n -1)
    if [ -z "$DECEPTION_SECTION" ]; then
        DECEPTION_SECTION=$(sed -n '/^## DECEPTION/,$p' "$REPORT_FILE")
    fi
    DECEPTION_LINE_COUNT=$(printf '%s\n' "$DECEPTION_SECTION" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    if [ "$DECEPTION_LINE_COUNT" -lt 2 ]; then
        add_failure "R5: DECEPTION 章节缺少内容（至少需要表头或标注）"
    fi
fi

output_failures "Codex 文档审查报告完整性检查未通过" "$WORK_DIR"
exit 0
