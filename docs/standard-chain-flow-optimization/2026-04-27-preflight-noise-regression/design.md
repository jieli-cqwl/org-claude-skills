# Standard Chain Flow Optimization Design

## Problem Statement

The standard-chain skills currently carry too much active context inside `SKILL.md`: mechanical prerequisite checks, repeated schema facts, historical migration notes, display formats, long method explanations, and prose-based failure handling. This increases LLM context load and creates ambiguity for downstream agents.

The concrete failure observed during discovery is that `tests/test-standard-chain-login-homepage-pilot.sh` passed the real HTTP login tests, then failed canonical phase validation because current `developer-report.schema.json` requires `self_testing.coverage_review` while the login homepage pilot fixture still uses the older report shape. This shows the chain can pass local behavior while breaking at the canonical contract boundary.

The optimization must make the standard chain easier for Codex to execute while preserving correctness: machine-verifiable facts move to scripts, schemas, validators, and fixtures; business and technical judgment remain in the owning skill role; failure handling becomes a structured routing contract instead of prose troubleshooting.

## Goals And Success Criteria

The first phase covers the full standard-chain main path, not a single skill sample. It must include:

- Main roles: `product-director`, `product-manager`, `design`, `test-design`, `tech-lead`, `delivery-owner`, `developer`, `verify`, `review`, and `qa`.
- Integration-only roles: `fix` and `consistency-audit`, limited to delivery-owner dispatch, consumption, and evidence return contracts.
- Excluded by default: install, release, and team rollout flows, except for minimal hook registry, manifest, or runtime catalog sync required by the main-chain contract.

Success means the chain has a versioned preflight and completion contract, a shared failure routing shape, role-specific preflight profiles, content-layer quality rules, and an updated login homepage delegated pilot that proves the current chain end to end.

The completion proof must include targeted contract tests, the login homepage pilot, contract validation, and the quick regression suite. Full regression is preferred when local runtime cost is acceptable, but quick regression cannot be presented as a substitute for a blocked full regression.

## Approach

The target architecture separates five responsibilities.

`SKILL.md` is the active execution protocol for an LLM. It keeps role purpose, hard gates, core judgment framework, step protocol, script entrypoints, failure routing rules, triggered references, output source-of-truth links, and context handoff rules.

Core checkers are explicit CLI tools. They accept clear inputs such as `--feature`, `--phase-dir`, `--unit`, or `--task-id`, and return structured routing JSON. They are the command path that a skill can tell Codex to run directly.

Hook adapters are runtime adapters. They translate Claude or Codex hook payloads into core checker arguments, enforce timeout and output limits, and fail closed when payloads are ambiguous. They do not contain independent business rules.

Canonical contracts remain the source of truth. Schemas, templates, artifact registry, refs, and validators define machine-verifiable facts. Scripts verify these contracts; they do not invent new field ownership, status semantics, or business policy.

References and projections keep non-active context out of the main skill body. Methodology files in `references/` remain valid and important, but are loaded only when their trigger applies. Projection templates render human-facing reports from canonical artifacts and do not act as runtime inputs.

The role data flow is:

`upstream canonical artifacts -> preflight core checker -> skill role process -> canonical output -> completion core checker -> phase/readiness validation -> downstream handoff`.

Hook dispatchers provide a second safety net for missed or malformed outputs, but the explicit CLI contract is the primary path.

## Checker And Adapter File Contract

Core checkers and hook adapters have separate file responsibilities.

Core CLI checkers live at:

- `shared/skills/{skill}/scripts/check_preflight.sh`
- `shared/skills/{skill}/scripts/check_completion.sh`

They are argv-only commands. They accept role-specific arguments such as `--feature`, `--phase-dir`, `--unit`, `--task-id`, `--artifact`, or `--scope`, and emit the failure routing JSON to stdout. They do not read hook payload JSON from stdin.

Hook adapters live at:

