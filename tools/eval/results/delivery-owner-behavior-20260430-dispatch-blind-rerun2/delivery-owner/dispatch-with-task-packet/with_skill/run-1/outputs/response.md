使用 `delivery-owner`：缺口 `T2 / AC-2 未实现` 属于 developer agent responsibility。当前只派发开发，不亲自实现、不进入 verifier/QA/commit。

**状态卡**
```text
status: DISPATCH_READY
plan_ref: tech-lead frozen plan; path=unavailable
tasks_ref: tech-lead frozen tasks#T2; path=unavailable
current_step: DO-S4 派发开发
execution_mode: serial
active_tasks: T2
current_gap: AC-2 未实现
gap_owner: developer agent
next_owner: developer agent
dev_verify_loop_count: 0
qa_fix_loop_count: 0
progress_signal: owner_changed
consecutive_no_progress_count: 0
evidence_refs: task_packet_check=PASS, delivery-owner-eval-T2-task-packet.json
decision_boundary: scope/AC/风险/资源变更、10轮上限、同一 gap 连续2轮无进展
next_action: 派发 developer agent；返回后必须调度 verifier agent 复验
resume_condition: developer-report.json 返回，或 developer 报告精确 blocker
```

**Task Packet**
```json
{
  "task_ref": "T2",
  "role": "developer",
  "goal": "Close the missing implementation gap for T2 AC-2 only, using the frozen tech-lead plan/tasks as the baseline.",
  "scope": [
    "logical_ref: tech-lead.tasks.T2.scope; path=unavailable",
    "Allowed changes are limited to files, directories, user paths, and behavior explicitly listed in the frozen T2 scope.",
    "Implement AC-2 only; preserve all other T2 ACs and unrelated tasks."
  ],
  "input_refs": [
    "artifact://plan; producer=tech-lead; status=frozen; path=unavailable",
    "artifact://tasks#T2; producer=tech-lead; status=frozen; path=unavailable",
    "gap://T2/AC-2; status=missing_implementation; path=unavailable",
    "test_refs://T2/AC-2; source=frozen_tasks; path=unavailable"
  ],
  "expected_evidence": [
    "developer preflight confirming frozen T2 scope, AC-2, test refs, dependencies, and reuse candidates before edits",
    "RED evidence showing AC-2 is currently failing or missing before implementation",
    "GREEN evidence from a fresh proving command showing AC-2 passes after implementation",
    "REFACTOR evidence or explicit no-op refactor note showing no unrelated changes remain",
    "developer-report.json with changed scope, commands, results, evidence refs, blockers, and residual risks"
  ],
  "stop_condition": [
    "PASS only when AC-2 is implemented within frozen T2 scope and fresh GREEN evidence is available.",
    "BLOCKED if T2 scope, AC-2 wording, dependencies, environment, or test refs are unavailable or contradictory.",
    "BLOCKED if implementation requires changing baseline plan/tasks, AC semantics, unrelated task scope, or accepting new risk."
  ],
  "forbidden_actions": [
    "Scope boundary: do not modify files, directories, user paths, or behavior outside frozen T2 scope.",
    "Baseline and AC boundary: do not change frozen plan/tasks, AC-2 semantics, acceptance criteria, dependencies, or QA handoff.",
    "Commit/release boundary: do not commit, release, deploy, or start long-running services as part of this developer task.",
    "Other roles boundary: do not replace verifier, qa, fixer, or delivery-owner conclusions; only provide developer evidence."
  ]
}
```

门禁结果：`task_packet_check.sh` 返回 `PASS / DISPATCH_READY / safe_to_dispatch=true`。下一步派给 developer agent；developer 返回后回到 DO-S5，必须由 verifier agent 独立验收 AC/scope 和证据。