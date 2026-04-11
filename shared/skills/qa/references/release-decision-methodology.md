# 放行判断方法

## 推荐枚举

| release_recommendation | 适用条件 |
|------------------------|----------|
| 放行 | 无阻断缺陷，所有 REQUIRED 义务已执行，残余风险可接受 |
| 条件放行 | 无阻断缺陷，但存在经批准的 waiver、剩余风险、或可接受的未执行项 |
| 阻塞 | 存在阻断缺陷、关键义务未执行、证据不足、或风险不可接受 |

## 判定规则
- 存在 `QAR-*` 且严重度达到阻断级，直接 `阻塞`
- REQUIRED 义务未执行且无有效 `not_executed_reason`，直接 `阻塞`
- `RESULT: FAIL` 时，`release_recommendation` 必须为 `阻塞`
- `RESULT: PASS` 时，若仍有 waiver / 高残余风险 / 条件性未执行项，可给 `条件放行`
- `RESULT: PASS` 且无额外放行条件时，给 `放行`

## 输出要求
- `release_recommendation`
- `residual_risk`
- 若为 `条件放行` 或 `阻塞`，必须说明风险边界、补偿控制或阻断原因
