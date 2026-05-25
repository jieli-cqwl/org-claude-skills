# Design 测试审查

## 任务

审查 owner 已自检并确认可送审的设计产物。判断它是否能让 `/test-design` 生成可执行、可观测、可回归的测试义务。

## 输入

读取：自检后的设计产物、Reviewed Design Digest、审查范围摘要、用户确认记录、open WARN 承接候选、`brief.json`、当前 `phase-prd.json` 和 `UNIT-*.json`。

## 证据

- 只采信输入基线、设计产物、验证映射和用户确认记录。
- 每条 finding 必须给出 JSON Pointer、输入基线引用或用户确认引用。
- Reviewed Design Digest 必须等于送审设计产物 digest。
- Finalize 只追加 `review_closure`、`final_confirmation` 和验证收口；本审查不重新解释设计内容。
- 你只输出审查报告，不写入或修改 `design.json`；设计 owner 最终取舍、修正、承接和用户确认。

## 检查

| # | 判断 | 判定方式 |
|---|------|---------|
| DT-1 | 可隔离 | 模块依赖、数据边界和外部依赖能被测试隔离或明确替身策略。 |
| DT-2 | 接口断言 | `input_params`、`output_params`、`error_codes` 和 `boundary_behaviors` 足够生成正常、异常和边界断言。 |
| DT-3 | 验证闭环 | 每个边界行为的 `verification_ref` 能回到 `verification_mapping[].evidence_ref`。 |
| DT-4 | 冻结状态 | `interface_boundary`、`key_decisions` 和 `quality_attributes` 已冻结，没有草稿或多版本痕迹。 |
| DT-5 | 可观测 | 关键链路、质量目标和异常场景有 metrics、日志、trace、告警或排障证据路径。 |
| DT-6 | 回归边界 | 变更范围、兼容策略、灰度/迁移阶段和回滚触发能转成回归测试义务。 |

## 审查报告格式

```
## 测试审查报告

Verdict: PASS | WARN | FAIL
Reviewed Design Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题；给出 DTR-001 风格稳定 issue id、证据和承接目标
- `FAIL`: 无法生成测试义务、引用悬空或冻结状态不成立；给出稳定 issue id、证据、阻塞原因和修复目标

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
