`runtime_status: "BLOCKED"`

我已按 `shared/skills/developer/SKILL.md` 检查，当前不能开始实现 Task T2，原因是关键前置条件缺失：

- 没有 `work_dir` / `unit_work_dir`
- 没有 Task 需求全文
- 没有 AC 列表
- 没有权威文件范围 `file_range` / `files` / `task_scope`
- 没有 `design.json`
- 没有 `tasks.json`
- 没有 `artifact-registry.json` 或 active registry
- 工作区里也确实只有 `shared/skills/developer/SKILL.md` 和 `shared/skills/developer/test-prompts.json`，没有可执行项目文件

按 skill 规则，这种情况下必须停在阻断，不进入 RED/GREEN，不写代码。

请补齐下面这些 canonical 输入后我再继续：
- `work_dir`
- `unit_work_dir`
- Task T2 的完整描述
- AC 列表
- `file_range` / `files` / `task_scope`
- `design.json`
- `tasks.json`
- `artifact-registry.json` 或 active registry

补齐后我会按 TDD 只在声明范围内处理这个订单金额计算 bug。