# Standard-Chain Team Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a reviewable readiness evidence package that determines whether standard-chain can enter controlled team pilot as a one-human plus AI-role-team delivery workflow.

**Architecture:** Keep the approved design as the decision source in the dated small-chain workset. Produce human-readable Markdown evidence reports beside the design, with `tasks.md` as the completion source of truth and `worklog.md` as the handoff entry. Use deterministic gates for machine-checkable contracts and read-only harness-style review for role, noise, and handoff risks.

**Tech Stack:** Markdown small-chain artifacts, Bash gate commands, Python task-plan consistency checker, existing `skill-harness` contract shape, existing standard-chain skill files under `shared/skills/`.

---

## File Boundaries

- Existing source: `docs/standard-chain-team-readiness/2026-04-22-readiness/design.md`
- Existing status: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/evidence-baseline.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/deterministic-gate-evidence.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/skill-harness-audit.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/noise-context-budget.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/role-capability-report.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/readiness-summary.md`
- Modify: `docs/standard-chain-team-readiness/worklog.md`
- Modify: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`

### Task 1: Small-Chain Workset And Evidence Baseline [T1]

Context: The design was approved before the workset was aligned to the current small-chain bridge. This task proves the workset path and records the evidence baseline that all later reports must use.

Files:
- Read: `docs/standard-chain-team-readiness/worklog.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/design.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/evidence-baseline.md`
- Modify: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`

1. [T1] Verify the expected small-chain paths

Run:

```bash
test -f docs/standard-chain-team-readiness/worklog.md
test -f docs/standard-chain-team-readiness/2026-04-22-readiness/design.md
test ! -e docs/standard-chain-team-readiness-20260422/design.md
```

Expected: all three commands exit 0.

2. [T1] Capture baseline command outputs

Run:

```bash
git rev-parse HEAD
git branch --show-current
date '+%Y-%m-%d %H:%M %Z'
git status --short
```

Expected: commands exit 0. `git status --short` may show unrelated pre-existing worktree changes; preserve them in the baseline note.

3. [T1] Create `evidence-baseline.md`

Write these sections with the command outputs from step 2:

```markdown
# Evidence Baseline

## Baseline

- repo_commit: recorded from `git rev-parse HEAD`
- branch: recorded from `git branch --show-current`
- review_time: recorded from `date '+%Y-%m-%d %H:%M %Z'`
- executor: Codex
- cwd: /Users/lijieli/org-claude-skills

## Review Objects

- shared/skills/product-director/SKILL.md
- shared/skills/product-manager/SKILL.md
- shared/skills/design/SKILL.md
- shared/skills/test-design/SKILL.md
- shared/skills/tech-lead/SKILL.md
- shared/skills/developer/SKILL.md
- shared/skills/review/SKILL.md
- shared/skills/verify/SKILL.md
- shared/skills/qa/SKILL.md
- shared/skills/delivery-owner/SKILL.md
- shared/skills/fix/SKILL.md
- shared/skills/consistency-audit/SKILL.md
- contracts/standard-chain.yaml
- tools/community/validate_standard_chain_phase.py
- tests/test-standard-chain-skill-structure.sh
- tests/test-chain-completeness.sh
- tests/test-standard-chain-skill-evals.sh
- tests/test-skill-harness-contract.sh
- tests/test-skill-harness-gates.sh
- tests/test-skill-harness-standard-chain-integration.sh
- tests/test-skill-harness-field-consumers.sh

## Dirty Worktree Note

Record the exact `git status --short` output. Classify each path as unrelated unless it touches this readiness workset.

## Rebaseline Rule

