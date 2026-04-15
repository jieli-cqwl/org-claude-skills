#!/usr/bin/env bash
# Skill 行为评测入口脚本
# 用途：协调评测执行流程，不直接运行评测（评测通过 Claude Code Agent tool 执行）
# 本脚本用于验证评测环境和查看结果

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$EVAL_DIR/results"
SCENARIOS_DIR="$EVAL_DIR/scenarios"
GRADERS_DIR="$EVAL_DIR/graders"

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

    # 检查 grader 文件
    for grader in hard-gate-grader.md arch-framework-grader.md distrust-grader.md product-thinking-grader.md problem-discovery-grader.md phase-slicing-quality-grader.md process-lightness-grader.md product-director-thinking-grader.md product-manager-unit-quality-grader.md; do
        if [[ -f "$GRADERS_DIR/$grader" ]]; then
            echo "  [OK] graders/$grader"
            ((ok++))
        else
            echo "  [MISSING] graders/$grader"
            ((fail++))
        fi
    done

    # 检查场景文件
    for scenario in \
        s1-design-execution.md \
        s2-review-planted.md \
        p1-clear-single-phase.md \
        p2-solution-anchoring.md \
        p3-multi-phase-value-slicing.md \
        product-director-p1-clear-single-phase.md \
        product-director-p2-solution-anchoring.md \
        product-director-p3-multi-phase-value-slicing.md \
        product-manager-p1-handoff-readiness.md \
        product-manager-p2-lock-drift-blocking.md \
        product-manager-p3-unit-boundary-cocreation.md; do
        if [[ -f "$SCENARIOS_DIR/$scenario" ]]; then
            echo "  [OK] scenarios/$scenario"
            ((ok++))
        else
            echo "  [MISSING] scenarios/$scenario"
            ((fail++))
        fi
    done

    # 检查 skill 变体
    for variant in design-with-why.md design-no-why.md; do
        if [[ -f "$SCENARIOS_DIR/skill-variants/$variant" ]]; then
            echo "  [OK] scenarios/skill-variants/$variant"
            ((ok++))
        else
            echo "  [MISSING] scenarios/skill-variants/$variant"
            ((fail++))
        fi
    done

    # 检查最小 PRD fixture
    local prd_path
    prd_path="$(cd "$EVAL_DIR/../.." && pwd)/tools/eval/fixtures/weekly-report/prd.md"
    if [[ -f "$prd_path" ]]; then
        echo "  [OK] tools/eval/fixtures/weekly-report/prd.md"
        ((ok++))
    else
        echo "  [MISSING] tools/eval/fixtures/weekly-report/prd.md"
        ((fail++))
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

    # S1 A 变体
    for i in 1 2 3; do
        local dir="$RESULTS_DIR/s1-a-run-$i"
        if [[ -f "$dir/grading-1.json" && -f "$dir/grading-2.json" ]]; then
            echo "  [DONE] s1-a-run-$i"
        elif [[ -d "$dir" ]]; then
            echo "  [PARTIAL] s1-a-run-$i (执行完成但评分未完成)"
        else
            echo "  [PENDING] s1-a-run-$i"
        fi
    done

    # S1 B 变体
    for i in 1 2 3; do
        local dir="$RESULTS_DIR/s1-b-run-$i"
        if [[ -f "$dir/grading-1.json" && -f "$dir/grading-2.json" ]]; then
            echo "  [DONE] s1-b-run-$i"
        elif [[ -d "$dir" ]]; then
            echo "  [PARTIAL] s1-b-run-$i"
        else
            echo "  [PENDING] s1-b-run-$i"
        fi
    done

    # S2
    for i in 1 2 3; do
        local dir="$RESULTS_DIR/s2-run-$i"
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
    for scenario in \
        p1-clear-single-phase \
        p2-solution-anchoring \
        p3-multi-phase-value-slicing; do
        for i in 1 2 3; do
            local dir="$RESULTS_DIR/${scenario}-run-$i"
            if [[ -f "$dir/grading-product-thinking.json" && -f "$dir/grading-problem-discovery.json" && -f "$dir/grading-phase-slicing-quality.json" && -f "$dir/grading-process-lightness.json" ]]; then
                echo "  [DONE] ${scenario}-run-$i"
            elif [[ -d "$dir" ]]; then
                echo "  [PARTIAL] ${scenario}-run-$i"
            else
                echo "  [PENDING] ${scenario}-run-$i"
            fi
        done
    done

    # Product director scenarios
    for scenario in \
        product-director-p1-clear-single-phase \
        product-director-p2-solution-anchoring \
        product-director-p3-multi-phase-value-slicing; do
        for i in 1 2 3; do
            local dir="$RESULTS_DIR/${scenario}-run-$i"
            if [[ -f "$dir/grading-product-director-thinking.json" ]]; then
                echo "  [DONE] ${scenario}-run-$i"
            elif [[ -d "$dir" ]]; then
                echo "  [PARTIAL] ${scenario}-run-$i"
            else
                echo "  [PENDING] ${scenario}-run-$i"
            fi
        done
    done

    # Product manager scenarios
    for scenario in \
        product-manager-p1-handoff-readiness \
        product-manager-p2-lock-drift-blocking \
        product-manager-p3-unit-boundary-cocreation; do
        for i in 1 2 3; do
            local dir="$RESULTS_DIR/${scenario}-run-$i"
            if [[ -f "$dir/grading-product-manager-unit-quality.json" ]]; then
                echo "  [DONE] ${scenario}-run-$i"
            elif [[ -d "$dir" ]]; then
                echo "  [PARTIAL] ${scenario}-run-$i"
            else
                echo "  [PENDING] ${scenario}-run-$i"
            fi
        done
    done
}

