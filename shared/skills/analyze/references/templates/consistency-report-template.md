## 全链路一致性报告

### 概览
- 扫描范围: docs/{feature}/
- 工件: prd.md ✓ | design.md ✓/✗ | plan.md ✓/✗ | test-cases.md ✓/✗
- Constitution: docs/constitution.md ✓/✗
- 检测结果: CRITICAL: N | WARNING: N | INFO: N

### CRITICAL 问题
| # | 层级 | 检查项 | 问题描述 | 证据 |
|---|------|--------|---------|------|
| 1 | L1-1 | UNIT 覆盖 | UNIT-3 在 design.md 中无对应模块 | prd.md:L42 定义了 UNIT-3，design.md 未提及 |

### WARNING 问题
[同上格式]

### INFO 建议
[同上格式]

### 追踪矩阵
| UNIT | AC 数 | Design 覆盖 | Plan 覆盖 | Test 覆盖 | 状态 |
|------|-------|------------|-----------|-----------|------|
| UNIT-1 | 5 | 5/5 | 5/5 | 4/5 | WARNING |
