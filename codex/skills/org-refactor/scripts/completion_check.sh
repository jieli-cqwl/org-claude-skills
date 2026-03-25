#!/bin/bash
# 重构计划完整性自动检查脚本
# 触发时机: refactor skill-local Stop
# 功能: 检查 docs/重构-{模块名}/plan.md 的诊断结果与三原则校验

set -euo pipefail

source "$HOME/.claude/hooks/lib/common.sh"
hook_init

# --- 重构目录定位 ---

TRANSCRIPT_PATTERN='docs/重构-[^/"[:space:]*{}]+/plan\.md'
resolve_feature_dir "docs/重构-*/plan.md" "$TRANSCRIPT_PATTERN" "plan.md" 'docs/重构-*'
output_failures "重构计划完整性检查未通过" ""

PLAN_FILE="$FEATURE_DIR/plan.md"

# RF1: plan.md 存在于 docs/重构-{模块名}/
if [ ! -f "$PLAN_FILE" ]; then
    add_failure "RF1: plan.md 不存在：$PLAN_FILE"
elif [ ! -s "$PLAN_FILE" ]; then
    add_failure "RF1: plan.md 为空：$PLAN_FILE"
fi

if [ ! -f "$PLAN_FILE" ] || [ ! -s "$PLAN_FILE" ]; then
    output_failures "重构计划完整性检查未通过" "$FEATURE_DIR"
    exit 0
fi

# RF2: 诊断结果存在（问题类型 + 方向）
DIAG_TYPES=("过度设计" "设计不足" "设计不当")
HAS_DIAG=false
for dtype in "${DIAG_TYPES[@]}"; do
    if grep -qF "$dtype" "$PLAN_FILE" 2>/dev/null; then
        HAS_DIAG=true
        break
    fi
done

if [ "$HAS_DIAG" = "false" ]; then
    if ! grep -qE '(诊断|问题类型|diagnosis)' "$PLAN_FILE" 2>/dev/null; then
        add_failure "RF2: 缺少诊断结果（问题类型：过度设计/设计不足/设计不当）"
    fi
fi

DIRECTIONS=("减法" "加法" "调整")
HAS_DIR=false
for dir in "${DIRECTIONS[@]}"; do
    if grep -qF "$dir" "$PLAN_FILE" 2>/dev/null; then
        HAS_DIR=true
        break
    fi
done

if [ "$HAS_DIR" = "false" ]; then
    if ! grep -qE '(重构方向|direction)' "$PLAN_FILE" 2>/dev/null; then
        add_failure "RF2: 缺少重构方向（减法/加法/调整）"
    fi
fi

# RF3: 三原则校验存在（Simple / Fit / Evolve）
PRINCIPLES=("简单" "合适" "演化" "Simple" "Fit" "Evolve")
FOUND_PRINCIPLES=0
for p in "${PRINCIPLES[@]}"; do
    if grep -qF "$p" "$PLAN_FILE" 2>/dev/null; then
        FOUND_PRINCIPLES=$((FOUND_PRINCIPLES + 1))
    fi
done

if [ "$FOUND_PRINCIPLES" -lt 3 ]; then
    if ! grep -qE '(三原则|3.*原则|principles)' "$PLAN_FILE" 2>/dev/null; then
        add_failure "RF3: 缺少三原则校验（Simple/Fit/Evolve 或 简单/合适/演化）"
    fi
fi

# RF4: 步骤有 file_path:line_number
FILE_LINE_COUNT=$(grep -cE '[a-zA-Z0-9_/.-]+\.[a-z]+:[0-9]+' "$PLAN_FILE" 2>/dev/null || true)
if [ "$FILE_LINE_COUNT" -eq 0 ]; then
    add_failure "RF4: 重构步骤缺少 file_path:line_number 定位"
fi

# RF5: 影响分析含调用方引用计数
if ! grep -qE '(引用.*[0-9]|调用方|caller|reference.*count|[0-9]+.*处引用)' "$PLAN_FILE" 2>/dev/null; then
    add_failure "RF5: 影响分析缺少调用方引用计数"
fi

output_failures "重构计划完整性检查未通过" "$FEATURE_DIR"
exit 0
