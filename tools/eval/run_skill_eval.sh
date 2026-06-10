#!/usr/bin/env bash
# Skill 行为评测入口脚本
# 用途：协调评测执行流程，不直接运行评测（评测通过 Claude Code Agent tool 执行）
# 本脚本用于验证评测环境和查看结果

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$EVAL_DIR/results"
SCENARIOS_DIR="$EVAL_DIR/scenarios"
GRADERS_DIR="$EVAL_DIR/graders"

RUN_IDS=(1 2 3)
GRADER_FILES=(
    hard-gate-grader.md
    arch-framework-grader.md
    distrust-grader.md
    product-thinking-grader.md
    problem-discovery-grader.md
    phase-slicing-quality-grader.md
    process-lightness-grader.md
    product-director-first-turn-grader.md
    product-director-thinking-grader.md
    product-manager-unit-quality-grader.md
)
SKILL_VARIANT_FILES=(
    design-with-why.md
    design-no-why.md
)
PRODUCT_SCENARIOS=(
    p1-clear-single-phase
    p2-solution-anchoring
    p3-multi-phase-value-slicing
)
PRODUCT_DIRECTOR_SCENARIOS=(
    product-director-p1-clear-single-phase
    product-director-p2-solution-anchoring
    product-director-p3-multi-phase-value-slicing
)
PRODUCT_MANAGER_SCENARIOS=(
    product-manager-p1-handoff-readiness
    product-manager-p2-lock-drift-blocking
    product-manager-p3-unit-boundary-cocreation
)
CORE_SCENARIOS=(
    s1-design-execution
    s2-review-planted
)

json_summary_value() {
    local file="$1"
    local field_path="$2"
    local default_value="${3:-?}"

    python3 - "$file" "$field_path" "$default_value" <<'PY'
import json
import sys

file_path, field_path, default_value = sys.argv[1:4]
try:
    with open(file_path, encoding="utf-8") as fh:
        value = json.load(fh)["summary"]
    for part in field_path.split("."):
        value = value[part]
except Exception:
    print(default_value)
else:
    print(value)
PY
}

has_required_files() {
    local dir="$1"
    shift

    local rel_path
    for rel_path in "$@"; do
        [[ -f "$dir/$rel_path" ]] || return 1
    done
    return 0
}

emit_status_runs() {
    local scenario="$1"
    shift

    local i dir
    for i in "${RUN_IDS[@]}"; do
        dir="$RESULTS_DIR/${scenario}-run-$i"
        if has_required_files "$dir" "$@"; then
            echo "  [DONE] ${scenario}-run-$i"
        elif [[ -d "$dir" ]]; then
            echo "  [PARTIAL] ${scenario}-run-$i"
        else
            echo "  [PENDING] ${scenario}-run-$i"
        fi
    done
}

emit_score_track_summary() {
    local title="$1"
    local grading_file="$2"
    shift 2

    local scenario i file passed score
    echo ""
    echo "--- $title ---"
    for scenario in "$@"; do
        echo "  ${scenario}:"
        for i in "${RUN_IDS[@]}"; do
            file="$RESULTS_DIR/${scenario}-run-$i/${grading_file}"
            if [[ -f "$file" ]]; then
                passed=$(json_summary_value "$file" "passed_count" "?")
                score=$(json_summary_value "$file" "score" "?")
                echo "    run-$i: passed=$passed/3, score=$score"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done
}

usage() {
    cat <<'EOF'
Skill 行为评测工具

用法:
  ./run_skill_eval.sh check     # 检查评测环境是否就绪
  ./run_skill_eval.sh status    # 查看评测执行状态
  ./run_skill_eval.sh summary   # 汇总评测结果

评测执行通过 Claude Code Agent tool 进行，本脚本仅用于环境检查和结果查看。

评测流程:
  1. check  — 确认所有输入文件就位
  2. 在 Claude Code 中执行 Stage D（Agent tool 调用 executor + grader）
  3. status — 检查哪些 run 已完成
  4. summary — 汇总所有 grading JSON 生成对比报告
EOF
}

