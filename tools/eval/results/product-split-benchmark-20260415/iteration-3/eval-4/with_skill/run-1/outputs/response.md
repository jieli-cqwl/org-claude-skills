依据 [product-manager SKILL.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/SKILL.md) 和 [Product Split Playbook Map](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-shared/references/playbook-map.md)，`/product-manager` 的评审闭环不是“做一次 review”，而是“三视角并行 + 轮次收敛”。

- 闭环顺序：产品/架构/测试独立审查，首轮即使全 `PASS` 也必须再做一轮 `CONFIRMATION`。
- 收敛规则：只重提 `FAIL` 视角，不重跑已 `PASS` 视角；连续 2 轮 `FAIL` 数不减少就 `ASK_USER`，同一 issue 3 轮未关闭就 `BLOCKED`。
- 必须显式保留：产品视角仍要查 `R1~R6`，并额外保留 `R13`、`PR-C1`、Director lock 与 `brief.lock.json / phase-{N}/prd.lock.json` 一致性检查；发现 lock 漂移，直接 `FAIL`，不能拿 `WARN` 继续。
- 结果落地：`WARN` 不能口头带过，要写进 `brief.md#审查结论`；稳定 issue id 用 `PR-* / AR-* / TR-*`，留痕用 `HIS-*`，`Issue Count` 只算未关闭项且 `PASS=0`；最终要落到 `审查结论 / 审查汇总 / 审查问题台账 / 收敛轮次摘要`。

如果你要，我可以再把这套规则压成一版“review 闭环检查清单”。