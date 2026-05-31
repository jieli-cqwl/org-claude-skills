# Standard-chain Product-to-delivery Production Readiness Design

## Objective

Make the `product-director -> product-manager -> tech-lead baseline -> delivery-owner -> signoff` chain ready for daily team use.

Production-ready means a real demand can enter the chain and each role can decide what to read, what to write, when to stop, how to recover, and whether final signoff is allowed by relying on structured artifacts, deterministic contracts, scripts, gates, and state. The model may perform semantic judgment and artifact generation, but it must not be responsible for guessing fields, filling flow gaps, bypassing failure states, or deciding signoff from narrative context.

Previous reports, prompts, diffs, and pilot artifacts are evidence inputs only. They are not the source of truth for this task's goal or success criteria.

## Scope

This task fixes chain contracts and delivery-owner consumability. It does not redesign every role's internal method.

In scope:

- Product baseline contracts produced or refined by `product-director` and `product-manager`.
- Delivery intake contracts consumed by `delivery-owner`.
- Runtime evidence contracts consumed by `delivery-owner`.
- Delivery control and closeout artifacts.
- Active schema, template, skill, script, test, fixture, runtime contract, and gate-plan surfaces that affect this chain.
- Pilot happy paths and negative cases proving the chain can be reused.
- Active historical noise cleanup where old fields, old concepts, wrong paths, or prose-only contracts still influence current execution.

Out of scope:

- Rewriting the internal method of `tech-lead`, `developer`, `verify`, `review`, `qa`, or `consistency-auditor`.
- Running a full real-business code E2E implementation.
- Continuing the separate test-system cleanup task.
- Editing `docs/archive/**`, `tools/eval/results/**`, raw transcripts, or historical outputs only to make searches clean.
- Broad repo cleanup unrelated to this chain.

## Artifact Layers

### Baseline Inputs

These define the demand, product model, task baseline, design/test obligations, and executable task set before delivery-owner dispatches work:

- `brief.json`
- `phase-prd.json`
- `UNIT-*.json`
- `design.json`
- `test-cases.json`
- `plan.json`
- `tasks.json`

Delivery-owner DO-S1 may require these baseline inputs. DO-S1 must not require future runtime evidence such as developer, verify, review, QA, or consistency results.

### Runtime Evidence

These prove execution, verification, review, QA, consistency, and fix-loop outcomes after delivery starts:

- `developer-report.json`
- `verify-result.json`
- `code-review-result.json`
- `qa-result.json`
- `consistency-audit-result.json`
- `fix-result.json` when a fix loop is triggered

This task defines how delivery-owner consumes these artifacts for dispatch decisions, QA admission, recovery, and signoff. It does not rewrite the producing roles' internal execution method unless their output contract cannot support delivery-owner signoff.

### Control And Closeout

These define active evidence truth, runtime state, human decisions, scope changes, and final signoff:

- `artifact-registry.json`
- `delivery-state.json`
- `signoff-package.json`
- `user-decision.json`
- `target-change.json`

`artifact-registry.json` is not an auxiliary file. It is the active truth for runtime evidence freshness, active-for-consumption status, lifecycle state, and stale or superseded checks.

## Contract Closure Rule

Every active field in the scoped artifacts must be classified.

Allowed decisions:

- `keep`: the field has a real consumer and drives a gate, handoff, transform, recovery, freshness check, evidence check, state transition, or user decision.
- `delete`: the field has no active consumer, duplicates another field, represents an old concept, only explains background, or increases active context noise.
- `derive`: the value should be computed from registry entries, digests, canonical refs, schema, or another source of truth rather than hand-written.
- `move`: the field is needed but belongs in a different artifact or path.
- `rename`: the semantics are needed but the current name misleads producers or consumers.
- `needs-human-decision`: evidence is insufficient to make a safe decision.

Each `keep` field must have:

- JSONPath.
- Owner.
- Consumer.
- Write stage.
- Read stage.
- Purpose.
- Source of truth.
- Verification method.
- Failure behavior.
- Recovery owner.

Each non-`keep` field must have a decision reason and an active cleanup surface. Cleanup surfaces include schema, template, skill instruction, script, test, fixture, runtime contract, gate plan, and active docs. Historical archives are not edited only for search cleanliness.

