# Design 架构审查

## 任务

审查 owner 已自检并确认可送审的设计产物。判断它是否把产品基线、系统事实和架构取舍转成可实施、可验证、可回滚的架构契约。

## 输入

读取：自检后的设计产物、Reviewed Design Digest、审查范围摘要、用户确认记录、open WARN 承接候选、`brief.json`、当前 `phase-prd.json`、`UNIT-*.json`、`docs/constitution.md`（如存在）。

## 证据

- 只采信设计产物、输入基线、源码/配置/运行事实、用户确认和可复查工件。
- 每条 finding 必须给出 JSON Pointer、输入基线引用或用户确认引用。
- Reviewed Design Digest 必须等于送审设计产物 digest。
- Finalize 只追加 `review_closure`、`final_confirmation` 和验证收口；本审查判断已审设计是否闭环。
- 只输出审查报告，不写入或修改 `design.json`；design owner 完成最终取舍、修正、承接和用户确认。

## 检查

| 判断 | 判定方式 |
|------|---------|
| 覆盖 | 每个 UNIT/AC 有设计承接；普通产品细节没有被误升为架构决策。 |
| 复杂度组织 | 设计写清复杂度来源，并用边界、数据、接口、质量属性或迁移策略组织复杂度。 |
| 取舍质量 | 每个关键决策有同 `decision_ref` 的 2+ 本质不同方案；选中方案写清代价、风险、失效条件和用户确认。 |
| 事实锚点 | 冻结决策引用可复查事实；事实来自输入基线、代码、配置、运行事实或用户确认。 |
| 过度设计 | 复杂模式只在真实复杂度、质量目标或风险代价证明必要时出现。 |
| 接口与边界 | 模块、数据、接口和横切关注点能被 `/test-design` 与 `/tech-lead` 消费。 |
| 迁移验证回滚 | 迁移、验证、回滚和风险回应有触发条件、证据路径、owner 或升级路径。 |
| Constitution | 继承的架构原则有用户确认、适用边界和失效条件。 |

## 审查报告格式

```
## 架构审查报告

Verdict: PASS | WARN | FAIL
Reviewed Design Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题；给出 DR-001 风格稳定 issue id、证据和承接目标
- `FAIL`: 阻断设计冻结或下游消费；给出稳定 issue id、证据、阻塞原因和修复目标

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
