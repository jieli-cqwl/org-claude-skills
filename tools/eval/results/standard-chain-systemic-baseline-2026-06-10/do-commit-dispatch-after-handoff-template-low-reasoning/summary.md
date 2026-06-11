# Standard-Chain Local Skill Eval

- total expectations: 7
- failed expectations: 1
- infra failures: 0
- pass rate: 0.86

## Runs
- delivery-owner / qa-pass-dispatches-commit: 6/7 passed
  - failed: 应确认 developer agent / verifier agent / qa agent、signoff-package.json 和 user-decision.json 闭环后调度 /commit；受限环境无法实际调用时输出 /commit handoff 并记录 dispatch_ready。handoff 必须提供提交输入、变更范围、验证证据、用户授权和期望 commit 结果；交付负责人不得直接提交，也不得把 qa agent PASS 冒充最终业务签收。

## Optimization Findings
- 只说“下一步生成字段完整的 /commit handoff”，但没有把 handoff 正文直接给出来。 -> 直接输出结构化 `/commit handoff`，至少包含提交输入、变更范围、验证证据、用户授权、期望 commit 结果，并保留 dispatch_ready 状态。
