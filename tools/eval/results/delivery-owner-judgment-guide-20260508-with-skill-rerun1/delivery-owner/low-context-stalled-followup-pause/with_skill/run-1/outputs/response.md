status: PAUSED_FOR_USER_DECISION  
plan_ref: 未提供，本次为 eval 场景判断  
tasks_ref: 未提供，本次为 eval 场景判断  
current_step: DO-S5/DO-S7 循环收敛门禁  
execution_mode: 暂停，不继续催办  
active_batch: 当前交付缺口  
active_tasks: 未提供  
current_gap: 同一个交付缺口连续两轮未收敛  
gap_owner: 原 owner，未变化  
next_owner: user  
dev_verify_loop_count: unknown  
qa_fix_loop_count: unknown  
progress_signal: no_progress  
consecutive_no_progress_count: 2  
completed_tasks: 无新增  
evidence_refs: 无新增  
stale_evidence_refs: 两轮仅回复“还在处理”  
current_risk: 循环不收敛，继续催办会制造空转  
decision_boundary: DO-HG-4，同一 gap 连续 2 轮无关闭、缩小、新证据、新阻塞、新风险或 owner 变化  
next_action: 暂停给用户决策，不再继续催  
resume_condition: 用户裁决下一步策略、资源或范围后恢复  

status: PAUSED_FOR_USER_DECISION  
current_step: DO-HG-4 用户暂停边界  
decision_needed: 是否调整策略，而不是继续催  
confirmed_facts: 同一交付缺口已跟进两轮；两轮都只有“还在处理”；没有新报告、新证据、新阻塞、新风险；owner 未变化  
attempted_actions: 已连续跟进两轮  
risk_or_blocker: 当前循环没有任何有效进展信号  
impact: 继续催不会满足 delivery-owner 的收敛要求，也无法进入下一轮派发或验收  
evidence_refs: 仅有两轮口头状态，无合格证据  
options: 1. 补充明确输入并收窄 packet；2. 更换 owner 或改派 fixer/verifier 诊断；3. 暂停该 gap，要求重新确认 scope/AC/资源；4. 升级回 tech-lead 评估方案或任务基线  
recommended_option: 不继续催。先暂停并要求用户选择：补信息、换 owner、收窄 scope，或升级基线审视  
required_user_answer: 选择下一步处理策略，并确认是否接受延期/资源调整/范围调整  
resume_condition: 用户明确策略与 owner 后恢复执行  
next_action_after_decision: 按裁决重写派发包或升级基线，不复用原来的“继续处理”循环