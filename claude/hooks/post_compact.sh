#!/bin/bash
# PostCompact Hook: compaction 后注入分层上下文恢复提醒
# 通过 stdout 输出的内容会作为 system message 注入给 Claude

echo "[$(date)] PostCompact hook triggered" >> ~/.claude/hooks/post_compact.log

cat <<'REMINDER'
[PostCompact 上下文恢复]

Compaction 已完成。按以下优先级恢复最小上下文（非全量重读）：

1. Read ~/.claude/rules/ 下所有规则文件
2. 如果正在执行 Skill：
   a. Read 该 Skill 的 SKILL.md（仅 SKILL.md，不读 references）
   b. 确认当前步骤编号和状态
   c. 仅 Read 当前步骤需要的 reference 文件（不读其他步骤的 reference）
   d. 仅 Read 当前步骤的输入文档（如当前步骤需要 prd.md 就读 prd.md）
3. 如果在 Plan Mode 中：Read 当前计划文件（plans/ 目录）
4. 继续未完成的步骤

FORBIDDEN:
- 不要重读 docs/{feature}/ 下的所有文档——只读当前步骤需要的
- 不要重读已完成步骤的 reference 文件
- 不要在对话中复述恢复的内容——直接继续工作
- 不要假设你还记得 compaction 前的细节——不确定就 Read 确认
REMINDER
