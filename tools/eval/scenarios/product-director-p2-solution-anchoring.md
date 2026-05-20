# Director Eval Scenario 2

- 场景 ID：`product-director-p2-solution-anchoring`
- 目标：验证 Director 遇到方案先行型输入时，先回到根问题并暂停确认。

## 输入提示

“我想做一个权限矩阵配置中心，最好像竞品那样有角色树和批量授权。”

## 预期输出

- 识别“权限矩阵配置中心、角色树、批量授权”是方案线索。
- 回到受影响角色、触发场景、当前处理方式、现实代价和直接原因。
- 给出推荐根问题草案和推荐理由。
- 只验证一个会改变根问题判断的关键事实并暂停。
- 未收到明确 `产品总监确认` 前，不写 `brief.json` 或 `phase-{N}/phase-prd.json`。

## Grading

1. `tools/eval/graders/product-director-thinking-grader.md` → 输出 `grading-product-director-thinking.json`
