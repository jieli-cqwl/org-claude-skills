#!/bin/bash
# 分层评审原生 agent team 模式契约测试
# 验证：已删除的协议/agent 文件不再被引用，reviewer prompt 不再包含双模式指令

set -euo pipefail

PASS=0; FAIL=0

assert() {
    local label="$1" result="$2"
    if [ "$result" = "0" ]; then
        echo "  PASS: $label"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $label"
        FAIL=$((FAIL+1))
    fi
}

assert_not() {
    local label="$1" result="$2"
    if [ "$result" != "0" ]; then
        echo "  PASS: $label"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $label"
        FAIL=$((FAIL+1))
    fi
}

echo "=== 分层评审原生模式契约测试 ==="

echo ""
echo "--- 已删除文件不存在 ---"
for f in \
    "shared/protocols/team-review-protocol.md" \
    "shared/protocols/review-iteration-protocol.md" \
    "shared/protocols/review-fix-loop-protocol.md" \
    "shared/agents/cross-review-lead.md" \
    "shared/agents/cross-reviewer.md"; do
    test ! -f "$f"; assert "已删除: $f" "$?"
done

echo ""
echo "--- SKILL.md 不再引用已删除协议 ---"
for skill_file in \
    "shared/skills/product/SKILL.md" \
    "shared/skills/design/SKILL.md" \
    "shared/skills/test-design/SKILL.md" \
    "shared/skills/review/SKILL.md" \
    "shared/skills/tech-lead/SKILL.md" \
    "shared/skills/project-manager/SKILL.md"; do
    if [ -f "$skill_file" ]; then
        ! grep -q "team-review-protocol" "$skill_file" 2>/dev/null; assert "无 team-review-protocol 引用: $skill_file" "$?"
        ! grep -q "review-iteration-protocol" "$skill_file" 2>/dev/null; assert "无 review-iteration-protocol 引用: $skill_file" "$?"
    fi
done

echo ""
echo "--- Reviewer prompt 不含双模式指令 ---"
for prompt in \
    "shared/skills/product/references/prd-reviewer-prompt.md" \
    "shared/skills/product/references/architect-reviewer-prompt.md" \
    "shared/skills/product/references/tester-reviewer-prompt.md" \
    "shared/skills/design/references/design-reviewer-prompt.md" \
    "shared/skills/design/references/design-product-reviewer-prompt.md" \
    "shared/skills/design/references/design-test-reviewer-prompt.md"; do
    if [ -f "$prompt" ]; then
        ! grep -qi "Team 模式" "$prompt" 2>/dev/null; assert "无 Team 模式指令: $(basename $prompt)" "$?"
        ! grep -qi "fallback" "$prompt" 2>/dev/null; assert "无 fallback 指令: $(basename $prompt)" "$?"
    fi
done

echo ""
echo "--- 模板不含已移除字段 ---"
for tmpl in \
    "shared/skills/product/references/templates/product-cross-review-template.md" \
    "shared/skills/design/references/templates/design-cross-review-template.md" \
    "shared/skills/test-design/references/templates/testdesign-cross-review-template.md"; do
    if [ -f "$tmpl" ]; then
        ! grep -q "横向质疑" "$tmpl" 2>/dev/null; assert "无横向质疑字段: $(basename $tmpl)" "$?"
        ! grep -q "R2.5" "$tmpl" 2>/dev/null; assert "无 R2.5 引用: $(basename $tmpl)" "$?"
    fi
done

echo ""
echo "--- completion_check.sh 使用新函数 ---"
for script in \
    "shared/skills/product/scripts/completion_check.sh" \
    "shared/skills/design/scripts/completion_check.sh" \
    "shared/skills/review/scripts/completion_check.sh"; do
    if [ -f "$script" ]; then
        ! grep -q "check_review_iteration" "$script" 2>/dev/null; assert "无旧函数调用: $(basename $(dirname $(dirname $script)))" "$?"
    fi
done

echo ""
echo "--- common.sh 旧函数已移除 ---"
if [ -f "shared/hooks/lib/common.sh" ]; then
    ! grep -q "check_review_iteration" "shared/hooks/lib/common.sh" 2>/dev/null; assert "common.sh 无 check_review_iteration 定义" "$?"
    ! grep -q "check_review_shallow_pass" "shared/hooks/lib/common.sh" 2>/dev/null; assert "common.sh 无 check_review_shallow_pass 定义" "$?"
fi

echo ""
echo "=== 结果: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
