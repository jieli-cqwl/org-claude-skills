#!/bin/bash
# 修复报告完整性自动检查脚本
# 触发时机: fix skill-local Stop
# 功能: 校验 fix-N.md 的诊断证据、failure_class、条件化修复证据与历史引用

set -euo pipefail

source "$HOME/.claude/hooks/lib/common.sh"
hook_init

# --- fix-N.md 文件定位 ---

FIX_FROM_TRANSCRIPT=""
if [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    FIX_FROM_TRANSCRIPT=$(grep -oE 'docs/[^/"[:space:]*{}]+/(phase-[0-9]+/unit-[0-9]+/)?fix-[0-9]+\.md' "$TRANSCRIPT_PATH" 2>/dev/null \
        | sed -E '/\{[^}]+\}/d' | sort -u || true)
fi

FIX_FROM_GIT=$({
    git diff --name-only HEAD -- 'docs/*/fix-*.md' 'docs/*/phase-*/unit-*/fix-*.md' 2>/dev/null || true
    git ls-files --others --exclude-standard -- 'docs/*/fix-*.md' 'docs/*/phase-*/unit-*/fix-*.md' 2>/dev/null || true
} | grep -E '^docs/[^/]+/(phase-[0-9]+/unit-[0-9]+/)?fix-[0-9]+\.md$' | sort -u || true)

FIX_FILES=""
if [ -n "$FIX_FROM_TRANSCRIPT" ] && [ -n "$FIX_FROM_GIT" ]; then
    INTERSECTION=$(comm -12 \
        <(printf '%s\n' "$FIX_FROM_TRANSCRIPT" | sort) \
        <(printf '%s\n' "$FIX_FROM_GIT" | sort))
    FIX_FILES="${INTERSECTION:-$FIX_FROM_TRANSCRIPT}"
elif [ -n "$FIX_FROM_TRANSCRIPT" ]; then
    FIX_FILES="$FIX_FROM_TRANSCRIPT"
elif [ -n "$FIX_FROM_GIT" ]; then
    FIX_FILES="$FIX_FROM_GIT"
fi

FIX_FILES=$(printf '%s\n' "$FIX_FILES" | sed '/^$/d')

if [ -z "$FIX_FILES" ]; then
    add_failure "无法定位修复报告：transcript_path=${TRANSCRIPT_PATH:-<empty>}，且工作树中不存在 docs/*/fix-*.md"
    output_failures "修复报告完整性检查未通过" ""
    exit 0
fi

WORK_DIR=$(printf '%s\n' "$FIX_FILES" | head -1 | sed -E 's#/fix-[0-9]+\.md$##')

has_root_cause_evidence() {
    local file="$1"
    grep -qE '[A-Za-z0-9_./-]+\.[A-Za-z0-9_]+:[0-9]+' "$file" 2>/dev/null
}

has_diagnosis_trace() {
    local file="$1"
    local has_phenomenon has_hypothesis has_validation
    has_phenomenon=false
    has_hypothesis=false
    has_validation=false

    grep -qiE '(现象|报错|错误|复现步骤|复现条件)' "$file" 2>/dev/null && has_phenomenon=true
    grep -qiE '(假设|候选根因)' "$file" 2>/dev/null && has_hypothesis=true
    grep -qiE '(验证方法|验证过程|排除|确认|未决)' "$file" 2>/dev/null && has_validation=true

    $has_phenomenon && $has_hypothesis && $has_validation
}

count_issue_entries() {
    local file="$1"
    local n_fail n_root n_phenomenon

    n_fail=$(grep -cE '^### [[:space:]]*FAIL-[0-9]+' "$file" 2>/dev/null || true)
    if ! printf '%s' "$n_fail" | grep -qE '^[0-9]+$'; then
        n_fail=0
    fi

    n_root=$(awk '
        BEGIN { in_section=0; count=0 }
        /^### [[:space:]]*根因结论/ { in_section=1; next }
        in_section && /^### / { in_section=0 }
        in_section && /^\|/ {
            line=$0
            if (line ~ /^\|[[:space:]]*#/) next
            if (line ~ /^\|[-[:space:]|]+\|?$/) next
            if (line ~ /\.\.\./) next
            if (line ~ /:[0-9]+/) count++
        }
        END { print count }
    ' "$file" 2>/dev/null || echo 0)
    if ! printf '%s' "$n_root" | grep -qE '^[0-9]+$'; then
        n_root=0
    fi

    n_phenomenon=$(awk '
        BEGIN { in_section=0; count=0 }
        /^### [[:space:]]*现象与复现/ { in_section=1; next }
        in_section && /^### / { in_section=0 }
        in_section && /^\|/ {
            line=$0
            if (line ~ /^\|[[:space:]]*#/) next
            if (line ~ /^\|[-[:space:]|]+\|?$/) next
            if (line ~ /\.\.\./) next
            count++
        }
        END { print count }
    ' "$file" 2>/dev/null || echo 0)
    if ! printf '%s' "$n_phenomenon" | grep -qE '^[0-9]+$'; then
        n_phenomenon=0
    fi

    # 取三个来源的最大值作为问题条目数，至少 1
    local issue_count
    issue_count="$n_fail"
    if [ "$n_root" -gt "$issue_count" ]; then
        issue_count="$n_root"
    fi
    if [ "$n_phenomenon" -gt "$issue_count" ]; then
        issue_count="$n_phenomenon"
    fi
    if [ "$issue_count" -lt 1 ]; then
        issue_count=1
    fi

    printf '%s' "$issue_count"
}

count_failure_class_entries() {
    local file="$1"
    local count

    count=$(awk '
        BEGIN { count=0; in_section=0 }
        /^失败分类[[:space:]]*[:：]/ { in_section=1; next }
        /^### [[:space:]]*失败分类/ { in_section=1; next }
        in_section && /^### / { in_section=0 }
        in_section && /^## / { in_section=0 }
        in_section && /^\|/ {
            line=$0
            if (line ~ /^\|[[:space:]]*#/) next
            if (line ~ /^\|[-[:space:]|]+\|?$/) next
            if (line ~ /\.\.\./) next
            if (line ~ /FIXABLE\/DESIGN_ISSUE\/ENV_ISSUE\/REQUIREMENT_AMBIGUITY/) next
            if (line ~ /(FIXABLE|DESIGN_ISSUE|ENV_ISSUE|REQUIREMENT_AMBIGUITY)/) count++
        }
        END { print count }
    ' "$file" 2>/dev/null || echo 0)

    if ! printf '%s' "$count" | grep -qE '^[0-9]+$'; then
        count=0
    fi
    if [ "$count" -eq 0 ]; then
        count=$(grep -ciE 'failure_class[[:space:]]*[:：][[:space:]]*(FIXABLE|DESIGN_ISSUE|ENV_ISSUE|REQUIREMENT_AMBIGUITY)' "$file" 2>/dev/null || true)
        if ! printf '%s' "$count" | grep -qE '^[0-9]+$'; then
            count=0
        fi
    fi
    printf '%s' "$count"
}

count_verified_hypotheses() {
    local file="$1"
    local count

    count=$(awk '
        BEGIN { in_section=0; count=0 }
        /^### [[:space:]]*假设验证过程/ { in_section=1; next }
        in_section && /^### / { in_section=0 }
        in_section && /^\|/ {
            line=$0
            if (line ~ /^\|[[:space:]]*#/) next
            if (line ~ /^\|[-[:space:]|]+\|?$/) next
            if (line ~ /\.\.\./) next
            if (line ~ /(排除|确认|未决)/) count++
        }
        END { print count }
    ' "$file" 2>/dev/null || echo 0)

    if ! printf '%s' "$count" | grep -qE '^[0-9]+$'; then
        count=0
    fi
    if [ "$count" -eq 0 ]; then
        count=$(grep -ciE '(假设[^[:cntrl:]]*(排除|确认|未决)|(排除|确认|未决)[^[:cntrl:]]*假设)' "$file" 2>/dev/null || true)
        if ! printf '%s' "$count" | grep -qE '^[0-9]+$'; then
            count=0
        fi
    fi

    printf '%s' "$count"
}

has_semantic_confirmation() {
    local file="$1"
    awk '
        BEGIN { found=0 }
        {
            line=$0
            if (line ~ /语义关系确认证据[[:space:]]*\|/) next
            if (line ~ /goToDefinition\/findReferences 或等效静态追踪/) next
            if (line ~ /\.\.\./) next
            if (line ~ /(goToDefinition|findReferences|定义跳转|引用追踪|静态追踪|语义关系证据|LSP)/) {
                found=1
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$file" 2>/dev/null
}

has_repro_conclusion() {
    local file="$1"
    grep -qiE '(可复现/不可复现|复现结论)[[:space:]]*[:：][[:space:]]*(可复现|不可复现)' "$file" 2>/dev/null
}

is_unreproducible_conclusion() {
    local file="$1"
    grep -qiE '(可复现/不可复现|复现结论)[[:space:]]*[:：][[:space:]]*不可复现' "$file" 2>/dev/null
}

check_fix_report() {
    local fix_file="$1"
    local label n has_fixable has_nonfixable q_count hypothesis_count issue_count failure_class_count

    label=$(basename "$fix_file" .md)

    if [ ! -f "$fix_file" ]; then
        add_failure "F1: [${label}] 报告不存在：$fix_file"
        return
    fi
    if [ ! -s "$fix_file" ]; then
        add_failure "F1: [${label}] 报告为空：$fix_file"
        return
    fi

    n=$(printf '%s' "$label" | grep -oE '[0-9]+$' || true)

    # F2: failure_class 必填
    if ! grep -qE '(FIXABLE|DESIGN_ISSUE|ENV_ISSUE|REQUIREMENT_AMBIGUITY|failure_class)' "$fix_file" 2>/dev/null; then
        add_failure "F2: [${label}] 缺少 failure_class 标签（FIXABLE/DESIGN_ISSUE/ENV_ISSUE/REQUIREMENT_AMBIGUITY）"
    fi
    issue_count=$(count_issue_entries "$fix_file")
    failure_class_count=$(count_failure_class_entries "$fix_file")
    if [ "$failure_class_count" -lt "$issue_count" ]; then
        add_failure "F2: [${label}] failure_class 数量不足（问题数=${issue_count}，分类条目=${failure_class_count}）"
    fi

    # F3: 诊断证据必填（现象 + 假设 + 验证 + 根因定位）
    if ! has_diagnosis_trace "$fix_file"; then
        add_failure "F3: [${label}] 缺少诊断过程记录（现象/假设/验证）"
    fi
    if ! has_root_cause_evidence "$fix_file"; then
        add_failure "F3: [${label}] 缺少根因定位证据（file_path:line_number）"
    fi
    hypothesis_count=$(count_verified_hypotheses "$fix_file")
    if [ "$hypothesis_count" -lt 2 ]; then
        add_failure "F3: [${label}] 假设验证不足（至少 2 个，当前 ${hypothesis_count}）"
    fi
    if ! has_semantic_confirmation "$fix_file"; then
        add_failure "F3: [${label}] 缺少语义关系确认证据（goToDefinition/findReferences 或等效静态追踪）"
    fi
    if ! has_repro_conclusion "$fix_file"; then
        add_failure "F3: [${label}] 缺少当前环境复现结论（可复现/不可复现）"
    fi
    if is_unreproducible_conclusion "$fix_file"; then
        if ! grep -qiE '(环境差异|环境.*不同|差异证据|配置差异|依赖版本差异|环境变量差异)' "$fix_file" 2>/dev/null; then
            add_failure "F3: [${label}] 标记不可复现但缺少环境差异证据"
        fi
    fi

    # F4: 修复四问记录
    q_count=$(grep -cE '(根因是什么|修复是否完整|是否引入新问题|是否需要补充测试|修复四问)' "$fix_file" 2>/dev/null || true)
    if [ "$q_count" -eq 0 ]; then
        add_failure "F4: [${label}] 缺少修复四问记录"
    fi

    has_fixable=false
    has_nonfixable=false
    # 忽略模板中的 "FIXABLE/DESIGN_ISSUE/..." 选项串，仅识别真实分类值
    grep -qE '(^|[^/A-Z_])FIXABLE([^/A-Z_]|$)' "$fix_file" 2>/dev/null && has_fixable=true
    grep -qE '(^|[^/A-Z_])(DESIGN_ISSUE|ENV_ISSUE|REQUIREMENT_AMBIGUITY)([^/A-Z_]|$)' "$fix_file" 2>/dev/null && has_nonfixable=true

    # F5: 条件化证据校验
    if $has_fixable; then
        if ! grep -qE '(RED[[:space:]（)阶段：:]|红灯|失败.*before|修复前.*失败)' "$fix_file" 2>/dev/null; then
            add_failure "F5: [${label}] 存在 FIXABLE 但缺少 RED 阶段证据"
        fi
        if ! grep -qE '(GREEN[[:space:]（)阶段：:]|绿灯|通过.*after|修复后.*通过)' "$fix_file" 2>/dev/null; then
            add_failure "F5: [${label}] 存在 FIXABLE 但缺少 GREEN 阶段证据"
        fi
        if ! grep -qE '(全量测试|全部通过|test.*pass|零回归)' "$fix_file" 2>/dev/null; then
            add_failure "F5: [${label}] 存在 FIXABLE 但缺少全量测试结果"
        fi
    fi

    if $has_nonfixable; then
        if ! grep -qE '(阻断|暂停修复|无法修复|不做代码修改|停止代码修改)' "$fix_file" 2>/dev/null; then
            add_failure "F5: [${label}] 存在非 FIXABLE 项但缺少阻断说明"
        fi
        if ! grep -qE '(下一步|后续动作|责任归属|回到 /design|回到 /product|环境处理)' "$fix_file" 2>/dev/null; then
            add_failure "F5: [${label}] 存在非 FIXABLE 项但缺少下一步动作"
        fi
    fi

    # F6/F7: N > 1 的额外约束
    if [ -n "$n" ] && [ "$n" -gt 1 ]; then
        if ! grep -qE '(差异说明|与.*不同|策略.*升级|换.*思路|上次.*这次)' "$fix_file" 2>/dev/null; then
            add_failure "F6: [${label}] N > 1 但缺少差异说明（与前次修复的策略差异）"
        fi

        has_history_ref=false
        for ((i = 1; i < n; i++)); do
            if grep -qE "fix-${i}(\.md)?" "$fix_file" 2>/dev/null; then
                has_history_ref=true
                break
            fi
        done
        if [ "$has_history_ref" = "false" ]; then
            add_failure "F7: [${label}] N > 1 但未引用历史 fix 报告（fix-1..fix-$((n - 1)).md）"
        fi
    fi

    # F8: 明确禁用弱结论
    if grep -qi 'works on my machine' "$fix_file" 2>/dev/null; then
        add_failure "F8: [${label}] 出现禁用表述：works on my machine"
    fi
}

while IFS= read -r fix_path; do
    [ -n "$fix_path" ] || continue
    check_fix_report "$fix_path"
done <<< "$FIX_FILES"

output_failures "修复报告完整性检查未通过" "$WORK_DIR"
exit 0
