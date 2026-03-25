#!/bin/bash
# 开发报告完整性自动检查脚本
# 触发时机: developer skill-local Stop
# 功能: 精确定位当前 feature，并检查 developer-report 的章节完整性与自测证据
# 版本: v2.0 2026-03-16

set -euo pipefail

source "$HOME/.claude/hooks/lib/common.sh"
hook_init

# --- 定位报告文件（developer 特殊：定位报告文件而非 feature 目录） ---

collect_report_paths_from_transcript() {
    local transcript="$1"

    [ -n "$transcript" ] && [ -f "$transcript" ] || return 0

    grep -oE 'docs/[^/"[:space:]*{}]+/(phase-[0-9]+/unit-[0-9]+/)?developer-report-Task-[0-9]+\.md' "$transcript" 2>/dev/null \
        | sed -E '/\{[^}]+\}/d' \
        | sort -u || true
}

collect_report_paths_from_git() {
    if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
        return 0
    fi

    {
        git diff --name-only HEAD -- 'docs/*/developer-report-Task-*.md' 'docs/*/phase-*/unit-*/developer-report-Task-*.md' 2>/dev/null || true
        git ls-files --others --exclude-standard -- 'docs/*/developer-report-Task-*.md' 'docs/*/phase-*/unit-*/developer-report-Task-*.md' 2>/dev/null || true
    } | sort -u || true
}

REPORT_PATHS=""

TRANSCRIPT_REPORTS=$(collect_report_paths_from_transcript "$TRANSCRIPT_PATH")
GIT_REPORTS=$(collect_report_paths_from_git)

if [ -n "$TRANSCRIPT_REPORTS" ] && [ -n "$GIT_REPORTS" ]; then
    INTERSECTION=$(comm -12 \
        <(printf '%s\n' "$TRANSCRIPT_REPORTS" | sort) \
        <(printf '%s\n' "$GIT_REPORTS" | sort))
    if [ -n "$INTERSECTION" ]; then
        REPORT_PATHS="$INTERSECTION"
    else
        REPORT_PATHS="$TRANSCRIPT_REPORTS"
    fi
elif [ -n "$TRANSCRIPT_REPORTS" ]; then
    REPORT_PATHS="$TRANSCRIPT_REPORTS"
elif [ -n "$GIT_REPORTS" ]; then
    REPORT_PATHS="$GIT_REPORTS"
fi

REPORT_PATHS=$(printf '%s\n' "$REPORT_PATHS" | sed '/^$/d')

if [ -z "$REPORT_PATHS" ]; then
    add_failure "无法定位开发报告：transcript_path=${TRANSCRIPT_PATH:-<empty>}，session_id=${SESSION_ID:-<empty>}，且工作树中不存在 developer-report-Task-*.md"
    output_failures "开发报告完整性检查未通过" ""
fi

extract_file_change_rows() {
    local report="$1"
    local section
    section=$(extract_markdown_section "$report" "### 文件变更")
    printf '%s\n' "$section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            file = trim($2)
            op = trim($3)
            ac = trim($4)
            in_scope = trim($5)
            if (file == "" || file == "文件" || file ~ /^-+$/) next
            print file "|" op "|" ac "|" in_scope
        }
    '
}

# --- 逐文件检查 ---

