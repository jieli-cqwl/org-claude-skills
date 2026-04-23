已按 `shared/skills/developer/SKILL.md` 检查，当前任务必须阻断。

阻断原因：
- 没有 `design.json`
- 没有 `tasks.json`
- 没有 `artifact-registry.json`
- 没有 `AC`、`file_range/files/task_scope`
- 没有可执行的 TDD 依据，也无法确定允许修改的文件范围

按这个 skill 的规则，以上前置条件缺失时，不能直接实现 `Task T2`，否则会违反：
- 先有 RED 再改代码
- 只能在已声明的文件范围内修改
- 需要有可解析的 canonical 任务与设计真源

请补齐后再派发，至少需要：
- `work_dir / phase_dir`
- `design.json`
- `tasks.json`
- `artifact-registry.json`
- `Task T2` 的 AC 列表
- 明确的 `file_range / files / task_scope`

拿到这些后，我可以继续按 TDD 流程执行。