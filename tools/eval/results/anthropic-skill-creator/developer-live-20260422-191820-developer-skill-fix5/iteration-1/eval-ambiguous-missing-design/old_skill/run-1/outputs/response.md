已按 `shared/skills/developer/SKILL.md` 检查，当前任务需要的前置条件不足，必须阻断。

阻断原因：
- 没有 `design.json`
- 没有 `tasks.json`
- 没有 `artifact-registry.json`
- 没有明确的 `file_range` / `files` / `task_scope`
- 只有一句任务描述，无法建立 TDD 的 RED/GREEN 证据链
- skill 明确要求：找不到权威文件范围时，不能进入真实代码改动

当前结论：
- `Task T2` 不能开始实现
- 预期结果无法落到具体文件和验收标准，因此按规则返回给 delivery-owner / 上游补齐信息

请补齐这些内容后我再继续：
1. `phase_dir` 下的 `design.json`
2. `tasks.json`
3. 任务 `T2` 的完整 AC
4. 明确文件范围 `file_range` / `files` / `task_scope`

补齐后我会按该 skill 继续做：
- 代码探索
- TDD：RED → GREEN → REFACTOR
- 自测
- 生成 `developer-report.json`