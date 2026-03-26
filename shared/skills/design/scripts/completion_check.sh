#!/bin/bash
# 设计文档完整性自动检查脚本
# 触发时机: design skill-local Stop
# 功能: 精确定位当前 feature，并检查 design.md/ADR/三路评审工件闭环
# 版本: v2.0 2026-03-16

set -euo pipefail

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
hook_init

# --- Feature 目录定位 ---

TRANSCRIPT_PATTERN='docs/[^/"[:space:]*{}]+/(phase-[0-9]+/)?(design\.md|design/MOD-[0-9]+\.md|design/adr/ADR-[0-9]+\.md|design-cross-review\.md)'
resolve_feature_dir "docs/*/phase-*/design.md" "$TRANSCRIPT_PATTERN" "design.md" "docs/*/phase-*"
output_failures "设计文档完整性检查未通过" ""

# --- PRD 驱动 Phase 工作区定位 ---
resolve_phase_work_dir_from_prd "$FEATURE_DIR" "design.md"
WORK_DIR="$PHASE_WORK_DIR"

DESIGN_FILE="$WORK_DIR/design.md"
ADR_DIR="$WORK_DIR/design/adr"
CROSS_REVIEW_FILE="$WORK_DIR/design-cross-review.md"
FEATURE_CONSTITUTION_FILE="$FEATURE_DIR/constitution.md"
ROOT_DOCS_CONSTITUTION_FILE="$REPO_ROOT/docs/constitution.md"
ROOT_CONSTITUTION_FILE="$REPO_ROOT/constitution.md"

pick_constitution_file() {
    for f in "$FEATURE_CONSTITUTION_FILE" "$ROOT_DOCS_CONSTITUTION_FILE" "$ROOT_CONSTITUTION_FILE"; do
        if [ -f "$f" ] && [ -s "$f" ]; then
            printf '%s' "$f"
            return 0
        fi
    done
    return 1
}

is_placeholder_text() {
    local value
    value=$(printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if [ -z "$value" ]; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^(待补|TBD|TODO|N/?A|无|未填写|\[.*\]|\{.*\}|-|—)$'; then
        return 0
    fi
    return 1
}

extract_impact_scope_rows() {
    local design_file="$1"
    local impact_section

    impact_section=$(extract_markdown_section "$design_file" "## 影响范围清单")
    if [ -z "$impact_section" ]; then
        impact_section=$(extract_markdown_section "$design_file" "## 影响访问清单")
    fi
    printf '%s\n' "${impact_section}" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            scope_id = trim($2)
            change_type = trim($3)
            old_boundary = trim($4)
            new_boundary = trim($5)
            risk = trim($6)
            evidence = trim($7)
            owner = trim($8)

            if (scope_id == "" || scope_id == "scope_item_id" || scope_id ~ /^-+$/) next
            print scope_id "|" change_type "|" old_boundary "|" new_boundary "|" risk "|" evidence "|" owner
        }
    '
}

