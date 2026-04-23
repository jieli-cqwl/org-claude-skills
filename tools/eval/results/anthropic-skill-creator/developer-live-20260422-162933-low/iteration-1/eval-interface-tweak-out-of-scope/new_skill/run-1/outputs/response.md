按 `shared/skills/developer/SKILL.md` 判断，这个 Task 现在必须阻断，不能继续改代码。

原因有两点：
1. 当前 eval workspace 里没有任何输入文件，`src/api/user.ts`、`tests/api/user.test.ts`、`design.json` 都不存在。
2. 该 skill 明确要求 `design.json` 和 `tasks.json` 必须存在，并且 `design_refs` 必须能在 `design.json` 里解析；缺失时要终止并报告，不能猜测或绕过。

因此下一步不是实现 `display_name`，而是向 delivery-owner / 上游补齐本次 Task 的 canonical 输入，至少需要：
- `task` 全文
- `file_range/files/task_scope`
- `design.json` 中 `#/interfaces/UserResponse` 对应内容
- 目标文件实际存在于 workspace

在这些前置条件补齐前，我不能进入 RED/GREEN，也不能修改任何文件。