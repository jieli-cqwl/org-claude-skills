#!/bin/bash
# PostCompact Hook: compaction 后注入最小恢复契约
# 通过 stdout 输出 JSON hookSpecificOutput.additionalContext 注入给 Claude
# 版本: v2.2 2026-04-13

echo "[$(date)] PostCompact hook triggered" >> ~/.claude/hooks/post_compact.log

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostCompact",
    "additionalContext": "[PostCompact 上下文恢复]\n\nCompaction 是有损压缩。不要假设你还记得压缩前细节。\n\n按以下顺序恢复最小上下文（非全量重读）：\n\n1. Read ~/.claude/rules/ 下所有规则文件\n2. 如果正在执行 Skill：\n   a. Read 该 Skill 的 SKILL.md（仅 SKILL.md，不读 references）\n   b. 确认当前步骤编号和状态\n3. 优先读取最新接手入口（如 worklog.md），确认：\n   - mode / stage / status / scope_ref / state_ref / next_ref / blocker / decision_needed\n4. 做新鲜度检查：\n   - 如果 goal / owner / lane / phase 已变化，先回源纠偏，不继续执行\n   - 如果 state_ref / next_ref 缺失、过期或冲突，先修锚点\n5. 最小回源：\n   - 只 Read state_ref、next_ref、当前步骤需要的输入文档与 reference\n   - 如果在 Plan Mode 中：Read 当前计划文件（plans/ 目录）\n   - supporting/ 只作补充，不作真源\n6. 继续或阻塞：\n   - 信息足够：继续未完成的步骤\n   - 信息不足：进入 blocked / waiting_on / unblock_condition / decision_needed\n7. 探索型任务额外允许保留最多 3 条理由胶囊：\n   - 为什么不走 A\n   - 当前优先验证什么\n   - 失败后回退到哪里\n\nFORBIDDEN:\n- 不要重读 docs/{feature}/ 下的所有文档——只读当前步骤需要的\n- 不要重读已完成步骤的 reference 文件\n- 不要在对话中复述恢复的内容——直接继续工作\n- 不要把恢复提示当成真源\n- 不要凭印象补全细节——不确定就 Read 确认"
  }
}
EOF

exit 0
