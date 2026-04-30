# 证据与跟进

Trigger: 不确定证据能否推进、是否失效、如何回派时读取。
Read: executor 结论、evidence refs、diff/命令/报告、后续变更、retry history。
Expect: evidence decision、follow-up packet、无增量退出动作。
Consume: `流程/Observe`、`流程/Control`、`流程/Follow up`。
Evidence: 证据缺口、新增量记录、下一步 owner。
Sync: 证据标准、freshness 或 follow-up 规则变化时同步。

## 证据合格线

推进状态前回答五个问题：

| 标准 | 问题 | 不满足时 |
| --- | --- |
| direct | 是否直接回答当前 gap | 回派，要求补对应证据 |
| fresh | 是否仍有效 | 重跑验证或重派受影响角色 |
| traceable | 是否可追溯到文件、命令、报告、diff 或日志 | 要求补 evidence ref |
| role-owned | 是否由正确 role 产出 | 重派给正确 owner |
| actionable | 失败时是否给出可执行下一步 | 要求补最小下一步 |

## Freshness 传播

真实交付里，后续动作会让旧证据失效：

- fix 改代码后，旧 review、qa、verify 默认重新判定。
- plan/tasks/AC 变化后，旧 task packet 和验收证据默认重新判定。
- 环境、数据、feature flag 或依赖变化后，旧运行证据降级为参考。
- 只改文档但影响用户承诺时，qa 或 authority 证据也要重新判断。

## 回派包

不要写“继续处理”。回派必须带差距：

```text
missing_gap:
why_current_evidence_is_insufficient:
bounded_scope:
expected_new_evidence:
stop_condition:
```

## Control Decision

每轮 Observe 后先写 control decision，再更新状态卡：

```text
task_ref:
previous_owner:
owner:
gap:
decision:
increment:
gap_delta:
packet_delta:
loop_state:
evidence_refs:
next_action:
blocked_by:
```

`increment.kind` 说明新增量来源：`evidence / fix / judgment / blocker / risk / authority_decision / owner_changed / packet_changed / rebaseline_request / readiness_bundle / no_increment`。

`increment.effect` 说明它是否推动收敛：`gap_closed / gap_narrowed / new_blocker / new_risk / owner_changed / packet_changed / rebaseline_needed / readiness_bundle_complete / no_progress`。

`increment.kind` 必须和 `increment.effect` 匹配：例如 `packet_changed` 只能来自 `packet_changed`，`rebaseline_needed` 只能来自 `rebaseline_request`，`readiness_bundle_complete` 只能来自 `readiness_bundle`，`no_progress` 只能来自 `no_increment`。

顶层 `evidence_refs` 和停止包内 `evidence_refs` 必须是非空 canonical ref 数组，不能用普通字符串或口头说明代替。

`gap_closed` 和 `gap_narrowed` 必须有结构化 `gap_delta.before_open_items / after_open_items / closed_items / narrowing_basis_refs`。`after_open_items` 必须是 `before_open_items` 的真子集，`closed_items` 必须等于 before 减 after，`narrowing_basis_refs` 必须是 canonical evidence refs；否则只是文字变化，不算收敛。

`packet_changed` 必须有 `packet_delta.before / after / changed_fields / reason / change_basis_refs`，且 before 和 after 不能相同。它表示交付负责人收窄或改正派发包后让同一 owner 继续，不表示 gap 已关闭；同一 owner / gap 只允许用它做首次 packet correction，下一轮仍不能产出证据时必须换策略或停止。

同 owner `RETURN` 必须有 `loop_state.gap_id / previous_control_decision_ref / remaining_gap_ids / return_count / stop_condition / next_no_progress_action`。`remaining_gap_ids` 必须等于 `gap_delta.after_open_items`；`loop_state.stop_condition` 必须等于 `follow_up.stop_condition`；`next_no_progress_action` 只能是 `REROUTE / ESCALATE / REBASELINE / BLOCKED`，不能继续 RETURN。

脚本 PASS 后才按决策转换：只有 `gap_closed` 才能 `ADVANCE` 回 Pick/Signoff；只有 `gap_narrowed` 或首次 `packet_changed` 且 owner 不变才能 `RETURN` 回 Packet；owner 改变到可执行 role 才能用 `REROUTE` 回 Dispatch；资源、authority 或基线问题使用 `BLOCKED / ESCALATE / REBASELINE` 停止当前执行循环；`SIGNOFF_READY` 交 authority。不要在脚本 FAIL 时更新状态卡。

`authority_decision` 是已取得裁决的新增量；如果它关闭当前 gap，使用 `ADVANCE + gap_closed`。不要在拿到 authority 决策后继续输出 `ESCALATE`。

写入后运行：

```bash
bash shared/skills/delivery-owner/scripts/control_decision_check.sh --decision "$CONTROL_DECISION_PATH"
```

脚本失败时不要更新状态；按失败字段改 packet、换 owner、升级、rebaseline 或停止。

停止分支也必须可交接：`ESCALATE` 写 `escalation_packet`，`REBASELINE` 写 `rebaseline_request`，`BLOCKED` 写 `blocker_packet`。每个包都要包含问题、已尝试动作、证据引用、下一步 owner 和可继续条件；`owner` 必须和包里的 `required_authority / rebaseline_owner / next_owner` 对齐，否则只是停止说明，不是交付控制动作。

## 无增量处理

任一轮没有新增证据、修复、判断、阻塞或风险时：

1. packet 是否太大或目标不清：改 packet。
2. owner 是否不匹配：重派。
3. 是否缺权限、环境或资源：`BLOCKED`，并写 `blocker_packet` 给 resource owner。
4. 是否触及 scope、AC、技术基线或业务风险：升级。
5. 仍无法推进：停止，给出阻塞证据和需要裁决的人。
