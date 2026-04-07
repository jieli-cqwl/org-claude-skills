#!/bin/bash
# 代码扫描报告完整性自动检查脚本
# 触发时机: scan skill-local Stop
# 功能: 检查 docs/reports/tech-debt/ 报告的维度覆盖与健康度评分

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
scan/completion_check.sh — 代码扫描报告完整性自动检查脚本
触发时机: scan skill-local Stop
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
hook_init

# --- 报告文件定位 ---

REPORT_DIR="docs/reports/tech-debt"
REPORT_FILE=""

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    REPORT_FILE=$(grep -oE 'docs/reports/tech-debt/[^"[:space:]{}]+\.md' "$TRANSCRIPT_PATH" 2>/dev/null \
        | sed -E '/\{[^}]+\}/d' | sort -u | tail -1 || true)
fi

if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
    REPORT_FILE=$(find_report_by_pattern "$REPORT_DIR" "*.md")
fi

# S1: 报告存在于 docs/reports/tech-debt/
if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
    add_failure "S1: docs/reports/tech-debt/ 下无扫描报告"
    output_failures "代码扫描报告完整性检查未通过" ""
    exit 0
fi

# S2: 报告非空且有实质内容
if [ ! -s "$REPORT_FILE" ]; then
    add_failure "S2: 扫描报告为空：$REPORT_FILE"
    output_failures "代码扫描报告完整性检查未通过" ""
    exit 0
fi

CONTENT_LINES=$(grep -cvE '^[[:space:]]*$' "$REPORT_FILE" 2>/dev/null || true)
if [ "$CONTENT_LINES" -lt 10 ]; then
    add_failure "S2: 扫描报告内容不足（仅 ${CONTENT_LINES} 行非空内容）"
fi

# S3: 6 个扫描维度全有结论
SCAN_DIMENSIONS=("铁律" "安全" "代码规范" "技术债" "Skills" "文档")
for dim in "${SCAN_DIMENSIONS[@]}"; do
    if ! grep -qF "$dim" "$REPORT_FILE" 2>/dev/null; then
        add_failure "S3: 扫描报告缺少维度覆盖：${dim}"
    fi
done

# S4: 健康度评分存在
if ! grep -qE '(健康度|评分|评级|score|rating|[0-9]+/100)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "S4: 扫描报告缺少健康度评分"
fi

# S5: 问题有 file_path:line_number（用标题行/列表项触发，避免"无问题"等否定句误报）
ISSUE_COUNT=$(grep -cE '(^#{2,3}[[:space:]].*(严重|警告|问题)|^[-*][[:space:]].*(Issue|CRITICAL|WARNING)|SCAN-[0-9]+)' "$REPORT_FILE" 2>/dev/null || true)
if [ "$ISSUE_COUNT" -gt 0 ]; then
    FILE_LINE_COUNT=$(grep -cE '[a-zA-Z0-9_/.-]+\.[a-z]+:[0-9]+' "$REPORT_FILE" 2>/dev/null || true)
    if [ "$FILE_LINE_COUNT" -eq 0 ]; then
        add_failure "S5: 扫描报告有问题项但缺少 file_path:line_number 定位"
    fi
fi

output_failures "代码扫描报告完整性检查未通过" "$REPORT_FILE"
exit 0
