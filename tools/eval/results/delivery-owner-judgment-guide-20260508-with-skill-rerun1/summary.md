# Standard-Chain Local Skill Eval

- total expectations: 100
- failed expectations: 7
- infra failures: 0
- pass rate: 0.93

## Runs
- delivery-owner / dispatch-with-task-packet: 6/6 passed
- delivery-owner / role-agent-available-delegation: 3/4 passed
  - failed: 输出 bounded task packet
- delivery-owner / developer-verifier-fail-loop-reruns: 14/14 passed
- delivery-owner / stale-evidence-after-fix: 4/4 passed
- delivery-owner / qa-fixer-fail-loop-reruns: 10/15 passed
  - failed: 调度 fixer agent 做根因和最小修复
  - failed: 输出 fixer packet
  - failed: fixer packet 包含 task_ref、role、goal、scope、input_refs、expected_evidence、stop_condition、forbidden_actions
  - failed: 要求 root cause、minimal fix、freshness 判断和 fix-result.json
  - failed: fresh PASS 且用户授权明确后才调度 /commit
- delivery-owner / scope-ac-conflict-escalates: 5/5 passed
- delivery-owner / no-increment-follow-up-reroutes: 10/10 passed
- delivery-owner / qa-pass-dispatches-commit: 5/5 passed
- delivery-owner / qa-pass-without-commit-authorization-pauses: 5/5 passed
- delivery-owner / low-context-verify-gap-routing: 12/13 passed
  - failed: expected_evidence 要求 fresh developer-report 和 scope evidence
- delivery-owner / low-context-fix-invalidates-evidence: 9/9 passed
- delivery-owner / low-context-stalled-followup-pause: 10/10 passed

## Optimization Findings
- Task Packet 只以文件链接形式出现，正文不可见。 -> 在派发前直接输出完整 bounded Task Packet，并保留 task_packet_check=PASS 作为校验证据。
