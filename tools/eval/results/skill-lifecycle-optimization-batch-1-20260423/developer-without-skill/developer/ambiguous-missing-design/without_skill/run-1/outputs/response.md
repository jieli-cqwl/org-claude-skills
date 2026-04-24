已阻断执行。

我理解当前请求是“直接实现 Task T2：修一个订单金额计算 bug”，但输入只有一句描述，缺少 developer 执行所需的最小上下文：

- `work_dir`：不知道要在哪个项目/目录修改
- `design.json`：没有设计边界和任务来源
- `AC`：没有验收标准，无法证明修复正确
- 文件范围：不知道允许修改哪些文件，也无法判断影响面

因此本轮不能猜测实现，不能进入 TDD 的 RED/GREEN/REFACTOR，也不能修改代码。

给 delivery-owner 的问题：

请补齐 Task T2 的执行输入：`work_dir`、对应的 `design.json`、明确 AC，以及允许修改/测试的文件范围。补齐后我才能按 developer 边界开始实现。