# Skill Quality Standard MVP Phase 1 Design

## Background

The current Skill quality discussion started from a concrete concern: whether `delivery-owner` is a real delivery control plane or a loose explanatory document. That question exposed a larger problem. The repository does not yet have a small, stable, and executable way to judge whether a first-party Skill is clean, focused, contract-driven, and auditable.

Existing materials mix several kinds of truth:

- official or upstream Skill principles, such as progressive disclosure and with/baseline evaluation;
- local runtime contracts, such as hooks, schemas, completion checks, and standard-chain artifacts;
- local governance policies, such as context budget heuristics and lifecycle thresholds;
- historical archive evidence and pilot eval results;
- `skill-harness` audit dimensions and output contracts.

When these are not separated, a local heuristic can look like a best practice, readiness evidence can look like effectiveness evidence, and an audit tool can become a second source of standards.

## Problem

Phase 1 solves a deliberately narrow problem:

How do we judge whether a first-party Skill runtime surface is well formed enough to be loaded, followed, and audited?

This is not a lifecycle-retention problem yet. It is a Skill runtime-surface quality and audit-boundary problem. A Skill can have lifecycle metadata and still be noisy, over-broad, unclear, or hard to audit. Conversely, a clean Skill runtime surface does not prove the Skill still has long-term value.

## Goal

Define a Minimum Viable Skill Quality Standard for first-party standard-chain Skills and `skill-harness`.

The MVP must let a reviewer answer whether a Skill has:

- a clear responsibility;
- an accurate trigger contract;
- runtime instructions free of stale or explanatory noise;
- progressive loading boundaries;
- contract-style references to scripts, references, schemas, or artifacts;
- a clear split between LLM judgment and engineering validation;
- consumable output and evidence contracts;
- permission and script boundaries;
- D9 readiness represented without being mistaken for effectiveness.

The MVP also governs `skill-harness` as the read-only assurance layer that consumes the standard. It must not define the standard, self-certify, or make final lifecycle decisions.

## Scope

Phase 1 covers standard-chain first-party Skills and `skill-harness` only. It does not claim to cover every directory under `shared/skills/*`, community Skills, or third-party Skill packages.

`contracts/standard-chain.yaml` is the scope source for standard-chain roles. Phase 1 applies to active first-party Skill implementations that correspond to those roles, with existing runtime mapping used only to resolve naming differences. `skill-harness` is added because it audits the standard; it is not itself a standard-chain role.

The design scope is:

- Skill runtime-surface quality: content noise, role clarity, trigger boundary, progressive loading, contract-style references, LLM/engineering boundary, output contract, permission boundary, and evidence chain.
- Minimal D9 readiness: D9 remains the existence-value entry point, but Phase 1 only prevents readiness from being misread as proven effectiveness.
- `skill-harness` governance: `skill-harness` is a read-only assurance layer that maps its audit findings to the standard and cannot become a second quality framework.
- Eval posture: creation, update, and trigger evals should reuse the upstream `skill-creator` style where possible. Phase 1 does not create a new eval platform.
- Double-source prevention: local heuristics, including line-count budgets, cannot be hard quality standards unless they have a clear execution form, evidence scope, and reason to remain.

## Non-Goals

Phase 1 does not define a complete Skill lifecycle system. It does not introduce final `retain`, `optimize`, or `retire` decision rules.

Phase 1 does not build a new eval runner, full Eval Playbook, or full Evidence Ledger. It only establishes enough eval posture to prevent readiness and small pilot evidence from being treated as long-term effectiveness.

Phase 1 does not batch-rewrite all Skills, produce a global Skill ranking, or create a numeric scoring model.

Phase 1 does not fully govern community Skills. Community Skill governance remains a separate concern involving source pinning, compatibility, license, adapter, and update policy.

## Quality Model

The MVP keeps D1-D8 as the main Skill runtime-quality surface. D9 is explicitly separate.

### Skill Runtime Surface

A Skill runtime surface includes the `SKILL.md` frontmatter and body plus the active-path resources it names or relies on: references, scripts, schemas, manifests, examples, tests, and canonical artifacts when they affect runtime behavior or audit evidence.

A Skill runtime surface is healthy when it gives the model only the instructions needed for the active runtime path, and delegates low-frequency detail to named resources.

The surface should make the Skill's role obvious. A delivery control Skill should govern delivery flow; an audit Skill should audit; a developer Skill should implement within its scope. Role drift is a quality problem even if individual instructions are useful.

The `description` is the routing contract. It should explain when the Skill should trigger, what it does, and where adjacent Skills should win instead.

The body should use progressive loading. `SKILL.md` contains the entry flow, hard gates, and decision points. Detailed protocols, examples, schemas, scripts, and templates live in resources and are loaded or executed only when relevant.

References must be contractual, not decorative. A reference to a file should make clear when to read or use it, what purpose it serves, and what output or failure state it affects. A script reference should have an owner, input boundary, output boundary, timeout or execution expectation, and failure interpretation.

The Skill should separate LLM work from engineering work. Semantic judgment, intent classification, orchestration, and risk explanation belong to the LLM. Stable checks over files, schemas, paths, artifacts, states, and preconditions belong to scripts, schemas, hooks, or validators when available.

Outputs must be consumable. If a Skill emits an artifact, field, status, or decision, the downstream consumer or human review purpose should be clear. Structured output should not be introduced solely because it looks tidy.

