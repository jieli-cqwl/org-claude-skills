## 全链路一致性报告

### 概览
- 扫描范围: docs/{feature}/
- decision_authority: advisory_only
- consumer: {tech-lead / delivery-owner / user / other}
- 工件: brief.json ✓ | phase-prd.json ✓/✗ | artifact-registry.json ✓/✗ | units/UNIT-*.json ✓/✗ | design.json ✓/✗ | plan.json ✓/✗ | tasks.json ✓/✗ | test-cases.json ✓/✗
- Constitution: docs/constitution.md ✓/✗
- blocked_layers: []
- skipped_layers: []
- tool_warning: []
- 检测结果: CRITICAL: N | WARNING: N | INFO: N

### CRITICAL 问题
| # | layer | check | issue_summary | file_path | json_pointer | content_evidence | impact | required_owner_action |
|---|-------|-------|---------------|-----------|--------------|------------------|--------|-----------------------|
| 1 | L1-1 | UNIT 覆盖 | UNIT-3 在 design.json 中无对应模块 | docs/{feature}/phase-1/phase-prd.json | /unit_index/2 | UNIT-3 exists in phase-prd unit_index | design 未承接 UNIT-3，后续 plan/test 无稳定设计依据 | design owner 补齐设计承接或 product owner 移除 UNIT |

### WARNING 问题
[同上格式]

### INFO 建议
[同上格式]

### 追踪矩阵
| UNIT | AC 数 | Design 覆盖 | Plan 覆盖 | Test 覆盖 | 状态 |
|------|-------|------------|-----------|-----------|------|
| UNIT-1 | 5 | 5/5 | 5/5 | 4/5 | WARNING |

### Owner Action
| owner | required_owner_action | evidence_ref |
|-------|-----------------------|--------------|
| tech-lead | 刷新 plan/tasks 或解释跳过原因 | artifact://... |
