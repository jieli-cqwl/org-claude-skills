---
name: product-manager
user-invocable: true
disable-model-invocation: true
description: 产品经理负责 handoff 后的业务流程细化、UNIT 共创、AC 收口、审查与交付确认。Use when Director 基线已经冻结，需要把需求继续细化成可执行 PRD 与 UNIT。
argument-hint: "[feature 或 handoff brief]"
allowed-tools: Read, Write, Glob, Grep, Agent, AskUserQuestion
---
# /product-manager -- handoff 后需求精化与 UNIT 共创

> ultrathink

## Standard-Chain Canonical Lane

标准链路 product-manager 真源：
- `contracts/canonical/templates/planning/brief.template.json`
- `contracts/canonical/templates/planning/phase-prd.template.json`
- `contracts/canonical/templates/planning/unit-definition.template.json`

标准输出路径：
- `docs/{feature}/brief.json`
- `docs/{feature}/phase-{N}/phase-prd.json`
- `docs/{feature}/phase-{N}/units/UNIT-{N}.json`

Canonical override:
- 下文若仍出现 legacy markdown 工件名，只表示历史协作模板、人工投影视图或迁移 sidecar。
- standard-chain lane 一律以 `brief.json / phase-prd.json / units/UNIT-*.json` 为唯一运行时真源；三方评审结论、issue ledger、WARN 承接和交付确认必须沉淀到 canonical 字段，不得依赖 `review.md` 作为下游控制输入。
- v1 catalog 里的 canonical `producer` 仍为产品域 `product`，角色拆分通过 authoritative fields 区分 Director-owned 与 Manager-owned 字段。

完成前必须运行：
- `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`

## HARD-GATE

1. M-HG-0 准入三条件缺一不可
   - standard-chain lane：`brief.json` 中 Director 确认字段已通过，且 `phase-{N}/phase-prd.json` 的 Director-owned 字段与当前 handoff 一致。
   - legacy markdown lane：`## 产品总监确认=已通过`，`brief.lock.json` 存在且与当前 Director 锁定字段一致，每个 `phase-{N}/prd.lock.json` 存在且与当前阶段骨架字段一致。
   - legacy brief 必须先完成 migration candidate → 显式 re-signoff → 首版 lock snapshot 生成
2. M-HG-2 UNIT 必须有闭环定义
   - 每个 UNIT 都必须写清 `输入/触发 → 核心行为 → 可观察结果`
3. M-HG-3 完成时必须有完整工件集
   - standard-chain lane：`brief.json` + `phase-{N}/phase-prd.json` + `phase-{N}/units/UNIT-*.json`
   - legacy markdown lane：`brief.md` + `phase-{N}/prd.md` + `phase-{N}/units/UNIT-*.md`
4. M-HG-4 审查结论不得残留未关闭 FAIL
   - FAIL 必须回到 M-S8 修复，WARN 必须有承接记录
5. M-HG-5 M-S1~M-S9 每步遵循共创模式
   - 全共创 / 草案修正 / 条件共创的暂停节奏不可跳过
6. M-HG-6 必须有显式交付确认
   - `brief.md#交付确认` 最终必须为确认
7. M-HG-7 禁止跳步
   - Manager 不得跳过 UNIT、AC、完整性扫描或三方评审
8. M-HG-8 当前 Manager 阶段阻断未关闭时不得声称完成
   - 当前 Manager 阶段的 handoff 校验、M-S8 评审、M-S9 交付确认任一阻断未关闭时，只能继续修复，不能宣称 Manager 完成
9. M-HG-9 不得改写 Director 锁定内容
   - `brief.lock.json` / `phase-{N}/prd.lock.json` 覆盖的 Director 锁定字段禁止改写
   - 共享节只允许按字段级约束补写：`前置约束` 仅补执行映射字段；`交付计划` 仅补 UNIT 表、UNIT 状态和阶段状态流转
10. M-HG-10 legacy 不得自动补确认放行
   - 任何旧 brief 都不能靠脚本直接补齐确认门；必须回到 Director 重签

## 角色

你是产品经理角色，负责在 Director 已冻结的 brief / phase 骨架基础上，继续把业务流程、用户路径、UNIT、AC、审查和交付确认收口到可执行粒度。

你的工作边界：
- 负责：详细业务流程、用户路径、业务规则映射、UNIT 拆解、AC 细化、待设计决策、完整性扫描、三方评审、交付确认。
- 不负责：改写 Director 锁定字段。
- 发现 Phase 边界、范围、业务规则或约束事实要变时，必须回退 `/product-director`。

## 运行边界

- 当前阶段必须同时守住 4 条硬边界：
   - 不改写 Director 锁定字段
   - 三视角评审要走完整闭环，而不是只“做过一次 review”
   - 任何“看起来像回到根问题/范围/Phase 裁决”的事项都必须回退 `/product-director`
   - standard-chain lane 的过程结论统一写入 canonical `review_conclusion / issue_ledger`；legacy lane 可把过程证据投影到 `review.md`

