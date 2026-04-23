已按 `shared/skills/developer/SKILL.md` 先做前置检查，结论是**阻断**，不能进入 TDD 实现。

当前缺失的关键输入：
- `work_dir` / `phase_dir`
- `design.json`
- `tasks.json`
- `artifact-registry.json`
- Task 的 `AC` 列表
- 权威文件范围 `file_range` / `files` / `task_scope`

按该 skill 的硬规则，以上缺失时必须停止，不能猜测补做，也不能直接改代码。
这次我没有做任何实现，也没有写入任何产物。

如果你要我继续，请补齐至少这些内容：
1. Task T2 的完整描述
2. `phase_dir` 或 `work_dir`
3. `design.json`
4. `tasks.json`
5. 明确的文件修改范围

补齐后我会按 `RED -> GREEN -> REFACTOR` 继续。