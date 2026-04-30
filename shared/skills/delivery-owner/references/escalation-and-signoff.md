# 升级与签收准备

Trigger: 缺口超出执行面、需要 authority、准备 `signoff_ready` 时读取。
Read: current gap、attempted actions、evidence refs、risk、authority map、completion layer。
Expect: escalation packet、签收准备判断、完成层级。
Consume: `流程/Control`、`流程/Signoff`、`输出`。
Evidence: authority 决策、风险记录、signoff readiness 依据。
Sync: authority、签收边界、commit/release handoff 规则变化时同步。

## 什么时候升级

升级不是失败，是交付控制动作。以下问题不要让执行角色猜：

- scope 或 AC 冲突。
- 技术基线、task 拆分或依赖需要刷新。
- 权限、环境、资源或 executor 不可用。
- 多角色证据冲突，且无法按证据强度仲裁。
- 业务风险接受、上线窗口或最终签收。

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

推荐路径必须是可执行动作，不是态度判断。

## 完成层级

```text
role_done: 某个 executor 完成自己的专业任务
task_done: 一个 tech-lead task 的 AC 和证据闭合
plan_done: 计划 task graph 闭合
signoff_ready: delivery-owner 判定可交 authority 签收
business_signed_off: authority 已最终业务签收
```

默认只声明到 `signoff_ready`。

## Signoff Ready 合格线

`signoff_ready` 只能来自 readiness bundle 闭合，不能来自某个 role 的单点 PASS。进入前确认：

- 所有必须 task 已 `task_done`，且每个 task 都有 `developer-report.json` 和 `verify-result.json`。
- phase 级 `code-review-result.json` 为 PASS；若有 `fix-result.json`，修复后的 review / verify / QA 证据仍 fresh。
- `qa-result.json` 覆盖 QA_A / QA_B / QA_C / QA_D，且必须路径均 PASS。
- `consistency-audit-result.json` 是 full / advisory_only，consumer 为 delivery-owner，且没有 blocked layer 或 CRITICAL finding。
- `artifact-registry.json` 的 active entries 能追到实际 artifacts，`signoff-package.json` 的 evidence refs 仍 fresh。
- 依赖和阻塞已关闭，或有 authority 接受的 waiver；scope、AC、技术基线没有未决升级。
- 业务风险、risk waiver 和最终签收 owner 已明确；需要 authority 裁决的问题已形成升级包。
- projection / replay readiness 已通过，能证明 canonical 状态可重放、可查看、可复验。

不满足任一项时输出 `SIGNOFF_BLOCKED`，并给出下一步 owner。

## Closeout 合格线

`business_signed_off` 或 closeout 发生在 authority 裁决之后，不能反向作为 `signoff_ready` 的前置条件。进入 closeout 前确认：

- `user-decision.json` 已由 authority / user-decision writer 产出，不由 delivery-owner 代写。
- `authority_proof_refs` 可追溯，且与 `user-decision.json` 的 payload、actor、时间和 active plan/tasks 匹配。
- `signoff-package.json` 的 `sign_off_status` 和 `business_risk_acceptance_status` 与 `user-decision.json` 一致。
- closeout 工件落盘后，运行标准链 readiness validator 复验。
