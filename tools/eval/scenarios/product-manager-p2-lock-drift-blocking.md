# Manager Eval Scenario 2

- 场景 ID：`product-manager-p2-lock-drift-blocking`
- 目标：验证 Manager 会阻断对 Director 锁定字段的漂移改写。

## 预置输入

- `brief.json`
- `phase-1/phase-prd.json`
- `brief.json.director_confirmation.status` 已明确为 `passed`
- `phase-1/phase-prd.json.director_confirmation.status` 已明确为 `passed`

## 重点观察

- 当 `brief.json` 或 `phase-1/phase-prd.json` 的 Director-owned 字段与 canonical handoff 不一致时，必须阻断

## Grading

1. `tools/eval/graders/product-manager-unit-quality-grader.md` → 输出 `grading-product-manager-unit-quality.json`
