使用 `delivery-owner` 规则判断：当前处在 **DO-S5 开发/验证循环**。T2 的 AC-2 不能推进到 QA、也不能提交，因为最新 `verify-result=FAIL`，缺口是 **AC-2 只有结论，没有 scope evidence**。

```text
status: BLOCKED_IN_DEV_VERIFY_LOOP
plan_ref: unavailable
tasks_ref: T2
current_step: DO-S5 开发/验证循环
execution_mode: serial
active_batch: unavailable
active_tasks: T2
current_gap: AC-2 缺少 scope evidence，developer-report 只有完成结论
gap_owner: developer
next_owner: developer
dev_verify_loop_count: 1
qa_fix_loop_count: 0
progress_signal: gap_narrowed
consecutive_no_progress_count: 0
completed_tasks: []
evidence_refs:
  - developer-report:T2 path=unavailable
  - verify-result:latest path=unavailable status=FAIL reason=AC-2 missing scope evidence
stale_evidence_refs:
  - AC-2 completion conclusion without scope evidence
current_risk: 若继续推进会形成虚假完成，verifier/QA 无法独立验收 AC-2
decision_boundary: 暂无用户取舍；这是证据缺口，按流程回派 developer
next_action: 回派 T2 developer 补 AC-2 scope evidence，然后重跑 verifier
resume_condition: developer 产出 fresh developer-report，包含 AC-2 scope evidence；verifier 重新核验 AC/scope 后 PASS 或给出新 missing gap
```

下一步安排是 **回派 developer，不派 QA，不调 commit**。

```text
task_ref: T2
role: developer
goal: 补齐 T2 / AC-2 的 scope evidence，使 verifier 能独立判断 AC-2 是否在冻结 scope 内完成
scope:
  - 仅处理 T2 / AC-2 的证据补充或必要的最小实现修正
  - 不扩大 scope，不修改 AC，不处理其他 task
input_refs:
  - tasks:T2 path=unavailable
  - AC:AC-2 path=unavailable
  - developer-report:T2 path=unavailable
  - verify-result:latest path=unavailable status=FAIL reason="AC-2 只有结论，没有 scope evidence"
expected_evidence:
  - developer preflight 结论
  - RED evidence，如适用；若不适用需说明原因
  - GREEN evidence，直接对应 AC-2
  - REFACTOR evidence 或 no-op 说明
  - developer-report.json，必须包含 AC-2 scope evidence、改动范围、验证命令/输出引用
stop_condition:
  - AC-2 scope evidence 已补齐并可供 verifier 独立核验
  - 或报告精确 blocker：缺 plan/tasks/AC 路径、环境不可用、scope/AC 不清
forbidden_actions:
  - 禁止越过 T2 / AC-2 scope 处理其他范围
  - 禁止修改 baseline、AC 或验收口径
  - 禁止 commit、release 或进入 QA
  - 禁止代替 verifier/qa/fixer 给 PASS 结论
```

门禁：正式派发前这个 Task Packet 需要落盘并通过 `task_packet_check.sh`；本 eval 要求不实际写文件、不调 agent，所以我只输出必需字段和下一步。若回派后同一 gap 连续 2 轮没有新证据/缩小缺口，或循环达到 10 轮，按 skill 暂停给用户决策。