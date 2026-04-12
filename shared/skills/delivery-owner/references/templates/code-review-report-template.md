# code-review-report.md

审查分级: {轻量, 标准, 完整}

> 强门禁仅跟踪 `REVIEW_A / REVIEW_B`。可选增强 `REVIEW_C` 如执行，仅作为外部补充证据，不进入本模板 metadata。

## 审查汇总

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 维度 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| REVIEW_A（安全性） | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> | 0 | {概述} |
| REVIEW_B（质量） | {OK, ISSUE, N/A}（轻量模式不执行） <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> | 0 | {概述} |

## 审查轮次记录
| 轮次 | 审查 commit SHA | FAIL 数 | delta |
|------|----------------|---------|-------|
| R1 | {commit SHA} | {N} | — |

> PASS 维度精简规则：维度无 finding 时，只保留结论行（`OK`）。禁止对 PASS 维度添加正面评述或解释"为什么通过"。

## 审查-A 详情
{正确性 + 安全性 + 错误处理}

## 审查-B 详情
{设计 + 测试覆盖 + 注释准确性}（轻量模式标注 N/A）

## 汇总代理引用
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Agent | 汇总文件 | 字段引用位 | 证据锚点引用位 | 重入规则 | 汇总状态 |
|------|----------|-----------|----------------|----------|----------|
| Status Synthesis Agent | `delivery-status-summary.md` | `输入边界` / `当前判断` / `未决项` / `禁止越权项` | `code-review-report.md#...` / `qa-report.md#...` | `BLOCKED` 计入并行数；重试不重复计数；replan 跨批次重新计数 | {N/A, TRIGGERED, STALE} |
| Evidence Synthesis Agent | `evidence-summary.md` | `输入边界` / `当前判断` / `证据锚点` / `未决项` / `禁止越权项` | `code-review-report.md#...` / `qa-report.md#...` / `acceptance-summary.md#...` | 仅允许在 Status Synthesis Agent 结束或停止后进入；旧 summary 可标记 `STALE`，且仅允许重跑 `1` 次 | {N/A, TRIGGERED, STALE} |

<!-- HOOK-CONTRACT:METADATA 花括号替换为真实值 -->
<metadata>{"grade":"{轻量, 标准, 完整}","review":{"REVIEW_A":"{OK, ISSUE, N/A}","REVIEW_B":"{OK, ISSUE, N/A}"},"status":"{PASS, FAIL}"}</metadata>
