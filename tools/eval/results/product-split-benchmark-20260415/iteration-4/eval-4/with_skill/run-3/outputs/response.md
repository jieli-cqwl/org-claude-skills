你担心的是对的：split 后不能只说“做过一次 review”，要把它做成闭环。

- M-S8 里三视角并行（产品/架构/测试），M-G1 只在 PASS/WARN 后放行；首轮全 PASS 也要再跑 `CONFIRMATION`，有 FAIL 只重提 FAIL 视角，2 轮 FAIL 不减→`ASK_USER`，同 issue 3 轮未关→`BLOCKED`。
- 结果必须落到 `brief.md#审查结论 / 审查汇总 / 审查问题台账 / 收敛轮次摘要`；`WARN` 不能口头带过，`Issue Count` 只算未关闭且 PASS 必为 0，`Review Round` 只记首次出现轮次，`ASK_USER/BLOCKED` 才写用户裁决记录。
- 必保：`PR/AR/TR` 稳定 issue id，已关项改 `HIS-*`，台账不能空，首轮全 PASS 也要留 1 条 `HIS-*`；产品视角按 `R1~R6 + R13 + PR-C1`，且 `R1=UNIT与根问题一致性+Director lock一致性`，lock 漂移直接 `FAIL`。

依据见 [product-manager SKILL.md](./shared/skills/product-manager/SKILL.md#L76)、[playbook-map.md](./shared/skills/product-shared/references/playbook-map.md#L101)、[brief-template.md](./shared/skills/product-shared/references/templates/brief-template.md#L134)、[PRD 审查 prompt](./shared/skills/product-manager/references/prd-reviewer-prompt.md#L21)。