Claims must be evidence-backed. Completion, blocking, sign-off, review, or audit claims must point to exact files, commands, user decisions, eval outputs, or other replayable evidence.

### Finding Boundary

Phase 1 uses findings, not numeric scores.

`FAIL` is reserved for issues that block a Skill from being reliably loaded, followed, or audited. Examples include role mixing that changes authority, missing or contradictory trigger boundaries, active runtime noise that changes execution behavior, resource references without a usable contract, missing evidence for completion or blocking claims, unsafe or undeclared script/permission boundaries, and `skill-harness` overreach.

`COMMENT` or warning-level findings are used for non-blocking quality risks. Examples include style inconsistency, minor repetition, unclear but non-blocking wording, line-count or context-size concerns without evidence of runtime confusion, and improvement suggestions that do not affect role, trigger, loading, permission, output, or evidence contracts.

Every finding must map to one MVP quality concern. `skill-harness` audit dimensions may describe the output shape, but they cannot be the independent reason a finding blocks.

### D9 Readiness Boundary

D9 asks whether a Skill still deserves to exist and be maintained. Phase 1 does not answer that full question.

In Phase 1, D9 checks are readiness checks only. `eval-type`, `evals/evals.json`, anchors, grader dimensions, or `lifecycle-review.json` can show that a review frame exists. They do not prove effectiveness, retention, or retirement.

Any standard text or audit finding must preserve this distinction. Readiness evidence may support a need for further evaluation. It must not be treated as `retain`, `retire`, or proven-effectiveness evidence.

## Harness Governance

`skill-harness` is part of the MVP because it will consume and check the standard during audits.

Its role is:

- read target Skill files, references, scripts, manifests, tests, and D9 readiness artifacts;
- apply hard gates and produce evidence-backed findings;
- keep Markdown as the default human audit output;
- upgrade to JSON only when a named machine consumer, validation path, and drop condition exist.

Its role is not:

- define the Skill quality standard;
- create lifecycle decisions;
- certify its own correctness;
- promote historical or migration fields into active audit output;
- use its dimensions as a second quality framework.

`skill-harness` audit dimensions may remain useful as output dimensions, but they must map back to the quality standard rather than replace it. For example, trigger findings map to trigger-contract quality, loading findings map to progressive loading, and engineering-control findings map to consumer and validation contracts.

## Eval Posture

Phase 1 reuses `skill-creator` style evaluation as the default reference posture for creation, update, and trigger testing. The useful parts are realistic prompts, with/baseline comparison, old-version snapshots, assertions where objective checks exist, human review for subjective quality, benchmark summaries, and trigger evals with positive, negative, and near-miss cases.

Phase 1 does not rebuild that system locally.

The MVP only adds one integrity boundary: eval evidence must not be overstated. Small samples, readiness metadata, and non-blind comparisons are not lifecycle proof. Expected outputs, assertions, and preference anchors should be grader-side material, not task answers leaked into executor prompts.

## Handling Local Heuristics

Local heuristics are allowed only when their identity is clear.

A local heuristic can be a warning, review prompt, or temporary local governance policy. It should not become a hard quality standard unless it has a named execution form and evidence scope.

Line-count budgets such as `250/200/150/100` are not Phase 1 hard standards. The underlying concern is real: a Skill runtime surface can overload context or hide low-frequency detail in the active path. Phase 1 addresses that concern through progressive loading, runtime noise checks, and contract-style resource boundaries rather than fixed line-count pass/fail rules.

## Validation Samples

Phase 1 uses two samples to verify the MVP.

`delivery-owner` validates whether the quality model can identify a control-plane Skill. The sample should answer whether the Skill governs delivery flow, separates dispatch from implementation, uses canonical artifacts contractually, and avoids becoming a loose explanation of the delivery process.

`skill-harness` validates whether the audit executor is itself governed. The sample should answer whether it stays read-only, consumes standards rather than inventing them, maps audit dimensions back to the standard, and avoids self-certification or lifecycle overreach.

The samples validate the MVP's usability. Their outcomes must not be generalized into full lifecycle rules.

Each sample validation must produce reviewable findings, not just a narrative claim. The findings must include verdict, mapped MVP quality concern, evidence, impact, recommendation, and whether any `skill-harness` dimension is only an output label rather than the source of authority.

## Acceptance Criteria

Phase 1 is successful when the MVP can evaluate `delivery-owner` and `skill-harness` without introducing a second source of truth.

A reviewer should be able to produce `PASS`, `FAIL`, or `COMMENT` findings for Skill runtime-surface quality using the same standard language across both samples.

The standard must distinguish hard quality issues from warnings or guidance. It must not treat fixed line-count budgets, small eval samples, or D9 readiness metadata as hard proof of quality or effectiveness.

`skill-harness` must be described and tested as a read-only assurance layer. It may report evidence gaps and contract violations, but it must not define the standard, certify itself, or make final lifecycle decisions.

Every sample finding must map to an MVP quality concern. Findings that only cite `skill-harness` dimensions, historical labels, line-count thresholds, or D9 readiness metadata as authority do not satisfy Phase 1.

D9 readiness findings must not generate `retain`, `retire`, or proven-effectiveness conclusions.

The result should be small enough to implement without redesigning the full lifecycle system, eval platform, or community Skill governance.