If any reviewed skill, standard-chain contract, validator, eval, or harness gate changes before the readiness decision, rebuild this baseline and rerun affected evidence.
```

4. [T1] Mark T1 complete in `tasks.md`

Edit only the T1 checkbox line in `tasks.md` from incomplete to complete after steps 1-3 pass.

5. [T1] Commit T1 artifacts

Run:

```bash
git add docs/standard-chain-team-readiness/worklog.md docs/standard-chain-team-readiness/2026-04-22-readiness/design.md docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/plan.md docs/standard-chain-team-readiness/2026-04-22-readiness/evidence-baseline.md
git commit -m "docs: align readiness small-chain workset"
```

Expected: commit succeeds. Do not stage unrelated worktree changes.

### Task 2: Deterministic Gate Evidence [T2]

Context: Machine-checkable contracts should be proven by commands before relying on harness-style review. Failed commands must be reported as BLOCKED with evidence, not treated as subjective review findings.

Files:
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/evidence-baseline.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/deterministic-gate-evidence.md`
- Modify: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`

1. [T2] Run deterministic gate commands

Run each command from `/Users/lijieli/org-claude-skills`:

```bash
bash tests/test-standard-chain-skill-structure.sh
bash tests/test-chain-completeness.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-skill-harness-contract.sh
bash tests/test-skill-harness-gates.sh
bash tests/test-skill-harness-standard-chain-integration.sh
bash tests/test-skill-harness-field-consumers.sh
```

Expected: each command exits 0 and prints a PASS line. If any command exits non-zero, keep the failing output and classify the gate as BLOCKED.

2. [T2] Create `deterministic-gate-evidence.md`

For each command, write a row with:

- gate
- command
- cwd
- exit_code
- key_output
- status
- owner
- readiness_relation

Use `PASS` only for exit code 0. Use `BLOCKED` for non-zero exit and include the observed output. Use owner `readiness-work` only when the failure is caused by this workset; otherwise use `pre-existing-worktree` or the most specific path owner visible from the output.

3. [T2] Mark T2 complete or blocked in `tasks.md`

If every required command passed, mark T2 complete. If any required command is BLOCKED, leave T2 incomplete and add a short blocker note under T2 in `tasks.md` naming the command and report file.

4. [T2] Commit T2 artifacts when T2 is complete

Run only if every required command passed:

```bash
git add docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/deterministic-gate-evidence.md
git commit -m "docs: add readiness deterministic gate evidence"
```

Expected: commit succeeds. If a gate is blocked, stop after updating the report and ask for owner action.

### Task 3: Skill-Harness Audit And Noise Report [T3]

Context: This task performs a read-only audit of standard-chain runtime contracts and context noise. It must use exact file evidence and must not edit the reviewed skills.

Files:
- Read: `shared/skills/product-director/SKILL.md`
- Read: `shared/skills/product-manager/SKILL.md`
- Read: `shared/skills/design/SKILL.md`
- Read: `shared/skills/test-design/SKILL.md`
- Read: `shared/skills/tech-lead/SKILL.md`
- Read: `shared/skills/developer/SKILL.md`
- Read: `shared/skills/review/SKILL.md`
- Read: `shared/skills/verify/SKILL.md`
- Read: `shared/skills/qa/SKILL.md`
- Read: `shared/skills/delivery-owner/SKILL.md`
- Read: `shared/skills/fix/SKILL.md`
- Read: `shared/skills/consistency-audit/SKILL.md`
- Read: `contracts/standard-chain.yaml`
- Read: `shared/reference/Skill质量标准.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/skill-harness-audit.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/noise-context-budget.md`
- Modify: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`

1. [T3] Collect line-numbered source evidence

Run:

```bash
for f in shared/skills/product-director/SKILL.md shared/skills/product-manager/SKILL.md shared/skills/design/SKILL.md shared/skills/test-design/SKILL.md shared/skills/tech-lead/SKILL.md shared/skills/developer/SKILL.md shared/skills/review/SKILL.md shared/skills/verify/SKILL.md shared/skills/qa/SKILL.md shared/skills/delivery-owner/SKILL.md shared/skills/fix/SKILL.md shared/skills/consistency-audit/SKILL.md; do nl -ba "$f" | sed -n '1,220p'; done
```

Expected: command exits 0 and provides exact line numbers for reviewed entries.

2. [T3] Create `skill-harness-audit.md`

Write one section per reviewed skill. For each skill, include:

- overall_verdict
- dimension
- dimension_result
- finding_severity
- file:line
- evidence
- impact
- recommendation
- audit_proof_type
- proof_command
- gate_type