The classification must be captured before implementation in:

- `docs/superpowers/specs/2026-05-31--standard-chain-product-to-delivery-production-readiness--field-decision-matrix.md`

The matrix is the implementation input, not a retrospective report. Minimum columns:

- Artifact.
- JSONPath.
- Decision.
- Owner.
- Consumer.
- Write stage.
- Read stage.
- Purpose.
- Source of truth.
- Verification method.
- Failure behavior.
- Recovery owner.
- Cleanup surface.
- Decision evidence.

Matrix acceptance rules:

- A `keep` row is invalid unless every minimum column except cleanup surface is complete and the verification method names a deterministic schema, script, contract test, fixture test, or gate check.
- A non-`keep` row is invalid unless cleanup surface and decision evidence are complete.
- A `derive` row must name the source value and the deterministic derivation point.
- A `move` or `rename` row must name the old path, new path, migration surface, and consumer update surface.
- In-scope `needs-human-decision` rows block implementation until resolved to another decision. If the item is out of scope, the row must state the scope reason and no active schema, template, script, fixture, or gate may depend on it.

## Chain Invariants

### Director Baseline Lock

Director-owned baseline fields are protected by `director_confirmation.locked_fields` and `director_confirmation.locked_field_digest`.

Product-manager and downstream roles may refine their owned fields. They must not silently change Director locked fields. If a locked field must change, the chain must route through `target-change` or back to product-director for a fresh baseline.

### PM Refinement Boundary

Product-manager owns WHAT-level product detail and delivery confirmation fields. PM may add evidence, flows, features, risks, units, AC, verification plans, review conclusions, issue ledgers, and delivery confirmation within its contract.

PM must not turn downstream HOW decisions into product facts, and must not extend the field model outside schema, template, and contract ownership.

### Delivery-owner Stage Boundary

Delivery-owner owns execution control, state, dispatch readiness, runtime evidence consumption, user pause packages, and signoff preparation.

DO-S1 is baseline intake and baseline audit readiness. Later stages consume runtime evidence:

- DO-S5 consumes developer and verify evidence.
- DO-S6 consumes code-review evidence.
- DO-S7 consumes QA and fix-loop evidence.
- DO-S8 consumes consistency audit evidence and prepares signoff.

### Signoff Evidence Boundary

`signoff-package.runtime_evidence_matrix` must cover all required runtime evidence types and task-level entries. Each entry must contain canonical ref, producer, status, freshness basis, active registry proof, and stale or superseded check.

Narrative summaries can explain evidence. They cannot replace canonical runtime evidence refs.

### Decision Boundary

`user-decision.json` records signoff, authorization, waiver, or risk acceptance.

`target-change.json` records changes to scope, AC, goal, tasks, design target, or other baseline-changing facts. A target change invalidates affected evidence and requires fresh proof before signoff.

These two artifacts must not be mixed.

### State Boundary

`READY_FOR_COMMIT` means signoff package and commit handoff are prepared. It is not delivery completion.

`DELIVERED` requires a commit result or equivalent delivery result to be recorded and linked.

## Failure Modes That Must Block

The chain must block, name the owner, explain the reason, and provide a recovery condition for these cases:

- Missing required baseline input.
- Director confirmation missing or failed.
- Director lock digest drift.
- Mixed baseline or tasks version.
- `plan.json` and `tasks.json` version mismatch.
- Tasks not frozen or not confirmed.
- Task acceptance refs missing or not traceable.
- QA handoff obligations missing or not covered.
- Developer or verify evidence missing for an in-scope task.
- Code review missing, stale, or blocking.
- QA result missing, not PASS, or obligation coverage incomplete.
- Consistency audit required owner action not consumed.
- Runtime evidence exists on disk but is not active in the registry.
- Registry entry lifecycle is not finalized or not active for consumption.
- Signoff evidence matrix omits a required evidence type or task-level entry.
- Target change invalidates evidence but old evidence is still consumed.
- User decision or risk acceptance is required but absent.
- `READY_FOR_COMMIT` is treated as `DELIVERED`.

