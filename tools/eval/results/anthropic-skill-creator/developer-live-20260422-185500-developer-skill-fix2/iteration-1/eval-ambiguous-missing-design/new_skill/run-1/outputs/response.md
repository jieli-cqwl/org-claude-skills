我理解的是：你要我按 `shared/skills/developer/SKILL.md` 直接做 `Task T2`，修一个“订单金额计算 bug”。

当前结论：`BLOCKED`

阻断原因很明确：
- 没有 `work_dir / unit_work_dir`
- 没有 AC 列表
- 没有权威文件范围 `file_range / files / task_scope`
- 没有 `design.json`
- 没有 `tasks.json`
- 没有 active `artifact-registry.json`
- 输入里也没有任何可用文件

按这个 skill 的硬规则，这些前置条件缺失时，必须停止，不能进入 RED/GREEN，不能写代码，允许修改集合为空。

请先补齐这些信息，我才能继续：
- `work_dir`
- `unit_work_dir`
- `Task T2` 的 AC 列表
- 权威文件范围 `file_range/files/task_scope`
- `design.json`
- `tasks.json`
- `artifact-registry.json` 或 active registry 解析结果

补齐后我会按 TDD 流程继续。