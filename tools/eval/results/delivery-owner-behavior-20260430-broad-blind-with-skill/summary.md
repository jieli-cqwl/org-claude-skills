# Standard-Chain Local Skill Eval

- total expectations: 37
- failed expectations: 2
- infra failures: 0
- pass rate: 0.95

## Runs
- delivery-owner / missing-tech-lead-plan-blocks: 4/4 passed
- delivery-owner / preflight-missing-qa-handoff-blocks: 4/4 passed
- delivery-owner / delivery-review-finds-dependency-risk: 4/4 passed
- delivery-owner / dispatch-with-task-packet: 6/6 passed
- delivery-owner / stale-evidence-after-fix: 4/4 passed
- delivery-owner / scope-ac-conflict-escalates: 5/5 passed
- delivery-owner / qa-pass-dispatches-commit: 3/5 passed
  - failed: 确认 developer agent / verifier agent / qa agent 证据闭合
  - failed: 调度 /commit
- delivery-owner / qa-pass-without-commit-authorization-pauses: 5/5 passed

## Optimization Findings
- 责任域字段存在轻微歧义。 -> 将 gap_owner 改为 gap_responsibility: developer agent，delivery-owner 仅保留为 dispatcher/orchestrator。
- 在 eval prompt 已给定 dev/verify/QA PASS 与授权的情况下，实际输出没有形成 commit handoff 或调度 /commit。 -> 若 skill eval 允许把 prompt 作为证据源，应明确列出 developer-report、verify PASS、QA PASS、无风险、用户授权，并调度 /commit，同时注明交付负责人仅交接不直接提交。