cmd_check() {
    echo "=== 评测环境检查 ==="
    local ok=0
    local fail=0
    local grader scenario variant

    # 检查 grader 文件
    for grader in "${GRADER_FILES[@]}"; do
        if [[ -f "$GRADERS_DIR/$grader" ]]; then
            echo "  [OK] graders/$grader"
            ok=$((ok + 1))
        else
            echo "  [MISSING] graders/$grader"
            fail=$((fail + 1))
        fi
    done

    # 检查场景文件
    for scenario in "${CORE_SCENARIOS[@]}" "${PRODUCT_SCENARIOS[@]}" "${PRODUCT_DIRECTOR_SCENARIOS[@]}" "${PRODUCT_MANAGER_SCENARIOS[@]}"; do
        if [[ -f "$SCENARIOS_DIR/${scenario}.md" ]]; then
            echo "  [OK] scenarios/${scenario}.md"
            ok=$((ok + 1))
        else
            echo "  [MISSING] scenarios/${scenario}.md"
            fail=$((fail + 1))
        fi
    done

    # 检查 skill 变体
    for variant in "${SKILL_VARIANT_FILES[@]}"; do
        if [[ -f "$SCENARIOS_DIR/skill-variants/$variant" ]]; then
            echo "  [OK] scenarios/skill-variants/$variant"
            ok=$((ok + 1))
        else
            echo "  [MISSING] scenarios/skill-variants/$variant"
            fail=$((fail + 1))
        fi
    done

    # 检查最小 PRD fixture
    local prd_path
    prd_path="$(cd "$EVAL_DIR/../.." && pwd)/tools/eval/fixtures/weekly-report/prd.md"
    if [[ -f "$prd_path" ]]; then
        echo "  [OK] tools/eval/fixtures/weekly-report/prd.md"
        ok=$((ok + 1))
    else
        echo "  [MISSING] tools/eval/fixtures/weekly-report/prd.md"
        fail=$((fail + 1))
    fi

    echo ""
    echo "结果: $ok OK, $fail MISSING"
    if [[ $fail -gt 0 ]]; then
        echo "环境未就绪，请补齐缺失文件。"
        return 1
    else
        echo "环境就绪，可以开始评测。"
    fi
}

cmd_status() {
    echo "=== 评测执行状态 ==="
    local i dir

    # S1 A 变体
    for i in "${RUN_IDS[@]}"; do
        dir="$RESULTS_DIR/s1-a-run-$i"
        if [[ -f "$dir/grading-1.json" && -f "$dir/grading-2.json" ]]; then
            echo "  [DONE] s1-a-run-$i"
        elif [[ -d "$dir" ]]; then
            echo "  [PARTIAL] s1-a-run-$i (执行完成但评分未完成)"
        else
            echo "  [PENDING] s1-a-run-$i"
        fi
    done

    # S1 B 变体
    for i in "${RUN_IDS[@]}"; do
        dir="$RESULTS_DIR/s1-b-run-$i"
        if [[ -f "$dir/grading-1.json" && -f "$dir/grading-2.json" ]]; then
            echo "  [DONE] s1-b-run-$i"
        elif [[ -d "$dir" ]]; then
            echo "  [PARTIAL] s1-b-run-$i"
        else
            echo "  [PENDING] s1-b-run-$i"
        fi
    done

    # S2
    for i in "${RUN_IDS[@]}"; do
        dir="$RESULTS_DIR/s2-run-$i"
        if [[ -f "$dir/grading-3.json" ]]; then
            echo "  [DONE] s2-run-$i"
        elif [[ -d "$dir" ]]; then
            echo "  [PARTIAL] s2-run-$i"
        else
            echo "  [PENDING] s2-run-$i"
        fi
    done

    # Comparison
    if [[ -f "$RESULTS_DIR/comparison.json" ]]; then
        echo "  [DONE] comparison (A/B 盲比较)"
    else
        echo "  [PENDING] comparison"
    fi

    # Product scenarios
    local scenario
    for scenario in "${PRODUCT_SCENARIOS[@]}"; do
        emit_status_runs \
            "$scenario" \
            grading-product-thinking.json \
            grading-problem-discovery.json \
            grading-phase-slicing-quality.json \
            grading-process-lightness.json
    done

    # Product director scenarios
    for scenario in "${PRODUCT_DIRECTOR_SCENARIOS[@]}"; do
        emit_status_runs "$scenario" grading-product-director-thinking.json
    done

    # Product manager scenarios
    for scenario in "${PRODUCT_MANAGER_SCENARIOS[@]}"; do
        emit_status_runs "$scenario" grading-product-manager-unit-quality.json
    done
}