- `shared/skills/{skill}/scripts/preflight_check.sh`
- `shared/skills/{skill}/scripts/completion_check.sh`

Adapters read Claude or Codex runtime payloads, resolve the target role arguments, and invoke the matching core checker. Existing hook-facing `completion_check.sh` files may remain at their current paths for registry compatibility, but after cutover they must delegate to `check_completion.sh` rather than keeping independent validation policy.

Tests must cover core CLI behavior and adapter behavior separately:

- CLI test: explicit argv input, routing JSON output, exit code, and fail-closed malformed arguments.
- Adapter test: hook payload conversion, timeout, output truncation, ambiguous target handling, and delegation to the core checker.
- Drift test: adapter and core checker return the same routing semantics for equivalent inputs.

## Alternatives Considered

### Option 1: Versioned preflight and completion contracts for every standard-chain role

This is the chosen option. Each main role gets a role-specific preflight profile, completion gate alignment, and shared failure routing shape. It provides early failure, clean handoff, and a way to verify the entire chain with the login homepage pilot.

The cost is broader implementation scope. The scope is controlled by freezing the main-chain role list, limiting `fix` and `consistency-audit` to integration contracts, and excluding install/release/team rollout unless directly touched by hook or manifest sync.

### Option 2: Only enhance existing completion checks

This would reduce implementation work, but it would not solve context load at role entry. Many failures would still surface only after a role has already spent context producing output. It also leaves prerequisite prose in `SKILL.md`.

### Option 3: Make `validate_standard_chain_phase.py` the single universal checker

This would provide one command, but it would mix role entry, role completion, phase consistency, and delivery readiness into one large control point. That would make owner routing and role-specific failures harder to diagnose.

## Change Scope

The design affects:

- Standard-chain skill bodies under `shared/skills/*/SKILL.md` for the main role list.
- Role scripts under `shared/skills/*/scripts/` for preflight and completion contracts.
- Shared hook registry and manifests only where required to connect hook adapters to the new core checker shape.
- Canonical schemas, templates, validator helpers, and runtime catalog entries required by the failure routing and fresh-proof contracts.
- Tests and fixtures for standard-chain structure, login homepage pilot, preflight routing, content quality, and schema/template synchronization.
- Documentation for the active workset and process retrospective produced by the delegated pilot.

The design does not require changing install/release/team rollout behavior unless a changed hook registry or manifest must remain installable.

## Invariants

Scripts must never replace human or role judgment. They may detect that a confirmation is missing or malformed, but they must not create Director confirmation, PM delivery confirmation, design final confirmation, plan confirmation, business risk acceptance, or signoff.

Preflight checks are read-only, idempotent, and side-effect free. They may not create files, patch artifacts, update registries, or normalize documents.

Completion checks verify current role output and handoff readiness. They may not silently migrate old artifacts or accept stale evidence as fresh proof.

`WARN` is not automatically safe to continue. Continuation depends on an explicit `continuation_condition`, such as handoff-note recording, owner acknowledgement, or user risk acceptance.

Codex Delegated Pilot Mode is valid only for the login homepage regression pilot. It does not change the standard-chain rule that formal user decisions belong to the user or owning role.

`references/` are not noise by default. They are method libraries loaded by trigger. The active skill body should link to them with precise trigger/read/expect/consume/evidence/sync semantics instead of copying their long-form content.

## Failure Routing Contract

All preflight and completion checkers emit a versioned routing result with a closed shape:

```json
{
  "schema_version": "1.0.0",
  "status": "PASS",
  "stage": "qa.preflight",
  "failure_code": "NONE",
  "owner": "qa",
  "next_action": "continue",
  "safe_to_continue": true,
  "human_decision_required": false,
  "continuation_condition": "none",
  "evidence_refs": [],
  "user_message": "QA preflight passed."
}
```

`status` is `PASS`, `WARN`, or `BLOCKED`.

`failure_code` comes from a shared registry. Each code defines the default owner, default next action, whether human decision is required, and whether continuation is safe.

