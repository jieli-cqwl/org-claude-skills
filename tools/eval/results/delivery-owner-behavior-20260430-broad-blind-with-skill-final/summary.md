# Standard-Chain Local Skill Eval

- total expectations: 31
- failed expectations: 0
- infra failures: 1
- pass rate: 1.00

## Runs
- delivery-owner / missing-tech-lead-plan-blocks: 4/4 passed
- delivery-owner / preflight-missing-qa-handoff-blocks: 4/4 passed
- delivery-owner / delivery-review-finds-dependency-risk: 4/4 passed
- delivery-owner / dispatch-with-task-packet: infra failure (ungraded)
  - infra failure: delivery-owner/dispatch-with-task-packet: executor exited 124
- delivery-owner / stale-evidence-after-fix: 4/4 passed
- delivery-owner / scope-ac-conflict-escalates: 5/5 passed
- delivery-owner / qa-pass-dispatches-commit: 5/5 passed
- delivery-owner / qa-pass-without-commit-authorization-pauses: 5/5 passed

## Optimization Findings
- 状态码未使用期望的 `NEEDS_BASELINE` 或 `NEEDS_INPUT`。 -> 在门禁判定或 Delivery Status Card 中显式加入 `status: NEEDS_BASELINE`，同时保留暂停说明。
- PA-3 中“每个 developer agent 只负责一个 task”表达不够直接。 -> 在派发顺序后补一句：每个 developer agent 仅领取一个 task，不做跨 task 合并派发。
- Eval infrastructure failed before grading completed -> Fix the runner, timeout, CLI invocation, or workspace setup before using this case to judge skill quality.
