#!/bin/bash
# 开发报告完整性自动检查脚本
# 触发时机: developer skill-local Stop
# 功能: 精确定位当前 feature，并检查 developer-report 的章节完整性与自测证据
# 版本: v2.0 2026-03-16

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'USAGE'
developer/completion_check.sh — 开发报告完整性自动检查脚本
触发时机: developer skill-local Stop
输入: stdin JSON (cwd, session_id, transcript_path)
输出: stdout JSON decision (block/allow) + stderr 诊断信息
USAGE
    exit 0
fi

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
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

    # C2: TDD 证据索引（替代旧的 RED/GREEN 完整输出粘贴）
    # 兼容旧格式：接受 "### TDD 证据索引" 或旧的 "### RED 阶段完整输出"
    if ! grep -q '### TDD 证据索引' "$report" 2>/dev/null && \
       ! grep -q '### RED 阶段完整输出' "$report" 2>/dev/null; then
        add_failure "[${label}] 缺少 TDD 证据章节：### TDD 证据索引（或旧格式 ### RED 阶段完整输出）"
    fi

    # C2.5: TDD 证据索引按行验证（或旧格式 RED/GREEN 内容非空）
    local tdd_index_content
    tdd_index_content=$(extract_section_content "$report" "### TDD 证据索引" 3)
    if ! has_substance "$tdd_index_content"; then
        # 回退检查旧格式：RED 和 GREEN 都必须存在且有内容
        local red_content green_content
        red_content=$(extract_section_content "$report" "### RED 阶段完整输出" 3)
        green_content=$(extract_section_content "$report" "### GREEN 阶段完整输出" 3)
        if ! has_substance "$red_content"; then
            add_failure "[${label}] TDD 证据索引（或 RED 阶段完整输出）章节无实质内容"
        fi
        if ! has_substance "$green_content"; then
            add_failure "[${label}] GREEN 阶段完整输出章节无实质内容"
        fi
    else
        # 新格式：用 awk 逐行解析表格，提取 RED/GREEN 行的 SHA
        # 有效 = 阶段列含 RED/GREEN 且 SHA 列为 7+ 位纯小写 hex 且在 git 中真实存在
        local tdd_rows
        tdd_rows=$(printf '%s\n' "$tdd_index_content" | awk -F'|' '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            /^\|/ {
                phase = trim($2)
                sha   = trim($3)
                if (phase == "" || phase == "阶段" || phase ~ /^-+$/) next
                if (sha ~ /^-+$/) next
                if (sha !~ /^[0-9a-f]{7,40}$/) next
                if (phase ~ /RED|red/)   print "RED " sha
                if (phase ~ /GREEN|green/) print "GREEN " sha
            }
        ')

        local tdd_red_ok=0 tdd_green_ok=0
        if [ -n "$tdd_rows" ] && git rev-parse --show-toplevel >/dev/null 2>&1; then
            while read -r row_phase row_sha; do
                [ -n "$row_sha" ] || continue
                # 验证 SHA 在 git 中真实存在
                if git rev-parse --verify "${row_sha}^{commit}" >/dev/null 2>&1; then
                    case "$row_phase" in
                        RED)   tdd_red_ok=$((tdd_red_ok + 1)) ;;
                        GREEN) tdd_green_ok=$((tdd_green_ok + 1)) ;;
                    esac
                else
                    echo "[WARN] [${label}] TDD 证据索引中 ${row_phase} 行的 SHA ${row_sha} 在 git 中不存在" >&2
                fi
            done <<< "$tdd_rows"
        elif [ -n "$tdd_rows" ]; then
            # 非 Git 环境无法验证 Commit SHA，现行合同要求 fail-close
            tdd_red_ok=$(printf '%s\n' "$tdd_rows" | grep -c '^RED ' || true)
            tdd_green_ok=$(printf '%s\n' "$tdd_rows" | grep -c '^GREEN ' || true)
            add_failure "[${label}] 当前环境不是 Git 仓库，无法验证 TDD 证据索引中的 Commit SHA；现行合同要求可追溯的 Commit SHA，非 Git 环境不能通过"
        fi

        if [ "$tdd_red_ok" -lt 1 ]; then
            add_failure "[${label}] TDD 证据索引缺少有效 RED 行（需含可追溯的 Commit SHA）"
        fi
        if [ "$tdd_green_ok" -lt 1 ]; then
            add_failure "[${label}] TDD 证据索引缺少有效 GREEN 行（需含可追溯的 Commit SHA）"
        fi
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

    # --- Git-based TDD 验证（warning 级别，不阻断） ---
    # W1: 报告声明的文件与 git 工作树 uncommitted 变更一致性比对
    # 仅在工作树有 uncommitted 变更时运行（clean tree 场景跳过——文件已 commit，无法从 diff 推断）
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        local all_uncommitted
        all_uncommitted=$(git diff --name-only HEAD 2>/dev/null || true)

        if [ -n "$all_uncommitted" ]; then
            local report_declared_files
            report_declared_files=$(printf '%s\n' "$file_rows" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); if($1!="") print $1}' | sort -u || true)

            if [ -n "$report_declared_files" ]; then
                local missing_from_git
                missing_from_git=""
                while IFS= read -r declared_file; do
                    [ -n "$declared_file" ] || continue
                    # 检查声明的文件是否在 uncommitted 变更或 untracked 文件中
                    if ! printf '%s\n' "$all_uncommitted" | grep -qxF "$declared_file" && \
                       ! git ls-files --others --exclude-standard -- "$declared_file" 2>/dev/null | grep -q .; then
                        missing_from_git="${missing_from_git:+$missing_from_git
}$declared_file"
                    fi
                done <<< "$report_declared_files"

                if [ -n "$missing_from_git" ]; then
                    local missing_count
                    missing_count=$(printf '%s\n' "$missing_from_git" | sed '/^$/d' | wc -l | tr -d ' ')
                    echo "[WARN] [${label}] 报告声明了 ${missing_count} 个文件但 git 工作树中无对应 uncommitted 变更" >&2
                fi
            fi
        fi
    fi

    # W2: Test-first 提交顺序验证（test 文件的首次 commit 应早于或等于实现文件）
    if git rev-parse --show-toplevel >/dev/null 2>&1 && [ -n "$file_rows" ]; then
        local w2_test_files="" w2_impl_files=""
        while IFS='|' read -r f_path f_op f_ac f_in_scope; do
            [ -n "$f_path" ] || continue
            f_path=$(printf '%s' "$f_path" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
            if printf '%s' "$f_path" | grep -qiE '(test|spec|__tests__|_test\.|\.test\.|\.spec\.)'; then
                w2_test_files="${w2_test_files:+$w2_test_files
}$f_path"
            elif printf '%s' "$f_path" | grep -qE '\.(js|ts|jsx|tsx|py|go|rs|java|rb|sh|vue|svelte)$'; then
                w2_impl_files="${w2_impl_files:+$w2_impl_files
}$f_path"
            fi
        done <<< "$file_rows"

        if [ -n "$w2_test_files" ] && [ -n "$w2_impl_files" ]; then
            local earliest_test_ts="" earliest_impl_ts=""

            while IFS= read -r tf; do
                [ -n "$tf" ] || continue
                local ts
                ts=$(git log --format=%ct --diff-filter=A -- "$tf" 2>/dev/null | tail -1 || true)
                if [ -n "$ts" ]; then
                    if [ -z "$earliest_test_ts" ] || [ "$ts" -lt "$earliest_test_ts" ]; then
                        earliest_test_ts=$ts
                    fi
                fi
            done <<< "$w2_test_files"

            while IFS= read -r imf; do
                [ -n "$imf" ] || continue
                local ts
                ts=$(git log --format=%ct --diff-filter=A -- "$imf" 2>/dev/null | tail -1 || true)
                if [ -n "$ts" ]; then
                    if [ -z "$earliest_impl_ts" ] || [ "$ts" -lt "$earliest_impl_ts" ]; then
                        earliest_impl_ts=$ts
                    fi
                fi
            done <<< "$w2_impl_files"

            if [ -n "$earliest_test_ts" ] && [ -n "$earliest_impl_ts" ]; then
                if [ "$earliest_impl_ts" -lt "$earliest_test_ts" ]; then
                    echo "[WARN] [${label}] Test-first 顺序异常：实现文件首次 commit (ts=${earliest_impl_ts}) 早于测试文件 (ts=${earliest_test_ts})" >&2
                fi
            fi
        fi
    fi

    # W3: 测试命令格式验证（仅检查报告中是否记录了合法的测试命令，不执行）
    # Why 不执行：报告是 LLM 生成的 Markdown，不是可信源，不应交给 bash -c
    local test_cmd=""
    test_cmd=$(extract_section_content "$report" "#### 全量测试回归" 4 \
        | sed -nE 's/^-[[:space:]]*命令[[:space:]]*:[[:space:]]*`(.+)`[[:space:]]*$/\1/p' | head -1 || true)

    if [ -z "$test_cmd" ]; then
        echo "[WARN] [${label}] 全量测试回归章节未记录测试命令（缺少 - 命令: \`...\` 行）" >&2
    elif ! printf '%s' "$test_cmd" | grep -qE '^(npm[[:space:]]+test|npx[[:space:]]|yarn[[:space:]]+test|pnpm[[:space:]]+test|pytest|python[[:space:]]+-m[[:space:]]+pytest|go[[:space:]]+test|cargo[[:space:]]+test|bash[[:space:]]+tests/|jest|vitest|mocha|make[[:space:]]+test)'; then
        echo "[WARN] [${label}] 测试命令不匹配已知测试框架模式：${test_cmd}" >&2
    fi
}

while IFS= read -r report_path; do
    [ -n "$report_path" ] || continue
    check_report "$report_path"
done <<< "$REPORT_PATHS"

output_failures "开发报告完整性检查未通过" ""
exit 0
