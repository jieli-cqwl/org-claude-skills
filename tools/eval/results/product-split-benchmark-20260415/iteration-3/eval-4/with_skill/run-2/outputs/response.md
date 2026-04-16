在 split 后的 `product-manager`，评审闭环要按“完整性扫描 → 三方独立审查 → 结果入台账 → `CONFIRMATION` → 裁决/升级”跑，不是做一次 review 就结束。
- 产品/架构/测试必须并行独立审查；首轮全 `PASS` 也要再做一轮 `CONFIRMATION`。
- 有 `FAIL` 时只重提 `FAIL` 视角，不重跑已 `PASS` 视角；连续 2 轮 `FAIL` 数不减就 `ASK_USER`，同一 issue 连续 3 轮未关闭就 `BLOCKED`。
- 必须显式保留 `PR-* / AR-* / TR-*`、`PASS` 时 `Issue Count=0`、`WARN` 的书面承接，以及 `brief.md#审查结论 / 审查汇总 / 审查问题台账 / 收敛轮次摘要`。
- 产品视角还要保留 `R1` 的 `UNIT` 与根问题/Director lock 一致性检查，以及 `R13`、`PR-C1`；一旦改写 lock，直接 `FAIL`，回退 `/product-director`。对话上每次只收口一个主题，先复述冻结基线，再问新增细节。

依据：
[product-manager/SKILL.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/SKILL.md)
[playbook-map.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-shared/references/playbook-map.md)
[conversation-guide.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/references/conversation-guide.md)
[prd-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/references/prd-reviewer-prompt.md)
[architect-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/references/architect-reviewer-prompt.md)
[tester-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/references/tester-reviewer-prompt.md)
[completeness-checklist.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/references/completeness-checklist.md)