cmd_summary() {
    echo "=== 评测结果汇总 ==="

    # Track 1: HARD-GATE compliance
    echo ""
    echo "--- Track 1: HARD-GATE Why 效果 ---"
    for variant in a b; do
        local variant_label
        variant_label=$(printf '%s' "$variant" | tr '[:lower:]' '[:upper:]')
        echo "  变体 ${variant_label}:"
        for i in 1 2 3; do
            local file="$RESULTS_DIR/s1-${variant}-run-$i/grading-1.json"
            if [[ -f "$file" ]]; then
                # 提取 compliance_rate
                local rate
                rate=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['compliance_rate'])" 2>/dev/null || echo "parse_error")
                echo "    run-$i: compliance_rate=$rate"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done

    # Track 2: Architecture framework
    echo ""
    echo "--- Track 2: 架构思维框架 ---"
    for i in 1 2 3; do
        local file="$RESULTS_DIR/s1-a-run-$i/grading-2.json"
        if [[ -f "$file" ]]; then
            local covered avg_depth
            covered=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['dimensions_covered'])" 2>/dev/null || echo "?")
            avg_depth=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['avg_depth'])" 2>/dev/null || echo "?")
            echo "  run-$i: covered=$covered/4, avg_depth=$avg_depth"
        else
            echo "  run-$i: [未完成]"
        fi
    done

    # Track 3: Distrust principle
    echo ""
    echo "--- Track 3: 不信任原则 ---"
    for i in 1 2 3; do
        local file="$RESULTS_DIR/s2-run-$i/grading-3.json"
        if [[ -f "$file" ]]; then
            local ind_rate planted_rate level
            ind_rate=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['independent_rate'])" 2>/dev/null || echo "?")
            planted_rate=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['planted_detection_rate'])" 2>/dev/null || echo "?")
            level=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['independence_level'])" 2>/dev/null || echo "?")
            echo "  run-$i: independent_rate=$ind_rate, planted_detection=$planted_rate, level=$level"
        else
            echo "  run-$i: [未完成]"
        fi
    done

    # Track 4: Product thinking
    echo ""
    echo "--- Track 4: Product Thinking ---"
    for scenario in \
        p1-clear-single-phase \
        p2-solution-anchoring \
        p3-multi-phase-value-slicing; do
        echo "  $scenario:"
        for i in 1 2 3; do
            local file="$RESULTS_DIR/${scenario}-run-$i/grading-product-thinking.json"
            if [[ -f "$file" ]]; then
                local passed score
                passed=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['passed_count'])" 2>/dev/null || echo "?")
                score=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['score'])" 2>/dev/null || echo "?")
                echo "    run-$i: passed=$passed/3, score=$score"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done

    # Track 5: Problem discovery
    echo ""
    echo "--- Track 5: Problem Discovery ---"
    for scenario in \
        p1-clear-single-phase \
        p2-solution-anchoring \
        p3-multi-phase-value-slicing; do
        echo "  $scenario:"
        for i in 1 2 3; do
            local file="$RESULTS_DIR/${scenario}-run-$i/grading-problem-discovery.json"
            if [[ -f "$file" ]]; then
                local passed score
                passed=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['passed_count'])" 2>/dev/null || echo "?")
                score=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['score'])" 2>/dev/null || echo "?")
                echo "    run-$i: passed=$passed/3, score=$score"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done

    # Track 6: Phase slicing quality
    echo ""
    echo "--- Track 6: Phase Slicing Quality ---"
    for scenario in \
        p1-clear-single-phase \
        p2-solution-anchoring \
        p3-multi-phase-value-slicing; do
        echo "  $scenario:"
        for i in 1 2 3; do
            local file="$RESULTS_DIR/${scenario}-run-$i/grading-phase-slicing-quality.json"
            if [[ -f "$file" ]]; then
                local passed score
                passed=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['passed_count'])" 2>/dev/null || echo "?")
                score=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['score'])" 2>/dev/null || echo "?")
                echo "    run-$i: passed=$passed/3, score=$score"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done

    # Track 7: Process lightness
    echo ""
    echo "--- Track 7: Process Lightness ---"
    for scenario in \
        p1-clear-single-phase \
        p2-solution-anchoring \
        p3-multi-phase-value-slicing; do
        echo "  $scenario:"
        for i in 1 2 3; do
            local file="$RESULTS_DIR/${scenario}-run-$i/grading-process-lightness.json"
            if [[ -f "$file" ]]; then
                local passed score
                passed=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['passed_count'])" 2>/dev/null || echo "?")
                score=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['score'])" 2>/dev/null || echo "?")
                echo "    run-$i: passed=$passed/3, score=$score"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done

    # Track 8: Product director thinking
    echo ""
    echo "--- Track 8: Product Director Thinking ---"
    for scenario in \
        product-director-p1-clear-single-phase \
        product-director-p2-solution-anchoring \
        product-director-p3-multi-phase-value-slicing; do
        echo "  ${scenario}:"
        for i in 1 2 3; do
            local file="$RESULTS_DIR/${scenario}-run-$i/grading-product-director-thinking.json"
            if [[ -f "$file" ]]; then
                local passed score
                passed=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['passed_count'])" 2>/dev/null || echo "?")
                score=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['score'])" 2>/dev/null || echo "?")
                echo "    run-$i: passed=$passed/3, score=$score"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done

    # Track 9: Product manager unit quality
    echo ""
    echo "--- Track 9: Product Manager Unit Quality ---"
    for scenario in \
        product-manager-p1-handoff-readiness \
        product-manager-p2-lock-drift-blocking \
        product-manager-p3-unit-boundary-cocreation; do
        echo "  ${scenario}:"
        for i in 1 2 3; do
            local file="$RESULTS_DIR/${scenario}-run-$i/grading-product-manager-unit-quality.json"
            if [[ -f "$file" ]]; then
                local passed score
                passed=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['passed_count'])" 2>/dev/null || echo "?")
                score=$(python3 -c "import json; d=json.load(open('$file')); print(d['summary']['score'])" 2>/dev/null || echo "?")
                echo "    run-$i: passed=$passed/3, score=$score"
            else
                echo "    run-$i: [未完成]"
            fi
        done
    done
}

case "${1:-}" in
    check)   cmd_check ;;
    status)  cmd_status ;;
    summary) cmd_summary ;;
    *)       usage ;;
esac
