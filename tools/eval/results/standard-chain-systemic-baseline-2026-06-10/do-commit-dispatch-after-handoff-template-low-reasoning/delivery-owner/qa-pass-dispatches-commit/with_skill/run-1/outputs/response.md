**状态卡**
- `current_stage`: `DO-S8c`
- `status`: `READY_FOR_COMMIT`
- `control_action`: `DISPATCH_READY`
- `blocker_id`: `none`
- `blocker_owner`: `none`
- `blocker_basis_refs`: `none`
- `resume_stage`: `DO-S8d`
- `next_action`: 输出字段完整的 `/commit` handoff
- `resume_condition`: 维持现有 `signoff-package.json` 与 `user-decision.json` 一致，且不改 scope/AC/goal/tasks/design

**收尾结论**
- 你给出的现场事实已经满足 DO-S8a/DO-S8b 的前置条件：`qa PASS`、`consistency-auditor` 无阻断 owner action、`signoff-package.json` 已形成且覆盖当前 active evidence、`user-decision.json` 已记录提交授权、当前无未决风险。
- 但本 eval 明确不要求真实提交，所以不能声称 `DELIVERED`，也不应调用真实 `/commit`。
- 当前应停在 `DO-S8c`，向下一步输出 `/commit handoff`，状态标记为 `dispatch_ready`。

**必须保留的门禁**
- 不能在没有 `commit_result` / `commit_result_ref` 的情况下写 `DELIVERED`。
- 不能在 `/commit` 中改变 scope、AC、goal、tasks 或 design。
- 不能跳过 `signoff-package.json` 与 `user-decision.json` 的一致性校验。
- 不能把“无阻断”误写成“已提交完成”。

**下一步**
- 生成字段完整的 `/commit handoff`，然后等待真实提交动作。