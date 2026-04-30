# Intake And State

Trigger: 接手、状态优先级或缺输入判断不清时读取。
Read: tech-lead plan/tasks、scope、AC、依赖、确认状态、证据入口和可用 executor。
Expect: 接手决策、状态优先级和最小状态卡。
Consume: `Intake / State` 步骤。
Evidence: decision log 中的 `ACCEPTED / NEEDS_BASELINE / NEEDS_INPUT / NEEDS_RESOURCE`。
Sync: 接手门槛、状态字段或 authority 边界变化时同步。

## 接手门槛

只有同时满足这些条件，才能进入交付控制：

- plan/tasks 来自 `tech-lead` 冻结输出。
- plan 已有用户或 authority 确认进入交付。
- 每个 task 有明确 scope。
- 每个 task 有 AC、test refs、acceptance targets 或等价验收依据。
- task 依赖只指向计划内 task。
- 至少存在下一步可调度的 role executor。

缺目标、scope、AC、依赖或技术基线时，输出 `NEEDS_BASELINE`。缺路径、版本、证据入口或工作区时，输出 `NEEDS_INPUT`。缺角色、权限、环境或工具时，输出 `NEEDS_RESOURCE`。

## 状态优先级

同一时间出现多个状态时，按这个顺序裁决：

```text
rebaseline_needed / authority_unclear
> blocked
> needs_rework
> in_progress
> evidence_ready
> signoff_ready
```

高优先级状态未解决时，不按低优先级状态推进。

## 最小状态卡

```text
plan_ref
task_ref
current_state
current_owner
dependency_state
handoff_state
highest_priority_gap
evidence_refs
decision_log
next_action
```

每个状态结论都要能追到证据引用，或者明确写出缺失项和 owner。
