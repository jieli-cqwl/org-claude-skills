# Product Director Decision Case Design

## Status

- Design status: approved section by section in human co-creation on 2026-07-30; pending final document review.
- Runtime status: not implemented.
- Authority: design input only. This document does not replace current runtime Skills, canonical schemas, `contracts/standard-chain.yaml`, or active standard-chain artifacts.
- Activation boundary: do not register this document in `contracts/active-doc-scope.yaml`. Runtime activation requires a separate approved implementation plan and synchronized contract migration.

## Objective

Redesign `product-director` as the evidence-driven decision gate for ambiguous demand in a one-human-plus-agent product delivery team.

The role must turn an incomplete request, customer quote, proposed feature, complaint, strategic idea, or constraint into an evidence-backed, falsifiable WHY baseline that supports one of three recommendations:

- `GO`
- `DISCOVERY`
- `NO_GO`

Only a human `GO` decision with every mandatory Director gate passed may become ready for `product-manager`.

## Success Definition

The Product Director succeeds when:

1. The human may start with a vague, incomplete, or solution-shaped statement.
2. The agent reconstructs the real scenario instead of polishing the statement into a false requirement.
3. Decision-critical claims remain traceable to evidence, inference, assumptions, conflicts, and falsifiers.
4. First-principles analysis reaches a decision-relevant causal mechanism without pretending to find an ultimate root cause.
5. The Director freezes WHY, value, investment boundary, and the Active Phase value boundary without entering product or technical solution design.
6. `DISCOVERY` and `NO_GO` are complete, governed outcomes rather than unfinished work.
7. The human owns the investment decision but cannot waive empirical evidence gates.
8. An accepted Director revision is immutable.
9. Product Manager can begin WHAT detailing without inventing or silently rewriting WHY.

## Context

### Team model

- The human is the global control plane and final business decision-maker.
- Early operation is manual invocation (`M0`); automation is deferred until every stage works reliably.
- Product and architecture stages are human-agent co-creation.
- Execution-heavy stages are agent-led and human-reviewed.
- Deployment to test and production remains a manual human gate.
- Stage packages are stage-owned, versioned, and immutable after acceptance.

### Relevant chain boundary

This design covers:

`human → product-director → product-manager`

It does not redesign Product Manager, Impact Owner, Architecture, Test Design, Development Owner, Quality Owner, or deployment behavior. It defines only the contracts those roles must not violate when consuming Director output.

### Reserved acceptance case

The `qft-tenants` future-tenant request remains the final whole-chain acceptance scenario. It must not be solved or overfitted into this design. Generic and adversarial Skill evaluations must pass before that scenario is used.

## Core Role Contract

### Purpose

Product Director owns the decision:

> For whom, in what real situation, why is change worth considering now, what result should change, how much is worth investing, and what is the smallest value boundary authorized for Product Manager detailing?

### Authority

Product Director owns:

- demand signal interpretation;
- concrete scenario truth;
- decision-relevant causal model;
- target actor and situation boundary;
- desired customer and business outcomes;
- value thesis and why now;
- investment appetite and external hard constraints;
- value-level non-goals;
- optional Phase Map;
- authoritative Active Phase value boundary;
- Director recommendation;
- Director evidence and uncertainty closure;
- handoff invalidation rules.

Product Director does not own:

- feature or MVP lists;
- AS-IS or TO-BE product behavior specifications;
- business objects, states, rules, or permissions;
- Product Units or Acceptance Criteria;
- source-code impact analysis;
- current-asset coverage denominators;
- architecture, interfaces, modules, schemas, migration, or rollback design;
- engineering estimates or delivery commitments;
- test cases, implementation plans, or tasks.

### One-hop responsibility

Product Director makes its output consumable by Product Manager. It must not build a super-document for every downstream role.

Product Manager may challenge the Director baseline but may not modify it. A WHY-changing challenge creates a new Director revision.

## Operating Architecture

Use two layers:

### Single user-visible orchestrator

The human invokes only `product-director`.

The Skill selects internal methods such as scenario interviewing, evidence retrieval, research synthesis, assumption mapping, causal challenge, value framing, and adversarial review. These methods:

- are replaceable capability modules, not additional team roles;
- do not require separate human invocation;
- do not create independent canonical outputs;
- return their findings to the Product Director evidence-and-decision state;
- may be skipped when the current demand does not need them.

### Human-facing co-creation frontstage

The human sees:

