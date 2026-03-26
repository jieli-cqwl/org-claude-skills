# qa-report.md

审查分级: {轻量, 标准, 完整} <!-- required, enum: {轻量, 标准, 完整} -->

## 验收汇总

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 阶段 | 状态 | 修复轮次 | 说明 |  <!-- all columns required -->
|------|------|---------|------|
| QA_A（AC 验收） | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> | 0 | {概述} |
| QA_B（E2E 旅程） | {OK, ISSUE, N/A}（轻量/标准模式不执行） <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> | 0 | {概述} |
| QA_C（回归验证） | {OK, ISSUE, N/A}（轻量模式不执行） <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> | 0 | {概述} |
| QA_D（探索性测试） | {OK, ISSUE, N/A}（轻量/标准模式不执行） <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> | 0 | {概述} |

## QA-A 详情
{脚本化 AC 验收结果}

> QA-A 详情必须包含 AC 追踪表（格式详见 `skills/qa/references/templates/qa-report-template.md`），每条 PRD AC 关联 test_ref + 验证结果 + 证据摘要。

## QA-B 详情
{端到端用户旅程验证}（轻量/标准模式标注 N/A）

## QA-C 详情
{回归验证结果}（轻量模式标注 N/A）

## QA-D 详情
{探索性测试发现}（轻量/标准模式标注 N/A）

<!-- HOOK-CONTRACT:METADATA 花括号替换为真实值 -->
<metadata>{"grade":"{轻量, 标准, 完整}","qa":{"QA_A":"{OK, ISSUE, N/A}","QA_B":"{OK, ISSUE, N/A}","QA_C":"{OK, ISSUE, N/A}","QA_D":"{OK, ISSUE, N/A}"},"status":"{PASS, FAIL}"}</metadata>
