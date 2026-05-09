判定：**不能先交给 `/product-manager` 拆 UNIT**。

对齐理解：
- 目标：判断 legacy `brief.md` 是否足以进入 `/product-manager`。
- 当前事实：有 legacy `brief.md`，但没有产品总监确认、没有 `brief.json`。
- 结论标准：必须满足 `/product-director` 的 D-G1 总监确认门和 Director schema gate。

阻断原因：
- `/product-manager` 只能消费**已通过总监确认门**的 `brief.json` / `phase-{N}/phase-prd.json`，不能消费 legacy `brief.md` 作为 handoff 真源。
- 缺少明确 `产品总监确认`，D-G1 未通过。
- 缺少 `director_confirmation.status=passed`、`locked_fields`、`locked_field_digest`，下游没有不可改写基线。
- 缺少 Phase 级 `phase-prd.json` 骨架，PM 无法基于已冻结的 `phase_goal`、`entry_conditions`、`exit_conditions` 拆 UNIT。
- legacy `brief.md` 最多只能作为 D-S1 输入线索，不能参与 handoff 判断。

下一步：
1. 回到 `/product-director` 流程，补齐并确认 Director 基线。
2. 收到明确 `产品总监确认` 后，生成 `brief.json` 和各 `phase-{N}/phase-prd.json`。
3. 写入 `director_confirmation.locked_fields` 与 `locked_field_digest`。
4. 通过 Director schema gate 后，才允许 handoff 给 `/product-manager` 拆 UNIT。

协作评估：这是单点门禁判断，不需要启动审查 agent、生成完整产物或执行长链路命令。