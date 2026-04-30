理解：当前所有 task 已有 developer-report 和 verifier PASS，但 QA 用户路径 FAIL 且可复现；fixer 已做最小修复后，delivery-owner 不能提交，必须停在 DO-S7 QA/修复循环，重跑受影响 verifier agent 与 qa agent，直到 fresh PASS。已按 skill 生成并校验 fixer packet：`task_packet_check.sh` 返回 `PASS / DISPATCH_READY`。

**门禁**
- QA FAIL 可复现：调度 `fixer`，不进入 `/commit`。
- fixer 修改后：旧 `verify-result.json` / `qa-result.json` 对受影响范围失效，必须 fresh rerun。
- 只有受影响 verifier agent PASS + qa agent fresh PASS + 用户明确提交授权后，才可调度 `/commit`。
- 同一 gap 连续 2 轮无进展，或 QA/修复循环达到 10 轮，暂停给用户决策。

**Fixer Packet**
```json
{
  "task_ref": "qa-result.json::task_ref",
  "role": "fixer",
  "goal": "Close the reproducible QA failure recorded in failing qa-result.json for qa-result.json::task_ref without changing the frozen AC or expanding scope.",
  "scope": [
    "Only the task scope declared by frozen tasks.json for qa-result.json::task_ref.",
    "Only code, tests, and documentation directly affected by the failing user path in qa-result.json.",
    "Do not touch unrelated tasks, unrelated user paths, or unrelated cleanup."
  ],
  "input_refs": [
    "failing qa-result.json",
    "latest verify-result.json for qa-result.json::task_ref",
    "latest developer-report.json for qa-result.json::task_ref",
    "frozen plan.json and tasks.json AC/scope for qa-result.json::task_ref"
  ],
  "expected_evidence": [
    "Root cause analysis that maps the failing qa-result.json reproduction to the code path.",
    "Minimal fix summary with exact touched scope and why it is the smallest safe change.",
    "Freshness judgment: which prior qa-result.json or verify-result.json evidence became stale after the fix, and which verifier/qa reruns are required.",
    "fix-result.json containing task_ref, defect_ref, root cause, changed files, commands run, residual risk, and rerun recommendations."
  ],
  "stop_condition": [
    "Stop when the recorded failure is fixed and fix-result.json is complete enough for affected verifier agent and qa agent reruns.",
    "Stop and report exact blocker if root cause needs scope/AC/user-path changes, external facts, unavailable environment, or broader risk acceptance."
  ],
  "forbidden_actions": [
    "Do not work outside the task scope or unrelated files.",
    "Do not change baseline, AC, acceptance criteria, qa_handoff_contract, or user-path expectations.",
    "Do not commit, release, tag, merge, or invoke /commit.",
    "Do not replace other roles: do not mark verifier PASS, do not mark qa PASS, and do not substitute for other roles' independent evidence."
  ]
}
```

**状态卡**
```text
status: QA_FIX_LOOP_ACTIVE
current_step: DO-S7 QA/修复循环
current_gap: qa-result.json 中的可复现用户路径缺陷；fixer 已返回 fix-result.json，需 fresh 验证
progress_signal: owner_changed / new_evidence
consecutive_no_progress_count: 0
stale_evidence_refs: previous verify-result.json, failing qa-result.json
next_owner: affected verifier agent, then qa agent
evidence_refs: developer-report.json, previous verify-result.json, failing qa-result.json, fix-result.json
decision_boundary: /commit 授权尚不可用；需 fresh verifier PASS + fresh QA PASS 后再请求
next_action: 重跑受影响 verifier agent；PASS 后重跑 qa agent 用户路径
resume_condition: verifier agent fresh PASS 且 qa agent fresh PASS；若同一 gap 两轮无进展则暂停给用户决策
```