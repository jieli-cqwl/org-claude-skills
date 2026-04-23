理解：这个 Task 只允许改 `src/api/user.ts` 和 `tests/api/user.test.ts`，但 AC 依赖 `design.json#/interfaces/UserResponse`；而 `design.json` 不在声明范围内，当前工作区也没有可用输入文件。

按 `developer` skill 的规则，下一步应当是：

- `阻断`
- 向 `delivery-owner` 报告：`design_refs` 需要解析 `design.json`，但当前 `design.json` 不在 `file_range/files/task_scope` 中
- 请求补齐权威文件范围，或者由上游刷新 canonical `design.json` 后再继续
- 在未补齐前，不能进入真实代码改动，也不能自行同步 `design.json`

结论：`BLOCKED`，原因是“前置条件不足 + 范围外文件不可改”。