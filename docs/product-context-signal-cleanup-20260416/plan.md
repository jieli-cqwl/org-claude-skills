# Product Context Signal Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Reduce product-split prompt noise while preserving product capabilities through explicit reference contracts, executable gates, and evidence.

**Architecture:** Keep `/product-director` and `/product-manager` as self-contained runtime skills. Convert heavy templates into focused output/evidence schemas, move enforceable constraints into `contracts/product-artifacts.yaml` plus completion gates and tests, and protect product thinking/review orchestration with reference contracts.

**Tech Stack:** Markdown skills/templates, Bash completion gates, YAML contracts, shell contract tests, Python benchmark helpers.

---

### Task 1: Product Template Purity [T1]

Files:
- Modify: `shared/skills/product-director/references/templates/brief-template.md`
- Modify: `shared/skills/product-director/references/templates/phase-prd-template.md`
- Modify: `shared/skills/product-manager/references/templates/brief-template.md`
- Modify: `shared/skills/product-manager/references/templates/phase-prd-template.md`
- Modify: `shared/skills/product-manager/references/templates/product-manager-review-template.md`
- Test: `tests/test-product-template-purity-contract.sh`

1. [T1] Write a failing purity contract for forbidden Director-owned template content and review template shape.
2. [T1] Run `bash tests/test-product-template-purity-contract.sh`; expected result before implementation: FAIL on Manager-only content in Director templates and over-heavy review template sections.
3. [T1] Shrink Director templates to Director-owned output structure only.
4. [T1] Shrink Manager templates to Manager-owned continuation structure only.
5. [T1] Keep `product-manager-review-template.md` focused on evidence fields: final verdict, review summary, issue ledger, convergence rounds, user decisions, and unresolved blockers.
6. [T1] Run `bash tests/test-product-template-purity-contract.sh`; expected result after implementation: PASS.

### Task 2: Product Artifact Contract [T2]

Files:
- Create: `contracts/product-artifacts.yaml`
- Modify: `shared/skills/product-director/scripts/completion_check.sh`
- Modify: `shared/skills/product-manager/scripts/completion_check.sh`
- Test: `tests/test-product-artifact-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T2] Write a failing contract test that requires `contracts/product-artifacts.yaml` and requires both product gates to reference it.
2. [T2] Run `bash tests/test-product-artifact-contract.sh`; expected result before implementation: FAIL because the contract does not exist or gates do not reference it.
3. [T2] Add `contracts/product-artifacts.yaml` with `brief_lock`, `prd_lock`, and `review` sections.
4. [T2] Update product gates to derive lock section lists from `contracts/product-artifacts.yaml`.
5. [T2] Update gate fixtures/tests for the declared sections.
6. [T2] Run `bash tests/test-product-artifact-contract.sh` and `bash tests/test-skill-output-and-gate-contract.sh`; expected result after implementation: PASS.

### Task 3: Prompt And Evidence Noise Cleanup [T3]

Files:
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-director/references/conversation-guide.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/product-manager/references/conversation-guide.md`
- Modify: `docs/product-role-split-20260414/evidence-and-eval-plan.md`
- Modify: `docs/product-role-split-20260414/deep-validation-report.md`
- Test: `tests/test-product-stability-guidance-contract.sh`
- Test: `tests/test-product-template-purity-contract.sh`

1. [T3] Add assertions that evidence docs state benchmark boundaries instead of self-certifying “best practice”.
2. [T3] Run the guidance and purity tests; expected result before implementation: FAIL on stale proof language or repeated process prose.
3. [T3] Keep role boundary and gate policy in `SKILL.md`, and remove duplicate status-machine prose from guides/templates.
4. [T3] Rewrite evidence docs as scorecard plus known limitations.
5. [T3] Run `bash tests/test-product-stability-guidance-contract.sh` and `bash tests/test-product-template-purity-contract.sh`; expected result after implementation: PASS.

### Task 4: Evidence Contract Hardening [T4]

Files:
- Modify: `tools/eval/scenarios/product-split-benchmark-evals.json`
- Modify: `tools/eval/scripts/product_split_benchmark_core.py`
- Modify: `tools/eval/scripts/run_product_split_benchmark.py`
- Modify: `tests/test-product-split-benchmark-contract.sh`
- Modify: `tests/test-product-eval-contract.sh`

