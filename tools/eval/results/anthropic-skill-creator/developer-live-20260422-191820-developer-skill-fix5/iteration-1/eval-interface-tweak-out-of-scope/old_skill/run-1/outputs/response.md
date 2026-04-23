按 `developer` skill 的规则，这一步应当**阻断并上报 delivery-owner**，不要继续改代码。

原因很明确：
- 当前 Task 的允许修改范围只有 `src/api/user.ts` 和 `tests/api/user.test.ts`
- `design_refs` 指向 `design.json#/interfaces/UserResponse`
- 你已经判断出实现 `display_name` **必须同步 `design.json`**
- 这属于**范围外文件**修改，命中硬约束：`NO code changes in files outside declared file range`

下一步应做的是：
- 记录为 `DESIGN_ISSUE:INTERFACE_TWEAK`
- 向 delivery-owner 报告：需要把 `design.json` 纳入任务范围，或由上游刷新 canonical design 后再继续
- 在未补齐前，**不要进入 GREEN，也不要修改任何代码**

当前结论：
- 状态：`BLOCKED`
- 原因：`design.json` 不在授权文件范围内，但实现该 AC 必需修改它