已按 `developer` skill 判断：当前应**阻断，不继续实现**。

原因很明确：
- 任务要求新增 API 响应字段 `display_name`，这属于接口微调。
- `design_refs` 指向 `design.json#/interfaces/UserResponse`，但 `design.json` **不在本次允许文件范围**。
- `developer` 规则要求：`design_refs` 必须能在 `{phase_dir}/design.json` 里解析，且**禁止修改范围外文件**。现在这两个条件都不满足。

下一步应该是：
- 向 `delivery-owner` 请求补齐/放宽范围，把 `design.json` 纳入可修改文件，或刷新 canonical 设计版本后再继续。
- 在未补齐前，只能保持 `src/api/user.ts` 和 `tests/api/user.test.ts` 不动，不能开始 RED/GREEN。

如果需要，我可以继续帮你整理一段给 `delivery-owner` 的阻断说明。