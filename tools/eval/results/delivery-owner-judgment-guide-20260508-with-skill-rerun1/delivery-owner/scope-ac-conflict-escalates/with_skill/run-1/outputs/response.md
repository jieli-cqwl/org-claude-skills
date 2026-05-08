```text
status: NEEDS_BASELINE
plan_ref: unavailable
tasks_ref: T4 logical ref only, source file unavailable
current_step: DO-S2 交付 review -> Pause 用户决策
execution_mode: paused
active_batch: unavailable
active_tasks: T4
current_gap: developer agent 判断必须修改 T4 scope 外的设计和接口；qa agent 判断当前 AC 无法判定通过标准。
gap_owner: baseline owner / user decision
next_owner: user
dev_verify_loop_count: unavailable
qa_fix_loop_count: unavailable
progress_signal: new_blocker
consecutive_no_progress_count: 0
completed_tasks: none
evidence_refs: eval prompt facts only; developer-report unavailable; qa-report unavailable
stale_evidence_refs: none
current_risk: 继续派发会让 developer 猜 scope，让 QA 猜验收标准，违反 delivery-owner 的 scope/AC 门禁。
decision_boundary: scope 扩大、设计/接口变更、AC 可验收口径需要上游裁决。
next_action: 暂停交付执行，回流补齐并冻结 T4 baseline。
resume_condition: 用户确认处理路径，并提供冻结后的 T4 scope、设计/接口基线、AC、QA handoff。
```

```text
status: PAUSED_FOR_USER_DECISION
current_step: DO-S2 交付 review
decision_needed: 是否允许 T4 扩大到设计/接口变更，并要求上游重做 baseline。
confirmed_facts:
- developer agent 明确说实现需要改 T4 scope 外的设计和接口。
- qa agent 明确说当前 AC 无法判断通过标准。
- 当前 eval 无 plan/tasks 文件，只有逻辑事实。
attempted_actions:
- 已按 delivery-owner 读取并应用 SKILL.md。
- 未派发 developer/verifier/qa/fixer，未写文件，未启动服务。
risk_or_blocker: scope/AC/QA handoff 不可执行，属于 NEEDS_BASELINE，不是执行 agent 可自行修复的问题。
impact: 若继续执行，会产生范围漂移、接口/设计未授权变更、验收不可判定，后续 verifier/qa 结论无效。
evidence_refs: eval prompt
options:
1. 推荐：暂停 T4，回流 tech-lead，并让 product/design 补齐设计/接口变更、T4 scope、AC、QA handoff 后重新冻结 plan/tasks。
2. 拒绝扩大 scope：要求 tech-lead/product 重新裁剪 T4，只保留原 scope 内可实现、可验收的目标；若无法实现则调整/取消 T4。
3. 用户显式接受风险：授权临时扩大 scope，但仍必须先形成新的冻结 baseline，不能直接让 developer 修改。
recommended_option: 选项 1
required_user_answer: 选择是否允许 T4 scope 扩大；若允许，指定回流 owner 并冻结新的 scope/AC/设计接口基线。
resume_condition: 新 baseline 冻结且 T4 的 file_range/scope/AC/依赖/QA handoff 全部可判定。
next_action_after_decision: 回到 DO-S1 preflight，重新检查冻结 plan/tasks；通过后再进入派发。
```