Use `PASS` when no blocking issue is found. Use `FAIL` only with exact `file:line`, impact, recommendation, and proof command. Use `COMMENT` for non-blocking observations.

3. [T3] Create `noise-context-budget.md`

Write sections:

- Scope
- S1 Noise Findings
- S2 Noise Findings
- S3 Noise Findings
- Main Entry Layering Check
- Runtime Authority Thinness Check
- Reference Use-Point Check
- Delivery Owner Control-Plane Check
- Pilot Readiness Impact

For S1/S2/S3 findings, include exact `file:line`, evidence, impact, and cleanup action. If no S1/S2 finding exists, say `No S1/S2 noise found in reviewed scope` and list the proof commands used.

4. [T3] Run supporting proof commands

Run:

```bash
bash tests/test-standard-chain-skill-structure.sh
bash tests/test-skill-harness-standard-chain-integration.sh
```

Expected: both commands exit 0. If either fails, leave T3 incomplete and record the blocker in both reports.

5. [T3] Mark T3 complete or blocked in `tasks.md`

Mark T3 complete only if the reports exist, S1/S2 findings are absent or explicitly classified as blocking, and supporting proof commands passed. If S1/S2 findings exist, leave T3 incomplete and record a blocker note.

6. [T3] Commit T3 artifacts when T3 is complete

Run only if T3 is complete:

```bash
git add docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/skill-harness-audit.md docs/standard-chain-team-readiness/2026-04-22-readiness/noise-context-budget.md
git commit -m "docs: add readiness harness and noise audit"
```

Expected: commit succeeds.

### Task 4: Role Capability Scenario Report [T4]

Context: The review must show whether each AI role can behave like its corresponding human role. This is a desk-check scenario audit against role instructions and existing contract evidence, not a claim that a real end-to-end pilot has already run.

Files:
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/design.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/skill-harness-audit.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/role-capability-report.md`
- Modify: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`

1. [T4] Create the role scenario matrix

Create `role-capability-report.md` with one subsection for each role:

- product-director
- product-manager
- design
- test-design
- tech-lead
- developer
- review
- verify
- qa
- delivery-owner
- fix
- consistency-audit

Each subsection must include two scenarios named `positive` and `failure-or-overreach`.

2. [T4] Apply scenario acceptance rules

For every scenario, write:

- verdict: PASS, FAIL, or COMMENT
- scenario
- expected_role_behavior
- evidence_source
- result_reason
- downstream_impact

Mark FAIL if the role would require the human principal to supply professional role judgment before continuing. Mark PASS only if the role instructions define the judgment, stopping rule, or escalation path.

3. [T4] Cross-check role boundaries against harness findings

Run:

```bash
rg -n '不负责|不得|禁止|必须|HARD-GATE|Runtime Authority|完成校验|advisory|sign-off|用户确认' shared/skills/product-director/SKILL.md shared/skills/product-manager/SKILL.md shared/skills/design/SKILL.md shared/skills/test-design/SKILL.md shared/skills/tech-lead/SKILL.md shared/skills/developer/SKILL.md shared/skills/review/SKILL.md shared/skills/verify/SKILL.md shared/skills/qa/SKILL.md shared/skills/delivery-owner/SKILL.md shared/skills/fix/SKILL.md shared/skills/consistency-audit/SKILL.md
```

Expected: command exits 0 and provides evidence anchors for role boundaries and stop rules.

4. [T4] Mark T4 complete or blocked in `tasks.md`

Mark T4 complete only if every role has both scenarios, every scenario has a verdict, and no role has a FAIL that blocks controlled pilot readiness. If any role has a blocking FAIL, leave T4 incomplete and record the role and report path.

5. [T4] Commit T4 artifacts when T4 is complete

Run only if T4 is complete:

```bash
git add docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/role-capability-report.md
git commit -m "docs: add readiness role capability report"
```

Expected: commit succeeds.

### Task 5: Readiness Summary And Pilot Decision [T5]

Context: The summary converts evidence into a team-facing decision. It must not overclaim complete delivery capability without a real low-risk end-to-end pilot.

