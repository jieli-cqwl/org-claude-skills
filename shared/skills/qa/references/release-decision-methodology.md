# 放行判断方法

## 裁决枚举

| release_recommendation | 显示含义 | 适用条件 |
|------------------------|----------|----------|
| ALLOW | 放行 | 无阻断缺陷，所有 REQUIRED 义务已执行，残余风险可接受 |
| CONDITIONAL_ALLOW | 条件放行 | 无阻断缺陷，但存在经批准的 waiver、剩余风险、或可接受的未执行项 |
| BLOCK | 阻塞 | 存在阻断缺陷、关键义务未执行、证据不足、或风险不可接受 |
| DEFER | 延后 | 关键环境、依赖或决策未就绪，无法形成有效验收结论 |

## 判定规则
- 存在 `QAR-*` 且严重度达到阻断级，裁决为 `BLOCK`
- REQUIRED 义务未执行且无有效 `not_executed_reason`，裁决为 `BLOCK`
- `gate_result: FAIL` 时，`release_recommendation` 取 `BLOCK`
- `gate_result: PASS` 且存在 waiver、高残余风险或条件性未执行项，裁决为 `CONDITIONAL_ALLOW`
- `gate_result: PASS` 且无额外放行条件，裁决为 `ALLOW`
- 环境、依赖或决策缺失导致无法执行验收时，裁决为 `DEFER`

## 输出要求
- `release_recommendation`
- `residual_risk`
- `CONDITIONAL_ALLOW` / `BLOCK` / `DEFER` 时，必须说明风险边界、补偿控制、阻断原因或延后原因
