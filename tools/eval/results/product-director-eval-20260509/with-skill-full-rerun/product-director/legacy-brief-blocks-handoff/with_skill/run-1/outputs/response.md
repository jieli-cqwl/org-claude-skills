结论：**不能先交给 `/product-manager` 拆 UNIT。**

对齐结果：当前对象是 `legacy brief.md`，但缺少 Director 权威基线。按 `product-director` skill，`/product-manager` 只能消费已经通过总监确认门的 `brief.json` / `phase-{N}/phase-prd.json`，以及其中冻结的 `director_confirmation`、`locked_fields`、`locked_field_digest`、`delivery_plan` 和 Phase 骨架。`legacy brief.md` 最多是输入线索，不是 handoff 依据。

**阻断点**
- 未收到明确 `产品总监确认`
- 没有 canonical `brief.json`
- 没有 `phase-{N}/phase-prd.json` 骨架
- 未写入 `director_confirmation.locked_fields`
- 未写入 `locked_field_digest`
- 未通过 Director schema gate
- `/product-manager` 不得直接补、改 `locked_fields` 或 `locked_field_digest`

**下一步**
回到 `/product-director`：把 legacy brief 作为 D-S1 线索，按 D-S2 → D-S6 补齐并闭合根问题、目标、范围、风险、Phase 规划；进入 D-G1 后等待明确 `产品总监确认`；再写入 `brief.json` 和 `phase-prd.json` 骨架，冻结 `director_confirmation.locked_fields` 与 `locked_field_digest`，通过 ledger 校验和 Director schema gate。通过后，才允许交给 `/product-manager` 拆 UNIT。

本 eval 不生成文件、不启动服务、不调审查 agent。