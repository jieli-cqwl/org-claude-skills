Trigger: 当 tech-lead 需要渲染 `plan.json.design_review` 的人类投影视图时读取。
Read: `projections/design-review-template.md`
Expect: 输入分析、Design 评审结论、Gate 检查明细、三原则裁决和交接项章节。
Consume: 人类审阅视图消费该模板；机器真源仍为 `plan.json.design_review`，不得作为下游控制输入。
Evidence: 模板每个章节都能回指 DESIGN_OK/DESIGN_ISSUE、Gate 明细和 JSON 字段。
Sync: `plan.json.design_review` 字段或 Design review 方法论变化时同步更新。

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