check_report() {
    local report="$1"
    local label
    label=$(basename "$report" .md)

    # C1: 报告文件存在且非空
    if [ ! -f "$report" ]; then
        add_failure "[${label}] 报告不存在：$report"
        return
    fi

    if [ ! -s "$report" ]; then
        add_failure "[${label}] 报告为空：$report"
        return
    fi

    # C2: TDD 证据章节
    grep -q '### TDD 记录' "$report" 2>/dev/null \
        || add_failure "[${label}] 缺少 TDD 证据章节：### TDD 记录"

    grep -q '### RED 阶段完整输出' "$report" 2>/dev/null \
        || add_failure "[${label}] 缺少 TDD 证据章节：### RED 阶段完整输出"

    grep -q '### GREEN 阶段完整输出' "$report" 2>/dev/null \
        || add_failure "[${label}] 缺少 TDD 证据章节：### GREEN 阶段完整输出"

    # C2.5: RED/GREEN 阶段内容非空
    local red_content
    red_content=$(extract_section_content "$report" "### RED 阶段完整输出" 3)
    if ! has_substance "$red_content"; then
        add_failure "[${label}] RED 阶段完整输出章节无实质内容"
    fi

    local green_content
    green_content=$(extract_section_content "$report" "### GREEN 阶段完整输出" 3)
    if ! has_substance "$green_content"; then
        add_failure "[${label}] GREEN 阶段完整输出章节无实质内容"
    fi

    # C3: 自测结果章节
    grep -q '### 自测结果' "$report" 2>/dev/null \
        || add_failure "[${label}] 缺少自测结果章节：### 自测结果"

    # C4: 自测 5 层面子章节
    local subtests=("测试完备性审视" "全量测试回归" "静态分析" "功能集成冒烟" "E2E 端到端")
    for sub in "${subtests[@]}"; do
        grep -q "#### ${sub}" "$report" 2>/dev/null \
            || add_failure "[${label}] 缺少自测子章节：#### ${sub}"
    done

    # C5: 全量测试回归章节内容非空
    local regression_content
    regression_content=$(extract_section_content "$report" "#### 全量测试回归" 4)
    if ! has_substance "$regression_content"; then
        add_failure "[${label}] 全量测试回归章节无实质内容"
    fi

    # C6: 静态分析章节内容非空
    local static_content
    static_content=$(extract_section_content "$report" "#### 静态分析" 4)
    if ! has_substance "$static_content"; then
        add_failure "[${label}] 静态分析章节无实质内容"
    fi

    # C7: 冒烟/E2E 有结论（有内容或包含"不适用"）
    local smoke_content e2e_content
    smoke_content=$(extract_section_content "$report" "#### 功能集成冒烟" 4)
    if ! has_substance "$smoke_content"; then
        add_failure "[${label}] 功能集成冒烟章节既无结果也无不适用标注"
    fi

    e2e_content=$(extract_section_content "$report" "#### E2E 端到端" 4)
    if ! has_substance "$e2e_content"; then
        add_failure "[${label}] E2E 端到端章节既无结果也无不适用标注"
    fi

    # C8: 自审发现章节
    grep -q '### 自审发现' "$report" 2>/dev/null \
        || add_failure "[${label}] 缺少自审发现章节：### 自审发现"

    # C9: 文件变更章节
    grep -q '### 文件变更' "$report" 2>/dev/null \
        || add_failure "[${label}] 缺少文件变更章节：### 文件变更"

    # C10: 文件变更范围合规（developer 一期边界门禁）
    local file_rows file_row_count
    file_rows=$(extract_file_change_rows "$report")
    file_row_count=$(printf '%s\n' "$file_rows" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$file_row_count" -eq 0 ]; then
        add_failure "[${label}] 文件变更表缺少数据行"
    else
        while IFS='|' read -r f_path f_op f_ac f_in_scope; do
            [ -n "$f_path" ] || continue
            f_in_scope_norm=$(printf '%s' "$f_in_scope" | tr '[:lower:]' '[:upper:]')
            if [ "$f_in_scope_norm" = "否" ] || [ "$f_in_scope_norm" = "NO" ] || [ "$f_in_scope_norm" = "OUT-OF-SCOPE" ]; then
                add_failure "[${label}] 文件变更越界：${f_path} 标记为在范围外（${f_in_scope}）"
            fi
        done <<< "$file_rows"
    fi
}

while IFS= read -r report_path; do
    [ -n "$report_path" ] || continue
    check_report "$report_path"
done <<< "$REPORT_PATHS"

output_failures "开发报告完整性检查未通过" ""
exit 0
