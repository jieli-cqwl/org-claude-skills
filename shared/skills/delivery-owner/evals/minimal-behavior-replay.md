# Delivery Owner Minimal Behavior Replay

Replay Result: PASS

Purpose: 用最小样例回放 delivery-owner 的关键循环行为；只检查下一跳是否清晰、证据是否新鲜、何时暂停给用户决策，不替代真实 agent 执行。这里的 PASS 表示 expected-behavior contract 完整，不表示 live subagent eval 已运行。

## Replay 1: verifier FAIL replay

Input:

- `developer-report.json` exists for task `T1`.
- `verify-result.json` returns FAIL because AC-2 scope evidence is missing.
- The gap is inside the frozen task goal and outside `forbidden_scope`.

Expected Output Sample:

```text
Delivery Status Card
status: IN_PROGRESS
current_step: DO-S5 developer/verifier loop
current_gap: AC-2 scope evidence missing from verify-result.json
gap_owner: verifier agent
next_owner: developer agent
dev_verify_loop_count: 2
progress_signal: gap_judgment_changed
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
forbidden_scope: ["tasks.json", "test-cases.json", "phase-prd.json"]
input_refs: ["tasks.json#T1", "verify-result.json#AC-2-missing", "developer-report.json"]
expected_evidence: ["fresh developer-report.json", "AC-2 command output", "scope evidence"]
stop_condition: AC-2 gap closed or exact blocker reported
forbidden_actions: no files in forbidden_scope; no baseline/AC change; no commit/release; no other role conclusion
```

Resume Checkpoint:

```text
verifier packet
task_ref: T1
role: verifier
goal: verify AC-2 after fresh developer evidence closes the previous missing gap
forbidden_scope: ["src/", "tests/", "tasks.json", "test-cases.json"]
input_refs: ["tasks.json#T1", "fresh developer-report.json#AC-2"]
expected_evidence: ["AC verification", "scope verification", "verify-result.json"]
stop_condition: verifier PASS or exact missing gap reported
forbidden_actions: no files in forbidden_scope; no baseline/AC change; no commit/release; no QA or delivery conclusion
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
progress_signal: gap_judgment_changed
consecutive_no_progress_count: 0
evidence_refs: ["verify-result.json#PASS", "qa-result.json#checkout-fail"]
stale_evidence_refs: ["verify-result.json#PASS"]
next_action: dispatch fixer packet; after fix, rerun affected verifier agent, fresh review skill, and qa agent
resume_condition: fix-result.json includes root cause, minimal fix, and freshness judgement
```

```text
fixer packet
task_ref: T1
role: fixer
goal: root cause and minimal fix for checkout-path failure from qa-result.json
forbidden_scope: ["tasks.json", "test-cases.json", "phase-prd.json"]
input_refs: ["qa-result.json#checkout-fail", "verify-result.json#PASS", "developer-report.json"]
expected_evidence: ["root cause", "minimal fix", "freshness judgement", "fix-result.json"]
stop_condition: failure fixed or exact blocker reported
forbidden_actions: no files in forbidden_scope; no baseline/AC change; no commit/release; no QA PASS or commit conclusion
```

Resume Checkpoint:

```text
verifier packet
task_ref: T1
role: verifier
goal: re-verify affected AC and scope after fix-result.json
forbidden_scope: ["src/", "tests/", "tasks.json", "test-cases.json"]
input_refs: ["fix-result.json", "qa-result.json#checkout-fail", "stale verify-result.json#PASS"]
expected_evidence: ["AC verification", "scope verification", "fresh verify-result.json"]
stop_condition: verifier PASS or exact missing gap reported
forbidden_actions: no files in forbidden_scope; no baseline/AC change; no commit/release; no QA or delivery conclusion
```

```text
review packet
task_ref: T1
role: review
goal: review code changed by fix-result.json after fresh verifier PASS
forbidden_scope: ["src/", "tests/", "tasks.json", "test-cases.json"]
input_refs: ["fix-result.json", "fresh verify-result.json", "stale code-review-result.json#pre-fix"]
expected_evidence: ["Strengths", "Issues", "Assessment", "fresh code-review-result.json"]
stop_condition: review PASS or exact review blocker reported
forbidden_actions: no files in forbidden_scope; no baseline/AC change; no commit/release; no QA or delivery conclusion
```

```text
qa packet
task_ref: T1
role: qa
goal: rerun checkout-path QA after fresh verifier PASS and fresh code-review-result.json
forbidden_scope: ["src/", "tests/", "tasks.json", "test-cases.json"]
input_refs: ["qa_handoff_contract", "fresh verify-result.json", "fresh code-review-result.json", "fix-result.json"]
expected_evidence: ["checkout-path QA result", "qa-result.json"]
stop_condition: QA PASS or reproducible failure reported
forbidden_actions: no files in forbidden_scope; no baseline/AC change; no commit/release; no verifier or delivery conclusion
```

## Replay 3: qa non-PASS routing replay

Input:

- `qa-result.json.gate_result` is `CONDITIONAL`, `NOT_RUN`, or `N_A`; or `release_recommendation` is `CONDITIONAL_ALLOW`, `BLOCK`, or `DEFER`.
- The result is not an unconditional QA PASS.
- The next action requires risk acceptance, missing execution evidence, or scope/resource clarification.

Expected Output Sample:

```text
Delivery Status Card
status: PAUSED_FOR_USER_DECISION
current_step: DO-S7 QA/fix loop
current_gap: QA result is non-PASS or release recommendation is not ALLOW
gap_owner: qa agent
next_owner: user
progress_signal: new_risk
consecutive_no_progress_count: 0
evidence_refs: ["qa-result.json#gate-result", "qa-result.json#release-recommendation"]
stale_evidence_refs: []
next_action: request user decision for waiver, rerun scope, or deferred release
resume_condition: user provides waiver, missing evidence, or revised QA scope
```

```text
routing table
CONDITIONAL: next_owner=user; required_artifact=user-decision.json or waiver entry; resume_condition=waiver accepted or QA rerun requested
NOT_RUN: next_owner=qa agent or user; required_artifact=qa-result.json.not_executed_reason; resume_condition=missing QA evidence produced or user accepts non-execution risk
N_A: next_owner=delivery-owner; required_artifact=qa-result.json.not_executed_reason; resume_condition=N_A source refs resolve and requiredness is non-required
CONDITIONAL_ALLOW: next_owner=user; required_artifact=waiver entry; resume_condition=user accepts conditions
BLOCK: next_owner=fixer agent, developer agent, product-manager, design, or user based on issue_ledger.owner_hint; required_artifact=issue_ledger triage; resume_condition=blocker closed or user changes scope
DEFER: next_owner=user; required_artifact=user-decision.json; resume_condition=user accepts deferral plan
waiver: user-owned risk acceptance only; delivery-owner cannot self-waive
```

## Replay 4: two no-progress rounds replay

Input:

- The same gap has gone through two follow-up rounds.
- No gap closure, gap narrowing, gap judgment change, new blocker, new risk, or authoritative owner route appeared.
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
