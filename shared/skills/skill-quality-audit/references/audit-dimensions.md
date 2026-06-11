# Audit Dimensions

Use 10-point scores. Score the current Skill as it exists, not the maintainer's intent.

If required target surfaces cannot be inspected or evidence is too unstable to score core dimensions, return `blocked` before quality scoring. In that case, use `0` only as a not-scored sentinel for affected dimensions and state the blocking evidence in each reason.

## Evidence Levels

| Level | Meaning |
| --- | --- |
| E0 | No evidence, only opinion or memory. |
| E1 | Weak text clue, not tied to an active runtime or consumer. |
| E2 | Direct file evidence in the target package or active repo path. |
| E3 | Direct file evidence plus active consumer, test, schema, script, or runtime path. |
| E4 | E3 plus executed verification output proving the behavior or failure. |

P0/P1 findings require E2 or higher, structured `evidence_checks` that re-open the cited current file line and match the expected snippet, `claim_review.status: supported`, and matching `severity_calibration`. A completion verdict requires E3 or higher for the dimensions that decide the verdict.

## Severity

| Severity | Meaning |
| --- | --- |
| P0 | Blocks safe team use or can make the Skill route, write, or complete incorrectly. |
| P1 | Major defect that can mislead output, verification, handoff, or downstream consumers. |
| P2 | Repairable quality problem with bounded impact. |
| P3 | Polish, clarity, or future hardening item. |

## Dimensions

| Dimension | Weight | 9-10 | 7-8 | 5-6 | 0-4 |
| --- | ---: | --- | --- | --- | --- |
| Real Use Capability | 10 | Real scenario, user value, expected output, and team reason are explicit. | Mostly clear with minor missing boundary. | Plausible but generic or consumer is weak. | No clear reason to use the Skill. |
| Trigger And Routing | 10 | Runtime mode, description, and entry boundary route the request without stealing adjacent Skill work. | Good routing with minor ambiguity. | Overbroad, underbroad, or mixes neighboring work. | Runtime can misroute the request. |
| Instruction Contract | 15 | Sentences are executable contracts with conditions, objects, outputs, evidence, and failure states. | Most key instructions are executable. | Many advice-like or vague instructions remain. | The Skill reads like prose or ambiguous policy. |
| Content Behavior Induction | 15 | Clear, low-noise content reliably induces the agent to follow the user-confirmed capability standard, ask required confirmations, preserve unknowns, and avoid premature verdicts. | Main behavior is induced with minor unproven edges. | Instructions are clear but the behavior chain or failure-mode coverage is only partially proven. | Content can make the agent execute clean prose while still failing the real task. |
| Workflow Causality | 10 | Steps follow the real order of work and each output feeds the next consumer. | Order is usable with minor gaps. | Steps are mixed, repetitive, or weakly causal. | The workflow cannot reliably guide execution. |
| Output And Handoff | 10 | Output format, consumer, repair target, and verification are explicit. | Output is clear but handoff can be sharper. | Output exists but downstream must infer. | No consumable output contract. |
| Determinism And Validation | 10 | Enumerated checks are handled by schema, script, test, gate, or hook. | Most deterministic checks are automated. | Several deterministic checks remain in prose. | LLM prose replaces deterministic control flow. |
| Runtime Integration | 10 | Adapter, allowed tools, install, runtime surface, gates, and active references align. | Minor runtime/documentation gaps. | Runtime path or active references are partly stale. | Install/routing/test paths contradict the Skill. |
| Evidence And Evals | 5 | Tests/evals cover positive, negative, boundary, and regression behavior. | Main behavior is covered. | Some coverage exists but weakly maps to risk. | No meaningful verification loop. |
| Noise And Maintainability | 5 | Every loaded sentence has a consumer or action. | Minor excess. | Noticeable duplication or method prose. | Bloated, drifting, or history-heavy. |

## Verdict Rules

- `blocked`: required target surfaces cannot be inspected, a P0 prevents safe continuation, or evidence is too weak or unstable to score core dimensions.
- `unfit`: any P0 remains after inspection, Instruction Contract < 5, or Runtime Integration < 5.
- `conditional`: no P0, but at least one P1 remains, total score < 8, or Instruction Contract < 7.
- `fit`: no P0/P1, Instruction Contract >= 7, Content Behavior Induction >= 7, Runtime Integration >= 7, Evidence And Evals >= 7, supported `content_behavior_audit` for every confirmed target, and total weighted score >= 8.

P0 forces `blocked` or `unfit`. For scored verdicts, Instruction Contract < 7 caps verdict at `conditional`, and Instruction Contract < 5 forces `unfit`. Instruction clarity and noise control are necessary but not sufficient; Content Behavior Induction must prove that the clear instructions support the user-confirmed capability standard. `blocked` requires blocked scope evidence or a P0 finding; do not use it to avoid an unfavorable scored verdict.
