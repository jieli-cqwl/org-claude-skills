# 测试设计默认方法

> 引用者：`test-design/SKILL.md` 固定主流程（步骤 1-5）。
> Trigger: 基础 AC 提取、UNIT 优先视图、基础用例、排除项验证或 typed gap 判断。
> Read: 本文件。
> Expect: AC 提取顺序、基础用例规则、排除项验证、typed gap 规则和收敛顺序。
> Consume: `test_analysis`、`ac_coverage_matrix`、`test_cases[]`、`design_gap_report.gaps[]`。
> Evidence: final `test-cases.json` 中的 source refs、case_type 覆盖、gap owner/next_action 和 validator 输出。
> Sync: methodology 变化时同步 `test-design/SKILL.md` 主流程、test-cases schema/template、completion gate、fixtures 和治理测试。

## AC 提取顺序

1. `brief.json` / 非功能需求、约束、全局排除项
2. `phase-{N}/phase-prd.json` + `phase-{N}/units/UNIT-*.json` / 功能闭环定义、验收标准、排除项
3. canonical `design.json`（`phase-{N}/design.json`）/ 接口、错误码、字段约束

编号建议：
- 功能 AC：`AC-U{UNIT序号}-{序号}`（如 `AC-U1-01`）
- 全局 AC：`GAC-{序号}`（如 `GAC-001`）
- 排除项：`EX-{序号}`（如 `EX-001`）

## UNIT 优先视图

先按 UNIT 建立功能闭环视图，再展开到 AC：

| UNIT | 闭环目标 | 关联 AC | 排除项 | 设计映射 |
|------|----------|---------|--------|---------|
| UNIT-1 | ... | AC-U1-01, AC-U1-02 | EX-001 | `design.json#interface_boundary` |

## 基础用例规则

每条 AC 固定输出：
- 正例：验证目标行为成立
- 反例：验证错误输入或非法状态被拒绝
- 边界：验证阈值和边界值行为

表达统一为：
- `输入/操作 -> 期望输出`

## 排除项验证规则

每条 EX 至少 1 条用例，证明“不应发生”：
- 不提供该能力
- 不返回该字段
- 不触发该流程

## Typed Gap 规则

仅在以下情况输出 typed gap：
- 产品意图、范围或 AC 自身冲突：`PRODUCT_GAP`
- AC 无法映射到任何设计承接点
- 关键错误码缺失，导致反例不可验证
- 关键字段约束缺失，导致边界不可验证
- 产品与设计 refs 冲突：`TRACE_CONFLICT`
- AC、排除项或专项无法形成可执行断言：`TESTABILITY_GAP`
- 等价性对照缺少承接或不可证明：`EQ_GAP`

非阻断优化建议不标记 gap。每条 gap 都必须写入 `design_gap_report.gaps[]`，包含 `gap_type`、`blocking_refs`、`owner`、`next_action` 和 `blocking`。

## 收敛顺序

- 覆盖映射与等价性对照可以并行整理，但都只能作为中间草稿。
- QA 交接内容只能在 coverage / equivalence 已收敛且不存在 `blocking=true` 的 typed gap 时生成。
- typed gap 永远只由主 Agent 在最终 `test-cases.json` 中单点裁决。
- 最终 `test-cases.json` 仍是唯一真源；中间草稿不得作为最终证据。

## 覆盖矩阵最小字段

| UNIT | AC | 描述 | 正例 | 反例 | 边界 | 排除 | 状态 |
|------|----|------|------|------|------|------|------|

状态建议：
- `COVERED`
- `PARTIAL`
- `DESIGN_GAP`
