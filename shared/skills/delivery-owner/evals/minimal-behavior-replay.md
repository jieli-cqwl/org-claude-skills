# Delivery Owner Minimal Behavior Replay

Replay Result: PASS

Purpose: 用最小样例回放 delivery-owner 的关键循环行为；只检查下一跳是否清晰、证据是否新鲜、何时暂停给用户决策，不替代真实 agent 执行。这里的 PASS 表示 expected-behavior contract 完整，不表示 live subagent eval 已运行。

## Replay 1: verifier FAIL replay

Input:

- `developer-report.json` exists for task `T1`.
- `verify-result.json` returns FAIL because AC-2 scope evidence is missing.
- The gap is inside the frozen task scope.

Expected Output Sample:

```text
Delivery Status Card
status: IN_PROGRESS
current_step: DO-S5 developer/verifier loop
current_gap: AC-2 scope evidence missing from verify-result.json
gap_owner: verifier agent
next_owner: developer agent
dev_verify_loop_count: 2
progress_signal: new_evidence
consecutive_no_progress_count: 0
evidence_refs: ["developer-report.json", "verify-result.json#AC-2-missing"]
stale_evidence_refs: []
next_action: dispatch narrowed developer packet, then rerun verifier agent
resume_condition: developer-report.json contains fresh AC-2 scope evidence
```

```text
developer packet
task_ref: T1
role: developer
goal: close AC-2 missing scope evidence reported by verifier agent
scope: ["src/feature.ts", "tests/feature.test.ts"]
input_refs: ["tasks.json#T1", "verify-result.json#AC-2-missing", "developer-report.json"]
expected_evidence: ["fresh developer-report.json", "AC-2 command output", "scope evidence"]
stop_condition: AC-2 gap closed or exact blocker reported
forbidden_actions: no scope outside packet; no baseline/AC change; no commit/release; no other role conclusion
```

Resume Checkpoint:

```text
verifier packet
task_ref: T1
role: verifier
goal: verify AC-2 after fresh developer evidence closes the previous missing gap
scope: ["src/feature.ts", "tests/feature.test.ts"]
input_refs: ["tasks.json#T1", "fresh developer-report.json#AC-2"]
expected_evidence: ["AC verification", "scope verification", "verify-result.json"]
stop_condition: verifier PASS or exact missing gap reported
forbidden_actions: no code changes; no baseline/AC change; no commit/release; no QA or delivery conclusion
```

## Replay 2: qa FAIL replay

Input:

- `verifier agent` has passed task `T1`.
- `qa-result.json` returns FAIL with a reproducible checkout-path defect.
- The failure invalidates previous verifier evidence for files touched by the fix.

Expected Output Sample:

```text
Delivery Status Card
status: IN_PROGRESS
current_step: DO-S7 QA/fix loop
current_gap: checkout-path regression reproduced by qa-result.json
gap_owner: qa agent
next_owner: fixer agent
qa_fix_loop_count: 1
progress_signal: new_evidence
consecutive_no_progress_count: 0
evidence_refs: ["verify-result.json#PASS", "qa-result.json#checkout-fail"]
stale_evidence_refs: ["verify-result.json#PASS"]
next_action: dispatch fixer packet; after fix, rerun affected verifier agent and qa agent
resume_condition: fix-result.json includes root cause, minimal fix, and freshness judgement
```

```text
fixer packet
task_ref: T1
role: fixer
goal: root cause and minimal fix for checkout-path failure from qa-result.json
scope: ["src/feature.ts", "tests/feature.test.ts"]
input_refs: ["qa-result.json#checkout-fail", "verify-result.json#PASS", "developer-report.json"]
expected_evidence: ["root cause", "minimal fix", "freshness judgement", "fix-result.json"]
stop_condition: failure fixed or exact blocker reported
forbidden_actions: no scope outside packet; no baseline/AC change; no commit/release; no QA PASS or commit conclusion
```

Resume Checkpoint:

```text
verifier packet
task_ref: T1
role: verifier
goal: re-verify affected AC and scope after fix-result.json
scope: ["src/feature.ts", "tests/feature.test.ts"]
input_refs: ["fix-result.json", "qa-result.json#checkout-fail", "stale verify-result.json#PASS"]
expected_evidence: ["AC verification", "scope verification", "fresh verify-result.json"]
stop_condition: verifier PASS or exact missing gap reported
forbidden_actions: no code changes; no baseline/AC change; no commit/release; no QA or delivery conclusion
```

```text
qa packet
task_ref: T1
role: qa
goal: rerun checkout-path QA after fresh verifier PASS
scope: ["checkout-path"]
input_refs: ["qa_handoff_contract", "fresh verify-result.json", "fix-result.json"]
expected_evidence: ["checkout-path QA result", "qa-result.json"]
stop_condition: QA PASS or reproducible failure reported
forbidden_actions: no code changes; no baseline/AC change; no commit/release; no verifier or delivery conclusion
```

## Replay 3: two no-progress rounds replay

Input:

- The same gap has gone through two follow-up rounds.
- No gap closure, gap narrowing, new evidence, new blocker, new risk, or owner change appeared.
- The next action requires scope, resource, or risk decision.

Expected Output Sample:

```text
Delivery Status Card
status: PAUSED_FOR_USER_DECISION
current_step: DO-S5 or DO-S7 follow-up loop
current_gap: same failing checkout-path gap after two rounds
gap_owner: fixer agent
next_owner: user
progress_signal: no_progress
consecutive_no_progress_count: 2
evidence_refs: ["round-1/fix-result.json", "round-2/fix-result.json", "latest-qa-result.json#same-fail"]
stale_evidence_refs: ["round-1/verify-result.json", "round-2/verify-result.json"]
next_action: stop dispatching the same owner and ask user for a decision
resume_condition: user selects scope adjustment, resource change, risk acceptance, or stop
```

```text
User Decision Package
decision_needed: choose how to handle the non-converging gap
facts: same gap persisted for two rounds with no new evidence or blocker
impact: continuing the same route is unlikely to converge and may consume more engineering cycles
options: ["narrow scope", "assign different owner/resource", "accept risk", "stop task"]
recommendation: assign a different owner/resource if the user wants to keep the same scope and AC
required_user_answer: one option plus any scope/risk constraint
resume_condition: user decision is explicit enough to build the next packet
next_action_after_decision: dispatch a narrowed packet to the selected owner or stop delivery for this task
```