## Success Criteria

1. Chain contracts are clean: active artifacts have only fields with clear owners, consumers, stages, purposes, and verification paths. Unneeded active fields, old concepts, wrong paths, and prose-only contracts are removed or downgraded out of active execution.
2. Stage boundaries are enforceable: product-director freezes the Director baseline, product-manager refines WHAT artifacts, tech-lead freezes tasks, and delivery-owner controls execution and signoff without requiring future evidence during intake.
3. Delivery-owner can execute deterministically: intake, dispatch readiness, loop state, pause state, recovery, evidence consumption, and signoff conditions are defined by artifacts and scripts rather than chat memory.
4. Runtime evidence is consumable: developer, verify, review, QA, consistency, and fix artifacts expose the fields needed for status, freshness, active registry proof, and stale or superseded checks.
5. Failure paths are hard-blocking: the listed failure modes are covered by schema, script, contract, or negative fixture tests.
6. Signoff is auditable: `signoff-package.runtime_evidence_matrix` proves complete, fresh, active, non-superseded evidence coverage for required runtime evidence.
7. Human decisions are correctly separated: signoff, authorization, waiver, and risk acceptance use `user-decision.json`; scope, AC, goal, tasks, or design changes use `target-change.json`.
8. Pilot proof is repeatable: at least two pilot fixtures prove the happy path from baseline artifacts to signoff, and targeted negative fixtures prove blocking behavior.
9. Verification reaches production-readiness confidence: final evidence includes schema checks, script checks, contract tests, pilot tests, negative tests, and diff-range review. Markdown prose assertions or report self-reference cannot prove completion.

## Validation Strategy

Validation should be built from deterministic checks first:

- Schema validation for scoped artifacts.
- Script validation for Director lock, PM preflight, delivery-owner intake, task packet readiness, artifact registry, delivery-state, signoff, user-decision, and target-change.
- Pilot happy-path tests for at least two existing fixtures.
- Negative tests for failure modes listed above.
- Runtime contract tests for stage/state vocabulary and evidence matrix semantics.
- Gate execution as defined in the Gate Strategy section.

Manual review is allowed only to classify ambiguous field decisions or user-facing semantics. It must not replace deterministic contract validation.

### Canonical Pilot Fixtures

The reusable happy-path proof uses these canonical fixtures unless a later design update replaces them and also updates the matching gate plan or test coverage:

- `tests/fixtures/standard-chain-pilots/login-homepage-pilot`
- `tests/fixtures/standard-chain-pilots/feedback-thanks-pilot`

Each pilot must prove the same observable chain:

- Baseline artifacts are present, version-aligned, and accepted by delivery-owner intake.
- Director locked fields are present and digest-valid.
- Product-manager refinements stay inside WHAT-level ownership.
- `plan.json` and `tasks.json` are aligned, confirmed, and frozen for delivery dispatch.
- Runtime evidence entries exist for every in-scope task and are active in `artifact-registry.json`.
- `delivery-state.json` transitions do not skip required evidence gates.
- `signoff-package.runtime_evidence_matrix` covers every required evidence type and task-level evidence entry.
- `READY_FOR_COMMIT` is not accepted as `DELIVERED` unless a commit or equivalent delivery result is recorded and linked.

### Acceptance Test Matrix

Implementation is not ready for review until every row has a named validator, fixture or sample input, and expected result.

