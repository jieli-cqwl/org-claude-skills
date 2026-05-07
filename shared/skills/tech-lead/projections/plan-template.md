# plan projection

> 运行时真源为 `plan.json / tasks.json`；本文件只作为人类投影视图。

## Planning Readiness

- status: {READY, BLOCKED, READY_WITH_USER_DECISION}
- summary: {输入是否足够进入 WBS 计划}
- blocking_gaps: {无 / gap 列表}
- decision_package: {无 / 用户裁决选项与推荐路径}

## Implementation Path

- summary: {本 Phase 的可交付实施路径}
- WBS:

| Work Package | 目标 | Task refs | 完成信号 |
| --- | --- | --- | --- |
| WP-1 | {交付包目标} | T1, T2 | {可观察完成信号} |

- critical_path: {T1 -> T2 -> T4}
- dependency_strategy: {依赖根、串行原因、集成点}
- investment_risk_signals: {投入重、风险高、易返工或需要用户裁决的信号}

## Source Trace

| Source | Ref | Consumed For |
| --- | --- | --- |
| brief / phase-prd / UNIT | {canonical ref} | 目标、范围、优先级 |
| design.json | {canonical ref} | 实施边界、接口、数据、迁移、回滚 |
| test-cases.json | {canonical ref} | 测试义务、assertion target、evidence expectation |

## Goal Fidelity

| goal_source_ref | Task refs | execution_basis_ref | status | note |
| --- | --- | --- | --- | --- |
| {artifact://brief/...#goal-001} | T1 | {artifact://design/...#key-decisions} | COVERED | {说明} |

## Task List

### T1: {title}

- wbs_ref: WP-1
- critical_path_role: {critical, supporting, independent}
- unit_refs: [...]
- scope_item_refs: [...]
- design_refs: [...]
- test_refs: [...]
- depends_on: [...]
- shared_files: [...]
- batch: 1
- acceptance_targets: [...]
- proving_command: {fresh proving command}
- real_dependency_note: {真实依赖说明}
- evidence_target: {developer-report / verify-result / qa-result / signoff-package ref}
- mock_boundary_note: {Mock 边界与最终验收限制}
- AC:
  1. {可 assert 的验收标准}

## Dependency And Batch Plan

| Batch | Task refs | Parallelizable | Reason | Integration note |
| --- | --- | --- | --- | --- |
| 1 | T1 | false | dependency root | {说明} |
| 2 | T2, T3 | true | no file/data conflict | {说明} |

## User Confirmation

- plan_version: {plan-vN}
- status: {PENDING, CONFIRMED}
- confirmed_by: {user / N/A}
- confirmed_at: {timestamp / N/A}
- confirmation_notes: {可选}

## Handoff Summary

- delivery-owner consumes: frozen `plan.json / tasks.json`
- developer consumes: task scope, refs, dependencies, proving command, evidence target
- verify / qa consume: acceptance targets, test refs, evidence expectations
