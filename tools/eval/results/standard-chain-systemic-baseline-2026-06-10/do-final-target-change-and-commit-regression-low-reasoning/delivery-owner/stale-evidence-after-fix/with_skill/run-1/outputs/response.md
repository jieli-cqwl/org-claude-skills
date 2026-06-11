状态卡
- current_stage: `DO-S8b / 用户决策接收前置`
- status: `BLOCKED`
- control_action: `PAUSE_FOR_USER`
- blocker_id: `target_changed_after_qa`
- blocker_owner: `tech-lead`
- blocker_basis_refs: `T3 相关代码已被 fixer agent 修改；现有 verifier/qa 证据不再能证明当前代码`
- resume_stage: `DO-S1 / 重新冻结 baseline`
- next_action: `回到 tech-lead 重新冻结 T3，重新跑受影响 verifier / code-review / qa，再谈 /commit`
- resume_condition: `新一轮 evidence 必须晚于最后一次代码变更，并且 QA PASS + release_recommendation=ALLOW`

结论：**不能直接调度 `/commit`。**

原因很硬：
1. `verifier` 和 `qa` 通过的是**旧代码状态**。
2. `fixer agent` 已经改了 T3 相关代码，这会让旧的 `verify-result`、`qa-result`、`code-review-result` 失去“current/fresh”资格。
3. 按 delivery-owner 规则，**最后一次代码变更之后必须有 fresh 的 verifier → code-reviewer → qa 证据**，否则不能进入 `/commit`。

你现在应该走的是：
- 先判定这是 **target change / rebaseline required**
- 若 T3 变更影响 scope/AC/tasks，写 `target-change.json`
- 由 `tech-lead` 重新冻结 baseline
- 重新派发受影响 task 的 `developer/verifier/code-reviewer/qa`
- 只有新的 `signoff-package.json` + `user-decision.json` 对齐后，才进入 `/commit handoff`

阻断条件：
- 旧 QA 不能覆盖新代码
- 缺少“最后一次变更之后”的 fresh 证据
- 当前还没完成重新基线

下一步：
1. 把这次 fixer 改动视为 T3 重基线事件。
2. 先拿新鲜的 `verify-result` / `code-review-result` / `qa-result`。
3. 证据齐了再决定是否可以 `/commit`。