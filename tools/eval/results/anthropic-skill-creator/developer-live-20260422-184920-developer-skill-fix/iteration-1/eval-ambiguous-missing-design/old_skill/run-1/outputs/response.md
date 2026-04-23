按 `shared/skills/developer/SKILL.md` 处理后，这个 Task 现在必须阻断，不能开始实现。

缺失的前置条件：
- 没有 `design.json`
- 没有 `tasks.json`
- 没有 `artifact-registry.json`
- 没有任务全文里的 `AC`
- 没有 `file_range / files / task_scope`
- 当前临时 workspace 也是空的，没有可执行输入

按 skill 规则，`file_range/files/task_scope` 解析不到时，允许修改集合只能是空集合，不能进入真实代码改动；而 `design.json` 缺失时必须直接终止并报告。

你只要补齐以下任一组信息，我就可以继续：
1. `phase_dir` 下的 canonical 产物：`design.json`、`tasks.json`、`artifact-registry.json`
2. 这个 Task T2 的完整内容：AC、允许修改的文件范围、相关 test refs
3. 如果是评测输入，请至少给出可落地的 workspace 路径和任务边界

目前结论：`BLOCKED`，原因是前置条件不足，不能按 developer skill 进入 TDD。