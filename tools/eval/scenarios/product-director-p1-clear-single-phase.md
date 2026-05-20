# Director Eval Scenario 1

- 场景 ID：`product-director-p1-clear-single-phase`
- 目标：验证 Director 在边界清晰但未显式确认的需求下，给出单 Phase 基线草案并暂停确认。

## 输入提示

“给内部周报系统加一个已发布周报列表页，登录后可分页查看已发布周报，先不做搜索和编辑。”

## 预期输出

- 复述操作对象、范围边界和预期产物。
- 给出单 Phase Director 推荐基线草案。
- 只验证一个会改变基线的关键事实。
- 未收到明确 `产品总监确认` 前，不写 `brief.json` 或 `phase-{N}/phase-prd.json`。
- 不输出 UNIT、AC、字段、状态流转或实现方案。

## Grading

1. `tools/eval/graders/product-director-thinking-grader.md` → 输出 `grading-product-director-thinking.json`
