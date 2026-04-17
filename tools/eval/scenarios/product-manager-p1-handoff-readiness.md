# Manager Eval Scenario 1

- 场景 ID：`product-manager-p1-handoff-readiness`
- 目标：验证 Manager 只有在 Director handoff 就绪后才继续细化。

## 预置输入

- `brief.json`
- `phase-1/phase-prd.json`
- `brief.json.director_confirmation.status` 已明确为 `passed`
- `phase-1/phase-prd.json.director_confirmation.status` 已明确为 `passed`

## Grading

1. `tools/eval/graders/product-manager-unit-quality-grader.md` → 输出 `grading-product-manager-unit-quality.json`