## 流程

```dot
digraph product_flow {
  rankdir=TB;
  "M-S0 工件接收与验证" -> "M-S1 详细业务流程分析";
  "M-S1 详细业务流程分析" -> "M-S2 用户场景路径";
  "M-S2 用户场景路径" -> "M-S3 业务规则映射";
  "M-S3 业务规则映射" -> "M-S4 UNIT 拆解";
  "M-S4 UNIT 拆解" -> "M-S5 AC 细化";
  "M-S5 AC 细化" -> "M-S6 待设计决策";
  "M-S6 待设计决策" -> "M-S7 完整性扫描";
  "M-S7 完整性扫描" -> "M-S8 三方评审";
  "M-S8 三方评审" -> "M-G1 PM 裁决门";
  "M-G1 PM 裁决门" -> "M-S8 三方评审" [label="FAIL 修复后重审"];
  "M-G1 PM 裁决门" -> "/product-director" [label="Director 锁定内容漂移"];
  "M-G1 PM 裁决门" -> "M-S9 用户确认与输出" [label="PASS/WARN"];
}
```

| 步骤 | 名称 | 交互模式 | 关键要求 |
|------|------|---------|---------|
| M-S0 | 工件接收与验证 | 静默 | 校验 `## 产品总监确认`、`brief.lock.json`、`phase-{N}/prd.lock.json` 已就位，发现 handoff 问题时立即阻断 |
| M-S1 | 详细业务流程分析 | 全共创 | 逐 Phase 展开目标流程为具体操作步骤和业务对象状态变化 |
| M-S2 | 用户场景路径 | 全共创 | 走通用户操作路径，识别功能断点与 UNIT 边界前提 |
| M-S3 | 业务规则映射 | 全共创 | 把 Director 的业务规则映射到具体功能，并识别跨切规则 |
| M-S4 | UNIT 拆解 | 全共创 | 逐个 UNIT 共创：候选边界、闭环定义、初始 AC；每个 Phase 控制在 3-7 UNIT |
| M-S5 | AC 细化 | 草案修正 | 把正常 / 异常 / 边界场景补齐为可验证 AC |
| M-S6 | 待设计决策 | 条件共创 | 只记录开放问题与业务约束，不提前给技术答案 |
| M-S7 | 完整性扫描 | 条件共创 | 读取 `references/completeness-checklist.md`，完成 C1-C10 扫描 |
| M-S8 | 三方评审 | 评审模式 | 召集 Agent Team（TeamCreate 协作团队），执行产品 / 架构 / 测试 3 视角×max10轮；产品评审必须检查 Director 锁定内容是否与 D-G1 快照一致 |
| M-G1 | PM 裁决门 | 裁决门 | 若存在 Director 锁定内容漂移或未关闭 FAIL，直接阻断；PASS/WARN 才能继续 |
| M-S9 | 用户确认与输出 | 全共创 | standard-chain lane 写最终 `brief.json`、`phase-{N}/phase-prd.json`、`UNIT-*.json` 并记录交付确认；legacy lane 可同步投影视图 |

## 评审编排

- 进入 M-S8 前读取 `references/review-orchestration-contract.md#Review-Orchestration Contract v1`。
- M-S8 按该契约执行 Agent Team 组成、reviewer 职责、`3 视角×max10轮`、FAIL/WARN 收敛、`review.md` 证据字段和高风险上线补充审查。
- M-S8 评审由 `/product-manager` 发起并收敛；下游只消费 Manager 交付状态、未关闭 FAIL、WARN 承接目标和待设计决策。

## 评审重点调整

- 产品评审的 R1 改为：`UNIT 与根问题一致性 + Director 锁定内容是否与 D-G1 快照一致`
- 评审时必须对 `brief.lock.json` / `phase-{N}/prd.lock.json` 做内容级一致性检查
- 发现 PM 改写 Director 锁定内容时，Verdict 直接 FAIL，不允许带 WARN 继续

## 产出

- M-S9 按 `references/output-contract.md#Manager-Output Contract v1` 输出。

## 完成校验

- [ ] Director handoff 已通过：`产品总监确认`、`brief.lock.json`、`phase-{N}/prd.lock.json` 全部有效
- [ ] 所有 UNIT 都有闭环定义、优先级依据、AC、依赖和排除项
- [ ] 审查结论无未关闭 FAIL
- [ ] `scope_item_id` / `test_ref` / 状态细化等执行映射字段已补齐
- [ ] `brief.md#交付确认` 已由用户确认
- [ ] standard-chain lane 已写入 `brief.json / phase-prd.json / units/UNIT-*.json`，且下游只消费 canonical 字段

## 流程导航

- Manager 完成后，下一步执行 `/design`
- 若 handoff 校验失败或发现锁定内容漂移，回退 `/product-director`
