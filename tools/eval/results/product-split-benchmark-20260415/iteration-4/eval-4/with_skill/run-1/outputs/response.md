按当前文档，`product-manager` 的闭环是：先 `M-S7` 完整性扫描，再 `M-S8` 三视角独立评审，最后走 `M-G1` 裁决并在 `brief.md#交付确认` 收口，不是“做过一次 review”就算结束。

必须显式保留的规则是：
- 三视角并行且独立：产品 / 架构 / 测试都只看工件，不信任自我报告。
- 首轮全 PASS 也要补一轮 `R2 / CONFIRMATION`；有 FAIL 只重提 FAIL 视角，PASS 视角不重跑。
- 连续 2 轮 FAIL 数不减少就 `ASK_USER`，同一 issue 连续 3 轮未关就 `BLOCKED`。
- 结果必须落到 `brief.md#审查结论 / 审查汇总 / 审查问题台账 / 收敛轮次摘要`，并保持 `Verdict / Issue Count / Findings`。
- `Issue Count` 只算未关闭稳定 issue；`PASS` 必须是 `0`；`PR-* / AR-* / TR-*` 只给未关闭项，已关闭痕迹改 `HIS-*`。
- 产品视角必须保留 `R1~R6 + R13 + PR-C1`，并检查 Director lock 与 `D-G1` 快照一致性；锁漂移直接 `FAIL`，不能用 `WARN` 放行。
- `WARN` 不能口头带过，必须显式承接；`审查问题台账` 不能空，`ASK_USER / BLOCKED` 才写 `用户裁决记录`。
- 一旦 review 发现根问题、范围或 Phase 要变，立刻回 `/product-director`，不要在 Manager 里硬改。

依据：
- [product-manager/SKILL.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/with_split/shared/skills/product-manager/SKILL.md)
- [playbook-map.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/with_split/shared/skills/product-shared/references/playbook-map.md)
- [brief-template.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/with_split/shared/skills/product-shared/references/templates/brief-template.md)