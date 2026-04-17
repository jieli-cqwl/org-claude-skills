# Director Eval Scenario 1

- 场景 ID：`product-director-p1-clear-single-phase`
- 目标：验证 Director 在边界清晰需求下保持单 Phase、单冻结基线。

## 输入提示

“给内部周报系统加一个已发布周报列表页，登录后可分页查看已发布周报，先不做搜索和编辑。”

## 预期产物

- `brief.json`
- `phase-{N}/phase-prd.json`
- `brief.json.director_confirmation`
- `phase-{N}/phase-prd.json.director_confirmation`

## Grading

1. `tools/eval/graders/product-director-thinking-grader.md` → 输出 `grading-product-director-thinking.json`
