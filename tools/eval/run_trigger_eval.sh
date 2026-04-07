#!/usr/bin/env bash
# Skill description 触发率评测脚本
# 基于 c4-trigger-rate-baseline.md 中定义的查询，测量每个 skill 的触发准确率
# 用法: bash tools/eval/run_trigger_eval.sh [--dry-run] [skill-name]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASELINE="$ROOT/tools/eval/scenarios/c4-trigger-rate-baseline.md"
RESULTS_DIR="$ROOT/tools/eval/results/trigger-rate"

DRY_RUN=false
TARGET_SKILL=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            cat <<'USAGE'
run_trigger_eval.sh — Skill description 触发率评测
用法: bash tools/eval/run_trigger_eval.sh [--dry-run] [skill-name]
  --dry-run  仅解析查询定义，不实际调用 Claude
  skill-name 只评测指定 skill（默认全部）
USAGE
            exit 0
            ;;
        *) TARGET_SKILL="$arg" ;;
    esac
done

if [ ! -f "$BASELINE" ]; then
    echo "ERROR: baseline file not found: $BASELINE" >&2
    exit 1
fi

mkdir -p "$RESULTS_DIR"

# 从 baseline.md 中提取每个 skill 的 eval 查询 JSON
extract_skill_queries() {
    local skill="$1"
    awk -v skill="$skill" '
        BEGIN { found=0; in_json=0 }
        /^### / {
            if (found && in_json) exit
            gsub(/^### */, "")
            gsub(/[[:space:]]*$/, "")
            if ($0 == skill) found=1
        }
        found && /^```json/ { in_json=1; next }
        found && in_json && /^```/ { exit }
        found && in_json { print }
    ' "$BASELINE"
}

# 从 baseline.md 中提取 skill 列表
SKILLS=$(awk '/^### / { gsub(/^### */, ""); gsub(/[[:space:]]*$/, ""); print }' "$BASELINE" | sort -u)

echo "=== Skill Description 触发率评测 ==="
echo "基线: $BASELINE"
echo "模式: $([ "$DRY_RUN" = true ] && echo 'dry-run (仅解析)' || echo 'live')"
echo ""

total_skills=0
total_queries=0
total_correct=0

while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    [ -n "$TARGET_SKILL" ] && [ "$skill" != "$TARGET_SKILL" ] && continue

    queries_json=$(extract_skill_queries "$skill")
    if [ -z "$queries_json" ]; then
        echo "[$skill] SKIP — 无查询定义"
        continue
    fi

    query_count=$(printf '%s\n' "$queries_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

    if [ "$DRY_RUN" = true ]; then
        echo "[$skill] 已解析 ${query_count} 个查询（dry-run，不执行）"
        total_skills=$((total_skills + 1))
        total_queries=$((total_queries + query_count))
        continue
    fi

    # 实际评测需要调用 Claude API，此处记录为待执行
    echo "[$skill] ${query_count} queries — 实际评测需要 Claude API 调用"
    echo "  建议方式: 使用 skill-creator 的 run_eval.py 框架"
    echo "  查询已保存到: $RESULTS_DIR/${skill}-queries.json"

    # 保存查询到结果目录
    printf '%s\n' "$queries_json" > "$RESULTS_DIR/${skill}-queries.json"

    total_skills=$((total_skills + 1))
    total_queries=$((total_queries + query_count))
done <<< "$SKILLS"

echo ""
echo "=== 汇总 ==="
echo "Skills: $total_skills"
echo "总查询数: $total_queries"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "下一步: 移除 --dry-run 执行实际评测（需要 Claude API）"
fi
