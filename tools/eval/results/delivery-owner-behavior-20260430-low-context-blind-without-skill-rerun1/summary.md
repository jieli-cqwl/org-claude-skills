# Standard-Chain Local Skill Eval

- total expectations: 32
- failed expectations: 24
- infra failures: 0
- pass rate: 0.25

## Runs
- delivery-owner / low-context-verify-gap-routing: 2/13 passed
  - failed: 回派 developer agent
  - failed: 内联 developer Task Packet
  - failed: developer packet input_refs 指向 developer-report 和 verify-result
  - failed: expected_evidence 要求 fresh developer-report 和 scope evidence
  - failed: 状态卡记录 current_gap
  - failed: 状态卡记录 progress_signal
  - failed: 状态卡记录 consecutive_no_progress_count
  - failed: 状态卡记录 next_owner
  - failed: 状态卡记录 resume_condition
  - failed: developer agent 返回后再调度 verifier agent
  - failed: 说明 10 轮或 2 轮无进展暂停
- delivery-owner / low-context-fix-invalidates-evidence: 5/9 passed
  - failed: 状态卡记录 stale_evidence_refs
  - failed: 调度受影响 verifier agent 复验
  - failed: 调度 qa agent 重跑受影响路径
  - failed: 提交前要求用户授权明确
- delivery-owner / low-context-stalled-followup-pause: 1/10 passed
  - failed: 不继续催同一个 owner
  - failed: 状态卡记录 PAUSED_FOR_USER_DECISION
  - failed: 状态卡记录 current_gap
  - failed: 状态卡记录 progress_signal=no_progress
  - failed: 状态卡记录 consecutive_no_progress_count=2
  - failed: 状态卡记录 next_owner=user
  - failed: 输出用户决策包
  - failed: 用户决策包包含 required_user_answer
  - failed: 用户决策包包含 next_action_after_decision

## Optimization Findings
- 调度可执行性不足 -> 补充内联 developer Task Packet，包含 input_refs、expected_evidence、next_owner、resume_condition，并明确 developer 返回后调度 verifier 复验。
- 循环控制缺失 -> 加入 10 轮上限和同一 gap 连续 2 轮无进展暂停给用户决策的规则。