1. [T4] Add failing assertions that benchmark scoring cannot rely only on split-specific terminology and fixed A/B ordering.
2. [T4] Run `bash tests/test-product-split-benchmark-contract.sh` and `bash tests/test-product-eval-contract.sh`; expected result before implementation: FAIL on current benchmark bias.
3. [T4] Add outcome-oriented evaluation metadata and neutral rubric wording.
4. [T4] Add randomized blind order metadata or explicit smoke-only boundary output.
5. [T4] Update tests to distinguish wiring checks from quality proof.
6. [T4] Run `bash tests/test-product-split-benchmark-contract.sh` and `bash tests/test-product-eval-contract.sh`; expected result after implementation: PASS.

### Task 5: Capability Contract Parity [T5]

Files:
- Create: `tests/test-product-inherited-capability-parity.sh`
- Create: `shared/skills/product-director/references/product-thinking-contract.md`
- Create: `shared/skills/product-manager/references/review-orchestration-contract.md`
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/product-manager/references/templates/product-manager-review-template.md`
- Modify: `tests/test-product-template-purity-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T5] Write a failing parity contract for current capability contracts: product thinking framework, warning signals, TeamCreate review team, `3 视角×max10轮`, confirmation round, convergence stop rules, `Issue Count`, `HIS-*`, and stable issue ledger.
2. [T5] Run `bash tests/test-product-inherited-capability-parity.sh`; expected result before implementation: FAIL on missing reference contracts or missing SKILL-to-contract links.
3. [T5] Move product thinking framework and warning signals into `product-director/references/product-thinking-contract.md`, and keep `/product-director/SKILL.md` as a contract router.
4. [T5] Move TeamCreate review orchestration into `product-manager/references/review-orchestration-contract.md`, and layer split-specific checks (`R13`, `PR-C1`, Director lock) inside the contract.
5. [T5] Expand `product-manager-review-template.md` to carry review evidence fields while keeping flow rules in SKILL / gate / contract.
6. [T5] Update related contract tests so template purity means “no process noise in brief/phase templates,” while reference contracts preserve capability detail.
7. [T5] Run `bash tests/test-product-inherited-capability-parity.sh`, `bash tests/test-product-template-purity-contract.sh`, `bash tests/test-product-role-split-contract.sh`, and `bash tests/test-skill-output-and-gate-contract.sh`; expected result after implementation: PASS.

### Task 6: Output Contract Routing [T6]

Files:
- Create: `tests/test-product-output-contract-reference.sh`
- Create: `shared/skills/product-director/references/output-contract.md`
- Create: `shared/skills/product-manager/references/output-contract.md`
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `tests/test-product-stability-guidance-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T6] Write a failing output contract test requiring both `## 产出` sections to route to `references/output-contract.md` instead of listing artifact paths, templates, lock files, or review details inline.
2. [T6] Run `bash tests/test-product-output-contract-reference.sh`; expected result before implementation: FAIL on missing output contracts or inline output details in `SKILL.md`.
3. [T6] Add `product-director/references/output-contract.md` with Director artifact paths, templates, lock files, `contracts/product-artifacts.yaml` anchors, and write boundaries.
4. [T6] Add `product-manager/references/output-contract.md` with Manager artifact paths, templates, review evidence, `contracts/product-artifacts.yaml` anchors, and write boundaries.
5. [T6] Replace both `SKILL.md` `## 产出` sections with output-contract routing only.
6. [T6] Update related contract tests so output detail is verified in output contracts, not in runtime SKILL bodies.
7. [T6] Run `bash tests/test-product-output-contract-reference.sh`, product role/stability contracts, and `bash tests/test-skill-output-and-gate-contract.sh`; expected result after implementation: PASS.

### Task 7: Context Signal Quality Gate [T7]

Files:
- Create: `tests/test-product-context-signal-quality.sh`
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-director/references/product-thinking-contract.md`
- Modify: `shared/skills/product-director/references/output-contract.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/product-manager/references/review-orchestration-contract.md`
- Modify: `shared/skills/product-manager/references/output-contract.md`
- Modify: `shared/skills/product-manager/references/prd-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/architect-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/tester-reviewer-prompt.md`

1. [T7] Write a failing context-signal contract that rejects runtime meta prose such as `SKILL.md 只保留...`, `本契约定义...`, `## 适用范围`, source annotations, and abstract “沿用标准” output shells.
2. [T7] Run `bash tests/test-product-context-signal-quality.sh`; expected result before implementation: FAIL on runtime noise, missing D-S1 explicit agents, missing split flow contract, and insufficient standalone reviewer output schema.
3. [T7] Remove author-facing contract explanations from product runtime entry points and reference contracts.
4. [T7] Restore D-S1 as explicit `Context Scan Agent` + `Problem Hypothesis Agent` scanning, while keeping final conclusions blocked until user confirmation.
5. [T7] Add minimal split `digraph product_flow` contracts for Director and Manager gate/backtracking paths.
6. [T7] Expand product reviewer prompts so each prompt independently carries `Findings`, `承接目标`, stable issue ids, and Verdict Rules.
7. [T7] Run `bash tests/test-product-context-signal-quality.sh` plus product parity, output, role-split, and template purity tests; expected result after implementation: PASS.

