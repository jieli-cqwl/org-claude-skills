# design-review projection

> 运行时真源为 `plan.json.design_review`；本文件只作为人类投影视图。

## 输入分析

REVIEW: {DESIGN_OK, DESIGN_ISSUE}

## Design 评审结论
### 评审摘要
### Issues（如有）
1. {ISSUE-1} 位置 + 问题 + 建议

## Gate 检查明细
| Gate | 结论 | 关键证据 | 阻断项 |
|------|------|----------|--------|
| 需求语义一致性 Gate | {PASS, FAIL} | {语义覆盖证据} | {若 FAIL，列阻断点} |
| 决策充分性 Gate | {PASS, FAIL} | {方案对比与确认证据} | {若 FAIL，列阻断点} |
| 边界与契约完整性 Gate | {PASS, FAIL} | {边界/接口/数据证据} | {若 FAIL，列阻断点} |
| 演进可实施性 Gate | {PASS, FAIL} | {迁移/验证/回滚证据} | {若 FAIL，列阻断点} |
| 计划交接就绪 Gate | {PASS, FAIL} | {待计划约束/追踪覆盖证据} | {若 FAIL，列阻断点} |

## 三原则裁决
| 原则 | 裁决 | 依据 |
|------|------|------|
| 简单 | {PASS, FAIL} | {是否控制不必要复杂度} |
| 合适 | {PASS, FAIL} | {是否保留必要复杂度} |
| 演化 | {PASS, FAIL} | {是否体现按需增长复杂度 + 可逆性优先（实施证据：渐进迁移/可验证/可回退）} |

## 交接项
- 若 DESIGN_OK：进入任务拆分
- 若 DESIGN_ISSUE：回退 design 修正后重新评审
