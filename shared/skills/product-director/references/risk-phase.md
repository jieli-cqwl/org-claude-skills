# 风险与 Phase

## 风险优先
先闭合会改变根问题、价值、范围、Phase 或冻结条件的风险，再切 Phase。

## Phase 规则
- 按场景价值切分，不按后端、前端、集成顺序切分。
- 每个 Phase 必须有独立场景价值和可验证出口条件。
- timebox 是产品切片粒度，不是人力、agent 数量或工程估时承诺。
- 不知道组织迭代节奏时，默认 timebox 为 14 天。
- `phase-prd.json` 只承载 Phase 骨架，UNIT、AC 和 PM 细化字段由 `/product-manager` 承接。

## 复杂度信号
simple / medium / complex 只作为下游拆解风险信号，必须附带场景原因。
