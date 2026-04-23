已按 `shared/skills/developer/SKILL.md` 读取并核对。

结论：`runtime_status: "BLOCKED"`，不能直接实现这个 Task。

缺失的关键前置条件有：
- `work_dir` / `unit_work_dir`
- `design.json`
- `tasks.json`
- `artifact-registry.json` 或 active registry
- AC 列表
- 权威文件范围 `file_range` / `files` / `task_scope`

你给的描述只有一句“修一个订单金额计算 bug”，不足以进入 developer skill 要求的 TDD 流程，也不足以确认允许修改的文件范围。按 skill 规则，这种情况必须停住，不能进入 RED/GREEN，也不能写代码。

请 delivery-owner 补齐 `work_dir`、`AC 列表`、`file_range/files/task_scope` 后再继续。
在补齐前，允许修改集合为空，不进入 RED/GREEN，不写代码。