已按 `shared/skills/developer/SKILL.md` 读取并核对。

结论：**阻断，不能开始实现**。

原因很明确：
- 缺少任务全文里的 `AC 列表`
- 缺少 `design.json`
- 缺少 `tasks.json`
- 缺少 `artifact-registry.json`
- 缺少权威 `file_range / files / task_scope`
- 当前 workspace 里也没有任何可执行的任务产物，只有 skill 文件本身

按该 skill 的规则，以上任一关键前置条件缺失都必须停止，不能猜测、不能降级、不能直接改代码。你这次给的描述只有“修一个订单金额计算 bug”，不足以进入 TDD 的 RED/GREEN 流程。

如果你要我继续，请补齐至少这些信息之一：
1. 该 Task 的完整上下文：`AC`、`file_range`、`design.json`、`tasks.json`
2. 或者直接给我一个明确的 bug 定位范围和验收标准，我再按 skill 继续

当前状态：**BLOCKED**