- the agent's current best interpretation;
- evidence and limitations;
- competing explanations;
- the strongest counterargument;
- the single question most likely to change the decision;
- the agent recommendation;
- the exact baseline proposed for confirmation.

The human is not asked to:

- design the questioning sequence;
- enumerate unknown unknowns;
- fill a fixed template;
- synthesize evidence the agent can inspect;
- invent the agent's alternative hypotheses;
- write handoff artifacts.

### Evidence-and-decision backstage

The agent maintains:

- source references;
- scenario snapshots;
- decision-critical claims;
- epistemic state;
- counterevidence;
- causal hypotheses and falsifiers;
- gate results;
- recommendation and human decision as separate records;
- version, digest, and invalidation dependencies.

The backstage may be mechanically strict. The frontstage must remain concise and natural.

## Scenario Discovery Loop

Do not use a fixed questionnaire or unconstrained free-form interview. Use an adaptive, hypothesis-driven evidence loop.

### 1. Decode the signal

- Preserve the original customer or stakeholder wording verbatim.
- Separate explicit facts, implied claims, proposed solutions, preferences, and unknowns.
- Treat a feature request as a signal, not a validated requirement.

### 2. Inspect available evidence first

Before asking the human for discoverable facts, inspect relevant:

- customer or stakeholder records;
- interview or meeting notes;
- support tickets and operational records;
- analytics and logs;
- existing product and business documentation;
- current code, configuration, or tests when current system behavior is disputed.

Code inspection at this stage is current-state evidence only. It must not become impact analysis or technical solution design.

### 3. Reconstruct a concrete episode

For an existing problem, prefer the most recent real occurrence:

- affected actor and relevant segment;
- triggering event and preconditions;
- intended progress or job;
- actual sequence of behavior;
- tools, channels, artifacts, and handoffs;
- obstacle or failure;
- workaround or current alternative;
- person who bears the cost;
- consequence and final outcome;
- notable exception or variation.

For a new strategic opportunity with no prior occurrence, seek analogous behavior, current alternatives, attempted progress, or demonstrated time or money expenditure. Future intent alone is weak evidence.

If neither a concrete episode nor equivalent behavioral evidence exists, the Scenario Gate cannot pass.

### 4. Sweep the problem ecosystem

Inspect:

- user;
- buyer;
- operator;
- approver;
- support or exception handler;
- cost bearer;
- indirectly affected non-user;
- lifecycle, segment, channel, time, and exception variations.

This sweep primarily surfaces unknown-knowns held by people, documents, logs, and shadow processes outside the current conversation.

### 5. Construct competing hypotheses

Build two or three falsifiable explanations when evidence permits:

- visible symptom;
- candidate direct mechanism;
- candidate structural condition;
- alternative upstream explanation;
- segment-specific explanation;
- process, policy, information, or non-product explanation.

Recommend the best-supported explanation and explain why alternatives currently rank lower.

### 6. Seek disconfirmation

Ask:

- Does the same context ever avoid the problem?
- Does the same symptom occur without the proposed cause?
- Would removing the proposed cause materially reduce the cost?
- Does the workaround already solve the outcome?
- Does stated preference conflict with observed behavior?
- Would doing nothing actually create the claimed consequence?

Each conversational turn asks at most one decision-changing question. Evidence inspection may proceed in parallel when independent sources are available.

### 7. Synthesize and calibrate

Present:

- current scenario model;
- evidence and applicability;
- recommended causal explanation;
- strongest counterexample;
- remaining decision-changing gap;
- next recommendation.

The human corrects business reality, supplies authority-owned facts, and makes value tradeoffs. Human confirmation cannot turn an empirical assumption into a fact.

## First-Principles and Causal Depth

### Correct use

First-principles analysis:

1. removes inherited solution assumptions;
2. decomposes the demand into actor, context, behavior, constraint, result, and cost;
3. separates facts, inferences, assumptions, unknowns, and conflicts;
4. creates competing causal explanations;
5. attacks them with counterexamples and counterfactuals;
6. rebuilds a solution-free problem and outcome boundary from surviving claims.

### Causal ladder

`demand signal → concrete episode → symptom → direct mechanism → structural condition → business outcome`

Business problems may be multi-causal. The design must not force a single root cause when the evidence supports a mechanism plus contributing conditions.

### Stop rule

Stop descending when:

