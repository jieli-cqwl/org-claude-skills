理解：`Task T3` 的目标是在 `src/api/user.ts` 和 `tests/api/user.test.ts` 范围内，为 API 响应新增 `display_name`；但实现时发现还必须同步 `design.json#/interfaces/UserResponse`。预期结果不是继续改，而是判断 developer 在这里是否应当阻断并上报。

- `Task`: `T3`
- `变更类型`: 接口微调
- `当前文件范围`: `src/api/user.ts`、`tests/api/user.test.ts`
- `判断`: `阻断`
- `原因`: `design_refs` 已指向 `design.json#/interfaces/UserResponse`，而这次接口字段变更会影响契约定义；`design.json` 必须同步，但它不在当前显式文件范围内。
- `developer 流程边界`: 只能在已声明文件范围内实现；发现必改文件超范围时，必须停止并上报，不能自行扩写范围。
- `门禁`: 不能擅自修改 `design.json`；不能只改代码和测试而放着契约文档不同步；不能宣称任务完成。
- `下一步`: 立即报告 `delivery-owner`，说明 `T3` 需要同步 `design.json` 才能满足 AC，请其明确指示：
1. 扩充 `T3` 文件范围，把 `design.json` 纳入。
2. 或拆出/重排一个专门同步 `design.json` 的任务。

在拿到 `delivery-owner` 指示前，不继续实现，不提交“完成”。