cmd_summary() {
    echo "=== 评测结果汇总 ==="
    local variant variant_label i file rate covered avg_depth ind_rate planted_rate level

    # Track 1: HARD-GATE compliance
    echo ""
    echo "--- Track 1: HARD-GATE Why 效果 ---"
    for variant in a b; do
        variant_label=$(printf '%s' "$variant" | tr '[:lower:]' '[:upper:]')
        echo "  变体 ${variant_label}:"
        for i in "${RUN_IDS[@]}"; do
            file="$RESULTS_DIR/s1-${variant}-run-$i/grading-1.json"
            if [[ -f "$file" ]]; then
                rate=$(json_summary_value "$file" "compliance_rate" "parse_error")
                echo "    run-$i: compliance_rate=$rate"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done

    # Track 2: Architecture framework
    echo ""
    echo "--- Track 2: 架构思维框架 ---"
    for i in "${RUN_IDS[@]}"; do
        file="$RESULTS_DIR/s1-a-run-$i/grading-2.json"
        if [[ -f "$file" ]]; then
            covered=$(json_summary_value "$file" "dimensions_covered" "?")
            avg_depth=$(json_summary_value "$file" "avg_depth" "?")
            echo "  run-$i: covered=$covered/4, avg_depth=$avg_depth"
        else
            echo "  run-$i: [未完成]"
        fi
    done

    # Track 3: Distrust principle
    echo ""
    echo "--- Track 3: 不信任原则 ---"
    for i in "${RUN_IDS[@]}"; do
        file="$RESULTS_DIR/s2-run-$i/grading-3.json"
        if [[ -f "$file" ]]; then
            ind_rate=$(json_summary_value "$file" "independent_rate" "?")
            planted_rate=$(json_summary_value "$file" "planted_detection_rate" "?")
            level=$(json_summary_value "$file" "independence_level" "?")
            echo "  run-$i: independent_rate=$ind_rate, planted_detection=$planted_rate, level=$level"
        else
            echo "  run-$i: [未完成]"
        fi
    done

    # Track 4: Product thinking
    emit_score_track_summary "Track 4: Product Thinking" "grading-product-thinking.json" "${PRODUCT_SCENARIOS[@]}"

    # Track 5: Problem discovery
    emit_score_track_summary "Track 5: Problem Discovery" "grading-problem-discovery.json" "${PRODUCT_SCENARIOS[@]}"

    # Track 6: Phase slicing quality
    emit_score_track_summary "Track 6: Phase Slicing Quality" "grading-phase-slicing-quality.json" "${PRODUCT_SCENARIOS[@]}"

    # Track 7: Process lightness
    emit_score_track_summary "Track 7: Process Lightness" "grading-process-lightness.json" "${PRODUCT_SCENARIOS[@]}"

    # Track 8: Product director thinking
    emit_score_track_summary "Track 8: Product Director Thinking" "grading-product-director-thinking.json" "${PRODUCT_DIRECTOR_SCENARIOS[@]}"

    # Track 9: Product manager unit quality
    emit_score_track_summary "Track 9: Product Manager Unit Quality" "grading-product-manager-unit-quality.json" "${PRODUCT_MANAGER_SCENARIOS[@]}"
}

case "${1:-}" in
    check)   cmd_check ;;
    status)  cmd_status ;;
    summary) cmd_summary ;;
    *)       usage ;;
esac
