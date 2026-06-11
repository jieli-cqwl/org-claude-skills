结论：**不能直接按旧 Task 开始写代码。**

原因很明确：
- 当前 `task_id=T7`、`active_tasks_version_ref=tasks@v1` 只是旧派发口径。
- 用户已经明确把验收改成了“企业分层当天 SLA”，这属于**验收口径漂移**，而且 **tasks@v1 还没刷新**。
- 按 `developer` skill 的硬门禁，**Task / AC / Scope / Report target / 关键 Context 必须在实现前明确且一致**；现在 AC 与任务版本引用冲突，不能用旧 Task 继续开写。

当前边界判断：
- 现有可确认信息：`task_id=T7`、报告路径 `phase-1/unit-1/tasks/T7/developer-report.json`、允许修改 `src/reminders.ts` 和 `tests/reminders.test.ts`。
- 未满足的关键前置：**刷新后的 tasks 版本或明确裁决后的新 AC**。
- 阻断类型：**DEV-HG-1 / DEV-HG-7 前置不成立，必须先停。**

下一步必须做的事：
1. 让上游刷新 `tasks` 到新版本，或
2. 明确裁决：T7 的最终 AC 是否改为“企业分层当天 SLA”，以及对应测试口径。

在这之前：
- **不写代码**
- **不做 RED/GREEN**
- **不生成交付报告**
- **不把旧 Task 当成可执行依据**