Files:
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/deterministic-gate-evidence.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/skill-harness-audit.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/noise-context-budget.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/role-capability-report.md`
- Create: `docs/standard-chain-team-readiness/2026-04-22-readiness/readiness-summary.md`
- Modify: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`

1. [T5] Create `readiness-summary.md`

Write these sections:

- Decision
- Evidence Baseline
- Deterministic Gate Result
- Skill Harness Audit Result
- Noise And Context Budget Result
- Role Capability Result
- Residual Risks
- Pilot Boundary
- Next Actions

Decision must be exactly one of `GO for controlled pilot`, `FIX before pilot`, or `NO-GO`.

2. [T5] Apply decision rules

Use `GO for controlled pilot` only when T2, T3, and T4 are complete and no S1/S2 noise, S1/S2 harness finding, deterministic gate blocker, or role capability blocking FAIL remains.

Use `FIX before pilot` when a blocking issue is specific and fixable before trial.

Use `NO-GO` when the chain cannot produce credible readiness evidence or the workflow requires human professional role judgment in core AI roles.

3. [T5] State the capability boundary

Include this sentence in `readiness-summary.md`:

```markdown
This evidence supports controlled pilot readiness only; complete team delivery capability is not claimed until a real low-risk demand runs end-to-end from `product-director` to `delivery-owner`.
```

4. [T5] Mark T5 complete or blocked in `tasks.md`

Mark T5 complete if the summary exists, uses one allowed decision, and includes the capability boundary. If upstream reports are blocked, leave T5 incomplete and record the upstream blocker.

5. [T5] Commit T5 artifacts when T5 is complete

Run only if T5 is complete:

```bash
git add docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/readiness-summary.md
git commit -m "docs: add standard chain readiness summary"
```

Expected: commit succeeds.

### Task 6: Final Small-Chain Verification And Closeout [T6]

Context: Verify that the small-chain artifacts are internally consistent, free of placeholders, and that the handoff entry points to the readiness result.

Files:
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/design.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/plan.md`
- Read: `docs/standard-chain-team-readiness/2026-04-22-readiness/readiness-summary.md`
- Modify: `docs/standard-chain-team-readiness/worklog.md`
- Modify: `docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md`

1. [T6] Run task-plan consistency

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/plan.md
```

Expected: prints `[PASS] tasks-plan consistency`.

2. [T6] Run placeholder scan

Run:

```bash
python3 -c 'from pathlib import Path; bad=[]; terms=["TB"+"D","TO"+"DO","待"+"定","占"+"位"]; left=chr(123); right=chr(125); roots=[Path("docs/standard-chain-team-readiness/2026-04-22-readiness"), Path("docs/standard-chain-team-readiness/worklog.md")]; files=[]; [files.extend(sorted(root.rglob("*.md"))) if root.is_dir() else files.append(root) for root in roots]; [bad.append(str(path)) for path in files if any(term in path.read_text(encoding="utf-8") for term in terms) or (left in path.read_text(encoding="utf-8") and right in path.read_text(encoding="utf-8"))]; print("\n".join(bad)); raise SystemExit(1 if bad else 0)'
```

Expected: command exits 0 and prints nothing. Any match must be fixed before continuing.

3. [T6] Update `worklog.md` closeout entry

Prepend a latest entry with:

- time from `date '+%Y-%m-%d %H:%M'`
- actor: Codex
- owner: Codex
- mode: small-chain
- stage: signoff
- scope_ref: feature
- action: Close readiness evidence package and point handoff to the readiness summary.
- status: done if all tasks are complete; blocked if any task remains incomplete
- state_ref: 2026-04-22-readiness/readiness-summary.md
- next: Run verify-change and archive when readiness owner accepts the summary.
- next_ref: 2026-04-22-readiness/readiness-summary.md

4. [T6] Mark T6 complete in `tasks.md`

After steps 1-3 pass, mark T6 complete.

5. [T6] Run final consistency check again

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/plan.md
```

Expected: prints `[PASS] tasks-plan consistency`.

6. [T6] Commit final small-chain artifacts

Run:

```bash
git add docs/standard-chain-team-readiness/worklog.md docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/plan.md
git commit -m "docs: close standard chain readiness workset"
```

Expected: commit succeeds.