- the model explains the material observed episodes;
- competing explanations and at least one counterexample were checked;
- the proposed mechanism is falsifiable;
- removing the mechanism should materially change the observed cost;
- the model is sufficient to freeze actor, problem, outcome, and value boundary;
- deeper analysis would not change the Director decision or belongs to PM, Impact, or Architecture.

This is decision-relevant causal depth, not a claim to an ultimate root cause.

### Systemic does not mean maximal scope

Use global understanding to avoid local optimization and risk transfer. Authorize only the smallest independently valuable Active Phase:

> Understand globally; close value locally. Think systemically; deliver incrementally.

## Decision Claim Ledger

The ledger contains only claims that support or could overturn the Director baseline.

### Epistemic state

- `FACT`: supported by evidence appropriate to the exact claim.
- `INFERENCE`: derived from facts, with reasoning and a falsifier.
- `ASSUMPTION`: temporarily adopted but not sufficiently supported.
- `UNKNOWN`: no stable proposition can yet be made.
- `CONFLICT`: credible evidence cannot currently be reconciled.

An inference is allowed to support a decision when its evidence is decision-sufficient and live counterevidence has been handled. It must not be relabeled as fact.

### Minimum semantic fields

Each decision-critical claim needs:

- `claim_id`;
- statement;
- epistemic state;
- evidence references;
- source kind: observed, reported, authoritative, or derived;
- captured or observed time;
- applicability boundary;
- source independence and material limitations;
- counterevidence references;
- falsifier;
- decision criticality;
- impact if false;
- assertion state at this revision.

### Evidence fit

Use evidence appropriate to the claim:

| Claim | Suitable evidence |
|---|---|
| Actual behavior | observation, logs, operational records, behavior artifacts |
| Situation and motivation | concrete episode interview or contextual observation |
| Frequency and scale | quantitative data with timeframe and denominator |
| Business rule or constraint | authorized owner, formal policy, contract, or regulation |
| Current system behavior | code, configuration, tests, or runtime records |
| Causal mechanism | triangulation, counterexamples, counterfactuals, competing explanations |

Do not use a universal evidence hierarchy or unsupported numerical confidence score. Assess source fit, independence, freshness, scope, representativeness, consistency, and counterevidence.

### Decision criticality

- `BLOCKING`: a reasonable alternative answer could change actor, problem, outcome, value, investment, non-goals, constraints, or Active Phase.
- `BOUNDED`: uncertainty remains, but enumerated reasonable answers all preserve the Director baseline and the maximum possible loss is bounded.
- `DOWNSTREAM_OWNED`: PM, Impact, or Architecture owns the answer; enumerated reasonable answers cannot change WHY, and a result-to-reopen mapping identifies any evidence that would invalidate that judgment.
- `IRRELEVANT`: it cannot affect the current decision and should leave active context.

Every `BOUNDED` or `DOWNSTREAM_OWNED` classification must record:

- reasonable candidate answers;
- the WHY-change test for each answer;
- maximum loss or applicability boundary;
- accountable owner;
- evidence or verification obligation;
- expiry and reopen trigger.

Changing a label without this proof does not reduce Director debt. A false downgrade prevents the Evidence and Uncertainty Gate from passing.

### Lifecycle

Claims inside an accepted revision are immutable assertions. They are not edited when reality changes.

An external append-only lifecycle event references the original Case digest and Claim ID and declares one of:

- `STALE`;
- `SUPERSEDED`;
- `INVALIDATED`.

The current lifecycle projection is derived from the immutable assertion plus those events. New counterevidence invalidates dependent conclusions through further events. Do not patch only the visible sentence while leaving downstream conclusions active.

## Operationalizing Known and Unknown

The known/unknown categories select probes; they are not persistent artifact buckets.

- Known-known: verify source, freshness, and applicability.
- Known-unknown: define a falsifiable question and the cheapest discriminating probe.
- Unknown-known: search frontline roles, exception handlers, shadow workflows, historical documents, tickets, and logs; reclassify immediately once surfaced.
- Unknown-unknown: identify exposure conditions and bound them with adversarial review, observability, stop signals, and reopen triggers. Never claim they are eliminated.

## Human and Agent Authority

### Human authority

The human may establish or change:

- company strategy;
- priority;
- investment appetite;
- authorized business constraints;
- value tradeoffs and non-goals;
- risk tolerance within the human's authority;
- the final investment decision.

### Authority limits

Human confirmation alone cannot establish:

- customer behavior;
- market or population facts;
- current system behavior outside the human's direct authority;
- causal truth;
- absence of a decision-critical unknown;
- resolution of credible conflicting evidence.

