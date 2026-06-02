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

prompt_has_legacy_mode_wording() {
    local prompt="$1"
    python3 - "$prompt" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
for line in path.read_text(encoding="utf-8").splitlines():
    lowered = line.lower()
    if "team 模式" in lowered or "fallback" in lowered:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

echo "=== 分层评审原生模式契约测试 ==="

echo ""
echo "--- 已删除文件不存在 ---"
for f in \
    "shared/protocols/team-review-protocol.md" \
    "shared/protocols/review-iteration-protocol.md" \
    "shared/protocols/review-fix-loop-protocol.md"; do
    test ! -f "$f"; assert "已删除: $f" "$?"
done

legacy_agent_count="$(find shared/agents -maxdepth 1 -type f -name 'cross-*' | wc -l | tr -d ' ')"
[ "$legacy_agent_count" = "0" ]; assert "历史并行审查 agent 已清理" "$?"

echo ""
echo "--- SKILL.md 不再引用已删除协议 ---"
for skill_file in \
    "shared/skills/product-director/SKILL.md" \
    "shared/skills/product-manager/SKILL.md" \
    "shared/skills/design/SKILL.md" \
    "shared/skills/test-design/SKILL.md" \
    "shared/skills/review/SKILL.md" \
    "shared/skills/tech-lead/SKILL.md" \
    "shared/skills/delivery-owner/SKILL.md"; do
    if [ -f "$skill_file" ]; then
        ! grep -q "team-review-protocol" "$skill_file" 2>/dev/null; assert "无 team-review-protocol 引用: $skill_file" "$?"
        ! grep -q "review-iteration-protocol" "$skill_file" 2>/dev/null; assert "无 review-iteration-protocol 引用: $skill_file" "$?"
    fi
done

echo ""
echo "--- Reviewer prompt 不含双模式指令 ---"
for prompt in \
    "shared/skills/product-manager/references/prd-reviewer-prompt.md" \
    "shared/skills/product-manager/references/architect-reviewer-prompt.md" \
    "shared/skills/product-manager/references/tester-reviewer-prompt.md" \
    "shared/skills/design/references/design-reviewer-prompt.md" \
    "shared/skills/design/references/design-product-reviewer-prompt.md" \
    "shared/skills/design/references/design-test-reviewer-prompt.md"; do
    if [ -f "$prompt" ]; then
        ! prompt_has_legacy_mode_wording "$prompt"; assert "无 Team/fallback 模式指令: $(basename "$prompt")" "$?"
    fi
done

echo ""
echo "--- 历史独立审查模板已清理 ---"
legacy_template_dirs=()
for template_dir in \
    "shared/skills/product-manager/projections" \
    "shared/skills/design/projections" \
    "shared/skills/test-design/references/templates"; do
    if [ -d "$template_dir" ]; then
        legacy_template_dirs+=("$template_dir")
    fi
done
legacy_template_count="0"
if [ "${#legacy_template_dirs[@]}" -gt 0 ]; then
    legacy_template_count="$(
        find "${legacy_template_dirs[@]}" -maxdepth 1 -type f -name '*cross*.md' | wc -l | tr -d ' '
    )"
fi
[ "$legacy_template_count" = "0" ]; assert "历史独立审查模板已清理" "$?"

echo ""
echo "--- completion_check.sh 使用新函数 ---"
for script in \
    "shared/skills/product-director/scripts/completion_check.sh" \
    "shared/skills/product-manager/scripts/completion_check.sh" \
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