`owner` is a role or `user`. It cannot be omitted because unowned failures lead downstream agents to guess.

`safe_to_continue=false` is a hard stop. The current role cannot proceed and cannot hand off downstream.

`human_decision_required=true` means the only valid next action is to ask the user or, in the login homepage delegated pilot only, record the delegated confirmation basis. Scripts cannot generate the decision.

`continuation_condition` is required for `WARN`. If the condition has not been met, the effective result is blocked for handoff.

## Failure Routing Registry

The failure routing registry truth is `contracts/standard-chain-failure-routing.yaml`. The routing result schema truth is `contracts/canonical/schemas/runtime/failure-routing-result.schema.json`.

If a runtime JSON catalog is needed, it is derived from the contract into `shared/runtime/standard-chain-failure-routing.json`. The derived catalog is not allowed to define codes that do not exist in the contract.

Each registry entry contains:

- `failure_code`
- `status`
- `default_owner`
- `default_next_action`
- `safe_to_continue`
- `human_decision_required`
- `continuation_condition`
- `message_template`
- `introduced_in`
- `retired_in`

Unknown failure codes are invalid. A checker that encounters an unmapped condition must return `BLOCKED` with `failure_code=UNREGISTERED_FAILURE_CODE`, owner `delivery-owner`, `safe_to_continue=false`, and a diagnostic evidence ref pointing to the checker output.

Cutover rule: implementation first adds the registry and schema, then updates checkers to use registered codes, then updates skill text to refer to registered failure routing. Skill text cannot introduce a failure code by prose alone.

## Fresh Proof Contract

Fresh proof evidence must describe the current run, not merely point to a historical green artifact. A valid fresh proof includes:

- A run identifier or timestamp for this execution.
- The command or tool used.
- Exit code or structured result.
- Output reference or evidence anchor.
- The success criterion, AC, gate, or failure routing condition it proves.

Completion gates may validate evidence structure and recency rules. They cannot infer success from old logs, old fixture content, or a summary sentence that is not linked to the current run.

## Content Layer Contract

Skill text is not optimized for shortest length. It is optimized for single responsibility and low ambiguity.

Each normative paragraph belongs to one content layer:

- `HARD-GATE`: non-negotiable stop conditions.
- `Protocol`: ordered role actions and pauses.
- `Why`: reason for a rule. It must not add actions, commands, output fields, or hidden MUST requirements.
- `How`: judgment framework and thinking method. It must not specify concrete files, fields, commands, or completion conditions.
- `Script Contract`: explicit CLI command and result interpretation.
- `Failure Routing`: owner, next action, continuation, and human decision boundary.
- `Reference Link`: trigger-based pointer to long methodology.
- `Output Contract`: canonical output path and schema/template source of truth.

Ambiguous wording is treated as active skill noise when it contains vague action words, repeated source-of-truth claims, hidden requirements inside `Why`, mixed layers, unowned failure statements, or absolute phrasing that can be read in multiple ways. For example, a sentence that appears to ban methodology loading is ambiguous; the intended rule is "do not load untriggered methodology by default; when a Trigger applies, read the relevant reference file or section."

Instruction quality is verified by static checks and scenario replay, not by line-count reduction.

## Noise Migration Rules

Every removed or rewritten skill-body segment needs an audit record with source location, content layer, destination, consumer, reason, and verification method.

The destination categories are:

- `script`: mechanical checks such as file existence, schema validation, ref resolution, field closure, command availability, and active registry resolution.
- `contract`: canonical schema, template, catalog, ref grammar, field ownership, or closed vocabulary.
- `reference`: long method guidance loaded by trigger.
- `projection`: human display template or report format.
- `archive`: historical migration context or obsolete workflow notes.
- `delete`: content with no active consumer and no archival value.

Role-crossing content moves to the owning role or becomes a failure routing entry. For example, QA should not define test-design obligations; it should block with owner `test-design` when the QA handoff contract is missing or malformed.

