# QA/Test v2 Best-Practice Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Rebuild the `test-design -> qa -> project-manager Phase 3` chain into a best-practice QA/Test v2 system with explicit role boundaries, explicit test obligations, a usable defect and release model, and machine-checked contract consistency.

**Architecture:** Keep the three-role split, but make the contract explicit: `test-design` owns pre-dev test design and obligation triggering, `qa` owns post-build execution and risk judgment, and `project-manager` owns orchestration plus final sign-off. Remove duplicated authority, convert hidden assumptions into explicit contracts, and upgrade hooks from structure checks to decision-quality checks.

**Tech Stack:** Markdown skill specs, Markdown templates, shell completion checks, shell contract tests.

---

### Task 1: Unify Authority Map and Artifact Ownership [T1]

Files:
- Modify: `contracts/skill-chain.yaml`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/project-manager/SKILL.md`
- Modify: `shared/skills/project-manager/references/phase3-dispatch.md`
- Modify: `shared/agents/qa.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`
- Test: `tests/test-project-manager-phase3-contract.sh`

1. [T1] Normalize the authority model in `contracts/skill-chain.yaml`.
   - Declare one meaning for requirement UNIT artifacts (`phase-{N}/units/UNIT-*.md`) and one meaning for execution workspaces (`phase-{N}/unit-{N}/`).
   - Declare `qa-report.md` as a Phase-level artifact and `test-cases.md` as a UNIT-level artifact.

2. [T1] Rewrite the role and output sections in `shared/skills/test-design/SKILL.md`, `shared/skills/qa/SKILL.md`, and `shared/skills/project-manager/SKILL.md` so they no longer contradict the contract file.
   - Remove any wording that places `qa-report.md` in a UNIT work directory.
   - Make `test_cases_ref` a required QA dispatch input instead of an optional reference.

3. [T1] Update `shared/skills/project-manager/references/phase3-dispatch.md` and `shared/agents/qa.md` to match the same ownership model.
   - The QA dispatch contract must refer to the authoritative Phase-level `qa-report.md`.
   - The QA dispatch contract must explicitly require `test_cases_ref`.

4. [T1] Run authority-drift searches and fix any leftovers.
   - Run: `rg -n "UNIT work directory|qa-report\\.md|test_cases_ref|phase_dir|unit_work_dir" contracts shared/skills shared/agents`
   - Expected: only the new authoritative wording remains; no contradictory `qa-report` location text remains.

5. [T1] Run contract tests.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-project-manager-phase3-contract.sh`
   - Expected: PASS

### Task 2: Rebuild the `test-design -> qa` Handoff Contract [T2]

Files:
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/test-design/references/templates/test-cases-template.md`
- Modify: `shared/skills/test-design/scripts/completion_check.sh`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/agents/qa.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T2] Add an explicit QA handoff section to `test-cases.md`.
   - Extend the template with a contract table that lists: `test_obligation`, `trigger_source`, `qa_stage`, `requiredness`, `skip_rule`, `evidence_expectation`.
   - Cover at minimum: smoke, AC/function, API/interface, E2E, regression, exploratory, UX, exception recovery, and NFR-triggered obligations.

2. [T2] Update `shared/skills/test-design/SKILL.md` so the handoff contract becomes a required output.
   - The skill must explain that `test-design` decides which obligations are always required and which are conditional.
   - The skill must require reasons when an obligation is intentionally not expanded.

3. [T2] Update `shared/skills/test-design/scripts/completion_check.sh` to block missing or placeholder handoff contracts.
   - Validate that every generated `test-cases.md` contains the contract table.
   - Validate that required columns use real values, not placeholders.

4. [T2] Update `shared/skills/qa/SKILL.md` and `shared/agents/qa.md` so QA consumes the handoff contract as a hard precondition.
   - QA must not silently infer whether UX, performance, contract, or recovery obligations apply.
   - QA must execute or explicitly record why a triggered obligation was not executed.

5. [T2] Run targeted checks.
   - Run: `rg -n "专项测试触发依据与展开策略|测试义务|skip_rule|qa_stage" shared/skills/test-design shared/skills/qa`
   - Expected: all handoff obligations are discoverable from the templates and skill text.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 3: Rebuild the QA Execution Model [T3]

Files:
- Modify: `shared/skills/qa/SKILL.md`
- Create: `shared/skills/qa/references/qa-stage-obligation-matrix.md`
- Modify: `shared/skills/qa/references/e2e-journey-methodology.md`
- Modify: `shared/skills/qa/references/regression-methodology.md`
- Modify: `shared/skills/qa/references/exploratory-testing-methodology.md`
- Modify: `shared/agents/qa.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T3] Create `shared/skills/qa/references/qa-stage-obligation-matrix.md`.
   - Define the exact ownership of `QA_A`, `QA_B`, `QA_C`, `QA_D`, plus the NFR overlay.
   - State which obligations are mandatory, condition-triggered, or never standalone stages.

2. [T3] Rewrite `shared/skills/qa/SKILL.md` to align with that matrix.
   - `QA_A`: smoke + AC/function + API/interface + design/MOD/constraint acceptance.
   - `QA_B`: happy path + abnormal path + exception recovery + UX checkpoints.
   - `QA_C`: regression + impacted-surface validation.
   - `QA_D`: exploratory testing with explicit risk charters.
   - NFR obligations: execute when triggered by `test-cases.md`, otherwise record non-execution reasons.

3. [T3] Update the methodology reference files so they reflect the rebuilt ownership.
   - E2E methodology must mention UX and recovery checkpoints.
   - Regression methodology must mention impacted-surface reasoning and smoke positioning.
   - Exploratory methodology must keep risk charters and add recovery/UX exploration prompts where appropriate.

