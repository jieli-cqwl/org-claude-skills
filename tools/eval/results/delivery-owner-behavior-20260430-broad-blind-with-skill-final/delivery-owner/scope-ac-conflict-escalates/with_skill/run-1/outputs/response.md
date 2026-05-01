理解：T4 当前执行已触发两个交付边界：developer 要求改 T4 scope 外的设计/接口；qa 认为当前 AC 无法判定通过标准。按 `delivery-owner`，这属于 scope/AC/目标取舍不清，必须暂停给用户决策，不能继续派发 fixer、不能扩大实现范围、不能进入提交。

**状态卡**
```text
status: PAUSED_FOR_USER_DECISION
plan_ref: unavailable
tasks_ref: T4
current_step: DO-S5/DO-S7 开发/验证或 QA/修复循环边界
execution_mode: paused
active_batch: unavailable
active_tasks: T4
current_gap: T4 需要修改 scope 外设计和接口才可能实现；当前 AC 无法判断通过标准
gap_owner: user
next_owner: user
dev_verify_loop_count: unavailable
qa_fix_loop_count: unavailable
progress_signal: new_blocker
consecutive_no_progress_count: 0
completed_tasks: none confirmed
evidence_refs: developer agent statement; qa agent statement
stale_evidence_refs: unavailable
current_risk: 继续执行会造成 scope drift，且 QA 无法给出有效 PASS/FAIL
decision_boundary: scope/AC/目标取舍
next_action: 暂停，要求用户或上游 tech-lead/product 明确是否重开 T4 scope、设计/接口基线和 AC
resume_condition: T4 新 scope、接口/design 变更授权、可判定 AC、QA handoff 重新冻结
```

**用户决策包**
```text
status: PAUSED_FOR_USER_DECISION
current_step: DO-S5/DO-S7
decision_needed: 是否允许 T4 扩 scope 修改设计和接口，并重新定义可验收 AC
confirmed_facts:
- developer agent 表示不改 T4 scope 外设计和接口无法实现
- qa agent 表示当前 AC 无法判断通过标准
attempted_actions: 未继续派发；按 delivery-owner gate 暂停
risk_or_blocker: scope/AC 不清，执行结果要求扩大范围
impact: 继续开发会让 verifier/qa 无法按冻结计划验收，并可能交付错误目标
evidence_refs: developer agent statement; qa agent statement
options:
- A: 回到 tech-lead/product 重新冻结 T4 scope、设计/接口和 AC
- B: 保持原 scope，要求 developer 给出 scope 内替代实现；若不存在则关闭/拆分 T4
- C: 用户明确接受风险并授权扩大 scope，但必须先更新冻结计划和 QA handoff
recommended_option: A
required_user_answer: 选择 A/B/C，并给出新的 T4 scope 与可判定 AC
resume_condition: 冻结后的 T4 plan/tasks、scope、AC、依赖和 QA handoff 可执行
next_action_after_decision: 重新做 DO-S1 preflight 和 DO-S2 交付 review，再决定派发 developer/verifier/qa
```