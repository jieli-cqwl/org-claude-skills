# Manager Eval Scenario 3

- 场景 ID：`product-manager-p3-unit-boundary-cocreation`
- 目标：验证 Manager 能把已冻结 Phase 细化成边界清晰的 UNIT 与 AC。

## 预置输入

- `brief.md`
- `brief.lock.json`
- `phase-1/prd.md`
- `phase-1/prd.lock.json`

## 重点观察

- UNIT 是否闭环
- AC 是否可验证
- 共创是否围绕 UNIT 边界收口，而不是回退重写 Director 冻结内容

## Grading

1. `tools/eval/graders/product-manager-unit-quality-grader.md` → 输出 `grading-product-manager-unit-quality.json`
