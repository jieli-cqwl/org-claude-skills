已按 `shared/skills/developer/SKILL.md` 检查，当前任务必须阻断。

阻断原因：
- 当前临时 workspace 里没有任何可用任务输入文件。
- 缺少 `design.json`
- 缺少 `tasks.json`
- 缺少 `artifact-registry.json`
- 任务只有一句描述，没有 `AC`、`file_range/files/task_scope`，因此不能确定允许修改的文件范围
- 按 skill 规则，范围不明时只能将修改集合视为“空集合”，不能进入真实代码改动

结论：
- 现在不能执行 Task T2 的实现
- 需要 delivery-owner 先补齐 canonical 任务包，至少提供：
  - 任务全文
  - `design.json`
  - `tasks.json`
  - `artifact-registry.json`
  - 明确的文件范围 `file_range/files/task_scope`
  - AC 列表

如果你愿意，我可以继续帮你做下一步：
1. 按 developer 规则整理一份“缺失项清单”，方便你补包
2. 等你补齐后，我再继续按 TDD 执行 T2