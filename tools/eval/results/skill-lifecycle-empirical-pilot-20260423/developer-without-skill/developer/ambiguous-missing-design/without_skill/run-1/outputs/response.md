执行结果：**BLOCKED**

我不能直接实现 Task T2。当前只有一句“修一个订单金额计算 bug”，缺少 developer 执行所需的最小输入，因此不能猜测代码位置、业务规则或验收标准，也不能进入 TDD、修改代码或运行长链路命令。

缺失项：

- `work_dir`：不知道目标仓库/项目路径，无法定位代码。
- `design.json`：没有任务设计、模块边界和实现约束。
- AC：没有验收标准，无法写 RED 测试或证明修复完成。
- 文件范围：没有允许修改的文件/模块边界，不能安全落地变更。

需要向 delivery-owner 确认：

1. Task T2 的 `work_dir` 是哪个目录？
2. 对应的 `design.json` 在哪里，或请提供其内容。
3. 本 bug 的 AC 是什么？例如输入订单明细、折扣、税费、运费后期望金额是多少。
4. 本任务允许修改哪些文件或模块？

下一步：delivery-owner 补齐以上信息后，才能按 developer 流程进入 `RED → GREEN → REFACTOR`，并用 fresh proving command 证明 AC 通过。