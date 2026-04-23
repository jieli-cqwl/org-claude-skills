已按 `shared/skills/developer/SKILL.md` 读取规则并判定：当前任务必须阻断，不能进入实现。

阻断原因：
- 缺少 Task 需求全文，尤其是 `AC 列表`
- 缺少 `design.json`
- 缺少 `tasks.json`
- 缺少 `artifact-registry.json`
- 缺少权威 `file_range / files / task_scope`
- 也没有 `work_dir` / `unit_work_dir`

按 skill 规则，这种情况下只能向 delivery-owner 请求补齐信息，不能自行猜测范围或直接改代码。当前只能给出结论：

`runtime_status: BLOCKED`

如果你要继续，我需要至少拿到：
1. `work_dir` 或 `unit_work_dir`
2. `design.json`
3. `tasks.json`
4. 这个 Task 的 `AC`
5. 明确的 `file_range / files / task_scope`