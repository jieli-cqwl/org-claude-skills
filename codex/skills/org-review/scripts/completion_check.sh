#!/bin/bash
# 代码审查报告完整性自动检查脚本
# 触发时机: review skill-local Stop
# 功能: 检查 code-review-report.md 的十维审查覆盖与结论完整性

set -euo pipefail

source "$HOME/.claude/hooks/lib/common.sh"
hook_init

# --- Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/)?code-review-report\.md'
resolve_feature_dir "docs/*/phase-*/code-review-report.md" "$TRANSCRIPT_PATTERN" "code-review-report.md" "docs/*/phase-*"
output_failures "代码审查报告完整性检查未通过" ""

# --- PRD 驱动工作区定位 ---
resolve_phase_work_dir_from_prd "$FEATURE_DIR" "code-review-report.md"
WORK_DIR="$PHASE_WORK_DIR"

REPORT_FILE="$WORK_DIR/code-review-report.md"

# R1: code-review-report.md 存在且非空
if [ ! -f "$REPORT_FILE" ]; then
    add_failure "R1: code-review-report.md 不存在：$REPORT_FILE"
elif [ ! -s "$REPORT_FILE" ]; then
    add_failure "R1: code-review-report.md 为空：$REPORT_FILE"
fi

if [ ! -f "$REPORT_FILE" ] || [ ! -s "$REPORT_FILE" ]; then
    output_failures "代码审查报告完整性检查未通过" "$WORK_DIR"
    exit 0
fi

# R2: 十维审查全覆盖
DIMENSIONS=("正确性" "安全性" "错误处理" "并发/状态" "设计" "测试覆盖" "注释准确性" "向后兼容" "性能" "可观测性")
for dim in "${DIMENSIONS[@]}"; do
    if ! grep -qF "$dim" "$REPORT_FILE" 2>/dev/null; then
        add_failure "R2: 审查报告缺少维度覆盖：${dim}"
    fi
done

# R3: REVIEW_A + REVIEW_B + REVIEW_C 结论存在
if ! grep -qE 'REVIEW_A_(OK|ISSUE)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R3: 缺少 REVIEW_A 结论（REVIEW_A_OK/REVIEW_A_ISSUE）"
fi
if ! grep -qE 'REVIEW_B_(OK|ISSUE)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R3: 缺少 REVIEW_B 结论（REVIEW_B_OK/REVIEW_B_ISSUE）"
fi
if ! grep -qE 'REVIEW_C_(OK|ISSUE)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R3: 缺少 REVIEW_C 结论（REVIEW_C_OK/REVIEW_C_ISSUE）"
fi

# R4: 每条 finding 有 file_path:line_number（用结构化标记触发，避免"没有问题"等否定句误报）
FINDING_COUNT=$(grep -cE '(^#{2,3}[[:space:]].*Finding|^#{2,3}[[:space:]].*发现|CR-[0-9]+|FINDING-[0-9]+)' "$REPORT_FILE" 2>/dev/null || true)
if [ "$FINDING_COUNT" -gt 0 ]; then
    FILE_LINE_COUNT=$(grep -cE '[a-zA-Z0-9_/.-]+\.[a-z]+:[0-9]+' "$REPORT_FILE" 2>/dev/null || true)
    if [ "$FILE_LINE_COUNT" -eq 0 ]; then
        add_failure "R4: 审查报告有 finding 但缺少 file_path:line_number 证据"
    fi
fi

# R5: 每条 finding 置信度 >= 80
LOW_CONFIDENCE=$(grep -oE '置信度[[:space:]]*[:：][[:space:]]*[0-9]+' "$REPORT_FILE" 2>/dev/null \
    | grep -oE '[0-9]+$' \
    | awk '$1 < 80 { print }' || true)
if [ -n "$LOW_CONFIDENCE" ]; then
    add_failure "R5: 存在置信度 < 80 的 finding 被正式报告（值：$(echo "$LOW_CONFIDENCE" | tr '\n' ',' | sed 's/,$//')）"
fi

# R6: >= 2 个已排除问题（按稳定 ID 计数，避免章节标题"排除"膨胀计数）
EXCLUDED_ID_COUNT=$({ grep -oE 'EP-[0-9]+' "$REPORT_FILE" 2>/dev/null || true; } | sort -u | wc -l | tr -d ' ')
if [ "$EXCLUDED_ID_COUNT" -lt 2 ]; then
    # 回退：无 EP-NNN 编号时，按"排除"条目行数估算
    EXCLUDED_LINE_COUNT=$(grep -cE '^[[:space:]]*[-*][[:space:]].*(排除|ruled out|excluded)' "$REPORT_FILE" 2>/dev/null || true)
    if [ "$EXCLUDED_LINE_COUNT" -lt 2 ]; then
        add_failure "R6: 已排除问题不足 2 个（EP-ID: ${EXCLUDED_ID_COUNT}，排除条目行: ${EXCLUDED_LINE_COUNT}），HARD-GATE 4 要求至少 2 个"
    fi
fi

# R7: 结论为 APPROVE/REQUEST_CHANGES/COMMENT 之一
if ! grep -qE '(APPROVE|REQUEST_CHANGES|COMMENT)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "R7: 缺少最终审查结论（APPROVE/REQUEST_CHANGES/COMMENT）"
fi

# R8: 迭代检查（覆盖自评 + 审查轮次 + shallow pass 检测）
check_review_iteration "$REPORT_FILE" "代码审查"

# R9: shallow pass 额外检测（APPROVE + 全 OK 但无 Round 2 确认）
ALL_OK=true
for marker in REVIEW_A REVIEW_B REVIEW_C; do
    if grep -qE "${marker}_ISSUE" "$REPORT_FILE" 2>/dev/null; then
        ALL_OK=false
        break
    fi
done
if $ALL_OK && grep -qE 'APPROVE' "$REPORT_FILE" 2>/dev/null; then
    if ! grep -qE '(经 Round 2 确认|经对抗审查确认|Round 2.*收敛)' "$REPORT_FILE" 2>/dev/null; then
        add_failure "R9: APPROVE + 全组 OK 但缺少 Round 2 确认声明（疑似 shallow pass）"
    fi
fi

# R10: Critical/High findings 必须有 Verification 标记
HAS_CRITICAL_HIGH=$(grep -ciE '\b(Critical|High)\b' "$REPORT_FILE" 2>/dev/null || true)
if [ "$HAS_CRITICAL_HIGH" -gt 0 ]; then
    HAS_VERIFICATION=$(grep -ciE '\b(Verified|False Positive|Inconclusive)\b' "$REPORT_FILE" 2>/dev/null || true)
    if [ "$HAS_VERIFICATION" -eq 0 ]; then
        add_failure "R10: 存在 Critical/High finding 但缺少 Verification 标记（Verified/False Positive/Inconclusive）"
    fi
fi

output_failures "代码审查报告完整性检查未通过" "$WORK_DIR"
exit 0