The agent has no greater authority. It must preserve disagreement between its recommendation and the human decision.

## Mandatory Director Gates

Every evaluated gate produces `PASS`, `BLOCKED`, or `FAILED`. A gate that has not yet reached its evaluation point has no result; absence is never treated as `PASS`.

- `PASS`: evidence is sufficient for this decision horizon.
- `BLOCKED`: a decision-changing gap remains and has a plausible, bounded path to resolution.
- `FAILED`: decisive evidence or an authoritative constraint defeats the current framing; ordinary missing information is not failure.

### 1. Decision Contract Gate

- decision object and horizon are explicit;
- authorized human decision-maker is known;
- exploration appetite is bounded;
- GO is explicitly limited to PM detailing for the Active Phase.

### 2. Scenario Gate

- concrete episode or equivalent behavioral evidence exists;
- actor, trigger, current path, workaround, cost bearer, and consequence close;
- material roles and exceptions were swept.

### 3. Causal Gate

- symptom and decision-relevant mechanism are distinct;
- competing explanation exists;
- counterexample or counterfactual was checked;
- analysis stops before product or technical solution design.

### 4. Outcome and Value Gate

- customer and business outcomes are explicit;
- why now and cost of doing nothing are explicit;
- baseline or observable direction exists;
- success, failure, and stop signals exist;
- investment appetite and opportunity cost are visible;
- non-product alternatives were considered.

### 5. Evidence and Uncertainty Gate

- every locked conclusion references claims;
- no `BLOCKING + ASSUMPTION/UNKNOWN/CONFLICT` remains;
- decision-relevant inferences have supporting facts and falsifiers;
- bounded risks have owners, impact limits, and reopen triggers;
- downstream-owned questions cannot change WHY.

`blocking_director_debt` is the count of active Director claims for which any of the following is true:

- criticality is `BLOCKING` and epistemic state is `ASSUMPTION`, `UNKNOWN`, or `CONFLICT`;
- required freshness, source-fit, counterevidence, or falsification work is incomplete;
- a `BOUNDED` or `DOWNSTREAM_OWNED` classification lacks its candidate-answer analysis, WHY-change tests, loss boundary, owner, evidence obligation, expiry, or reopen trigger.

The count must be zero for this gate to pass. If decisive evidence defeats the framing, the gate is `FAILED`; otherwise unresolved or falsely downgraded debt makes it `BLOCKED`.

### 6. Active Phase Gate

- the Active Phase is the smallest independently valuable business closure;
- scope, value-level non-goals, and external hard constraints are explicit;
- entry and business exit conditions are clear;
- future phases, when needed, remain coarse, non-binding outcome hypotheses;
- no product behavior or technical solution is frozen.

### 7. Governance and Disposition Gate

This gate is evaluated only after Gates 1–6 produce the agent recommendation, the human makes a decision, the disposition-specific Case payload is assembled, and its digest is computed.

Every disposition requires:

- exact Case ID, revision, and content digest;
- recommendation and human decision as separate records;
- an external acceptance binding for the exact revision and digest;
- locked authority that is mechanically referable;
- expiry and reopen triggers.

The disposition then adds its own criteria:

- `GO`: blocking Director debt is zero, Product Manager can begin without inventing WHY, and the consumer contract version is supported.
- `DISCOVERY`: the bounded probe contract is complete and no PM handoff is emitted.
- `NO_GO` or `DEFER`: the decision scope, rationale, applicable horizon, and reopen triggers are complete and no PM handoff is emitted.

This gate governs the selected disposition. It does not participate in agent recommendation aggregation.

## Decision State Machine

### Separate state dimensions

| Dimension | States |
|---|---|
| Gate result | `PASS`, `BLOCKED`, `FAILED` |
| Agent recommendation | `GO`, `DISCOVERY`, `NO_GO` |
| Human decision | `GO`, `DISCOVERY`, `NO_GO`, `DEFER` |
| Handoff readiness | `READY`, `BLOCKED`, `NOT_APPLICABLE` |
| PM receipt | `NOT_REQUESTED`, `PENDING`, `ACCEPTED`, `REJECTED`, `INVALIDATED` |

### Agent recommendation aggregation

- Any decisive `FAILED` result among Gates 1–6 produces `NO_GO`.
- No `FAILED` result and at least one resolvable `BLOCKED` result among Gates 1–6 produces `DISCOVERY`.
- Gates 1–6 all `PASS` produces `GO`.