The noise migration audit truth lives at `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/noise-migration-audit.json`.

Each audit entry contains:

- `source_file`
- `source_anchor`
- `content_layer`
- `migration_action`: `script`, `contract`, `reference`, `projection`, `archive`, or `delete`
- `destination_ref`
- `consumer`
- `reason`
- `verification_ref`

For every standard-chain `SKILL.md` touched by this phase, the implementation must add audit entries for removed or substantially rewritten normative text. A content-quality test must fail when a touched skill has no audit entries or when an entry has `migration_action=delete` without a reason and verification ref.

## Preflight Role Profiles

`product-director` preflight validates workspace writability, contract availability, templates, and ability to produce Director artifacts. It must not require existing `brief.json` or `phase-prd.json` because Director is the chain entry.

`product-manager` preflight validates Director handoff, locked field digest, phase boundary consistency, and canonical product artifact availability.

`design` preflight validates PM delivery confirmation, closed product review state, phase/unit inputs, and existing project/context scan prerequisites.

`test-design` preflight validates product artifacts, `design.json`, unit definitions, and design refs needed to derive tests.

`tech-lead` preflight validates product, design, test-case inputs and checks that unresolved design decisions have not been pushed into planning.

`delivery-owner` preflight validates confirmed baseline artifacts, active artifact registry, plan/tasks refs, test-cases refs, and readiness to dispatch execution.

`developer` preflight validates task scope, declared file range, design/task refs, optional test-cases ref, and the absence of unauthorized write scope.

`verify` preflight validates developer-report availability, task refs, plan/tasks refs, and evidence anchors.

`review` preflight validates plan/tasks baseline, developer/verify evidence availability, and review scope.

`qa` preflight validates brief, phase PRD, units, design, plan, test-cases refs, code-review result, active artifact registry, QA handoff contract, and real execution entry conditions.

`fix` and `consistency-audit` are included through delivery-owner dispatch and result consumption. Their independent capability expansion is outside this phase.

## Completion Role Profiles

`product-director` completion validates Director canonical outputs, `director_confirmation`, locked fields, digest presence, absence of Manager-owned UNIT/AC output, and handoff readiness for `product-manager`.

`product-manager` completion validates Director lock preservation, UNIT closure definitions, AC examples, Verification Plan, review closure, delivery confirmation, and handoff readiness for `design`.

`design` completion validates `design.json` schema, Q1-Q9 semantic closure, option analysis, final confirmation, interface/data/cross-cutting coverage, product handoff acceptance, and handoff readiness for `test-design`.

`test-design` completion validates AC positive/negative/boundary coverage, exclusion tests, design refs, QA handoff contract, review convergence, unresolved design-gap handling, and handoff readiness for `tech-lead`.

`tech-lead` completion validates `plan.json` and `tasks.json`, design review result, task traceability, `proving_command`, real dependency notes, fresh-proof targets, plan confirmation, and handoff readiness for `delivery-owner`.

`delivery-owner` completion validates active baseline refs, delivery-state freshness, fixed review/QA gates, consistency-audit advisory consumption, signoff package, user decision, and readiness for commit or closeout.

`developer` completion validates declared file scope, RED/GREEN evidence per AC, `developer-report.json`, self-testing structure, fresh proof evidence, and handoff readiness for `verify`.

`verify` completion validates `verify-result.json`, SPEC/2A/2B/2C verdicts, AC verification, goal closure, evidence refs, and handoff readiness for `review` or delivery-owner aggregation.

`review` completion validates `code-review-result.json`, REVIEW_A/B/C coverage, findings schema, excluded issue rationale, evidence integrity checks, and handoff readiness for QA or fix routing.

`qa` completion validates `qa-result.json`, QA_A-D coverage, browser-required evidence, release recommendation, residual risk, ruled-out issues, QAR triage completeness, and handoff readiness for delivery-owner signoff.

