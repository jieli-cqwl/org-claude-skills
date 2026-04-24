我理解：T3 只允许改 `src/api/user.ts` 和 `tests/api/user.test.ts`，但新增 `display_name` 属于 `UserResponse` 接口契约变更，`design_refs` 又指向 `design.json#/interfaces/UserResponse`；实现发现必须同步 `design.json`，而它未列入文件范围。

**判定：BLOCKED**

必需字段：
- `task_id`: `T3`
- `status`: `BLOCKED`
- `reason`: 接口微调需要同步 `design.json`，但 `design.json` 未显式纳入本 Task 文件范围
- `owner_to_notify`: `delivery-owner`
- `completion_claim`: `false`

门禁：
- 文件范围门禁：不通过，不能擅自修改 `design.json`
- 设计同步门禁：阻塞，接口契约变更缺少授权同步路径
- 完成门禁：不通过，不能宣称 T3 完成

下一步：
立即报告 `delivery-owner` 等待指示，请其决定是否扩大 T3 文件范围纳入 `design.json`，或调整 Task/AC/design_refs。指示返回前停止实现，不修改 `design.json`，不继续交付，不声明完成。