| ID | Success criterion | Required proof | Minimum positive coverage | Minimum negative coverage | Gate tier |
| --- | --- | --- | --- | --- | --- |
| SC-1 | Chain contracts are clean | Field decision matrix plus schema, template, script, fixture, and active-doc diff review | Every active field has an accepted matrix row and matching active surface update | A field without owner, consumer, verification method, or cleanup decision fails matrix validation | Targeted contract gate |
| SC-2 | Stage boundaries are enforceable | Director lock validator, PM preflight, task freeze validator, delivery-owner intake validator | Canonical pilots pass without DO-S1 reading runtime evidence | Digest drift, missing Director confirmation, PM HOW leakage, unfrozen tasks, or DO-S1 future-evidence dependency blocks | Targeted contract gate |
| SC-3 | Delivery-owner can execute deterministically | Delivery intake, dispatch readiness, delivery-state, pause, recovery, and signoff validators | Canonical pilots produce deterministic owner, reason, state, recovery, and next-action outputs | Missing baseline, mixed versions, bad state transition, or missing recovery owner blocks | Targeted script gate |
| SC-4 | Runtime evidence is consumable | Runtime evidence schema plus artifact-registry validator | Developer, verify, review, QA, consistency, and triggered fix evidence expose status, freshness basis, canonical ref, producer, and active registry proof | Evidence on disk but absent, stale, superseded, non-finalized, or inactive in registry blocks | Runtime contract gate |
| SC-5 | Failure paths are hard-blocking | Negative fixture suite covering the failure mode matrix | Not applicable; positive behavior is covered by SC-2 through SC-4 and SC-6 through SC-8 | Every listed failure mode returns block status, owner, reason, and recovery condition | Negative gate |
| SC-6 | Signoff is auditable | Signoff package schema and signoff validator | Canonical pilots include complete, fresh, active, non-superseded evidence matrix entries | Missing evidence type, missing task entry, stale evidence, or narrative-only proof blocks | Signoff gate |
| SC-7 | Human decisions are separated | `user-decision.json` and `target-change.json` schema and validator | Waiver, risk acceptance, authorization, and signoff use user-decision; scope, AC, goal, task, and design changes use target-change | Target change inside user-decision, waiver inside target-change, or absent required decision blocks | Decision contract gate |
| SC-8 | Pilot proof is repeatable | Two canonical pilot happy-path tests and targeted negative fixtures | Both canonical pilots pass from baseline artifacts through signoff readiness | Mutated pilot fixtures for each targeted failure mode block at the expected stage | Pilot gate |
| SC-9 | Verification reaches production-readiness confidence | Fresh command output, diff-range review, and criterion-by-criterion evidence report | Targeted gates, quick gate, and full repository gate pass for implementation delivery | Markdown-only evidence, stale command output, skipped in-scope tests, or report self-reference blocks completion claim | Final gate |

### Failure Mode Coverage Matrix

Each failure mode must have one deterministic negative fixture or validator case. The expected result is always: block, owner, reason, recovery condition, and no signoff permission.

| ID | Failure mode | Stage | Required negative proof |
| --- | --- | --- | --- |
| FM-01 | Missing required baseline input | DO-S1 | Remove one required baseline artifact from a canonical pilot and prove intake blocks. |
| FM-02 | Director confirmation missing or failed | DO-S1 | Remove or fail `director_confirmation` and prove Director-owned baseline is not accepted. |
| FM-03 | Director lock digest drift | DO-S1 | Mutate a locked field without updating the approved path and prove digest validation blocks. |
| FM-04 | Mixed baseline or tasks version | DO-S1 | Combine baseline artifacts from different versions and prove version alignment blocks. |
| FM-05 | `plan.json` and `tasks.json` version mismatch | DO-S1 | Mutate one version field and prove task intake blocks. |
| FM-06 | Tasks not frozen or not confirmed | DO-S1 | Mark tasks as draft, unconfirmed, or mutable and prove dispatch readiness blocks. |
| FM-07 | Task acceptance refs missing or not traceable | DO-S1 | Remove AC refs from one task and prove dispatch readiness blocks. |
| FM-08 | QA handoff obligations missing or not covered | DO-S1 or DO-S7 | Remove QA obligations before dispatch or coverage before QA closure and prove the owning stage blocks. |
| FM-09 | Developer or verify evidence missing for an in-scope task | DO-S5 | Remove one required task evidence entry and prove execution closure blocks. |
| FM-10 | Code review missing, stale, or blocking | DO-S6 | Remove review evidence, mark it stale, or mark it blocking and prove review closure blocks. |
| FM-11 | QA result missing, not PASS, or obligation coverage incomplete | DO-S7 | Remove QA result, set non-PASS, or drop obligation coverage and prove QA closure blocks. |
| FM-12 | Consistency audit required owner action not consumed | DO-S8 | Add required owner action without consumed resolution and prove signoff prep blocks. |
| FM-13 | Runtime evidence exists on disk but is not active in the registry | DO-S5 through DO-S8 | Keep evidence file but remove or deactivate its registry entry and prove consumption blocks. |
| FM-14 | Registry entry lifecycle is not finalized or not active for consumption | DO-S5 through DO-S8 | Set lifecycle to draft, stale, superseded, or inactive and prove consumption blocks. |
| FM-15 | Signoff evidence matrix omits a required evidence type or task-level entry | DO-S8 | Drop one evidence type or task-level row and prove signoff blocks. |
| FM-16 | Target change invalidates evidence but old evidence is still consumed | DO-S5 through DO-S8 | Add target-change affecting an evidence scope and prove old evidence is rejected until refreshed. |
| FM-17 | User decision or risk acceptance is required but absent | DO-S8 or signoff | Require waiver, authorization, or risk acceptance and prove absent `user-decision.json` blocks. |
| FM-18 | `READY_FOR_COMMIT` is treated as `DELIVERED` | closeout | Set state to `DELIVERED` without commit or equivalent delivery result and prove closeout blocks. |

