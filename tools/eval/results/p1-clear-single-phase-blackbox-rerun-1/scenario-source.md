# Scenario Source

- 场景文件：`/Users/lijieli/org-claude-skills/tools/eval/scenarios/p1-clear-single-phase.md`
- 任务类型：`/product` 独立执行样本
- 用户首句：`给内部周报系统加一个已发布周报列表页，登录后可分页查看已发布周报，先不做搜索和编辑。`
- 约束摘要：
  - 只做一个闭环、一个 Phase
  - 登录能力已存在，本次不重做认证流程
  - 分页每页 10 条，仅上一页/下一页
  - 不做搜索、不做筛选、不做编辑、不做导出
  - 列表为空时要有明确提示
- 允许读取的参考：
  - `/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md`
  - `/Users/lijieli/org-claude-skills/shared/skills/product/references/phase-splitting-guide.md`
  - `/Users/lijieli/org-claude-skills/shared/skills/product/references/closed-loop-unit-spec.md`
  - `/Users/lijieli/org-claude-skills/shared/skills/product/references/completeness-checklist.md`
  - `/Users/lijieli/org-claude-skills/shared/skills/product/references/templates/brief-template.md`
  - `/Users/lijieli/org-claude-skills/shared/skills/product/references/templates/phase-prd-template.md`
  - `/Users/lijieli/org-claude-skills/shared/skills/product/references/conversation-guide.md`

