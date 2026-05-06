# skill-refiner tech-lead planning-owner shadow transcript

Requirement: pressure-test the updated skill-refiner SOP on a real `tech-lead` optimization demand before team rollout.

### SR-S1

Target located: shared/skills/tech-lead. Quality dimensions: S2, S3, S4, S6, S7, E4. Evidence: tech-lead already has gates, references, templates, schemas, completion gate, and planning-owner wording.

### SR-S2

real_scenario: The user wants tech-lead to act as the standard-chain technical planning owner after design/test-design and before delivery-owner/developer/verify/qa.
business_constraint: This is a shadow run; it must not modify shared/skills/tech-lead production files or install runtime copies.
expected_outcome_signal: SR-S2 stays as fielded intake facts; SR-S3 and SR-R define professional workflow, success boundary, candidate strategy, and verification later.
observed_pain: User feedback says tech-lead feels rule-heavy and field-heavy, while the main planning workflow does not naturally pull an Agent through the real planning responsibility.
protected_capability_candidate: Preserve tech-lead as the planning owner that turns confirmed design and test obligations into executable, traceable, evidence-backed plans.
entry_point_candidate: Responsibility and Flow are candidate entry points; exact problem cards, ring strategy, and verification stay deferred to SR-S3 and SR-R.
located_carrier: shared/skills/tech-lead/SKILL.md plus its references, schemas, templates, evals, scripts, and tests.
open_questions: No night-time user confirmation is requested; Codex owns this shadow decision, while production edits remain excluded until a clean SR-F1 execution window.

### SR-S3

Current judgment: the professional domain is implementation planning ownership, not design creation, product scoping, execution kickoff, or QA sign-off.
Best-practice target: tech-lead should turn already-confirmed product, design, and test artifacts into an executable rollout plan that downstream agents can follow literally.
Confirmation: accepted for this shadow run.

### SR-S4

Consumers: delivery-owner consumes plan/tasks; developer consumes task evidence fields; verify/qa consume proving commands and acceptance evidence; scripts and schemas consume deterministic plan contracts.
Candidate signal: SKILL.md contains strong hard gates and contracts, but the main flow still reads more like a rules ledger than an ergonomic planning-owner path.

### SR-R1

Trigger confirmed: tech-lead should trigger only after brief, phase PRD, UNITs, design, and test-cases are frozen enough to plan implementation; missing upstream artifacts route back instead of being solved here.

### SR-R2

Responsibility confirmed: own design review for implementation readiness, task decomposition, traceability, dependency planning, and plan freeze; do not own product scope, design decisions, code execution, or final release acceptance.

### SR-R3

Input confirmed: required inputs are frozen product artifacts, design coverage, impact scope, planning constraints, test analysis, traceability matrix, QA handoff, and cross-unit obligations.

### SR-R4

Flow confirmed: read canonical inputs, review design readiness, classify planning uncertainty, establish coverage chain, split executable tasks, plan order and parallelism, run cross-functional review, then request user confirmation.

### SR-R5

Output confirmed: plan.json and tasks.json are the machine truth; human projections are read-only views after JSON freeze.

### SR-R6

Resource confirmed: keep main SOP short; references carry design review, planning modes, decomposition, and reviewer prompts; schemas/templates/scripts carry deterministic contracts.

### SR-R7

Determinism confirmed: schema, completion_check.sh, and validate_standard_chain_phase.py should enforce required fields, traceability, user confirmation, and no mock-only acceptance.

### SR-R8

Eval confirmed: dogfood and contract tests must catch planning-owner drift, upstream responsibility leakage, and fake completion confidence.

### SR-R9

Cleanup confirmed: remove or relocate analysis labels, tool-boundary explanations, and duplicated schema prose when they do not directly drive execution.

### SR-R10

Runtime confirmed: runtime copy should be synced only in a clean install window, not from a dirty worktree with unrelated standard-chain/test-design changes.

### SR-F1

整体策略确认: final_operation_candidate=optimize; execution_scope=shadow evidence only.
No shared/skills/tech-lead production file was modified in this shadow run.

### SR-E1

Executed once: wrote shadow transcript, shadow assessment, and regression tests only.

### SR-V1

Validation target: tech-lead shadow flow test, SR-S2 fielded dogfood test, and full skill-refiner scoped regression.
