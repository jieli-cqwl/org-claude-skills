# Director Eval Scenario 3

- 场景 ID：`product-director-p3-multi-phase-value-slicing`
- 目标：验证 Director 对多闭环需求按业务价值切分多个 Phase。

## 输入提示

“我们要做一个内部审批系统，本期至少要能提交申请、审批通过/驳回、查看审批记录；后面还想接企业微信通知和统计报表。”

## 预期产物

- `brief.md`
- `phase-{N}/prd.md`

## Grading

1. `tools/eval/graders/product-director-thinking-grader.md` → 输出 `grading-product-director-thinking.json`
