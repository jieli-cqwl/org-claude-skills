# code-review-result projection

> 强门禁固定跟踪 `REVIEW_A / REVIEW_B / REVIEW_C`；本视图由 `code-review-result.json.dimension_verdicts` 派生展示。

## 审查汇总

| 维度 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| REVIEW_A（安全性） | {OK, ISSUE} | 0 | {概述} |
| REVIEW_B（质量） | {OK, ISSUE} | 0 | {概述} |
| REVIEW_C（运行质量） | {OK, ISSUE} | 0 | {性能 / 可观测性 / 变更边界概述} |

## 审查轮次记录
| 轮次 | 审查 commit SHA | FAIL 数 | delta |
|------|----------------|---------|-------|
| R1 | {commit SHA} | {N} | — |

> PASS 维度精简规则：维度无 finding 时，只保留结论行（`OK`）。禁止对 PASS 维度添加正面评述或解释"为什么通过"。

## 审查-A 详情
{正确性 + 安全性 + 错误处理}

## 审查-B 详情
{设计 + 测试覆盖 + 注释准确性}

## 审查-C 详情
{性能 + 可观测性 + 变更边界}
