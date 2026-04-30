理解：`T2` 的 developer 声称 `AC-2` 完成，但 verifier 返回 `FAIL`，明确缺口是 `AC-2 scope 证据缺失`。按 `delivery-owner`，当前停在 `DO-S5 开发/验证循环`，不能进入 QA。

**门禁结论**
- 不进入 QA：`T2` 尚未取得 verifier PASS。
- 下一 owner：`developer`。
- 回派原因：verifier 的 `verify-result.json` 已列出明确 `missing gap`。
- 回派 packet 形状已本地校验：`task_packet_check` 结果为 `PASS / DISPATCH_READY`。
- developer 返回后必须再次调度 `verifier` 复验同一 gap。
- 若同一 gap 连续 2 轮无关闭、缩小、新证据、新阻塞、新风险或 owner 变化，暂停给用户决策。

**Developer Task Packet**
```json
{
  "task_ref": "T2",
  "role": "developer",
  "goal": "Close verifier missing gap for T2 AC-2: verify-result.json reports AC-2 scope evidence is missing; produce fresh developer evidence that maps AC-2 completion to the frozen T2 scope.",
  "scope": [
    "Only T2 AC-2 implementation and evidence surfaces defined by frozen artifact://tasks#T2 and artifact://plan#active-batch.",
    "Update or regenerate the T2 developer-report.json and AC-2 supporting evidence needed to prove scope coverage.",
    "Do not touch unrelated tasks, unrelated AC, QA handoff, commit metadata, release artifacts, or verifier conclusions."
  ],
  "input_refs": [
    "artifact://plan#active-batch",
    "artifact://tasks#T2",
    "artifact://developer-report.json#T2/previous-claim-AC-2-complete",
    "artifact://verify-result.json#T2/missing-gap/AC-2-scope-evidence-missing"
  ],
  "expected_evidence": [
    "developer preflight confirming T2 AC-2 scope, inputs, reuse check, and evidence target before changes.",
    "RED evidence that reproduces or acknowledges the verifier missing gap: AC-2 scope evidence absent from the previous developer-report.json.",
    "GREEN evidence proving AC-2 within the frozen T2 scope, with concrete command/test/output or artifact refs tied to the missing gap.",
    "REFACTOR evidence or explicit no-op refactor note explaining no cleanup was needed after closing the evidence gap.",
    "fresh developer-report.json for T2 that includes AC-2 status, scope coverage mapping, evidence refs, and any exact blocker if the gap cannot be closed."
  ],
  "stop_condition": [
    "Stop when the AC-2 scope evidence missing gap is closed with a fresh developer-report.json and corresponding evidence refs ready for verifier re-run.",
    "If blocked, stop immediately with the exact blocker, impacted AC/scope, attempted evidence path, and the decision needed; do not broaden scope."
  ],
  "forbidden_actions": [
    "Do not work outside the T2 AC-2 scope boundary or change unrelated files/tasks.",
    "Do not change the frozen baseline, AC, acceptance criteria, scope, plan, or tasks to make verification pass.",
    "Do not commit, release, publish, or prepare commit handoff artifacts.",
    "Do not replace, edit, or speak for other roles; do not modify verifier, QA, fixer, or user decision conclusions."
  ]
}
```

**状态卡**
```text
status: IN_PROGRESS
current_step: DO-S5 开发/验证循环
active_tasks: T2
current_gap: AC-2 scope 证据缺失
gap_owner: verifier reported
next_owner: developer
dev_verify_loop_count: 1
progress_signal: new_evidence
consecutive_no_progress_count: 0
evidence_refs:
  - artifact://developer-report.json#T2/previous-claim-AC-2-complete
  - artifact://verify-result.json#T2/missing-gap/AC-2-scope-evidence-missing
decision_boundary: none currently; pause if same gap reaches 2 no-progress rounds or scope/AC becomes unclear
next_action: dispatch narrowed developer packet; after fresh developer-report.json returns, dispatch verifier packet for AC-2 scope evidence re-check
resume_condition: developer returns fresh developer-report.json with AC-2 scope evidence refs, or exact blocker requiring user decision
```