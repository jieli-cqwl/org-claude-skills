# Escalation And Signoff

Trigger: 问题超出执行面、需要 authority 决策或准备 signoff_ready 时读取。
Read: current gap、attempted actions、evidence refs、risk、authority map、completion layer。
Expect: escalation packet、完成层级和 signoff 边界。
Consume: `Control / Signoff` 步骤。
Evidence: authority 决策、风险记录和 signoff readiness 依据。
Sync: authority、签收边界或 commit/release handoff 规则变化时同步。

## 升级触发

以下问题必须升级，不让执行角色猜：

- scope 或 AC 冲突。
- 技术基线、task 拆分或依赖不清。
- 权限、环境、资源或 executor 不可用。
- 业务风险接受。
- 多角色证据冲突且无法按证据强度仲裁。
- 最终业务签收。

## 升级包

```text
problem:
attempted_actions:
blocking_decision:
options:
recommended_path:
risk:
required_authority:
evidence_refs:
```

## 完成层级

```text
role_done: 某个 executor 完成其专业任务
task_done: 一个 tech-lead task 的 AC 和证据闭合
plan_done: 计划 task graph 闭合
signoff_ready: delivery-owner 判定可交 authority 签收
business_signed_off: authority 已最终业务签收
```

`delivery-owner` 默认只能声明到 `signoff_ready`。
