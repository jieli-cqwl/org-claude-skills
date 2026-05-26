#!/bin/bash
# 安全扫描报告完整性自动检查脚本
# 触发时机: security skill-local Stop
# 功能: 检查 docs/reports--security/ 报告的工具执行证据与 OWASP 覆盖

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
security/completion_check.sh — 安全扫描报告完整性自动检查脚本
触发时机: security skill-local Stop
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
hook_init

# --- 报告文件定位 ---

REPORT_DIR="docs/reports--security"
REPORT_FILE=""

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    REPORT_FILE=$(grep -oE 'docs/reports--security/[^"[:space:]{}]+\.md' "$TRANSCRIPT_PATH" 2>/dev/null \
        | sed -E '/\{[^}]+\}/d' | sort -u | tail -1 || true)
fi

if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
    REPORT_FILE=$(find_report_by_pattern "$REPORT_DIR" "*.md")
fi

# SC1: 报告存在于 docs/reports--security/
if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
    add_failure "SC1: docs/reports--security/ 下无安全扫描报告"
    output_failures "安全扫描报告完整性检查未通过" ""
    exit 0
fi

if [ ! -s "$REPORT_FILE" ]; then
    add_failure "SC1: 安全扫描报告为空：$REPORT_FILE"
    output_failures "安全扫描报告完整性检查未通过" ""
    exit 0
fi

# SC2: 至少一个工具执行证据（Bandit/Semgrep/Gitleaks）
if ! grep -qEi '(bandit|semgrep|gitleaks|pip-audit|npm audit)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "SC2: 缺少专业工具执行证据（Bandit/Semgrep/Gitleaks 至少一个）"
fi

# SC3: OWASP Top 10 覆盖
if ! grep -qEi '(OWASP|owasp|Top.?10|A0[1-9]|A10)' "$REPORT_FILE" 2>/dev/null; then
    add_failure "SC3: 缺少 OWASP Top 10 覆盖分析"
fi

# SC4: 漏洞有 file_path:line_number + 修复代码（用结构化标记触发，避免"无严重漏洞"等否定句误报）
VULN_COUNT=$(grep -cE '(^#{2,3}[[:space:]].*漏洞|CVE-[0-9]|CWE-[0-9]|^[-*][[:space:]].*(高危|中危|低危))' "$REPORT_FILE" 2>/dev/null || true)
if [ "$VULN_COUNT" -gt 0 ]; then
    FILE_LINE_COUNT=$(grep -cE '[a-zA-Z0-9_/.-]+\.[a-z]+:[0-9]+' "$REPORT_FILE" 2>/dev/null || true)
    if [ "$FILE_LINE_COUNT" -eq 0 ]; then
        add_failure "SC4: 报告有漏洞但缺少 file_path:line_number 定位"
    fi

    FIX_CODE_COUNT=$(grep -cE '(修复|fix|Before|After|```|diff)' "$REPORT_FILE" 2>/dev/null || true)
    if [ "$FIX_CODE_COUNT" -eq 0 ]; then
        add_failure "SC4: 报告有漏洞但缺少修复代码"
    fi
fi

output_failures "安全扫描报告完整性检查未通过" "$REPORT_FILE"
exit 0
