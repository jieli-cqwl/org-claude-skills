# Delivery Owner Best-Practice Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Rebuild `delivery-owner` from an execution-oriented delivery orchestrator into a team-usable Phase delivery owner with explicit kickoff, deviation governance, dynamic quality escalation, and goal-level closure.

**Architecture:** Keep the existing chain split across `tech-lead`, `delivery-owner`, `developer`, `qa`, and `test-design`, but redefine their authority boundaries and interaction contracts. Upgrade the chain at five layers together: role definitions, templates, completion checks, contract tests, and rollout readiness artifacts so the new behavior is not just described but enforced.

**Tech Stack:** Markdown role/design docs, Markdown templates, shell completion checks, shell contract tests.

---

### Task 1: Freeze the role contract and authority boundaries [T1]

Files:
- Modify: `contracts/skill-chain.yaml`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Create: `docs/delivery-owner-role-20260411/authority-matrix.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T1] Update `contracts/skill-chain.yaml` to reflect the target authority model.
   - Add or revise ownership language so `delivery-owner` is the execution-phase delivery owner, `tech-lead` remains the planning owner, `qa` remains independent quality judgment owner, and business risk acceptance stays outside PM.

2. [T1] Rewrite role sections in `shared/skills/delivery-owner/SKILL.md`, `shared/skills/tech-lead/SKILL.md`, `shared/skills/qa/SKILL.md`, and `shared/skills/developer/SKILL.md`.
   - Align wording so only one skill owns each of these concerns: plan authorship, kickoff, execution orchestration, gate escalation, release recommendation, sign-off, and risk acceptance boundary.

3. [T1] Create `docs/delivery-owner-role-20260411/authority-matrix.md`.
   - Capture `Must Own / May Decide / Must Escalate / Forbidden` for each role.

4. [T1] Run authority-drift scans.
   - Run: `rg -n "交付负责人|计划 owner|风险接受|sign-off|release_recommendation|重计划|升级门禁" contracts shared/skills docs/delivery-owner-role-20260411`
   - Expected: wording is consistent; no downstream file grants contradictory authority.

5. [T1] Run contract tests.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 2: Rebuild the delivery kickoff and readiness model [T2]

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Create: `shared/skills/delivery-owner/references/kickoff-checklist.md`
- Test: `tests/test-delivery-owner-phase3-contract.sh`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T2] Add an explicit `Delivery Kickoff` stage to `shared/skills/delivery-owner/SKILL.md`.
   - Require alignment across `brief / prd / design / plan / test-cases`.
   - Require readiness checks for `preflight-evidence`, environment, dependency availability, risk owner assignment, and QA handoff readiness.

2. [T2] Create `shared/skills/delivery-owner/references/kickoff-checklist.md`.
   - Define the exact kickoff checklist, output fields, and failure handling.

3. [T2] Upgrade `shared/skills/delivery-owner/scripts/completion_check.sh`.
   - Promote `preflight-evidence` from warning-only to an explicit gate when relevant constraints exist.
   - Fail if kickoff-required evidence is missing or placeholder-only.

4. [T2] Extend `acceptance-summary-template.md`.
   - Add a compact section that records kickoff status and unresolved readiness waivers carried into execution.

5. [T2] Add failure fixtures and run tests.
   - Include at least one fixture for missing `preflight-evidence`.
   - Include at least one fixture for kickoff marked ready without required evidence.
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS

### Task 3: Rebuild orchestration and deviation-governance [T3]

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/dispatch-guide.md`
- Modify: `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- Modify: `shared/skills/developer/SKILL.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T3] Add an explicit deviation-governance section to `shared/skills/delivery-owner/SKILL.md`.
   - Define triggers for complexity drift, repeated non-convergence, interface drift, shared-file expansion, external dependency drift, and blocked accumulation.

2. [T3] Update `dispatch-guide.md`.
   - Map each trigger to a control action: continue, escalate, replan, or block.
   - Clarify when PM can reorder, batch, or reprioritize within `Scope Freeze`.

3. [T3] Rewrite `dev-report-template.md`.
   - Keep only metrics that lead to explicit governance actions.
   - Remove or demote fields that are report-only vanity metrics.
   - Add a section for `deviation triggers hit / control action taken`.

4. [T3] Update `developer/SKILL.md`.
   - Ensure interface `TWEAK/BREAK`, out-of-scope drift, dependency drift, and convergence failure are carried back to PM in a structured way that supports trigger detection.

