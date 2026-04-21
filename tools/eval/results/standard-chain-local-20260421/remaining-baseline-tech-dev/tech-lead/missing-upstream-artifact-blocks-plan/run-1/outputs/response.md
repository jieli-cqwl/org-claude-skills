按 [shared/skills/tech-lead/SKILL.md](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/remaining-baseline-tech-dev/_workspaces/tech-lead/shared/skills/tech-lead/SKILL.md) 的硬门槛，这次直接阻断 `plan.json / tasks.json`，我也没有修改任何文件。

**阻断点**
- 当前工作区未找到可用的 `brief.json`、`phase-prd.json`、`phase-{N}/units/` 命中项
- `design.json` 不是冻结后的 canonical 工件，只是口头说过，不能作为 `tech-lead` 的输入
- `test-cases.json` 缺失
- 在这些前置不齐时，`tech-lead` 不能进入 `DESIGN_OK`、覆盖矩阵校验和任务拆分

**为什么必须阻断**
- 这个 skill 明确要求 `brief.json + phase-prd.json + units/ + design.json + test-cases.json` 缺一不可
- 没有冻结设计和测试用例，就无法建立 `UNIT -> AC -> design_ref -> Task -> test_ref` 的可追溯链
- 这种状态下输出 `plan.json / tasks.json` 会变成无依据拆分，违反流程边界

**下一步**
- `brief.json`、`phase-prd.json`、`units/` 先回 `/product-director → /product-manager`
- 口头设计先回 `/design` 冻结成 `phase-{N}/design.json`
- `test-cases.json` 先回 `/test-design`
- 这些都补齐后，再回到 `/tech-lead` 继续拆开发计划

这次结论就是：前置工件不全，`plan.json / tasks.json` 不产出。