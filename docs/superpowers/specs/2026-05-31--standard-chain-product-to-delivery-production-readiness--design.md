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
- Targeted quick/full gate selection based on changed surfaces.

Manual review is allowed only to classify ambiguous field decisions or user-facing semantics. It must not replace deterministic contract validation.

## Implementation Approach

1. Produce a field and artifact decision matrix for scoped artifacts.
2. Resolve `needs-human-decision` items before implementation.
3. Update contracts, schemas, templates, skills, scripts, fixtures, and tests according to the matrix.
4. Add or update deterministic validation for happy paths and blocking paths.
5. Run targeted validation and then the agreed repository gate.
6. Report completion against each success criterion with direct evidence.

## Open Decisions

1. Whether `fix-result.json` is always part of runtime evidence closure, or only required when a fix loop is triggered.
2. Which existing reports remain active facts for this task and which become historical evidence only.
3. Whether final validation requires full `bash tests/run-all.sh` every time, or targeted full-profile validation plus agreed gates is acceptable for design/spec-only changes.
