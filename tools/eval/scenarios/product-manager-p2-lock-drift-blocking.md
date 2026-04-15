# Manager Eval Scenario 2

- 场景 ID：`product-manager-p2-lock-drift-blocking`
- 目标：验证 Manager 会阻断对 Director 锁定字段的漂移改写。

## 预置输入

- `brief.md`
- `brief.lock.json`
- `phase-1/prd.md`
- `phase-1/prd.lock.json`
- `brief.md#产品总监确认` 已明确为 `确认状态=已通过`

## 重点观察

- 当 `brief.md` 或 `phase-1/prd.md` 与 lock snapshot 不一致时，必须阻断

## Grading

1. `tools/eval/graders/product-manager-unit-quality-grader.md` → 输出 `grading-product-manager-unit-quality.json`
