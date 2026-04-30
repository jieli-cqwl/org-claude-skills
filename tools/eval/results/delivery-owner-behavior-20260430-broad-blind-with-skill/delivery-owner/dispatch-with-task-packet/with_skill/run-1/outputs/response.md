按 `delivery-owner` 边界执行：当前不是实现 AC-2，而是派发给 developer agent。

**状态卡**
```text
status: DISPATCH_READY
plan_ref: tech-lead frozen plan, path=unavailable
tasks_ref: T2, path=unavailable
current_step: DO-S4 派发开发
execution_mode: serial / single-task
active_batch: T2
active_tasks: T2
current_gap: AC-2 未实现
gap_owner: delivery-owner
next_owner: developer agent
dev_verify_loop_count: 0
qa_fix_loop_count: 0
progress_signal: owner_changed
consecutive_no_progress_count: 0
completed_tasks: none
evidence_refs: .eval/t2-ac2-developer-packet.json, task_packet_check PASS
stale_evidence_refs: none
current_risk: 输入无真实 plan/tasks 路径，developer 必须先解析冻结 T2 scope/AC；解析失败即停
decision_boundary: scope/AC/依赖冲突、资源不可用、连续无进展、提交授权不清
next_action: 将下方 Task Packet 派发给 developer agent executor
resume_condition: developer 返回 developer-report.json 或精确 blocker
```

**Task Packet**
```text
task_ref: T2
role: developer
goal: 实现 T2 中缺失的 AC-2，并只为该 gap 产出开发证据。
scope:
- T2 冻结实现范围，path=unavailable
- 只允许修改冻结 T2 scope 内的文件、目录和用户路径
- 不处理其他 task 或无关共享状态
input_refs:
- plan: tech-lead frozen plan, path=unavailable
- tasks: T2 frozen task/scope, path=unavailable
- acceptance: T2 AC-2, path=unavailable
- gap: AC-2 not implemented, path=unavailable
expected_evidence:
- developer preflight
- RED evidence
- GREEN evidence
- REFACTOR evidence 或 no-op 说明
- developer-report.json
stop_condition:
- AC-2 证据 GREEN 后停止并报告
- scope/AC/依赖/环境/权限不可解析或冲突时停止并报告 blocker
forbidden_actions:
- 不越过 T2 scope
- 不改写冻结 baseline、AC 或验收口径
- 不 commit/release/push
- 不代替 verifier/qa/fixer 角色结论
```

**门禁结果**
`task_packet_check.sh` 已通过：`status=PASS, decision=DISPATCH_READY, safe_to_dispatch=true`。

下一步：派发给 developer agent executor。developer 返回后进入 DO-S5，必须由 verifier agent 独立验 AC-2；若同一 gap 连续 2 轮无进展或总循环到 10 轮，暂停给用户决策。