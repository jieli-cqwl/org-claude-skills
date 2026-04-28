# Test Design Governance Design

## Problem Statement

`test-design` is already positioned between `design` and `tech-lead` in the standard chain, and its `test-cases.json` is consumed by `tech-lead`, `delivery-owner`, `developer`, and `qa`. That makes it a shared planning and verification contract, not a local testing note.

The current role definition and contract are not strong enough for that responsibility. The skill body emphasizes AC coverage, exclusion tests, design gaps, and QA handoff, but it does not make the full test-analysis layer explicit: test objectives, test scope, test strategy, test flow, risk model, environment assumptions, and data assumptions. At the same time, the canonical `test-cases` schema is thin enough that a case with only `case_id` and `title` can satisfy the shape contract, even though downstream roles need executable preconditions, actions, expected results, assertions, and traceability.

This creates a trust gap. Humans expect `test-design` to behave like a real test analyst and test designer, while the machine contract still allows shallow test artifacts. The redesign must close that gap without turning `test-design` into a second `design`, a `tech-lead` planning role, or a premature QA execution owner.

## Goals And Success Criteria

The redesign defines `test-design` as the pre-development test analysis and test design owner. It turns product truth and architecture design into a canonical test obligation source before planning starts.

Success means:

- `test-design` has a precise role boundary: it owns test analysis, test design, testability gaps, and QA obligation freezing; it does not own architecture, task planning, implementation, QA execution, release recommendation, or delivery sign-off.
- Product is a first-class source of truth. Test artifacts trace back to `brief.json`, `phase-prd.json`, `UNIT-*.json`, and `design.json`, not only to design refs.
- `test-cases.json` can carry executable test intent: objectives, scope, strategy, flow, risks, cases, assertions, evidence expectations, and QA handoff obligations.
- Gaps are typed instead of collapsed into a generic design problem: product ambiguity, missing design承接, scope drift, product/design conflict, testability gap, and equivalence gap have different owners and recovery actions.
- Downstream consumers can rely on the artifact mechanically. Schema, template, semantic validator, completion gate, fixtures, and evals all enforce the same contract.
- Existing standard-chain boundaries remain intact: `qa` executes and judges quality after code review; `test-design` defines what must be verified and when browser execution is mandatory.

## Approach

The target architecture keeps the existing chain order:

```text
product-director -> product-manager -> design -> test-design -> tech-lead -> delivery-owner -> developer / verify / review / qa
```

`test-design` becomes a contract-grade translation layer from product and design into test obligations:

```text
product intent / UNIT / AC / exclusions / risk
  + design interfaces / data / permissions / errors / NFR / rollout constraints
  -> test analysis
  -> executable test cases
  -> typed gap report
  -> QA handoff obligations
```

The redesign adds a `test_analysis` section to `test-cases.json`. This section is structured JSON, not prose. It captures:

- `objectives`: what this UNIT or phase must prove.
- `in_scope`: behavior, paths, roles, quality areas, and exclusions that must be verified.
- `out_of_scope`: behavior explicitly not verified in this phase or UNIT.
- `risk_model`: product, technical, data, permission, UX, rollout, and regression risks that shape test depth.
- `strategy_by_quality_area`: functional, negative, boundary, permission, data, integration, contract, security, performance, UX, regression, and exploratory strategy.
- `test_flow`: user or system flow checkpoints that tests must cover.
- `environment_assumptions`: runtime, service, browser, external dependency, and configuration assumptions.
- `data_assumptions`: seed data, migration state, boundary data, sensitive data, and cleanup assumptions.

The existing `test_cases` array is strengthened rather than replaced. Each case becomes executable enough for `developer` self-test, `verify` inspection, and `qa` execution planning. A valid case includes stable refs, case type, priority, preconditions, test data, steps or action, expected result, assertion target, execution mode, automation level, evidence expectation, and owner stage.

The existing `design_gap_report` field remains the canonical gap container for compatibility. Its content is expanded with typed gap rows. The field name does not change in this phase because existing consumers already know it. A later schema version may rename it only with explicit migration and compatibility handling.

