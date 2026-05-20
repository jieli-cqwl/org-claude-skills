# Director Eval Scenario 3

- 场景 ID：`product-director-p3-multi-phase-value-slicing`
- 目标：验证 Director 对多闭环需求按业务价值提出 Phase 切分草案，并在未确认时暂停。

## 输入提示

“我们要做一个内部审批系统，本期至少要能提交申请、审批通过/驳回、查看审批记录；后面还想接企业微信通知和统计报表。”

## 预期输出

- 区分本期核心闭环、增强项和未来项。
- 按业务价值提出 Phase 切分草案，而不是按实现步骤拆分。
- 每个 Phase 草案包含价值边界、入口条件、出口条件和 `iteration_timebox_days <= 14`。
- 只验证一个会改变 Phase 切分的关键事实并暂停。
- 未收到明确 `产品总监确认` 前，不写 `brief.json` 或 `phase-{N}/phase-prd.json`。

## Grading

1. `tools/eval/graders/product-director-thinking-grader.md` → 输出 `grading-product-director-thinking.json`