### Test Data And Evidence Rules

- Positive and negative fixtures must be independently specified from the contract. They must not be generated by the validator under test and then reused as its oracle.
- Each negative fixture changes one primary condition unless the failure mode itself requires a compound condition.
- Fixture mutations must be local to the test fixture and must not rewrite canonical happy-path fixtures in place.
- Persistent negative fixtures must use `tests/fixtures/standard-chain-pilots/negative/FM-XX--<failure-name>/`. Generated negative cases must use unique temporary directories and leave canonical happy-path fixtures unchanged.
- Before implementation changes begin, the implementation plan must bind every acceptance matrix row and failure-mode row to a concrete validator command or test path. If the validator does not exist yet, the plan must add the failing test before changing production contracts or scripts.
- Tests must assert business-observable outcomes: block/pass status, owner, reason, recovery condition, active evidence ref, state transition, and signoff permission.
- Tests must be runnable in any order. Generated temporary files must use unique paths and be cleaned up.
- Flaky, skipped, xfailed, markdown-only, or report-self-referential checks cannot prove any success criterion.
- Security is not the primary risk for this artifact-only chain unless user input is executed, rendered, or used in shell/query contexts. Data integrity is triggered by registry, state, and signoff artifacts and must be tested. Performance is marked by gate runtime and fixture volume; validators must have bounded traversal and no unbounded retry. Environment compatibility is marked by shell and Python runtime assumptions in the repository gates.

### Gate Strategy

For design-only edits, completion evidence is a diff review against this design goal plus two clean review loops with no new in-scope findings.

For implementation delivery, completion requires fresh output from:

- Field decision matrix validator.
- Scoped schema and script validators for changed artifacts.
- Runtime contract tests.
- Two canonical pilot happy-path tests.
- Failure-mode negative tests for every in-scope failure mode.
- `bash tests/run-all.sh --quick`.
- `bash tests/run-all.sh` before a production-readiness claim, merge, or handoff.

If the user explicitly accepts a narrower validation scope, the final claim must be downgraded to the proven scope and must not call the chain production-ready.

## Implementation Approach

1. Produce a field and artifact decision matrix for scoped artifacts.
2. Resolve `needs-human-decision` items before implementation.
3. Update contracts, schemas, templates, skills, scripts, fixtures, and tests according to the matrix.
4. Add or update deterministic validation for happy paths and blocking paths.
5. Run targeted validation and the required gates defined in Gate Strategy.
6. Report completion against each success criterion with direct evidence.

## Resolved Design Decisions

1. `fix-result.json` is required only when a fix loop is triggered. Once triggered, the fix result becomes required runtime evidence and must be active in the registry before signoff.
2. Previous reports, prompts, diffs, and pilot outputs are evidence inputs only. Active facts for implementation must live in scoped contracts, schemas, templates, scripts, fixtures, runtime artifacts, gate plans, or the field decision matrix.
3. Design-only completion uses diff review plus repeated review loops. Implementation completion uses targeted validators, runtime contract tests, canonical pilots, negative tests, quick gate, and full repository gate before claiming production readiness.