### Task 8: Ten-Round Context Signal Audit Loop [T8]

Files:
- Create: `docs/product-context-signal-cleanup-20260416/context-signal-audit-10-rounds.md`
- Modify: `tests/test-product-context-signal-quality.sh`
- Modify: `docs/product-context-signal-cleanup-20260416/design.md`
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/product-manager/references/review-orchestration-contract.md`

1. [T8] Extend the context-signal test so it fails when runtime files contain `split playbook` narration, when flow graphs come after step tables, when `product-manager-review.md` is used before definition, or when fewer than 10 audit rounds are recorded.
2. [T8] Run `bash tests/test-product-context-signal-quality.sh`; expected result before implementation: FAIL on the three user-reported issues and missing audit loop record.
3. [T8] Remove `split playbook 第 X 段` narration from product runtime skills while retaining actionable role boundaries.
4. [T8] Move each `digraph product_flow` before the step table so the state machine is consumed before procedural detail.
5. [T8] Add `product-manager-review.md 产物契约` before review orchestration rules and replace ambiguous “维护 product-manager-review.md” wording with write rules.
6. [T8] Record at least 10 audit rounds, each mapping an observed risk to action and proving gate.
7. [T8] Keep `design.md` at the principle level and move process proof into tasks, plan, and audit evidence.
8. [T8] Clarify review ownership: M-S8 review is initiated and converged by `/product-manager`; downstream skills consume only delivery status, unresolved FAIL, WARN handoff targets, and design decisions.
9. [T8] Run `bash tests/test-product-context-signal-quality.sh`; expected result after implementation: PASS.

### Task 9: Downstream Review-Detail Boundary [T9]

Files:
- Modify: `tests/test-product-context-signal-quality.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/references/templates/design-template.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `docs/product-context-signal-cleanup-20260416/tasks.md`
- Modify: `docs/product-context-signal-cleanup-20260416/context-signal-audit-10-rounds.md`

1. [T9] Add failing assertions that `/design`, design template, and `/tech-lead` cannot consume product review detail or use previous review results as a shortcut.
2. [T9] Run `bash tests/test-product-context-signal-quality.sh`; expected result before implementation: FAIL on downstream review-detail leakage.
3. [T9] Remove `product-manager-review.md` from `/design` and `/tech-lead` runtime input lists.
4. [T9] Replace design template `## 上游审查承接` with `## 产品交付承接` and keep only explicit handoff rows.
5. [T9] State the consumption boundary: downstream skills consume frozen artifacts and explicit handoff fields, not product review process.
6. [T9] Run `bash tests/test-product-context-signal-quality.sh`; expected result after implementation: PASS.

### Full Verification

1. [T1] Run `bash tests/test-product-template-purity-contract.sh`.
2. [T2] Run `bash tests/test-product-artifact-contract.sh`.
3. [T1] Run `bash tests/test-product-role-split-contract.sh`.
4. [T3] Run `bash tests/test-product-stability-guidance-contract.sh`.
5. [T4] Run `bash tests/test-product-eval-contract.sh`.
6. [T4] Run `bash tests/test-product-split-benchmark-contract.sh`.
7. [T2] Run `bash tests/test-skill-output-and-gate-contract.sh`.
8. [T5] Run `bash tests/test-product-inherited-capability-parity.sh`.
9. [T6] Run `bash tests/test-product-output-contract-reference.sh`.
10. [T7] Run `bash tests/test-product-context-signal-quality.sh`.
11. [T8] Verify `docs/product-context-signal-cleanup-20260416/context-signal-audit-10-rounds.md` contains at least 10 audit rounds.
12. [T2] Run `bash tests/test-runtime-integrity.sh`.
13. [T2] Run `bash tests/run-all.sh`.
14. [T1] Run `git diff --check`.
15. [T9] Verify `/design` and `/tech-lead` have no product `product-manager-review.md` runtime dependency.
