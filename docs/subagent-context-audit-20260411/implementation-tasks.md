# Tasks — 复杂链路 sub agent 最佳实践实施计划
Created: 2026-04-12
Related plan: ./implementation-plan.md

## Goal

把复杂链路 `/product → /design → /test-design → /tech-lead → /delivery-owner` 改造成“主 Agent 负责裁决，sub agent 负责降噪工序”的可执行流程，并把这套规则正式写入仓库里的 skill、reference、template、completion_check。

## Acceptance Checklist

- [ ] T1 全局合同层落地
  - AC: `contracts/skill-chain.yaml` 写明“节点责任不下放、工序可下放”；新增 `shared/reference/subagent-recovery-contract.md`、`shared/reference/context-noise-metrics.md` 和 5 个统一模板；`G0` 可独立成立。

- [ ] T2 `tech-lead` 改造落地
  - AC: `shared/skills/tech-lead/SKILL.md` 明确 `Traceability Draft Agent`、`Task Decomposition Draft Agent`、`Evidence Field Draft Agent` 的触发条件、最大数量、回收件、越权边界；`plan-template.md`、reviewer prompts、`completion_check.sh` 与之同步。

- [ ] T3 `test-design` 改造落地
  - AC: `shared/skills/test-design/SKILL.md` 明确 `Coverage Draft Agent`、`Equivalence Draft Agent`、`QA Handoff Draft Agent` 的触发条件、回收件、越权边界；`DESIGN-GAP(EQ)` 仍由主 Agent 单点裁决；reviewer prompts、methodology、`completion_check.sh` 同步。

- [ ] T4 `design` 改造落地
  - AC: `shared/skills/design/SKILL.md` 明确 `Runtime Fact Capture Agent`、`Option Draft Agent`、`ADR Draft Agent` 的串行触发顺序和回收件；最终技术裁决、接口边界确认仍由主 Agent 保留；相关 reference、reviewer prompts、`completion_check.sh` 同步。

- [ ] T5 `product` 改造落地
  - AC: `shared/skills/product/SKILL.md` 明确 `Context Scan Agent`、`Problem Hypothesis Agent` 只承担静默采集和候选问题生成，不接管关键提问和范围裁决；reviewer prompts、checklist、`completion_check.sh` 同步。

- [ ] T6 `delivery-owner` 条件式汇总代理落地
  - AC: `shared/skills/delivery-owner/SKILL.md` 明确 `Status Synthesis Agent` 与 `Evidence Synthesis Agent` 的唯一状态机、并行 Task 数统计口径、重入规则；`dispatch-guide.md`、`phase3-dispatch.md`、模板、`completion_check.sh` 同步。

- [ ] T7 端到端验收闭环
  - AC: 5 个主 skill 的 completion check 都能承接新字段；全局模板与阶段模板字段一致；基于至少 `3` 个 `tech-lead` 正式样本和后续阶段各自规定样本，能按 `M1~M6` 输出可复算结果。

## Repo-Level DoD

同时满足下面 6 条，才算这次改造完成：

1. `G0/G1/G2` 闭环完整
2. 5 个主 skill 都写明主 Agent / sub agent 边界
3. 所有新增 sub agent 都有固定输入、固定输出、固定禁止越权项
4. 所有 completion check 与模板同步
5. `M1~M6` 可落盘、可复算、可抽查
6. 至少完成 `tech-lead` 正式验证；其他阶段达到各自回写门槛后才算各阶段完成

## Definition of Done

All tasks checked = ready to execute implementation in sequence.