## Codex Delegated Pilot Mode

The login homepage flow is a regression pilot for the process itself. The user authorizes Codex to make the product, design, planning, delivery, and signoff decisions for this pilot so Codex can experience the whole flow without requiring user participation at every co-creation step.

The pilot must still traverse the confirmation gates. Artifacts record `confirmed_by=codex-delegated-gatekeeper` or equivalent and include a `confirmation_basis` that cites the user authorization for this regression run.

The pilot artifacts are marked as `pilot/regression` in the appropriate metadata or evidence notes. This mode expires outside the login homepage standard-chain regression and cannot be used as the default for formal user-facing work.

The pilot produces a process retrospective that records context load, unclear instructions, preflight failures, completion failures, failure routing quality, schema/fixture drift, and role boundary friction.

## Delegated Pilot Proof

The delegated pilot proof lives at `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/delegated-pilot-proof.json`. The process retrospective lives at `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/process-retrospective.md`.

The proof records:

- `run_id`
- `pilot_scope`
- `delegated_authorization_ref`
- `stage_results`
- `confirmation_records`
- `generated_or_updated_artifacts`
- `fresh_proof_commands`
- `fixture_sync_refs`
- `retrospective_ref`

Each `confirmation_records[]` entry includes the stage, confirmation field, `confirmed_by`, confirmation basis, and artifact ref. The basis must cite this design's Codex Delegated Pilot Mode and the user's approval in this workset. A missing basis blocks the pilot.

The login homepage fixture under `tests/fixtures/standard-chain-pilots/login-homepage-pilot/phase-1` can be updated only as a consequence of this delegated proof. A passing legacy fixture is not enough. The regression test must prove that fixture artifacts, delegated proof, and process retrospective all agree on the active plan/tasks refs, confirmation basis, and current developer-report schema including `self_testing.coverage_review`.

The pilot is complete only when Codex has recorded the full role traversal from `product-director` through delivery signoff in the proof. Repairing old JSON until `validate_standard_chain_phase.py` passes is not sufficient.

## Downstream Impact

`writing-plans` can create tasks for contracts, scripts, tests, skill text migration, fixture synchronization, and pilot replay without inventing policy because this design fixes the role list, output shape, migration categories, and pilot mode.

`delivery-owner` receives clearer dispatch boundaries after `tech-lead`: it owns orchestration of `developer -> verify -> review -> qa -> fix/consistency-audit -> signoff` rather than treating developer as a terminal chain step.

`developer`, `verify`, `review`, and `qa` get earlier input failure detection and less prose to interpret. They still retain professional judgment over implementation, verification, review findings, and release recommendation.

Future install/release/team rollout tasks may consume the new manifests or hook registry entries if the main-chain implementation changes them, but they are not default consumers of this design.

## Risks

There is a risk that scripts become hidden source of truth. The mitigation is to keep schemas, templates, catalogs, and canonical artifacts as truth, while scripts only validate them.

There is a risk that content quality lint deletes useful thinking guidance. The mitigation is to allow `Why` and `How` layers, but require them not to mix with Protocol, Output Contract, or Failure Routing.

There is a risk that delegated pilot behavior contaminates formal workflow. The mitigation is explicit pilot metadata, user authorization basis, and a documented expiration boundary.

There is a risk that broad role coverage causes too many simultaneous breaks. The mitigation is implementation sequencing: versioned contracts first, read-only checkers second, hook adapters and tests third, skill migration fourth, fixture/eval sync fifth, delegated pilot last.

There is a risk that old artifacts are silently tolerated. The mitigation is explicit compatibility decisions: migrate fixture, add documented compatibility, or block. Silent best-effort compatibility is not allowed.

## Contract-Grade Preflight

### C1 Current vs Target

Current HEAD already has canonical schemas, standard-chain validators, completion scripts, hook registry, and login homepage pilot fixtures. The target phase adds versioned preflight and failure routing contracts without removing existing completion gates until replacements are proven. Cutover owner is the standard-chain flow optimization implementation owner, with `delivery-owner` consuming the final readiness evidence.

