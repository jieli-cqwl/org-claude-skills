#!/bin/bash
# PostCompact Hook: compaction 后注入分层上下文恢复提醒
# 通过 stdout 输出 JSON hookSpecificOutput.additionalContext 注入给 Claude
# 版本: v2.1 2026-04-01

echo "[$(date)] PostCompact hook triggered" >> ~/.claude/hooks/post_compact.log

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostCompact",
    "additionalContext": "[PostCompact 上下文恢复]\n\nCompaction 已完成。按以下优先级恢复最小上下文（非全量重读）：\n\n1. Read ~/.claude/rules/ 下所有规则文件\n2. 如果正在执行 Skill：\n   a. Read 该 Skill 的 SKILL.md（仅 SKILL.md，不读 references）\n   b. 确认当前步骤编号和状态\n   c. 仅 Read 当前步骤需要的 reference 文件（不读其他步骤的 reference）\n   d. 仅 Read 当前步骤的输入文档（如当前步骤需要 prd.md 就读 prd.md）\n3. 如果在 Plan Mode 中：Read 当前计划文件（plans/ 目录）\n4. 继续未完成的步骤\n\nFORBIDDEN:\n- 不要重读 docs/{feature}/ 下的所有文档——只读当前步骤需要的\n- 不要重读已完成步骤的 reference 文件\n- 不要在对话中复述恢复的内容——直接继续工作\n- 不要假设你还记得 compaction 前的细节——不确定就 Read 确认"
  }
}
EOF

exit 0