The agent must not rewrite its historical recommendation to agree with the human.

The ordered computation is:

```text
Gates 1–6
→ agent recommendation
→ human decision
→ disposition-specific Case payload
→ content digest
→ external human acceptance binding
→ Gate 7
→ handoff readiness
→ optional PM receipt
```

### GO

GO means:

> The current Director revision is decision-sufficient for the human to authorize Product Manager detailing of the Active Phase.

It does not authorize design, development, test deployment, release, or production deployment.

### DISCOVERY

DISCOVERY is valid only when:

- value remains plausible;
- a decision-changing blocker exists;
- a discriminating probe is affordable within an authorized budget.

Each blocking probe defines:

- affected claim and Director decision;
- reasonable candidate answers;
- cheapest discriminating method;
- evidence threshold;
- owner;
- time and cost limit;
- GO mapping;
- NO_GO mapping;
- stop condition.

If the authorized discovery budget expires without decision sufficiency, default to `NO_GO` or a human `DEFER`. Continuing requires new human authorization.

### NO_GO

NO_GO records:

- rejected framing and the candidate Active Phase if one was formed;
- time horizon and applicable conditions;
- decisive evidence or constraint;
- avoided investment;
- reopen triggers.

If scenario or causal evidence fails before an Active Phase can be formed, the record states that no Active Phase exists. It must not invent one to satisfy a template.

It is not a permanent universal prohibition and is not a failed process.

### Human override

The human may override strategy, priority, investment appetite, or risk tolerance within their authority. The baseline becomes a new revision and gates are recomputed.

The human may choose to invest despite empirical blockers, but cannot make handoff ready by waiver:

```text
agent_recommendation = DISCOVERY
human_decision       = GO
handoff_readiness    = BLOCKED
```

### Ready-for-PM formula

```text
READY_FOR_PM =
  human_decision == GO
  AND Gates_1_through_7 == PASS
  AND blocking_director_debt == 0
  AND confirmed_revision_is_current
  AND current_time <= valid_until
  AND consumer_contract_is_supported
```

The agent recommendation may disagree with the human. Evidence gates remain mandatory.

### State invariants and transitions

- `handoff_readiness = NOT_APPLICABLE` when the current human decision is `DISCOVERY`, `NO_GO`, or `DEFER`.
- `handoff_readiness = BLOCKED` when the human decision is `GO` but any readiness condition is missing, stale, expired, incompatible, or failed.
- `handoff_readiness = READY` is allowed only when the Ready-for-PM formula is true.
- `PM receipt = NOT_REQUESTED` until a `READY` revision is submitted to Product Manager.
- `PM receipt = PENDING` is allowed only while Product Manager is evaluating a revision that was `READY` at submission.
- `PM receipt = ACCEPTED` or `REJECTED` records the result for that exact revision and digest.
- A PM rejection makes the current handoff `BLOCKED` until its exact cause is closed through a new Case revision or a compatible consumer correction.
- New counterevidence, expiry, supersession, or digest invalidation changes current readiness to `BLOCKED` and any previously accepted current receipt to `INVALIDATED`; historical events remain immutable.

Forbidden current-state combinations include:

- `READY` with any mandatory gate not `PASS`;
- `READY` with an absent, expired, or mismatched acceptance binding;
- `PENDING`, `ACCEPTED`, or `REJECTED` without a prior `READY` submission event;
- current `ACCEPTED` receipt with current readiness `BLOCKED` or `NOT_APPLICABLE`;
- any PM receipt for a `DISCOVERY`, `NO_GO`, or `DEFER` disposition.

## Director Decision Case

The final logical artifact has two common layers and one disposition-specific layer. Physical file boundaries and schemas are implementation decisions.

### Layer 1: Discovery Record

Answers: why should this interpretation be trusted?

Contains:

- verbatim demand signals and provenance;
- scenario snapshots;
- Decision Claim Ledger;
- causal hypotheses;
- counterexamples and contradictions;
- research limitations;
- completed probe results.

Large or sensitive raw evidence remains outside the repository when necessary. Store stable references, digests, redaction status, and sufficient review evidence.

### Layer 2: Director Baseline

Answers: what exactly is frozen?

Contains:

