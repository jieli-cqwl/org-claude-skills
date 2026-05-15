结论：Stage 1 planning 准入阻断。不能先排开发任务，也不能排期。

当前输入标记：`synthetic/missing`。
产品和设计“口头说准备好了”不等于 tech-lead 可消费的 canonical 输入；本次明确缺少：

- artifact：`docs/{feature}/phase-{N}/unit-{N}/test-cases.json`
- owner：`test-design / test-designer`
- 缺口类型：测试义务不明，`test_refs` 无法绑定
- 影响：planning input is not canonical or not present

按 `tech-lead` HARD-GATE：测试设计 baseline artifact 缺失时，禁止进入 WBS、任务拆解、依赖编排、排期或 `tasks.json/plan.json` 产出。现在直接拆任务，会把验收依据伪装成计划确定性。

对下游影响：

- delivery-owner：无法判断哪些任务可分配、哪些风险要盯、哪些验证证据算完成。
- developer：没有 `test_refs / acceptance_targets / proving_command`，只能猜实现边界和完成口径。
- verify：无法逐 Task 复验，缺少可追踪断言和证据路径。
- qa：无法确认覆盖矩阵、边界路径、失败路径和最终验收依据。

恢复条件：由 `test-designer` 补齐可读取、canonical 的 `phase-{N}/unit-{N}/test-cases.json`，并能覆盖对应 UNIT/AC 的测试断言、验证命令或证据要求。补齐后才允许重新进入 Stage 1 preflight；preflight 通过前，我不会产出开发任务、WBS 或排期。
