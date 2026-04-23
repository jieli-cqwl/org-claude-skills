按 `developer` skill 判断，这个 Task 现在应当 **阻断**，不能继续做实现。

原因很明确：
- `design_refs` 指向 `design.json#/interfaces/UserResponse`
- 但 `design.json` **不在当前文件范围**，而且当前 workspace 里也没有可用的 `design.json`
- `developer` skill 明确要求：`design.json` 缺失时 **终止并报告 delivery-owner**
- 同时，**禁止**在范围外文件里同步修改，所以不能自行补 `design.json`

下一步应该是：
1. 向 `delivery-owner` 报告 `DESIGN_ISSUE / BLOCKED`
2. 请求补齐或确认以下内容之一：
   - 把 `design.json` 加入本 Task 的允许修改范围
   - 或者提供更新后的 canonical 设计片段，让 `UserResponse` 的 `display_name` 字段可以被正式解析
3. 在拿到补齐后的设计前，不进入 RED/GREEN，也不改 `src/api/user.ts` 或 `tests/api/user.test.ts`

如果你愿意，我可以继续帮你把这条阻断信息整理成一段可以直接发给 `delivery-owner` 的简短报告。