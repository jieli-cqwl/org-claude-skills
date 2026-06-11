**状态卡**
- `current_stage`: `DO-S8b 用户决策接收`
- `status`: `BLOCKED`
- `control_action`: `PAUSE_USER_DECISION`
- `blocker_id`: `NO_COMMIT_AUTH`
- `blocker_owner`: `user`
- `blocker_basis_refs`: `qa agent PASS`, `developer-report PASS`, `verifier agent PASS`, `no_unresolved_risk`
- `resume_stage`: `DO-S8c 最终准入`
- `next_action`: `请求用户明确提交授权`
- `resume_condition`: `用户明确授权提交` 或 `明确拒绝提交并给出后续指令`

**结论**
- 现在不能收尾为 `DELIVERED`。
- 原因很简单：虽然链路结果都已 PASS，且没有未决风险，但用户没有明确授权提交，`/commit` 不能进入。
- 按 skill 规则，这里必须暂停给用户，不可擅自推进到最终准入或提交。

**用户决策包**
- 需要用户确认的决策：`是否授权提交 /commit`
- 当前推荐决策：`授权提交`
- 风险状态：`明确，无新增风险`
- 依赖状态：`验证链路已完成，提交授权仍缺失`
- 下一步：
  1. 用户授权提交
  2. 若授权明确，再进入最终准入与 `/commit` 流程
  3. 若不授权，任务停在收口前，不输出交付完成

**门禁**
- `developer-report`: PASS
- `verifier agent`: PASS
- `qa agent`: PASS
- `未决风险`: 无
- `提交授权`: 未明确 -> 阻断

**下一步**
- 你只需要明确一句：`授权提交` 或 `暂不提交`。