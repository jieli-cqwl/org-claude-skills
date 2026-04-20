# code-review-report.md

审查分级: {轻量, 标准, 完整}

> 强门禁固定跟踪 `REVIEW_A / REVIEW_B / REVIEW_C`，并同步写入 `code-review-result.json.dimension_verdicts`。

## 审查汇总

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 维度 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| REVIEW_A（安全性） | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> | 0 | {概述} |
| REVIEW_B（质量） | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> | 0 | {概述} |
| REVIEW_C（运行质量） | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> | 0 | {性能 / 可观测性 / backward compatibility 概述} |

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
{性能 + 可观测性 + backward compatibility}

## 汇总代理引用
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Agent | 汇总文件 | 字段引用位 | 证据锚点引用位 | 重入规则 | 汇总状态 |
|------|----------|-----------|----------------|----------|----------|
| Status Synthesis Agent | `delivery-status-summary.md` | `输入边界` / `当前判断` / `未决项` / `禁止越权项` | `artifact://code-review-result/...` / `artifact://qa-result/...` | `BLOCKED` 计入并行数；重试不重复计数；replan 跨批次重新计数 | {N/A, TRIGGERED, STALE} |
| Evidence Synthesis Agent | `evidence-summary.md` | `输入边界` / `当前判断` / `证据锚点` / `未决项` / `禁止越权项` | `artifact://code-review-result/...` / `artifact://qa-result/...` / `artifact://signoff-package/...` | 仅允许在 Status Synthesis Agent 结束或停止后进入；旧 summary 可标记 `STALE`，且仅允许重跑 `1` 次 | {N/A, TRIGGERED, STALE} |

<!-- HOOK-CONTRACT:METADATA 花括号替换为真实值 -->
<metadata>{"grade":"{轻量, 标准, 完整}","review":{"REVIEW_A":"{OK, ISSUE}","REVIEW_B":"{OK, ISSUE}","REVIEW_C":"{OK, ISSUE}"},"status":"{PASS, FAIL}"}</metadata>