- solution-free Problem Baseline;
- decision-relevant causal model;
- actor and scenario boundary;
- Outcome and Value Baseline;
- why now and cost of inaction;
- investment appetite;
- value-level non-goals and external hard constraints;
- optional, non-binding Phase Map;
- Active Phase state and baseline:
  - `GO` requires an authoritative Active Phase;
  - `DISCOVERY` may contain a candidate or explicitly unresolved Active Phase;
  - early `NO_GO` records `not_formed` when evidence never supported one;
- gate results;
- agent recommendation;
- human decision and rationale.

Only Gates 1–6 are embedded here. Gate 7 is an external disposition evaluation because it depends on the content digest and acceptance binding.

### Layer 3: Disposition Record

The third layer is exactly one of:

#### GO Handoff Candidate

Answers: what may Product Manager do, and when must the baseline reopen?

Contains:

- the actual blocking Director debt evaluation, including a nonzero result when the human chose `GO` despite an empirical blocker;
- Director authority lock;
- PM-owned elaboration boundary;
- bounded residual risks;
- evidence freshness and an explicit `valid_until`;
- reopen triggers;
- minimum supported consumer-contract version.

It references baseline and claim identifiers and must not duplicate their prose. It never asserts that debt is zero merely because the human selected `GO`; Gate 7 evaluates that condition. It is only a handoff candidate until the external envelope, acceptance binding, Gate 7, and readiness formula are valid.

#### DISCOVERY Contract

Contains the affected claim and decision, candidate answers, discriminating probe, evidence threshold, owner, budget and deadline, GO and NO_GO mappings, and stop condition. It emits no PM handoff.

#### NO_GO or DEFER Record

Contains the rejected or deferred decision object, applicable horizon, decisive evidence or unresolved condition, avoided investment where knowable, and reopen triggers. It emits no PM handoff. Active Phase is optional when the evidence never supported forming one.

### Case envelope and external control plane

The immutable payload contains the three layers above. A separate envelope or append-only control-plane record carries:

- Case ID and revision;
- canonical content digest computed over the payload, excluding the digest field itself;
- external human acceptance binding to that revision and digest;
- Gate 7 result;
- current Case and claim lifecycle projections;
- handoff readiness;
- PM receipt events.

This boundary prevents self-referential hashing and preserves accepted bytes.

## Immutability and Versioning

Use the lifecycle:

- `DRAFT`
- `READY_FOR_REVIEW`
- `ACCEPTED`
- `BLOCKED`
- `STALE`
- `SUPERSEDED`

Rules:

1. Human acceptance is an external append-only event that binds an exact human-readable summary to `revision + digest`.
2. Do not require a magic confirmation phrase as evidence of understanding.
3. Accepted artifact bytes never change.
4. New evidence creates a new revision with `supersedes`.
5. Append-only control-plane events mark old revisions or claims stale, superseded, or invalidated without rewriting accepted bytes.
6. Downstream artifacts referencing an invalidated digest stop until their authority is re-established.
7. `DISCOVERY` and `NO_GO` decisions remain reviewable records but cannot hand off to Product Manager.

## Product Manager Handoff

### Stage ownership

Replace shared mutable refinement of `brief.json` and `phase-prd.json`.

- Product Director owns an immutable Director Decision Case revision.
- Product Manager creates a separate PM Receipt and Product Definition Package.
- PM references the Director Case ID, revision, and digest.
- PM never mutates the Director artifact.

### Manual M0 protocol

1. Human explicitly invokes Product Manager with an accepted Director Case reference.
2. Product Manager verifies that the current handoff readiness is `READY`, records `PENDING`, and runs intake preflight.
3. Product Manager returns exactly one receipt outcome:
   - `ACCEPTED`: create a separate Product Definition Package.
   - `REJECTED`: cite exact gate, claim, revision, digest, authority, or compatibility failure.
4. Partial consumption is prohibited.
5. PM receipt is a separate consumer artifact; it does not mutate the Director Case.

### Return routing

| Finding | Owner |
|---|---|
| Target actor, real problem, value, or outcome is invalid | Return to Product Director |
| Active Phase value boundary must change | Return to Product Director |
| New evidence invalidates a locked Director claim | Return to Product Director |
| Product flow, object, state, rule, permission, or edge behavior is missing | Product Manager closes |
| Existing system assets and consumers affected are unknown | Impact Owner closes later |
| Technical solution or architecture is unknown | Architecture closes later |
| PM prefers another product solution inside the baseline | Product Manager decides; no return |

### Clean handoff test

Product Manager must be able to begin WHAT detailing without inventing:

