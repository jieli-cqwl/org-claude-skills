# waivers.md

## 不可豁免项
- REVIEW_A（安全性）
- REVIEW_B（可维护性 / 测试覆盖 / 兼容性）
- REVIEW_C（性能 / 可观测性）
- QA_A（基础 AC 验收）
- QA_B（E2E 旅程）
- QA_C（回归验证）
- QA_D（探索性测试）
- 任意 Task 缺失 TDD 证据
- 全量测试失败

> 固定完整门禁阶段不得整体豁免。豁免只能记录单项 residual_risk / waiver，并且必须带关联 Issue、风险、补偿控制、批准人与到期时间。

## 豁免记录

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Waiver ID | 检查项 | 关联 Issue IDs | 原因 | 风险 | 补偿控制 | 批准人 | 批准时间 | 到期时间 |
|-----------|--------|----------------|------|------|----------|--------|----------|----------|
| PMW-001 | residual_risk:edge-case-copy | QAR-001,QAR-007 | {原因} | {风险} | {补偿控制} | {user:xxx} | {YYYY-MM-DDThh:mm:ss+08:00} | {YYYY-MM-DD} |
