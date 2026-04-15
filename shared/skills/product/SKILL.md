---
name: product
user-invocable: true
disable-model-invocation: true
description: `/product` 的兼容入口。Use when 需要兼容旧链接、旧入口或历史文档引用，并将请求重定向到 `/product-director` 或 `/product-manager`。
argument-hint: "[需求描述]"
allowed-tools: Read, Write, Glob, Grep, Agent, AskUserQuestion
---
# /product -- 兼容入口

> 兼容入口：`/product` 已拆分为 `/product-director` + `/product-manager`。
> 新需求默认先走 `/product-director`，冻结根问题、目标、范围与 Phase 骨架；再走 `/product-manager`，继续 UNIT、AC、评审与 `交付确认`。
> 当前 skill 仅保留旧入口、旧链接和历史文档引用的 redirect 语义；不再作为推荐主入口，也不再维护 monolith runtime。

> ultrathink

## 路由规则

- 当用户通过 `/product` 发起新需求时，先改走 `/product-director`。
- 当 Director handoff 已冻结，且需要继续细化 `phase-{N}/prd.md`、`UNIT-*.md`、审查与 `交付确认` 时，改走 `/product-manager`。
- 过渡期 `/product` 不参与 gate / state / dispatch；compat only，不承担直接执行职责。

## 兼容语义

- 历史 `/product` 的问题优先原则仍然保留：先确认根问题，再谈方案与拆解。
- 历史 `/product` 文档里的 `flow override in S2-S12` 仅作为旧编号索引保留，用于兼容旧链接；拆分后不再作为稳定步骤契约，实际执行以 Director / Manager 当前步骤为准。
- 历史 `/product` 的共享工件仍是 `brief.md` + `phase-{N}/prd.md` + `phase-{N}/units/UNIT-*.md`，但 authoritative 主入口已经改为 `/product-director` 和 `/product-manager`。

## 评审闭环映射

- 产品评审目标保持不变：用于确认 PRD 是否完整回答用户问题，并形成可继续设计的需求基线。
- 架构评审目标保持不变：用于确认需求在当前技术上下文中可落地，且关键依赖与影响范围没有被漏掉。
- 测试评审目标保持不变：用于确认 AC 能被真实验证，并提前暴露回归与异常边界风险。
- 如有 FAIL，仍按同一收口动作处理：复核问题证据、影响范围与承接位置，系统性修复 brief.md / phase-{N}/prd.md / phase-{N}/units/，且仅对 FAIL 视角重新提交评审。

## 操作提示

- 需要重新澄清根问题、目标、范围、Phase 骨架：改用 `/product-director`
- 需要继续细化 UNIT、AC、完整性扫描、三方评审、`交付确认`：改用 `/product-manager`
- 若历史文档还在引用 `/product`，保持链接即可；运行时会把它视为 compat redirect，而不是主技能