- customer or target actor;
- concrete scenario;
- real problem;
- value and outcome;
- why now;
- Active Phase value boundary;
- value-level non-goals;
- external hard constraints.

## Failure Modes and Controls

| Failure mode | Control |
|---|---|
| Feature request becomes requirement without discovery | Preserve signal, reconstruct episode, Scenario Gate |
| Fixed questionnaire manufactures completeness | Adaptive next-best-question loop |
| Repeated “why” creates a fictional root cause | Competing hypotheses, counterfactuals, causal stop rule |
| Human confirmation launders assumptions into facts | Separate authority from epistemic state |
| Confidence score creates false precision | Evidence-fit assessment with limitations |
| One loud customer becomes a universal market claim | Applicability, denominator, and source-independence checks |
| Unknown unknowns are declared eliminated | Exposure conditions, observability, stop and reopen triggers |
| DISCOVERY becomes endless research | Probe contract, budget, evidence threshold, stop condition |
| NO_GO is treated as failure or forgotten | Time-bounded rationale and reopen triggers |
| Director GO is treated as build or release approval | Decision Contract Gate and explicit horizon |
| Human forces GO through empirical blockers | Human GO allowed; handoff remains blocked |
| PM receives upstream debt | Zero blocking Director debt and PM intake preflight |
| PM silently changes WHY | Stage-owned immutable packages and route-back contract |
| Form completion passes as quality | Behavioral evals, source traceability, adversarial cases |
| One Agent self-validates across roles | Separate consumer receipt and independent evaluation |

## Current Repository Gaps

Implementation planning must address, not paper over:

1. Current Product Director and Product Manager share refinement of `brief.json` and `phase-prd.json`, conflicting with stage-owned immutable packages.
2. Current Director-stage artifacts and generic canonical validation disagree on producer and required structure.
3. Structured success criteria are compressed into weak string fields during handoff.
4. Director business semantics and evidence context are not preserved as a clean downstream contract.
5. Current risk entries lack sufficient evidence, owner, decision impact, expiry, and reopen semantics.
6. Current quality checks can reward filled fields and plausible prose without proving source-backed claims.
7. Exact confirmation wording is stronger than confirmation-to-revision binding.
8. Current real-transcript evidence is insufficient to claim production-ready behavior.
9. Legacy `/product` evaluation surfaces and third-party PRD Skills may bypass the split role boundary.

These are implementation-scope findings. This design does not change current runtime behavior.

## Implementation Constraints

The later implementation plan must:

- preserve current user changes and unrelated dirty worktree content;
- define a staged migration from existing PM consumers;
- avoid two active canonical truths;
- version the new consumer contract;
- make unsupported old and new mixed revisions fail closed;
- keep third-party brainstorming and PRD Skills from writing standard-chain canonical artifacts;
- use English Skill instructions and contracts;
- allow runtime conversation language to follow the user context;
- keep verbatim customer evidence in its source language;
- avoid exact natural-language prose assertions in repository tests;
- use behavioral Skill evaluations and real consumer preflight evidence;
- retain manual invocation until the chain is proven.

## Evaluation Strategy

Use the official Skill creation loop after implementation approval:

1. Snapshot the existing Product Director as the baseline.
2. Draft the revised first-party Skill and contracts.
3. Create realistic prompts before assertions.
4. Run revised-Skill and baseline cases in the same turn.
5. Grade objective behavior and expose qualitative outputs to the human reviewer.
6. Analyze failures, token cost, interaction burden, and non-discriminating assertions.
7. Iterate until the human accepts the behavior.
8. Optimize Skill triggering only after behavior is stable.

### Required scenario classes

- vague customer quote with missing context;
- solution-shaped feature request;
- one loud customer with no representative evidence;
- conflicting qualitative and quantitative evidence;
- hidden exception handler or cost bearer;
- strategic opportunity without a prior exact event;
- real problem with a cheaper non-product response;
- human GO override while an empirical blocker remains;
- valid GO with PM-ready WHY;
- PM rejection caused by a stale or mismatched Director digest;
- PM-owned detail incorrectly routed back to Director;
- simple or frozen implementation request that should bypass Product Director.

### Decision oracle matrix

Each evaluation must declare its expected state tuple and forbidden behavior before execution. At minimum:

