# Standard-Chain Local Skill Eval

- total expectations: 31
- failed expectations: 4
- infra failures: 0
- pass rate: 0.87

## Runs
- delivery-owner / stale-evidence-after-fix: 5/5 passed
- delivery-owner / qa-pass-dispatches-commit: 2/6 passed
  - failed: 应确认 developer agent / verifier agent / qa agent 闭环后调度 /commit；受限环境无法实际调用时输出 /commit handoff 并记录 dispatch_ready。handoff 必须提供提交输入、变更范围、验证证据、用户授权和期望 commit 结果；交付负责人不得直接提交，也不得把 qa agent PASS 冒充最终业务签收。
  - failed: 确认 developer agent / verifier agent / qa agent 证据闭合
  - failed: 检查用户提交授权
  - failed: 调度 /commit 或记录 dispatch_ready
- delivery-owner / qa-pass-without-commit-authorization-pauses: 6/6 passed
- delivery-owner / acceptance-change-invalidates-signoff-evidence: 14/14 passed

## Optimization Findings
- 在题设已声明 developer-report/verify PASS、QA PASS、无未决风险、用户授权可提交的情况下，输出仍停在索要 baseline 工件，未进入 delivery-owner 收尾动作。 -> 应基于已给前提明确确认闭环与授权，并在受限环境下输出 `/commit handoff` 与 `dispatch_ready`，附提交输入、范围、验证证据、授权和期望 commit 结果。
- 没有单独完成“用户提交授权”检查。 -> 至少明确记录“用户已授权提交”并将其纳入 handoff 证据字段。
