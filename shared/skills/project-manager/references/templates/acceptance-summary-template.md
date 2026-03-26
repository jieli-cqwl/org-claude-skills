# acceptance-summary.md

## 交付范围
- Feature: {名称}
- PRD: {路径}
- Plan: {路径}
- Task 数: N（完成: M，BLOCKED: K）

## Task 执行进度
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 状态 |
|------|-----------|-----------|---------|---------|------|

## AC 验收状态
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| UNIT | AC 总数 | 通过 | 失败 | 覆盖率 |
|------|---------|------|------|--------|

## 质量门禁
> 仅汇总强门禁阶段；可选增强 `REVIEW_C` 不进入此表。

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 门禁 | 状态 |
|------|------|
| TDD 证据 | {PASS, FAIL} <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 --> |
| Code Review (REVIEW_A) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| Code Review (REVIEW_B) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_A (AC 验收) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| QA_B (E2E 旅程) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_C (回归验证) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_D (探索性测试) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| 全量测试 | {PASS, FAIL} <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 --> |

## 已知问题
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Issue ID | 来源 | 描述 | 严重度 | 处置 |
|----------|------|------|--------|------|

## 豁免（如有）
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Waiver ID | 检查项 | 关联 Issue | 到期时间 |
|-----------|--------|-----------|---------|

## 签收记录
- 签收状态: {确认, 拒绝, 待签收} <!-- HOOK-CONTRACT:ENUM 填 确认, 拒绝, 待签收 之一 -->
- 签收人: {user}
- 签收时间: {ISO 8601}
- 备注: {如有拒绝原因或附加条件}
