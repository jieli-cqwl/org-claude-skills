工作区里没看到独立的 `product-manager` 文档，所以按 `product` skill 的 S11/S12 来看：3 个 reviewer 要独立审，不看自评，输入固定是 `brief.md`、`phase-{N}/prd.md`、`units/`；结论统一回写 `brief.md#审查结论`，用 `审查汇总` + `审查问题台账` 闭环，且两者 issue 数必须一致。

必须显式保留：
- `FAIL` 直接阻塞，`WARN` 必须在 `审查结论` 里承接；
- `Issue Count` 只算未关闭稳定 issue（`PR-* / AR-* / TR-*`），`PASS` 必须为 `0`，关闭项改成 `HIS-*`，台账不能空，首轮全 PASS 也至少留 1 条 `HIS-*`；
- 首轮全 PASS 仍要补 `R2 / CONFIRMATION`；连续 2 轮 FAIL 数不降要暂停问用户；同一 issue 3 轮未关就 `BLOCKED`；
- 最后只有 S12 用户确认且 `交付确认=确认` 才算收口。

依据：[`shared/skills/product/SKILL.md`](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/old_monolith/shared/skills/product/SKILL.md)、[`shared/skills/product/references/templates/brief-template.md`](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/old_monolith/shared/skills/product/references/templates/brief-template.md)、[`shared/skills/product/scripts/completion_check.sh`](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/old_monolith/shared/skills/product/scripts/completion_check.sh)