extract_adr_alternative_count() {
    local adr_file="$1"
    local alt_section table_rows bullet_rows

    alt_section=$(extract_section_content "$adr_file" "## 备选方案" 2)
    if [ -z "$alt_section" ]; then
        alt_section=$(extract_section_content "$adr_file" "### 备选方案" 3)
    fi
    if [ -z "$alt_section" ]; then
        alt_section=$(awk '
            /\*\*备选方案\*\*[:：]/ { in_section=1; next }
            in_section && /^\*\*[^*]+\*\*[:：]/ { exit }
            in_section { print }
        ' "$adr_file")
    fi

    table_rows=$(printf '%s\n' "$alt_section" | awk -F'|' '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        /^\|/ {
            c1 = trim($2)
            if (c1 == "" || c1 == "方案" || c1 ~ /^-+$/) next
            count++
        }
        END { print count + 0 }
    ')
    bullet_rows=$(printf '%s\n' "$alt_section" | grep -cE '^[[:space:]]*[-*][[:space:]]*(方案|Option|候选)' || true)

    if [ "$table_rows" -gt "$bullet_rows" ]; then
        printf '%s' "$table_rows"
    else
        printf '%s' "$bullet_rows"
    fi
}

CONSTITUTION_FILE=""
if ! CONSTITUTION_FILE=$(pick_constitution_file); then
    add_failure "Constitution 文件不存在（需存在于 feature 或仓库根 docs/ 下）"
fi

# C1: design.md 存在且非空
if [ ! -f "$DESIGN_FILE" ]; then
    add_failure "设计文档不存在：$DESIGN_FILE"
elif [ ! -s "$DESIGN_FILE" ]; then
    add_failure "设计文档为空：$DESIGN_FILE"
fi

# C2: design.md 必需章节存在
REQUIRED_SECTIONS=(
    "## 输入分析"
    "## PRD 技术理解校正"
    "## 现状事实"
    "## 设计场景判断"
    "## 关键决策记录"
    "## 共创摘要"
    "## 架构边界"
    "## 接口边界"
    "## 数据边界"
    "## 质量属性"
    "## 迁移策略"
    "## 验证与可观测性"
    "## 回滚方案"
    "## 风险与缓解"
    "## 影响范围清单"
    "## 待计划约束"
    "## 覆盖表"
    "## 已排查并排除的潜在问题"
    "## 审查结论"
    "## 交接项"
)

IMPACT_SECTION_LABEL="影响范围清单"
if [ -f "$DESIGN_FILE" ]; then
    for section in "${REQUIRED_SECTIONS[@]}"; do
        if [ "$section" = "## 影响范围清单" ]; then
            if ! grep -qF "## 影响范围清单" "$DESIGN_FILE" && ! grep -qF "## 影响访问清单" "$DESIGN_FILE"; then
                add_failure "design.md 缺少章节：## 影响范围清单"
            fi
            if grep -qF "## 影响访问清单" "$DESIGN_FILE"; then
                IMPACT_SECTION_LABEL="影响访问清单"
            fi
        else
            if ! grep -qF "$section" "$DESIGN_FILE"; then
                add_failure "design.md 缺少章节：$section"
            fi
        fi
    done
fi

# C2.1: 影响范围/访问清单完整性（证据门禁）
if [ -f "$DESIGN_FILE" ]; then
    impact_rows=$(extract_impact_scope_rows "$DESIGN_FILE")
    impact_count=$(printf '%s\n' "$impact_rows" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$impact_count" -eq 0 ]; then
        add_failure "design.md「${IMPACT_SECTION_LABEL}」缺少数据行"
    else
        duplicate_scope_ids=$(printf '%s\n' "$impact_rows" | awk -F'|' '{print $1}' | sed '/^$/d' | sort | uniq -d || true)
        if [ -n "$duplicate_scope_ids" ]; then
            add_failure "design.md「${IMPACT_SECTION_LABEL}」存在重复 scope_item_id：$(printf '%s' "$duplicate_scope_ids" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
        fi

        while IFS='|' read -r scope_id change_type old_boundary new_boundary risk evidence owner; do
            [ -n "$scope_id" ] || continue

            if ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
                add_failure "${IMPACT_SECTION_LABEL}存在非法 scope_item_id：${scope_id}（需匹配 SCOPE-P{phase}U{unit}-{seq}）"
            fi
            if is_placeholder_text "$change_type"; then
                add_failure "${IMPACT_SECTION_LABEL} ${scope_id} 缺少有效变更类型"
            fi
            if is_placeholder_text "$old_boundary"; then
                add_failure "${IMPACT_SECTION_LABEL} ${scope_id} 缺少有效旧边界描述"
            fi
            if is_placeholder_text "$new_boundary"; then
                add_failure "${IMPACT_SECTION_LABEL} ${scope_id} 缺少有效新边界描述"
            fi
            if ! printf '%s' "$risk" | grep -qE '^(P0|P1|P2)$'; then
                add_failure "${IMPACT_SECTION_LABEL} ${scope_id} 风险等级非法：${risk}（需为 P0/P1/P2）"
            fi
            if is_placeholder_text "$evidence"; then
                add_failure "${IMPACT_SECTION_LABEL} ${scope_id} 缺少可复核证据"
            fi
            if is_placeholder_text "$owner"; then
                add_failure "${IMPACT_SECTION_LABEL} ${scope_id} 缺少 owner"
            fi
        done <<< "$impact_rows"
    fi
fi

# C2.2: Unit 级 design.md 影响范围/访问清单 scope_item_id 格式校验
if [ -d "$WORK_DIR" ]; then
    UNIT_DESIGN_FILES=$(find "$WORK_DIR" -path '*/unit-*/design.md' -type f 2>/dev/null || true)
    if [ -n "$UNIT_DESIGN_FILES" ]; then
        while IFS= read -r unit_design; do
            [ -n "$unit_design" ] || continue
            [ -f "$unit_design" ] || continue
            unit_impact_rows=$(extract_impact_scope_rows "$unit_design")
            unit_impact_count=$(printf '%s\n' "$unit_impact_rows" | sed '/^$/d' | wc -l | tr -d ' ')
            [ "$unit_impact_count" -gt 0 ] || continue

            rel_path="${unit_design#"$WORK_DIR"/}"
            while IFS='|' read -r scope_id _rest; do
                [ -n "$scope_id" ] || continue
                if ! printf '%s' "$scope_id" | grep -qE '^SCOPE-P[0-9]+U[0-9]+-[0-9]+$'; then
                    add_failure "${rel_path} 影响清单存在非法 scope_item_id：${scope_id}（需匹配 SCOPE-P{N}U{N}-{NNN}）"
                fi
            done <<< "$unit_impact_rows"
        done <<< "$UNIT_DESIGN_FILES"
    fi
fi

# C2.3: Unit 级不应存在 design.md（Phase 级文档不应下沉到 Unit）
for unit_design_file in "$WORK_DIR"/unit-*/design.md; do
    [ -f "$unit_design_file" ] || continue
    rel_path="${unit_design_file#"$WORK_DIR"/}"
    add_failure "${rel_path} 不应存在 — design.md 应在 Phase 工作区（${WORK_DIR}/design.md），Unit 目录不应包含独立 design"
done

# C3: ADR 目录存在且有 ADR 文件
if [ ! -d "$ADR_DIR" ]; then
    add_failure "ADR 目录不存在：$ADR_DIR"
else
    ADR_FILE_LIST=$(find "$ADR_DIR" -maxdepth 1 -type f -name 'ADR-*.md' | sort)
    ADR_FILE_COUNT=$(printf '%s\n' "$ADR_FILE_LIST" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$ADR_FILE_COUNT" = "0" ]; then
        add_failure "ADR 目录下无 ADR 文件：$ADR_DIR"
    else
        while IFS= read -r adr_file; do
            [ -n "$adr_file" ] || continue
            adr_name=$(basename "$adr_file")
            alternative_count=$(extract_adr_alternative_count "$adr_file")

            if [ "$alternative_count" -lt 2 ]; then
                add_failure "${adr_name} 备选方案不足 2 个（当前 ${alternative_count} 个）"
            fi

            if ! grep -qE '(用户确认|用户选择|用户决策|User Confirmation|User Decision)' "$adr_file"; then
                add_failure "${adr_name} 缺少用户确认/选择记录"
            fi
        done <<< "$ADR_FILE_LIST"
    fi
fi

# C4: ADR 文件数 >= design.md 关键决策记录行数
if [ -f "$DESIGN_FILE" ] && [ -d "$ADR_DIR" ]; then
    DECISION_COUNT=$(extract_markdown_section "$DESIGN_FILE" "## 关键决策记录" | grep -cE '^\|[[:space:]]*D-[0-9]{3,}' || true)
    ADR_COUNT=$(find "$ADR_DIR" -maxdepth 1 -type f -name 'ADR-*.md' | wc -l | tr -d ' ')
    if [ "$ADR_COUNT" -lt "$DECISION_COUNT" ]; then
        add_failure "关键决策记录条数(${DECISION_COUNT})与 ADR 文件数(${ADR_COUNT})不匹配"
    fi
fi

# C5: 共创摘要有数据行 + "用户回应"列非空 + D-* 决策映射
if [ -f "$DESIGN_FILE" ]; then
    CO_CREATE_SECTION=$(extract_markdown_section "$DESIGN_FILE" "## 共创摘要")
    # 匹配表格内容行（含表头），排除分隔行
    CO_CREATE_ROWS=$(printf '%s\n' "$CO_CREATE_SECTION" | grep -cE '^\|[[:space:]]*[^-|]' || true)
    if [ "$CO_CREATE_ROWS" -lt 2 ]; then
        # 表头占 1 行，至少需要 1 行数据 → 总计 >= 2
        add_failure "「共创摘要」无数据行，缺少共创过程记录"
    else
        # 跳过表头行，检查数据行的"用户回应"列（第 3 列 = awk $4）非空
        EMPTY_RESPONSE=$(printf '%s\n' "$CO_CREATE_SECTION" | grep -E '^\|[[:space:]]*[^-|]' | tail -n +2 | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); if ($4 == "") print NR}')
        if [ -n "$EMPTY_RESPONSE" ]; then
            add_failure "「共创摘要」存在用户回应列为空的记录"
        fi
        # 校验每个 D-* 决策在共创摘要的"对设计的影响"列（第 4 列 = awk $5）中有映射
        IMPACT_COL=$(printf '%s\n' "$CO_CREATE_SECTION" | grep -E '^\|[[:space:]]*[^-|]' | tail -n +2 | awk -F'|' '{print $5}')
        DECISION_IDS=$(grep -oE 'D-[0-9]{3,}' "$DESIGN_FILE" | sort -u || true)
        if [ -n "$DECISION_IDS" ]; then
            UNMAPPED=""
            for did in $DECISION_IDS; do
                if ! printf '%s\n' "$IMPACT_COL" | grep -qF "$did"; then
                    UNMAPPED="$UNMAPPED $did"
                fi
            done
            if [ -n "$UNMAPPED" ]; then
                add_failure "以下决策未在「共创摘要」的对设计的影响列中映射:$UNMAPPED"
            fi
        fi
    fi
fi

# C9: 已排查并排除的潜在问题 >= 2 条
if [ -f "$DESIGN_FILE" ]; then
    EP_COUNT=$({ grep -oE 'EP-[0-9]+' "$DESIGN_FILE" 2>/dev/null || true; } | sort -u | wc -l | tr -d ' ')
    if [ "$EP_COUNT" -lt 2 ]; then
        add_failure "「已排查并排除的潜在问题」不足 2 条（当前 ${EP_COUNT} 条）"
    fi
fi

# 提取审查结论内容供 WARN 承接校验使用
DESIGN_REVIEW_CONCLUSION=""
if [ -f "$DESIGN_FILE" ]; then
    DESIGN_REVIEW_CONCLUSION=$(extract_markdown_section "$DESIGN_FILE" "## 审查结论")
fi

# --- WARN 承接验证 + 目标存在性校验（design-specific） ---

check_warn_handoff() {
    local section_content="$1" label="$2" prefix="$3"
    local verdict issue_ids

    # 从视角 section 内容中提取 Verdict
    verdict=$(printf '%s\n' "$section_content" | sed -nE 's/^[[:space:]]*Verdict[[:space:]]*:[[:space:]]*(PASS|WARN|FAIL)[[:space:]]*$/\1/p' | head -1 || true)
    [ "$verdict" = "WARN" ] || return 0

    # 从视角 section 内容中提取 issue ID
    # 使用 {3,} 排除维度 ID（如 DR-1）只匹配 issue ID（如 DR-001）
    issue_ids=$(printf '%s\n' "$section_content" | grep -oE "${prefix}-[0-9]{3,}" | sort -u || true)

    while IFS= read -r issue_id; do
        [ -n "$issue_id" ] || continue
        if ! printf '%s\n' "$DESIGN_REVIEW_CONCLUSION" | grep -qF "$issue_id"; then
            add_failure "${label}审查 WARN 项 ${issue_id} 未在 design.md「审查结论」中显式记录"
        elif ! validate_handoff_entry "$issue_id" "$DESIGN_REVIEW_CONCLUSION"; then
            add_failure "${label}审查 WARN 项 ${issue_id} 在「审查结论」中缺少实质承接内容（需写明：已修正/承接位置/不处理理由）"
        fi
    done <<< "$issue_ids"
}

# C5-C8: 合并审查文件检查（1 个文件 3 个视角 section）
if [ ! -f "$CROSS_REVIEW_FILE" ]; then
    add_failure "跨职能审查文件不存在：$CROSS_REVIEW_FILE"
elif [ ! -s "$CROSS_REVIEW_FILE" ]; then
    add_failure "跨职能审查文件为空：$CROSS_REVIEW_FILE"
else
    # 检查 3 个视角 section 存在且 verdict 可解析
    for review_args in \
        "架构视角|架构|DR" \
        "产品视角|产品|DPR" \
        "测试视角|测试|DTR"; do
        IFS='|' read -r r_section r_label r_prefix <<< "$review_args"

        section_content=$(extract_markdown_section "$CROSS_REVIEW_FILE" "## ${r_section}")
        if [ -z "$section_content" ]; then
            add_failure "design-cross-review.md 缺少「## ${r_section}」section"
            continue
        fi

        # section 头部 Verdict / Issue Count
        section_verdict=$(printf '%s\n' "$section_content" | sed -nE 's/^[[:space:]]*Verdict[[:space:]]*:[[:space:]]*(PASS|WARN|FAIL)[[:space:]]*$/\1/p' | head -1 || true)
        section_issue_count=$(printf '%s\n' "$section_content" | sed -nE 's/^[[:space:]]*Issue Count[[:space:]]*:[[:space:]]*([0-9]+)[[:space:]]*$/\1/p' | head -1 || true)
        [ -n "$section_verdict" ] || add_failure "design-cross-review.md ${r_label}视角 section 缺少可解析 Verdict"
        [ -n "$section_issue_count" ] || add_failure "design-cross-review.md ${r_label}视角 section 缺少可解析 Issue Count"

        if [ -n "$section_verdict" ] && [ -n "$section_issue_count" ]; then
            if [ "$section_verdict" = "PASS" ] && [ "$section_issue_count" != "0" ]; then
                add_failure "design-cross-review.md ${r_label}视角 section Verdict=PASS 时 Issue Count 必须为 0"
            fi
            if [ "$section_verdict" != "PASS" ] && [ "$section_issue_count" = "0" ]; then
                add_failure "design-cross-review.md ${r_label}视角 section Verdict=${section_verdict} 时 Issue Count 不得为 0"
            fi
        fi

        conclusion_section=$(extract_markdown_section "$CROSS_REVIEW_FILE" "## 审查结论")
        verdict=$(printf '%s\n' "$conclusion_section" | awk -F'|' -v lbl="$r_label" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            /^\|/ {
                c1 = trim($2); c2 = trim($3)
                if (c1 == lbl) { print c2; exit }
            }
        ')
        conclusion_issue_count=$(printf '%s\n' "$conclusion_section" | awk -F'|' -v lbl="$r_label" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            /^\|/ {
                c1 = trim($2); c3 = trim($4)
                if (c1 == lbl) { print c3; exit }
            }
        ')

        if [ -z "$verdict" ]; then
            add_failure "design-cross-review.md 审查结论中${r_label}视角 Verdict 不可解析"
            continue
        fi
        if [ -z "$conclusion_issue_count" ]; then
            add_failure "design-cross-review.md 审查结论中${r_label}视角 Issue 数不可解析"
        fi

        if [ -n "$section_verdict" ] && [ "$verdict" != "$section_verdict" ]; then
            add_failure "design-cross-review.md ${r_label}视角审查结论表 Verdict=${verdict} 与 section Verdict=${section_verdict} 不一致"
        fi
        if [ -n "$section_issue_count" ] && [ -n "$conclusion_issue_count" ] && [ "$conclusion_issue_count" != "$section_issue_count" ]; then
            add_failure "design-cross-review.md ${r_label}视角审查结论表 Issue 数=${conclusion_issue_count} 与 section Issue Count=${section_issue_count} 不一致"
        fi

        issue_ids=$(printf '%s\n' "$section_content" | grep -oE "${r_prefix}-[0-9]{3,}" | sort -u || true)
        issue_id_count=$(printf '%s\n' "$issue_ids" | sed '/^$/d' | wc -l | tr -d ' ')
        if [ -n "$section_issue_count" ] && [ "$section_issue_count" != "0" ] && [ "$issue_id_count" = "0" ]; then
            add_failure "design-cross-review.md ${r_label}视角 section 声明存在问题，但未发现稳定 issue id（${r_prefix}-NNN）"
        elif [ -n "$section_issue_count" ] && printf '%s\n' "$section_issue_count" | grep -qE '^[0-9]+$' && [ "$section_issue_count" != "$issue_id_count" ]; then
            add_failure "design-cross-review.md ${r_label}视角 section Issue Count=${section_issue_count} 与稳定 issue id 数量=${issue_id_count} 不一致"
        fi

        # FAIL 门禁
        if [ "$section_verdict" = "FAIL" ] || [ "$verdict" = "FAIL" ]; then
            add_failure "${r_label}审查 Verdict 为 FAIL，阻塞 /design 完成"
        fi

        # WARN 承接校验
        check_warn_handoff "$section_content" "$r_label" "$r_prefix"
    done
fi

# C10: 跨职能审查文件的覆盖自评/审查轮次/shallow pass 检查
if [ -f "$CROSS_REVIEW_FILE" ] && [ -s "$CROSS_REVIEW_FILE" ]; then
    check_review_iteration "$CROSS_REVIEW_FILE" "跨职能审查"
fi

output_failures "设计文档完整性检查未通过" "$WORK_DIR"
exit 0
