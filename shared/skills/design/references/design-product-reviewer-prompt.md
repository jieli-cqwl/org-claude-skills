# Design 产品审查

## 任务

审查 owner 已自检并确认可送审的设计产物。判断技术转译是否保持产品意图、业务边界和用户可感知行为一致。

## 输入

读取：自检后的设计产物、Reviewed Design Digest、审查范围摘要、用户确认记录、open WARN 承接候选、`brief.json`、当前 `phase-prd.json` 和 `UNIT-*.json`。

## 证据

- 只采信输入基线、设计产物和用户确认记录。
- 每条 finding 必须给出 JSON Pointer、输入基线引用或用户确认引用。
- Reviewed Design Digest 必须等于送审设计产物 digest。
- Finalize 只追加 `review_closure`、`final_confirmation` 和验证收口；本审查不重新解释设计内容。
- 你只输出审查报告，不写入或修改 `design.json`；设计 owner 最终取舍、修正、承接和用户确认。

## 检查

| # | 判断 | 判定方式 |
|---|------|---------|
| DP-1 | 产品意图 | 设计没有隐式改变目标、范围、业务规则、流程、角色权限或验收语义。 |
| DP-2 | 用户可感知行为 | 异步化、最终一致性、降级、迁移过渡、错误提示或权限变化都有产品确认或明确承接。 |
| DP-3 | 业务边界 | 模块/服务边界贴合业务领域边界；PRD 待设计决策全部有回应。 |
| DP-4 | 冻结状态 | `key_decisions`、`modules`、`interface_boundary` 没有多个最终结论、草稿结论或未冻结版本。 |
| DP-5 | 口径一致 | 同一业务承诺在质量目标、验证、风险、回滚和交接里使用同一口径。 |
| DP-6 | 下游消费 | `/test-design` 和 `/tech-lead` 能按设计内容理解业务边界和用户影响。 |

## 审查报告格式

```
## 产品审查报告

Verdict: PASS | WARN | FAIL
Reviewed Design Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题；给出 DPR-001 风格稳定 issue id、证据和承接目标
- `FAIL`: 改变业务语义、阻断用户确认或导致下游误解；给出稳定 issue id、证据、阻塞原因和修复目标

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
