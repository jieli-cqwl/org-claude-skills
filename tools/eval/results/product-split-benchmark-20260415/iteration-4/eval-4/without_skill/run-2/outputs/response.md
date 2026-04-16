按当前工作区文档，评审闭环要固定成 `S11→S12`：3 个 reviewer 并行审 `brief.md + phase-{N}/prd.md + units/`，把结果合并回 `brief.md#审查结论`，再做 `FAIL` 修回、`PASS/WARN` 确认，不要只靠口头对齐。

必须显式保留：
- 3 视角 + 对应 prompt，且按独立第三方审查，不信任自报。
- `Issue Count` 只算未关闭稳定 issue；已关闭改 `HIS-*`，`审查问题台账` 不能空。
- 首轮全 PASS 也要 `R2 / CONFIRMATION`；`FAIL` 只重提 FAIL 视角，最多 10 轮，同一问题 3 轮未关即 `BLOCKED`。
- `WARN` 必须在 `审查结论` 承接；`ASK_USER/BLOCKED` 才填用户裁决记录。

出处：
- [product/SKILL.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/SKILL.md#L213)
- [brief-template.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/templates/brief-template.md#L121)
- [prd-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/prd-reviewer-prompt.md#L7)
- [architect-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/architect-reviewer-prompt.md#L7)
- [tester-reviewer-prompt.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/workspaces/old_monolith/shared/skills/product/references/tester-reviewer-prompt.md#L7)