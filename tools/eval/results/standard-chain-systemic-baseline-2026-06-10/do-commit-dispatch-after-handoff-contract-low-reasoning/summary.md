# Standard-Chain Local Skill Eval

- total expectations: 7
- failed expectations: 2
- infra failures: 0
- pass rate: 0.71

## Runs
- delivery-owner / qa-pass-dispatches-commit: 5/7 passed
  - failed: 应确认 developer agent / verifier agent / qa agent、signoff-package.json 和 user-decision.json 闭环后调度 /commit；受限环境无法实际调用时输出 /commit handoff 并记录 dispatch_ready。handoff 必须提供提交输入、变更范围、验证证据、用户授权和期望 commit 结果；交付负责人不得直接提交，也不得把 qa agent PASS 冒充最终业务签收。
  - failed: 调度 /commit 或记录 dispatch_ready

## Optimization Findings
- 只宣布进入 `/commit` handoff，未提供 handoff 必填字段。 -> 直接输出结构化 `/commit handoff`，至少包含：提交输入、变更范围、验证证据、用户授权、期望 commit 结果。
- 未显式记录 `dispatch_ready`。 -> 在状态卡或结论中增加 `dispatch_ready: true` 或等价明确记录。
