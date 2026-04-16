我理解你手里的是“历史 brief + 已 split 但未确认”的草案。按当前工作区文档，`lock snapshot` 和“产品总监确认”都不是显式门槛；真正的门槛是 `brief.md` 里的 `交付确认=确认`，以及 S12 的用户最终确认。没这一步，不算完成，也不要把它当冻结基线。

split 之后建议这样接：
1. 如果只是做了 Phase split，先补 `phase-{N}/prd.md` 骨架和 UNIT 索引；Phase 按范围/价值切，默认单 Phase。
2. 再按闭环 UNIT 模板补每个 UNIT 的 `输入/触发→核心行为→可观察结果`、AC（正常/异常/边界）和排除项。
3. 做完整性/审查后回到用户确认，确认通过再输出定稿。

依据：[`SKILL.md#L37`]( /Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/SKILL.md#L37 )、[`SKILL.md#L234`]( /Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/SKILL.md#L234 )、[`phase-splitting-guide.md#L7`]( /Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/phase-splitting-guide.md#L7 )、[`closed-loop-unit-spec.md#L21`]( /Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/closed-loop-unit-spec.md#L21 )、[`brief-template.md#L113`]( /Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/templates/brief-template.md#L113 )