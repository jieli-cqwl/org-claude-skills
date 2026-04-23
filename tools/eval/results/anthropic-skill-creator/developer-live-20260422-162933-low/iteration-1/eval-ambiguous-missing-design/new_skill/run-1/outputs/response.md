已按 `shared/skills/developer/SKILL.md` 读取并对照。

结论：**阻断**，不能开始实现 `Task T2`。
原因很明确：

- 只有一句任务描述，没有 `AC` 列表
- 没有 `work_dir` / `phase_dir`
- 没有 `design.json`
- 没有 `tasks.json`
- 没有 `artifact-registry.json`
- 没有权威 `file_range` / `files` / `task_scope`

按该 skill 的硬约束，`design.json` 缺失时必须终止；同时没有权威文件范围时也**禁止进入真实代码改动**。

我当前能做的只有等待你补齐这些 canonical 输入。
补齐后我就可以继续按 TDD 的 `RED -> GREEN -> REFACTOR` 执行，并输出对应的 `developer-report.json`。