`qa_handoff_contract` is retained but narrowed. It freezes the obligations QA must not guess: obligation, trigger source, requiredness, execution mode, browser requirement, evidence expectation, and skip rule. It does not define release readiness, final sign-off, or QA's independent release recommendation.

## Role Boundary

`test-design` owns:

- Test objective and test scope derivation from product and design.
- AC positive, negative, boundary, and exclusion verification obligations.
- Risk-based depth decisions for functional and specialty tests.
- Traceability from product refs and design refs to test obligations.
- Typed product/design/testability gap detection before planning.
- QA handoff obligations, including `browser_required` triggers and evidence expectations.

`test-design` does not own:

- Architecture decisions, interface design, migration design, or rollback design.
- Task decomposition, batch ordering, proving command design, or execution planning.
- Code implementation, TDD execution, or self-test evidence creation.
- QA execution, defect triage, release recommendation, or residual risk acceptance.
- Delivery sign-off, business risk acceptance, or user decision import.

This boundary preserves whole-team quality while giving one role authority over the shared test obligation contract.

## Canonical Artifact Design

The target `test-cases.json` keeps existing top-level fields and adds structured obligations where current shape is too thin.

Existing fields retained:

- `ac_coverage_matrix`
- `equivalence_matrix`
- `test_cases`
- `qa_handoff_contract`
- `unit_coverage_view`
- `design_gap_report`
- `special_test_triggers`
- `review_conclusion`
- `issue_ledger`

Fields added or strengthened:

- `test_analysis`
- `traceability_matrix`
- `test_cases[].product_refs`
- `test_cases[].design_refs`
- `test_cases[].case_type`
- `test_cases[].priority`
- `test_cases[].preconditions`
- `test_cases[].test_data`
- `test_cases[].steps`
- `test_cases[].expected_result`
- `test_cases[].assertion_target`
- `test_cases[].execution_mode`
- `test_cases[].automation_level`
- `test_cases[].evidence_expectation`
- `design_gap_report.gaps[].gap_type`
- `design_gap_report.gaps[].blocking_refs`
- `design_gap_report.gaps[].owner`
- `design_gap_report.gaps[].next_action`

`traceability_matrix` is the cross-source map. It connects:

- `product_ref`: source in `brief.json`, `phase-prd.json`, or `UNIT-*.json`.
- `unit_ref`: UNIT source.
- `ac_ref`: AC source.
- `exclusion_ref`: exclusion or non-goal source when applicable.
- `risk_ref`: product or design risk source when applicable.
- `design_ref`: design source when applicable.
- `test_case_refs`: cases proving or challenging the source.
- `gap_refs`: typed gaps when no valid test case can be derived.

## Ref Grammar

The redesign adds product-side refs instead of overloading design refs.

Supported source refs are:

```text
brief.json#<dotted-path>
phase-prd.json#<dotted-path>
UNIT-{N}.json#<dotted-path>
design.json#<dotted-path>
```

All refs must resolve against the canonical artifact in the same feature and phase context. Markdown projections and oral explanations cannot satisfy product or design source refs.

`design.json#...` remains valid and keeps current validator behavior. Product refs are added through semantic validation so product-first traceability becomes mechanically enforceable.

## Gap Vocabulary

`design_gap_report.gaps[].gap_type` uses a closed vocabulary:

- `PRODUCT_GAP`: product intent, AC, scope, non-goal, or expected behavior is unclear.
- `DESIGN_GAP`: product requirement exists but design lacks a valid承接 point.
- `SCOPE_DRIFT`: design introduces behavior or verification obligations not grounded in product scope.
- `TRACE_CONFLICT`: product and design conflict on behavior, constraint, state, data, or ownership.
- `TESTABILITY_GAP`: behavior may be specified but cannot be verified because observability, control point, data setup, or evidence path is missing.
- `EQ_GAP`: equivalence or invariant mapping cannot be proven.

Each gap has one owner and one recovery action. Product gaps route to `product-manager` or `product-director` depending on the source. Design, scope drift, trace conflict, testability, and equivalence gaps route to the owner whose canonical artifact must change or clarify. Unowned gaps are invalid.

