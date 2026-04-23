已按 `shared/skills/developer/SKILL.md` 读取规则。

结论：`BLOCKED`

缺失的前置条件有：
- `work_dir` / `unit_work_dir`
- Task 需求全文里的 `AC` 列表
- 权威文件范围：`file_range` / `files` / `task_scope`
- `design.json`
- `tasks.json`
- active registry / `artifact-registry.json`
- `design_refs` 的 canonical 解析结果

按该 skill 的硬规则，这种情况下我不能进入 RED/GREEN，也不能写代码。
请先补齐 `delivery-owner` 侧的 canonical 输入，尤其是 `work_dir`、`AC` 列表、`file_range/files/task_scope`，我再继续按 TDD 执行。