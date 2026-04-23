按 `developer` skill 的裁决，这个 Task 现在应当 **阻断**，不能进入 RED/GREEN，也不能修改代码。

结论：
- 当前允许修改集合是 `src/api/user.ts` 和 `tests/api/user.test.ts`
- 但 `design_refs` 指向 `design.json#/interfaces/UserResponse`
- `design.json` 不在本次权威文件范围内，且 `developer` 规则要求 `design_refs` 必须能从 canonical `design.json` 解析
- 由于关键前置条件不足，不能假设、不能降级绕过，也不能同步修改范围外文件

下一步应做的事：
- 向 `delivery-owner` 报告阻断
- 明确请求补齐或确认：
  - `design.json` 是否纳入本 Task 的权威输入
  - 如果要同步 `display_name`，是否需要把 `design.json` 加入允许修改范围
  - 若不允许改 `design.json`，则需先刷新 canonical 设计引用后再继续

可直接回传的阻断说明：
- `runtime_status: "BLOCKED"`
- 原因：`design_refs` 无法在当前可读的 canonical 输入中解析，且修复 `display_name` 这一响应字段补充属于接口微调，需要上游 design canonical 刷新或扩范围确认后才能进入 TDD

如果你要，我可以继续帮你把这段阻断信息整理成 `delivery-owner` 可直接接收的格式。