## SOP

The target `test-design` protocol has seven states.

`Input Check`: Read `brief.json`, `phase-prd.json`, `UNIT-*.json`, and `design.json`. Missing canonical inputs block the run. Markdown or oral context is only a clue and cannot replace canonical input.

`Product Understanding`: Extract product goals, users, flows, UNIT closure, AC, exclusions, non-goals, risk, priority, and verification hints. Produce product-side refs for every test obligation or gap.

`Design承接 Analysis`: Extract interfaces, data architecture, permissions, error paths, quality attributes, rollout constraints, verification mapping, rollback, migration, and cross-cutting concerns. Produce design-side refs where behavior has a valid technical承接 point.

`Test Analysis`: Derive objectives, scope, strategy, flow, risk model, environment assumptions, and data assumptions. This state decides what must be tested and why before generating cases.

`Test Case Design`: Generate positive, negative, boundary, exclusion, and specialty cases. Every AC has positive, negative, and boundary coverage. Every exclusion has a non-occurrence verification. Cases are executable enough for downstream consumers.

`Gap Judgment`: Classify unresolved issues as product, design, scope drift, trace conflict, testability, or equivalence gaps. Blocking gaps stop handoff to `tech-lead` until the owning upstream artifact changes or the user explicitly directs a valid recovery path.

`Handoff And Review`: Freeze QA obligations, run cross-functional review, update review conclusion and issue ledger, and run the completion validator. Completion requires semantic and schema evidence, not only a readable report.

## Phase-Level Aggregation

The current artifact path is UNIT-level: `phase-{N}/unit-{N}/test-cases.json`. That remains the primary output in this phase.

Cross-UNIT journeys and phase-level regression obligations are represented through stable aggregation rules before adding a new phase artifact. The rule is:

- Each UNIT artifact may declare journey participation and regression obligations through `traceability_matrix` and `qa_handoff_contract`.
- `qa` may consume multiple `test_cases_refs`, but it must not invent missing obligations.
- If a journey cannot be represented by composing UNIT artifacts without ambiguity, `test-design` emits a typed `TESTABILITY_GAP` or `TRACE_CONFLICT` instead of silently pushing aggregation to QA.

A future `phase-test-design.json` artifact is a valid later option, but it is not introduced in this redesign unless the implementation proves UNIT composition is insufficient.

## Downstream Impact

`tech-lead` consumes test obligations when building `plan.json` and `tasks.json`. It should treat `test_cases` and `traceability_matrix` as planning constraints and execution basis refs. Unresolved blocking gaps prevent planning.

`developer` consumes executable case fields for TDD orientation and self-test expectations. The developer does not redefine expected behavior and does not downgrade `browser_required` obligations.

`verify` may use refs from `test-cases.json` to check AC and evidence closure. It does not execute QA stages, but it can confirm that developer evidence maps to required obligations.

`qa` consumes `qa_handoff_contract` as the trigger source for execution mode, browser requirement, and evidence expectations. QA still owns real execution, defects, release recommendation, residual risk, and uncovered boundary.

`delivery-owner` consumes test obligations and QA output for delivery state and signoff package readiness. It does not rewrite test-design obligations.

`consistency-audit` can compare product refs, design refs, plan refs, task refs, developer evidence, verify results, and QA results against the strengthened test contract.

## Alternatives Considered

### Option A: Rewrite only `SKILL.md`

This is fast and improves wording, but it does not change machine behavior. Schema and gates would still allow shallow cases. This option is rejected because it creates a pleasant-looking empty shell.

### Option B: Upgrade `SKILL.md`, canonical contract, gates, fixtures, and evals together

This is the chosen option. It is larger, but it aligns role behavior with machine-verifiable artifacts. It follows the project quality standard that JSON artifacts, schemas, semantic validators, and gates carry machine truth.

### Option C: Split `test-analysis` and `test-design`

This is conceptually clean but adds a new standard-chain role and new handoff surface. The current chain can express both analysis and design in one artifact. Splitting is not justified until pilot evidence shows one role cannot stay reliable.