### C2 Source Of Truth Matrix

Role decisions remain in canonical artifacts owned by their producer. Failure routing shape lives in `contracts/canonical/schemas/runtime/failure-routing-result.schema.json`; routing codes live in `contracts/standard-chain-failure-routing.yaml`; any runtime catalog is derived from those contracts. Script manifests describe adapter boundaries. Progress and handoff state remain in active workset `worklog.md` and canonical artifact registry where standard-chain artifacts apply. If a skill body conflicts with schema/template/catalog, the canonical contract wins and the skill text must be fixed.

### C3 Closed Vocabulary And Grammar

Routing status is closed to `PASS`, `WARN`, `BLOCKED`. Required routing fields are `schema_version`, `status`, `stage`, `failure_code`, `owner`, `next_action`, `safe_to_continue`, `human_decision_required`, `continuation_condition`, `evidence_refs`, and `user_message`. Failure codes come from `contracts/standard-chain-failure-routing.yaml`. CLI and hook adapter inputs use role profiles instead of free-form shell payload construction.

### C4 Ownership And Waiver

Each checker has an owning skill. The failure code registry defines default owner and next action. Human decisions belong to `user` or the owning role in delegated pilot only. Waivers cannot skip fixed delivery gates; they can only accept recorded residual risk where the existing delivery-owner contract permits it.

### C5 Failure Contract

Blocked recovery returns the fixed routing shape and forbids guessing from untracked history, chat memory, or non-managed docs. `safe_to_continue=false` blocks downstream handoff. `human_decision_required=true` blocks scripts from writing confirmations.

### C6 Implementation Surface

Allowed implementation surface is limited to standard-chain skills, role scripts, `contracts/standard-chain-failure-routing.yaml`, `contracts/canonical/schemas/runtime/failure-routing-result.schema.json`, any derived shared runtime catalog, hook registry/manifest sync needed by those scripts, tests, fixtures, and active docs. Install/release/team rollout is outside default scope.

### C7 Proving Categories

Success criteria map to structure tests, preflight/failure routing tests, content quality tests, canonical phase validation, readiness validation, login homepage pilot replay, contract validation, and quick regression.

### C8 Existing Contract Diff

Implementation must check existing contracts in `contracts/standard-chain.yaml`, `contracts/small-chain.yaml`, `contracts/canonical/*`, `shared/hooks/registry.json`, current role `SKILL.md` files, current `completion_check.sh` scripts, `tests/test-standard-chain-skill-structure.sh`, and `tests/test-standard-chain-login-homepage-pilot.sh` before changing behavior.

## Verification Strategy

Targeted proof includes:

```bash
bash tests/test-standard-chain-skill-structure.sh
bash tests/test-standard-chain-login-homepage-pilot.sh
bash tools/validate-contracts.sh
bash tests/run-all.sh --quick
```

New or changed proof must cover:

- Failure routing schema and failure code registry.
- Role-specific preflight profiles.
- Role-specific completion profiles.
- Core checker CLI behavior.
- Hook adapter payload conversion and fail-closed behavior.
- Fresh proof structure and stale evidence rejection.
- Skill content layer quality and ambiguity checks.
- Noise migration audit coverage.
- Delegated pilot proof and process retrospective alignment.
- Login homepage fixture synchronization with the latest developer-report schema, including `self_testing.coverage_review`.

Full regression with `bash tests/run-all.sh` is the preferred final proof when runtime constraints allow it. If it is blocked, the blocker must be reported explicitly.

## Non Goals

This design does not redesign the product role split, replace canonical JSON with markdown, add new business capability to login homepage, or change installation/release/team rollout beyond minimal sync needed by the main-chain runtime contract.

This design does not authorize scripts to create or accept human decisions, and it does not treat reduced `SKILL.md` line count as proof of success.
