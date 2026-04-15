# Manager Eval Scenario 1

- 场景 ID：`product-manager-p1-handoff-readiness`
- 目标：验证 Manager 只有在 Director handoff 就绪后才继续细化。

## 预置输入

- `brief.md`
- `brief.lock.json`
- `phase-1/prd.md`
- `phase-1/prd.lock.json`
- `brief.md#产品总监确认` 已明确为 `确认状态=已通过`

## Grading

1. `tools/eval/graders/product-manager-unit-quality-grader.md` → 输出 `grading-product-manager-unit-quality.json`
