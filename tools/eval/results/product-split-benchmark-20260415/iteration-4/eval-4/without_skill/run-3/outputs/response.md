文档里对应的是 `/product` 阶段。我会把它理解成 `S11→S12` 的闭环：先让 3 个 reviewer（产品/架构/测试）并行审 `brief.md + phase-{N}/prd.md + units/`，主 agent 再把结果合并进 `brief.md#审查结论`；如果有 `FAIL`，只修对应工件并只重审 `FAIL` 视角，最多 10 轮。首轮全 `PASS` 也要补确认轮；连续 2 轮 `FAIL` 不减少就暂停问用户；同一问题 3 轮未关闭则 `BLOCKED`。

必须显式保留的规则有：
- `PR/AR/TR` 只统计未关闭稳定 issue，某视角 `PASS` 时 `Issue Count=0`。
- 已关闭痕迹改写为 `HIS-*`，`审查问题台账` 不能空，首轮全 `PASS` 也要留 1 条 `HIS-*`。
- `WARN` 必须在 `brief.md` 的 `审查结论` 里承接。
- 不能保留 `候选问题 / 候选根问题 / 未裁决 root problem` 这类草稿标记。
- `brief.md` 还必须有 `交付确认(确认状态=确认)`，`phase-prd` 不能丢 `阶段目标 / 入口与出口条件 / UNIT 索引`。

依据：[SKILL.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/SKILL.md)、[brief-template.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/templates/brief-template.md)、[prd-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/prd-reviewer-prompt.md)、[architect-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/architect-reviewer-prompt.md)、[tester-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/tester-reviewer-prompt.md)、[phase-prd-template.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/templates/phase-prd-template.md)