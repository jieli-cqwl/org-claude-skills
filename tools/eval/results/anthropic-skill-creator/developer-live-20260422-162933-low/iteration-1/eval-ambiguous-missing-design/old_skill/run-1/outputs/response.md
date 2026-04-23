已按 `shared/skills/developer/SKILL.md` 和硬规则核对，当前必须阻断，不能直接实现。

阻断原因：
- 没有 `design.json`
- 没有 `tasks.json`
- 没有 `artifact-registry.json`
- 没有 Task 的 `AC` 列表
- 没有权威 `file_range/files/task_scope`
- 只有一句“修一个订单金额计算 bug”，不足以进入 TDD 的 `RED -> GREEN -> REFACTOR`

按技能要求，这种情况只能先向 `delivery-owner` 补齐前置条件，不能猜测实现、不能扩大范围、不能开始改代码。

你补齐下面任一组信息后，我就可以继续：
1. `phase_dir` 下的 `design.json`、`tasks.json`、`artifact-registry.json`
2. 当前 Task 的完整描述，至少包含 `AC` 和 `file_range/files/task_scope`
3. 如果有 `test-cases.json` 也一并提供，便于按 TDD 走完证据链

当前结论：`BLOCKED`，未进行任何代码修改。