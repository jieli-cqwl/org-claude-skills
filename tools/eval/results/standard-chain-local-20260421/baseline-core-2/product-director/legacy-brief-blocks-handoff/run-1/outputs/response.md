我理解的操作对象是：当前只有一个 legacy `brief.md`，但没有用户明确的“产品总监确认”，也没有 standard-chain 的 canonical `brief.json`，更没有对应的 `phase-{N}/phase-prd.json` 骨架。

判定：**不能先交给 `/product-manager` 拆 UNIT。**

原因是 `product-director` skill 的运行边界很明确：

- standard-chain 运行时真源只认 `brief.json / phase-prd.json`，不认 legacy `brief.md` 或派生视图。
- `/product-manager` 只能在 Director 完成 D-G1 后接手；它负责 UNIT 拆解和 AC 细化，不负责补 Director 锁定语义。
- 当前缺少 `产品总监确认`，也缺少 canonical `director_confirmation.locked_fields` 与 `locked_field_digest`，所以 D-G1 未通过。
- 当前也缺少 `phase-{N}/phase-prd.json` 的 Phase 骨架，无法证明 Phase 边界、入口条件、出口条件和 UNIT 索引占位已经冻结。
- 在 `validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"` 通过前，不能把 hook 日志、legacy 文档或口头判断当作 handoff 依据。

下一步应回到 `/product-director` 流程：把 legacy `brief.md` 仅作为输入线索，补齐 Director 确认字段、`locked_fields`、`locked_field_digest`、全部 `phase-{N}/phase-prd.json` 骨架，然后运行标准链路校验。校验通过后，才允许 handoff 给 `/product-manager` 拆 UNIT。