### Option D: Merge `test-design` into `tech-lead`

This reduces phase count, but it makes the planning owner also define the test obligation source. That weakens the independent testability perspective and may hide design gaps inside plan work. This remains the least-bad fallback only if future pilots prove the independent role adds no measurable value.

## Change Scope

The implementation surface includes:

- `shared/skills/test-design/SKILL.md`
- `shared/skills/test-design/references/*` where methodology or reviewer prompts must reflect the new role boundary
- `shared/skills/test-design/projections/test-cases-template.md`
- `contracts/canonical/schemas/planning/test-cases.schema.json`
- `contracts/canonical/templates/planning/test-cases.template.json`
- `contracts/standard-chain.yaml`
- `tools/community/canonical_test_case_rules.py`
- `shared/skills/test-design/scripts/completion_check.sh`
- Standard-chain phase validators or readiness gates that consume `test-cases.json`
- Fixtures under `tests/fixtures/standard-chain-*`
- Contract and skill tests related to test-design governance
- `shared/skills/test-design/evals/evals.json`

The implementation should not alter QA release recommendation semantics, delivery signoff semantics, product-manager authority, or design authority except where ref validation must point back to those owners.

## Invariants

Product remains a first-class source of truth for test obligations.

`design.json` remains the technical承接 source. Test-design may report design problems but may not invent design facts.

`test-cases.json` remains the canonical test-design output. Markdown projections remain human views and cannot override JSON.

`design_gap_report` remains the compatibility field name during this redesign.

Blocking gaps prevent handoff to `tech-lead` unless an owning upstream artifact is corrected or a valid user-directed recovery path is captured.

QA remains independent. `test-design` may require browser execution and evidence expectations, but QA owns real execution, defects, release recommendation, and residual risk.

Compatibility is preferred where possible. Existing field names are retained and strengthened before introducing new top-level artifacts.

## Contract-Grade Preflight

### C1 Current Vs Target

Current HEAD has `test-cases.schema.json` requiring only shallow `test_cases[]` fields. The target contract strengthens the same artifact without renaming it. The migration phase is a schema-compatible strengthening phase if existing fixtures can be updated in one cutover; otherwise it must introduce a schema version bump and fixture migration path.

Cutover owner is the standard-chain contract owner. Skill text must not claim new guarantees before schema, template, validator, and fixtures enforce them.

### C2 Source Of Truth Matrix

Product intent, AC, scope, exclusions, and risk are authoritative in `brief.json`, `phase-prd.json`, and `UNIT-*.json`.

Technical承接, interface, data, permission, NFR, rollout, migration, and rollback facts are authoritative in `design.json`.

Test objectives, test scope, test strategy, executable cases, typed gaps, and QA obligation triggers are authoritative in `test-cases.json`.

QA execution evidence, release recommendation, residual risk, and uncovered boundary are authoritative in `qa-result.json`.

Delivery status and signoff readiness are authoritative in delivery-owner artifacts.

When facts conflict, upstream domain owners win for their domain, and `test-design` records a typed gap instead of resolving the conflict by invention.

### C3 Closed Vocabulary And Grammar

The target schema must close ref grammar, gap type vocabulary, execution mode, automation level, case type, requiredness, and review status. The validator must reject unknown gap types, unresolved refs, cases without product refs, cases without executable assertions, and QA obligations that lack trigger source or evidence expectation.

### C4 Ownership And Waiver

`product-manager` owns product gaps inside Phase/UNIT detail. `product-director` owns Director baseline gaps. `design` owns design承接 and testability gaps rooted in architecture or technical observability. `test-design` owns malformed test-analysis or test-case artifacts. `qa` owns execution gaps after handoff. `delivery-owner` owns delivery orchestration gaps.

Waiver of a blocking test-design gap is not a local skill decision. It requires user or owning-role decision recorded in the appropriate canonical artifact before handoff continues.

### C5 Failure Contract

Missing canonical inputs, unresolved refs, shallow cases, unknown gap types, unresolved blocking gaps, and malformed QA handoff obligations are blocking failures. The failure must name the owner and recovery action. The agent may not continue to `tech-lead` by treating incomplete test design as a warning.