| Scenario | Gates 1–6 | Agent recommendation | Human decision | Gate 7 | Handoff readiness | PM receipt | Required oracle |
|---|---|---|---|---|---|---|---|
| Valid evidence-backed GO | all `PASS` | `GO` | `GO` | `PASS` | `READY` | `ACCEPTED` after preflight | PM starts without inventing or changing WHY |
| Human GO while an empirical blocker remains | at least one `BLOCKED`, none `FAILED` | `DISCOVERY` | `GO` | `BLOCKED` | `BLOCKED` | `NOT_REQUESTED` | human choice is preserved; no waiver, handoff, or PM artifact exists |
| Governed DISCOVERY | at least one `BLOCKED`, none `FAILED` | `DISCOVERY` | `DISCOVERY` | `PASS` for complete probe contract | `NOT_APPLICABLE` | `NOT_REQUESTED` | probe has threshold, owner, budget, mappings, and stop condition; no PM handoff exists |
| Decisive NO_GO before an Active Phase forms | at least one `FAILED` | `NO_GO` | `NO_GO` | `PASS` for complete NO_GO record | `NOT_APPLICABLE` | `NOT_REQUESTED` | Active Phase is explicitly absent; no invented phase or PM handoff exists |
| Accepted digest becomes stale or invalid | previously all `PASS` | historical `GO` | historical `GO` | current projection `BLOCKED` | `BLOCKED` | `INVALIDATED` | downstream stops; accepted Case and historical receipt bytes remain unchanged |
| PM submits altered Director bytes | all `PASS` before alteration | `GO` | `GO` | `BLOCKED` on digest mismatch | `BLOCKED` | `NOT_REQUESTED` | altered bytes are rejected; Director Case is not rewritten |
| New evidence requires a Director revision | recomputed on new revision | recomputed | new decision required | not `PASS` until new binding | `BLOCKED` | old receipt `INVALIDATED` | new revision supersedes by reference; old accepted bytes remain unchanged |
| PM-owned product detail is incomplete | all `PASS` | `GO` | `GO` | `PASS` | `READY` | `ACCEPTED` | PM closes the WHAT detail; Director baseline is not reopened |
| Director debt is relabeled `BOUNDED` or `DOWNSTREAM_OWNED` without candidate-answer and WHY-change proof | Gate 5 `BLOCKED` | `DISCOVERY` | any | `BLOCKED` for human `GO`, otherwise disposition-specific | never `READY` | `NOT_REQUESTED` | relabeling does not reduce debt; no PM receipt or Product Definition Package exists |
| Consumer contract is unsupported | all `PASS` | `GO` | `GO` | `BLOCKED` | `BLOCKED` | `NOT_REQUESTED` | no partial consumption or compatibility guess is allowed |
| Simple or frozen implementation request bypasses Director | not evaluated | not applicable | not applicable | not evaluated | `NOT_APPLICABLE` | `NOT_REQUESTED` | routing evidence explains why Product Director was not invoked |

### Behavioral acceptance dimensions

- scenario fidelity;
- evidence traceability;
- epistemic honesty;
- causal quality and falsifiability;
- no interrogation;
- no pretend closure;
- no solution or role leakage;
- correct `GO / DISCOVERY / NO_GO`;
- human authority preserved without evidence waiver;
- zero blocking Director debt at handoff;
- immutable revision and digest behavior;
- PM consumer acceptance without WHY invention;
- correct route-back behavior;
- acceptable interaction and context cost.

The final `qft-tenants` acceptance scenario runs only after generic and adversarial cases pass.

## Design Acceptance Criteria

This design is ready for implementation planning when the human confirms that it:

- captures the intended Product Director role;
- defines the real-scenario discovery core;
- correctly limits first-principles and causal depth;
- operationalizes knowns, unknowns, evidence, and conflicts;
- preserves human final investment authority without evidence laundering;
- defines complete GO, DISCOVERY, and NO_GO semantics;
- requires every Director gate to pass before PM handoff;
- defines one logical Director Decision Case;
- replaces shared mutable PD/PM artifacts with stage-owned immutable packages;
- defines clean PM receipt and route-back boundaries;
- reserves the target case for later whole-chain validation.

## Next Step After Final Review

After the human reviews and accepts this document:

1. use `writing-plans` to create a migration-aware implementation plan;
2. use the official `skill-creator` workflow to revise Product Director;
3. run baseline and revised-Skill evaluations;
4. obtain human review of the evaluation outputs;
5. only then promote the revised role contract and continue to Product Manager design.

Do not modify runtime Skills, schemas, validators, or standard-chain artifacts before final document review.