5. [T3] Run drift searches and tests.
   - Run: `rg -n "complexity|shared_files|TWEAK|BREAK|BLOCKED|replan|deviation" shared/skills/delivery-owner shared/skills/developer`
   - Expected: each drift concept appears in both production rules and report templates.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 4: Rebuild dynamic quality escalation [T4]

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/phase3-dispatch.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/qa/references/qa-stage-obligation-matrix.md`
- Modify: `shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`

1. [T4] Keep `plan.md` as the baseline gate source but add escalation semantics in `delivery-owner/SKILL.md`.
   - Define which execution-time signals can force stronger review/QA coverage.

2. [T4] Update `phase3-dispatch.md`.
   - Add escalation rules for when standard-grade execution must additionally run `QA_B`, `QA_D`, or stronger impacted-surface review.
   - Add replay rules for fixes that affect shared logic or cross-UNIT behavior.

3. [T4] Update `qa/SKILL.md` and `qa-stage-obligation-matrix.md`.
   - Make it explicit how QA accepts escalated work from PM without violating QA’s independent judgment boundary.

4. [T4] Update `phase3-grade-matrix.sh` and tests.
   - Preserve baseline grade semantics while validating escalation rules and non-waivable boundaries.

5. [T4] Run contract tests.
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS

### Task 5: Rebuild goal-level evidence and closure [T5]

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/qa/references/templates/qa-report-template.md`
- Create: `docs/delivery-owner-role-20260411/goal-evidence-model.md`
- Test: `tests/test-delivery-owner-phase3-contract.sh`

1. [T5] Define the goal-evidence model in `docs/delivery-owner-role-20260411/goal-evidence-model.md`.
   - Map `brief success criteria / phase goal / delivery value` to AC, QA, constraints, and final sign-off evidence.

2. [T5] Update `acceptance-summary-template.md`.
   - Add a `goal closure` section with fields for `goal`, `success standard`, `evidence`, `result`, and `remaining gap`.
   - Add explicit result enums such as `已达成 / 部分达成 / 未达成`.

3. [T5] Update `delivery-owner/SKILL.md`.
   - Require PM to make a goal-level closure judgment before sign-off, not just a gate summary.

4. [T5] Update `completion_check.sh`.
   - Validate the presence and non-placeholder quality of goal-level closure fields.
   - Fail if sign-off is confirmed while goal closure is unresolved or contradicts QA blocking recommendations.

5. [T5] Run tests.
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS

### Task 6: Rebuild evidence ownership and reduce duplicated reporting [T6]

Files:
- Modify: `shared/skills/developer/references/templates/developer-report-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/verify/SKILL.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T6] Make `developer-report-Task-N.md` the authoritative one-source TDD evidence artifact.
   - Ensure `developer` and `verify` both point to the same authoritative report for RED/GREEN/proving evidence.

2. [T6] Rewrite `dev-report-template.md`.
   - Replace repeated raw evidence copying with stable references and spot-checkable anchors to authoritative artifacts.

3. [T6] Update `verify/SKILL.md` and `completion_check.sh`.
   - Clarify how PM and verify should consume/spot-check one-source evidence instead of duplicated blobs.

4. [T6] Add negative checks.
   - Fail when PM report references nonexistent anchors.
   - Fail when required one-source evidence is missing even if summary text exists.

5. [T6] Run tests.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 7: Define rollout and team-usage readiness [T7]

Files:
- Create: `docs/delivery-owner-role-20260411/quality-rubric.md`
- Create: `docs/delivery-owner-role-20260411/replay-scenarios.md`
- Modify: `docs/delivery-owner-role-20260411/tasks.md`
- Modify: `docs/delivery-owner-role-20260411/plan.md`

1. [T7] Create `quality-rubric.md`.
   - Score the rebuilt chain on role boundary clarity, kickoff quality, deviation governance, gate escalation, goal closure, evidence hygiene, and team usability.
   - Define a threshold for pilot and a stricter threshold for full team rollout.

2. [T7] Create `replay-scenarios.md`.
   - Include at least four representative scenarios:
     - readiness failure
     - execution drift and replan
     - quality escalation after risk increase
     - goal closure mismatch despite green gates

3. [T7] Update planning docs with rollout gates.
   - Make rollout blocked until rubric and replay expectations are satisfied.

4. [T7] Run consistency checks.
   - Run: `rg -n "\\[T[1-7]\\]" docs/delivery-owner-role-20260411/plan.md`
   - Expected: every task id appears in `plan.md`
   - Run: `rg -n "T[1-7] " docs/delivery-owner-role-20260411/tasks.md`
   - Expected: task ids are defined once each

5. [T7] Final proving commands before implementation handoff.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS
