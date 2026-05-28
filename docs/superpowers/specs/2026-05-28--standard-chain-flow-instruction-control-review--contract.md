# Standard-chain Flow & Instruction Control Review Contract

## Goal

Find the flow and instruction problems that prevent the `product-director -> delivery-owner` chain from supporting real requirement delivery by one human owner plus an agent team.

This review is a problem-discovery review. It does not decide pilot admission, production readiness, or whether an existing dogfood sample is acceptable.

## North Star

A finding is useful only when it explains how the current chain could fail to support real delivery by one human owner plus an agent team.

Every accepted finding must include:

- exact location
- evidence
- impact on the north star
- severity
- repair direction

Findings without all five parts are discarded.

## Review Directions

### 1. Flow Correctness Review

Question:

> Can information, responsibility, state, evidence, and decisions flow correctly from product-director to delivery-owner, and stop or recover when they should?

Inspect:

- `contracts/standard-chain.yaml`
- `contracts/standard-chain-field-consumption.yaml`
- `shared/runtime/standard-chain-catalog.json`
- schemas and templates used by standard-chain artifacts
- relevant `shared/skills/*/SKILL.md` handoff, input, output, and status sections
- active artifacts or dogfood samples only as evidence of flow behavior

Checks:

1. Role chain correctness: no missing role, duplicate responsibility, wrong ordering, or role that only produces documents without delivery responsibility.
2. Stage-dependent input closure: kickoff, execution, verification, QA, closeout, and signoff inputs must be checked at the stage where they are required. Future artifacts must not be global kickoff requirements.
3. Input/output closure: every required downstream input is produced upstream, and every upstream output has a downstream consumer or explicit archival purpose.
4. Authority consistency: each business fact, state, artifact, and decision has one clear authority across contract, catalog, schema, and skill text.
5. Terminal semantics: an artifact with any downstream consumer is not terminal unless the contract gives an explicit archival meaning and no further flow decision depends on it.
6. State transition correctness: continue, block, fail, needs-user-decision, ready-for-signoff, ready-for-commit, delivered, and done states have non-overlapping meanings and explicit transition rules.
7. State vocabulary mapping: canonical JSON, status cards, reports, scripts, and handoff text must map status words to the same state machine.
8. Trace continuity: goal, acceptance criteria, risk, assumption, design decision, task, evidence, verification, QA, and signoff can be traced without semantic drift.
9. Set coverage: scripts that validate collections must prove complete coverage, not only existence of one matching artifact. Examples: every in-scope task has current developer-report and verify-result; every QA obligation has an obligation result.
10. Failure recovery: verify fail, QA fail, user correction, AC change, evidence gap, and repeated non-convergence return to the right owner and require fresh proof where needed.
11. Operational recovery: after interruption, the human owner can identify current state, blocking reason, responsible owner, active artifact, and next action without reading the whole history.

### 2. Instruction Control Review

Question:

> Does each skill use only high-value language that precisely controls agent behavior, prevents likely failure modes, and produces verifiable, handoff-ready artifacts?

`brainstorming` is the quality reference because its language controls model behavior rather than merely documenting a process. Reviewers must analyze the intent behind each sentence, not copy its structure.

Inspect:

- frontmatter description
- hard gates and stop rules
- checklists and process flow
- user interaction rules
- input/output requirements
- evidence and completion rules
- handoff and next-skill transitions
- anti-pattern and failure-mode guidance
- references only when needed to decide whether SKILL.md is overloaded or under-specified

Sentence-level checks:

1. Behavior control value: what behavior does this sentence control, and would deleting it increase drift?
2. Failure-mode defense: what likely agent mistake does this sentence prevent?
3. Responsibility fit: does this sentence belong to this skill, or does it steal another role's authority?
4. Trigger precision: when does this instruction apply, and when must it not apply?
5. Action object: who acts, on what artifact or state, producing what output?
6. Evidence binding: words like done, pass, verify, confirm, approve, complete, ready, delivered, accepted, closed, authorized, and consumed must bind to evidence, a named owner action, or a human decision.
7. State endpoint: success, failure, blocked, needs-user-decision, ready-for-commit, delivered, and done outcomes must hand off to a named next owner or artifact.
8. Escape-path closure: the sentence must close common rationalizations such as "too simple", "just continue", "close enough", "mock is enough", "owner changed so progress happened", "logical reference is enough", or "I can sign off myself" when those risks apply.
9. Attention density: remove or move text that explains without controlling behavior, repeats earlier rules, uses vague adjectives, or adds structure without decision value.
10. Flow compatibility: skill instructions must not define inputs, outputs, state, evidence, or authority differently from the flow contracts.

Instruction issues may overlap flow issues. If the root flow risk is enabled by a specific skill sentence, report it as an instruction issue and name the flow consequence.

## Severity

Use issue severity, not GO/NO-GO.

- `P0`: can cause wrong delivery, fake signoff, failure continuing as success, agent self-approval, old evidence being reused after target change, or partial work being represented as phase/project completion.
- `P1`: can significantly reduce delivery reliability or make the chain unsafe for real dogfood without repair.
- `P2`: can increase ambiguity, human load, rework, or drift; track during dogfood if not fixed immediately.
- `P3`: wording, density, or maintainability issue that should be polished but does not materially change delivery safety.

Severity examples:

- P0: user AC changes but old verify/QA evidence remains acceptable.
- P0: QA passes a phase when not every in-scope task has current verify PASS.
- P0: a skill lets an agent self-clear required owner action or signoff.
- P1: READY_FOR_COMMIT is reported as DELIVERED before commit result exists.
- P1: an artifact is marked terminal while QA or delivery-owner still consumes it.
- P2: frontmatter description includes process details that can distract from正文 gates.

## Issue Types

- `FLOW_ROLE_ISSUE`
- `FLOW_IO_ISSUE`
- `FLOW_AUTHORITY_ISSUE`
- `FLOW_TERMINAL_ISSUE`
- `FLOW_STATE_ISSUE`
- `FLOW_TRACE_ISSUE`
- `FLOW_RECOVERY_ISSUE`
- `FLOW_OPERABILITY_ISSUE`
- `FLOW_SET_COVERAGE_ISSUE`
- `SKILL_TRIGGER_ISSUE`
- `SKILL_RESPONSIBILITY_ISSUE`
- `SKILL_GATE_ISSUE`
- `SKILL_PROCESS_ISSUE`
- `SKILL_OUTPUT_ISSUE`
- `SKILL_EVIDENCE_ISSUE`
- `SKILL_STATE_WORD_ISSUE`
- `SKILL_SENTENCE_DENSITY_ISSUE`
- `SKILL_FLOW_COMPATIBILITY_ISSUE`

## Issue Output Format

```json
{
  "issue_id": "FLOW-001 or SKILL-001",
  "direction": "FLOW | INSTRUCTION_CONTROL",
  "severity": "P0 | P1 | P2 | P3",
  "issue_type": "one issue type",
  "location": "file path plus line or JSON pointer when available",
  "claim": "specific problem",
  "evidence": ["file path, command output, or missing-evidence statement"],
  "impact_on_goal": "how this blocks or weakens one human + agent team real delivery",
  "repair_direction": "concrete repair direction, not a vague improvement",
  "reference_gap": "for instruction issues: what the reference behavior-control style does better, or null for flow-only issues",
  "reviewer_confidence": "high | medium | low"
}
```

## Valid Finding Rules

A finding is rejected when it:

- lacks a concrete location
- lacks evidence
- only says wording is unclear without explaining behavior risk
- only prefers a different style
- only asks for more structure without showing control value
- focuses on homepage dogfood readiness instead of chain capability
- proposes a fix unrelated to the north star
- duplicates another finding without adding new evidence or impact

## Non-goals

Do not decide pilot admission. Do not repair issues during review. Do not turn this into a documentation completeness audit. Do not judge a dogfood sample as the center of the review. Do not require every skill to copy the `brainstorming` structure; use `brainstorming` to judge language control quality.

## Calibration Before Full Review

Before full review, run a calibration pass on a narrow slice:

- one flow slice with high failure risk
- one role skill with high control risk

Calibration passes only if reviewers produce specific, evidence-backed issues whose severity and repair direction survive cross-review.

## Full Review Completion Criteria

The full review is complete only when:

- all P0/P1 findings have evidence and repair direction
- P0/P1 findings are cross-reviewed by another reviewer
- skill findings cite exact sentence or paragraph locations
- flow findings cite exact contract, schema, artifact, status, or handoff locations
- duplicate and style-only findings are removed
- the final roadmap orders P0 before P1, tracks P2, and separates P3 polishing
- one follow-up review pass finds no new P0/P1 within the same scope
