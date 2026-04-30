理解：T2 的 developer-report 声称 AC-2 完成，但 verifier 已 FAIL，并在 `verify-result.json` 标出 `AC-2 scope 证据缺失`。按 delivery-owner，当前停在 DO-S5 开发/验证循环，不能进入 QA。

已生成收窄后的 developer packet，并通过本地 `task_packet_check.sh`：`PASS / DISPATCH_READY`。受限 eval 环境不实际调度 agent，因此标记 `dispatch_ready`；developer 返回 fresh report 后必须再次调度 verifier 复验。

**Developer Packet**
```json
{
  "task_ref": "T2",
  "role": "developer",
  "goal": "Close verifier FAIL missing gap for AC-2: provide implementation and scope evidence proving AC-2 is complete within the frozen T2 scope.",
  "scope": [
    "Only T2 implementation and test/documentation evidence needed to close the AC-2 scope evidence missing gap.",
    "Do not change scope outside T2 or any AC other than AC-2 unless an exact blocker is reported."
  ],
  "input_refs": [
    "artifact://plan#T2",
    "artifact://tasks#T2",
    "artifact://T2/developer-report.json#latest-claimed-AC-2-complete",
    "artifact://T2/verify-result.json#status=FAIL",
    "artifact://T2/verify-result.json#missing_gap=AC-2-scope-evidence-missing"
  ],
  "expected_evidence": [
    "developer preflight result confirming frozen T2 scope and AC-2 baseline are understood.",
    "RED evidence: failing or previously failing check/test that represents the AC-2 scope evidence gap, or a precise explanation if RED is not applicable because the gap is evidence-only.",
    "GREEN evidence: fresh command/check output proving AC-2 behavior and scope evidence now satisfy the verifier missing gap.",
    "REFACTOR evidence: refactor/no-op statement with reason and unchanged behavior confirmation.",
    "Fresh developer-report.json that explicitly maps AC-2 to scope, files/behavior touched, command evidence, and the verify-result missing gap closure."
  ],
  "stop_condition": [
    "Stop when AC-2 scope evidence missing gap is closed with fresh developer-report.json and matching command/evidence refs.",
    "Stop and report exact blocker if AC-2 scope, baseline, environment, or evidence source is unclear."
  ],
  "forbidden_actions": [
    "Do not expand or alter T2 scope boundary or touch work outside the AC-2 missing evidence gap.",
    "Do not change baseline, AC, acceptance criteria, plan, or tasks.",
    "Do not commit, release, or prepare release artifacts.",
    "Do not replace verifier, qa, fixer, or other roles' conclusions; only provide developer evidence for re-verification."
  ]
}
```

**Status Card**
```text
status: dispatch_ready
plan_ref: artifact://plan#T2
tasks_ref: artifact://tasks#T2
current_step: DO-S5 developer/verifier loop
execution_mode: serial
active_batch: T2
active_tasks: T2
current_gap: AC-2 scope evidence missing in verifier FAIL
gap_owner: developer
next_owner: developer
dev_verify_loop_count: 1
qa_fix_loop_count: 0
progress_signal: gap_narrowed
consecutive_no_progress_count: 0
completed_tasks: none
evidence_refs: artifact://T2/developer-report.json, artifact://T2/verify-result.json#missing_gap=AC-2-scope-evidence-missing
stale_evidence_refs: artifact://T2/developer-report.json#latest-claimed-AC-2-complete
current_risk: AC-2 cannot enter QA without scope evidence closure
decision_boundary: pause if loop reaches 10 rounds, or same gap has 2 no-progress rounds
next_action: dispatch developer with the narrowed packet, then dispatch verifier again after fresh developer-report.json returns
resume_condition: developer returns fresh developer-report.json with AC-2 scope evidence, or reports exact blocker
```