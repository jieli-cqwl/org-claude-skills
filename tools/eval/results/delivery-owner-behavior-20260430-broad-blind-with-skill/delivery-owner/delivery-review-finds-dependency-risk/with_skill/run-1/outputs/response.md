我理解本 eval 的操作对象是：冻结计划中的 `T1/T2/T3`，目标是在 **派发 developer 前**完成 delivery-owner 的交付 review 与执行策略裁决，不实际派发、不写文件、不启动服务。

**状态卡**

```text
status: PAUSED_BEFORE_DISPATCH
plan_ref: frozen tech-lead plan, inline only
tasks_ref: T1/T2/T3, inline only
current_step: DO-S2 交付 review -> DO-S3 执行策略
execution_mode: serial
active_batch: B1
active_tasks: T1
current_gap: 无真实 plan/tasks 文件、scope、AC、QA handoff、证据入口和资源状态，不能进入 DO-S4 派发
gap_owner: user / tech-lead
next_owner: user
dev_verify_loop_count: 0
qa_fix_loop_count: 0
progress_signal: new_risk
consecutive_no_progress_count: 0
completed_tasks: none
evidence_refs: inline eval prompt only
stale_evidence_refs: none
current_risk: T3 虽无 depends_on，但会改同一个配置文件，属于共享文件/共享状态风险，不能与 T1/T2 并行派发
decision_boundary: 需要确认共享配置文件归属、冲突顺序、每个 task 的 scope/AC/证据入口/QA handoff
next_action: 暂停，不派发 developer；先补齐 Task Packet 所需输入
resume_condition: plan/tasks 文件、scope、AC、QA handoff、证据入口、资源状态齐备，并明确共享配置文件串行顺序
```

**派发前 review 结论**

执行策略应判定为 `serial`，不是 `parallel`。

原因：`T2 depends_on T1` 形成明确串行链路；`T3` 虽然无依赖，但会修改同一个配置文件，触发 delivery-owner 的共享状态/共享文件风险。按 skill 规则，存在 `depends_on`、共享状态或高回滚风险时必须串行。

推荐顺序：

```text
B1: T1
B2: T2
B3: T3
```

若确认 `T3` 修改的配置会影响 `T2` 的验收或运行前提，则必须回到 tech-lead 修正依赖图，可能变为：

```text
T1 -> T3 -> T2
```

**门禁**

当前不能进入 DO-S4 派发开发，因为缺合格 Task Packet 所需字段：

```text
task_ref / role / goal / scope / input_refs / expected_evidence / stop_condition / forbidden_actions
```

同时缺少可执行证据入口、QA handoff、资源状态，触发 DO-HG-1/DO-HG-2/DO-HG-3 的暂停边界。下一步应由用户或 tech-lead 补齐冻结 plan/tasks 真实引用与每个 task 的验收口径，再生成并校验 Task Packet。