4. [T3] Update `shared/agents/qa.md` to consume the rebuilt stage model.
   - The agent contract must describe the mandatory `test_cases_ref`.
   - The agent contract must treat `ux.md` as supplementary input, not as the only path to UX verification.

5. [T3] Verify stage discoverability.
   - Run: `rg -n "QA_A|QA_B|QA_C|QA_D|UX|恢复|冒烟|API|NFR" shared/skills/qa shared/agents/qa.md`
   - Expected: each obligation appears in one explicit stage or in the NFR overlay reference, not as scattered hidden assumptions.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 4: Rebuild the Defect Model and Release-Decision Model [T4]

Files:
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/qa/references/templates/qa-report-template.md`
- Create: `shared/skills/qa/references/release-decision-methodology.md`
- Delete: `shared/skills/project-manager/references/templates/qa-report-template.md`
- Modify: `shared/skills/project-manager/references/templates/acceptance-summary-template.md`
- Modify: `shared/skills/project-manager/references/templates/waivers-template.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`
- Test: `tests/test-project-manager-phase3-contract.sh`

1. [T4] Create `shared/skills/qa/references/release-decision-methodology.md`.
   - Define allowed release recommendations: `放行`, `条件放行`, `阻塞`.
   - Define how unresolved defects, waivers, residual risk, and missing obligations affect the recommendation.

2. [T4] Upgrade the authoritative QA report template.
   - Add issue-level fields: `severity`, `priority`, `impact_scope`, `user_impact`, `environment_or_build`, `regression_flag`, `temporary_workaround`, `owner_hint`.
   - Add report-level fields: `residual_risk`, `release_recommendation`, `not_executed_reason`.
   - Keep `QAR-*` as the stable issue ledger and make it the source for downstream summaries.

3. [T4] Update the project-manager-facing templates so they consume the same issue and release model.
   - `acceptance-summary.md` must import `QAR-*`, severity, and release recommendation without lossy rewriting.
   - `waivers.md` must require explicit linkage to `QAR-*`, risk, compensating control, and expiry.
   - Remove the duplicate project-manager QA template once the QA-owned template becomes the single authority source.

4. [T4] Update `shared/skills/qa/SKILL.md` so `release_recommendation` is a required QA output, not an informal side note.

5. [T4] Run template and contract validation.
   - Run: `rg -n "release_recommendation|severity|priority|impact_scope|residual_risk|QAR-" shared/skills/qa shared/skills/project-manager/references/templates`
   - Expected: the issue and release model exists in both the QA report and the acceptance/waiver flow.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-project-manager-phase3-contract.sh`
   - Expected: PASS

### Task 5: Upgrade Hooks and Contract Tests to Decision-Quality Gates [T5]

Files:
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Modify: `shared/skills/test-design/scripts/completion_check.sh`
- Modify: `shared/skills/project-manager/scripts/completion_check.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-project-manager-phase3-contract.sh`

1. [T5] Upgrade `shared/skills/qa/scripts/completion_check.sh`.
   - Validate the authoritative Phase-level report location.
   - Validate grade-to-stage requirements, not just `scope`.
   - Validate required defect fields and release recommendation enums.
   - Validate that every `N/A` or skipped obligation includes a reason.

2. [T5] Upgrade `shared/skills/test-design/scripts/completion_check.sh`.
   - Validate the new handoff contract table.
   - Validate that triggered obligations have executable expectations for QA.

3. [T5] Upgrade `shared/skills/project-manager/scripts/completion_check.sh`.
   - Validate that `acceptance-summary.md` and `waivers.md` reflect the authoritative `qa-report.md` issue ledger and release recommendation.
   - Validate that non-waivable items remain blocked.

4. [T5] Extend shell contract tests with both success and failure fixtures.
   - Add at least one failing fixture for wrong `qa-report` location.
   - Add at least one failing fixture for missing release recommendation.
   - Add at least one failing fixture for missing triage fields.
   - Add at least one failing fixture for a triggered obligation marked `N/A` without a reason.

5. [T5] Run the full shell gate suite.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-project-manager-phase3-contract.sh`
   - Expected: PASS

### Task 6: Add a Quality Rubric and Historical Replay Validation Set [T6]

Files:
- Create: `docs/qa-test-v2/2026-04-11-best-practice-rebuild/quality-rubric.md`
- Create: `docs/qa-test-v2/2026-04-11-best-practice-rebuild/replay-scenarios.md`
- Modify: `docs/qa-test-v2/2026-04-11-best-practice-rebuild/tasks.md`
- Modify: `docs/qa-test-v2/2026-04-11-best-practice-rebuild/plan.md`

1. [T6] Create `quality-rubric.md`.
   - Score the rebuilt chain on: role boundary, single source of truth, test-type explicitness, defect model, release model, engineering consistency, readability.
   - Define a passing threshold for pilot use.

2. [T6] Create `replay-scenarios.md`.
   - Document 3-5 representative escaped defects or high-risk scenarios.
   - For each scenario, state which handoff trigger should fire, which QA stage should catch it, what `QAR-*` output should exist, and what release recommendation should result.

3. [T6] Add rollout gates to the local planning docs.
   - Mark rollout blocked until both the rubric threshold and replay expectations are satisfied.

4. [T6] Run final consistency checks on the planning package.
   - Run: `rg -n "\[T[1-6]\]" docs/qa-test-v2/2026-04-11-best-practice-rebuild/plan.md`
   - Expected: every task id from `tasks.md` appears in `plan.md`.
   - Run: `rg -n "T[1-6] " docs/qa-test-v2/2026-04-11-best-practice-rebuild/tasks.md`
   - Expected: the same task set is defined once each.

5. [T6] Final proving commands before delivery.
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-project-manager-phase3-contract.sh`
   - Expected: PASS
