# Delivery Status Card

```text
status: NEEDS_INPUT
plan_ref: 未提供
tasks_ref: 缺失冻结版 tasks.json
current_step: DO-S1 接手与 preflight
execution_mode: Stage 1 eval dry-run / no-write / no-dispatch
active_batch: none
active_tasks: none
current_gap: phase-dir 证据入口不完整；缺 artifact-registry.json；缺 tech-lead 冻结且确认的 tasks.json
gap_owner: user / tech-lead
next_owner: user
dev_verify_loop_count: 0
qa_fix_loop_count: 0
progress_signal: new_blocker
consecutive_no_progress_count: 0
completed_tasks: none
evidence_refs: none
stale_evidence_refs: none
current_risk: 基线缺失，执行角色会猜 scope、AC、依赖和验收证据
decision_boundary: DO-HG-1 冻结计划不可执行时暂停
next_action: 补齐 phase-dir、tech-lead 冻结 tasks.json、artifact-registry.json 与 QA handoff 证据入口后重新 preflight
resume_condition: 可读取完整 phase-dir，且 tasks 由 tech-lead 产出、已冻结/确认，artifact-registry 指向有效 active revision
```

# User Decision Package

```text
status: PAUSED_FOR_USER_DECISION
current_step: DO-S1 intake/preflight
decision_needed: 是否回流 tech-lead 补齐冻结基线与 artifact-registry
confirmed_facts:
- 当前不能直接组织 developer 开干
- 当前没有可消费的冻结 tasks baseline
- 当前缺 artifact-registry.json
- 当前缺完整 phase-dir 证据入口
- 本次为 dry-run，未写入业务 JSON，未修改文件，未运行真实 qft-pai 代码，未派发任何执行角色

attempted_actions:
- 按 delivery-owner DO-S1 做准入判断
- 因准入缺失在 HARD-GATE 停止

risk_or_blocker:
- 缺 tasks：developer 无法确定唯一 task、scope、AC、depends_on、停止条件和证据要求
- 缺 artifact-registry：verifier 无法确认引用的是哪一版计划/设计/测试用例，证据链不可追踪
- 缺 QA handoff 证据入口：qa 无法按用户路径、qa_handoff_contract、cross_unit_obligations 验收
- 基线未冻结：code-reviewer 无法判断实现是否偏离冻结范围
- 证据链缺失：/commit 不能形成 signoff package，也不能证明提交范围与验收证据闭合

impact:
- 不进入 DO-S2 交付 review
- 不进入 DO-S3 执行策略
- 不进入 DO-S4 developer 派发
- 不调度 developer/verifier/code-reviewer/qa/fixer/consistency-auditor
- 不生成 delivery-state.json、signoff-package.json 或提交计划
- 不宣称业务交付成功，也不宣称 Stage 1 通过

evidence_refs:
- delivery-owner HARD-GATE DO-HG-1：phase-dir、tasks 文件或证据入口缺失时输出 NEEDS_INPUT 并暂停
- delivery-owner DO-S1：preflight 必须确认冻结 tasks、scope、AC、依赖、qa_handoff_contract、cross_unit_obligations 与 blocking gap 状态

options:
1. 回流 tech-lead 补齐并冻结 tasks baseline，生成 artifact-registry 后重新提交 phase-dir
2. 若已有文件，提供完整 phase-dir 路径，由 delivery-owner 重新 dry-run preflight
3. 若要变更目标为非交付执行，请重新定义 eval 目标和输出边界

recommended_option: 1
required_user_answer: 提供完整 phase-dir，或确认回流 tech-lead 补齐冻结 tasks 与 artifact-registry
resume_condition: phase-dir、冻结 tasks.json、artifact-registry.json、QA handoff 证据入口全部可读取且一致
next_action_after_decision: 重新执行 DO-S1 preflight；通过后才允许 baseline consistency-audit，仍不直接派发 developer
```