### C6 Implementation Surface

The cutover order is contract first, behavior second:

1. Schema/template and shared validators define the target shape.
2. Fixtures and negative probes prove the shape.
3. Completion gate enforces semantic behavior.
4. Skill text and projections describe only behavior already backed by contract or validator.
5. Evals verify agent behavior across positive, negative, conflict, and cross-UNIT scenarios.

### C7 Proving Categories

Success is proved by schema validation, semantic validator tests, completion gate tests, fixture validation, skill governance tests, and skill evals. Human review can judge role clarity, but it cannot replace mechanical proof for canonical JSON shape and ref resolution.

### C8 Existing Contract Diff

The implementation must diff and align existing contracts that already govern this area:

- `contracts/standard-chain.yaml`
- `contracts/canonical/schemas/planning/test-cases.schema.json`
- `contracts/canonical/templates/planning/test-cases.template.json`
- `shared/skills/test-design/SKILL.md`
- `shared/skills/test-design/projections/test-cases-template.md`
- `shared/skills/test-design/scripts/completion_check.sh`
- `tools/community/canonical_test_case_rules.py`
- `shared/skills/qa/SKILL.md`
- Standard-chain readiness and phase validation tests

Any mismatch between projection vocabulary and schema vocabulary is treated as contract drift.

## Risks

The main risk is over-expansion. If the redesign asks `test-design` to own QA execution or release readiness, it will recreate the role confusion it is meant to fix. The mitigation is to narrow QA handoff to obligations, triggers, execution mode, and evidence expectations.

The second risk is contract breakage. Strengthening the schema will break existing fixtures and possibly historical pilots. The mitigation is to update active fixtures and tests in the same implementation and treat archive content as non-authoritative history.

The third risk is schema bloat. If every testing concept becomes required, simple UNITs will become heavy. The mitigation is to require the minimal executable core and allow optional specialty detail only when triggered by risk, quality attributes, or design concerns.

The fourth risk is ref grammar complexity. Product and design refs must be enforceable, or the traceability matrix becomes decorative. The mitigation is to implement semantic ref resolution before relying on the new fields.

The fifth risk is phase-level ambiguity. UNIT artifacts may be insufficient for multi-UNIT journeys. The mitigation is to define composition rules first and introduce a phase-level artifact only if composition proves ambiguous in pilot evidence.

## Validation Strategy

Validation must prove both artifact quality and agent behavior.

Mechanical validation includes:

- Schema rejects shallow `test_cases[]` with only title.
- Semantic validator rejects unresolved product refs and design refs.
- Semantic validator rejects unknown gap types and unowned gaps.
- Completion gate rejects missing `test_analysis`.
- Completion gate rejects QA handoff obligations without trigger source, execution mode, or evidence expectation.
- Fixture validation passes after active fixtures are upgraded.

Behavioral evals include:

- A normal UNIT where `test-design` outputs objectives, scope, strategy, executable cases, and QA obligations.
- A product ambiguity case that must produce `PRODUCT_GAP`.
- A design-missing承接 case that must produce `DESIGN_GAP`.
- A design-extra-scope case that must produce `SCOPE_DRIFT`.
- A product/design conflict case that must produce `TRACE_CONFLICT`.
- A case with no observability or setup path that must produce `TESTABILITY_GAP`.
- A cross-UNIT journey case that must either compose refs cleanly or block with a typed gap.

## Open Decisions

The initial implementation should keep one UNIT-level `test-cases.json` artifact and add composition rules for cross-UNIT obligations. A dedicated phase-level test-design artifact is deferred until pilot evidence proves composition insufficient.

The schema versioning mode depends on fixture impact. If all active fixtures can be migrated in one implementation, the target contract can be introduced as a direct strengthening. If not, the implementation must introduce an explicit schema version transition and compatibility validator.

The final gap vocabulary spelling should use JSON enum style with underscores, while projections may render human-friendly labels derived from those enums. The schema vocabulary is authoritative.
