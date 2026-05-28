# Standard-chain Flow & Instruction Control Calibration Plan

## Goal

Calibrate the review method before launching a full review. The calibration must prove that reviewers can find evidence-backed flow and instruction-control issues, not generic advice.

## Contract

Use:

- `docs/superpowers/specs/2026-05-28--standard-chain-flow-instruction-control-review--contract.md`

## Calibration Scope

The calibration uses two narrow targets.

### Flow Slice

Slice:

> `developer -> verify -> QA -> delivery-owner`

Why this slice:

- It contains implementation proof, verification, QA, failure handling, and final coordination.
- It is where fake completion and weak evidence are most dangerous.
- It is directly relevant to one human owner plus agent team delivery.

Primary files:

- `contracts/standard-chain.yaml`
- `contracts/standard-chain-field-consumption.yaml`
- `shared/runtime/standard-chain-catalog.json`
- `shared/skills/developer/SKILL.md`
- `shared/skills/verify/SKILL.md`
- `shared/skills/qa/SKILL.md`
- `shared/skills/delivery-owner/SKILL.md`
- related schemas and templates under those skill directories

Dogfood artifacts may be used only as evidence of observed flow behavior. They are not the center of the review.

### Skill Sample

Skill:

> `shared/skills/delivery-owner/SKILL.md`

Why this skill:

- It owns coordination, dispatch, blocker handling, signoff preparation, and human decision boundaries.
- It is the highest-risk place for fake closure or agent self-approval.
- Its language must precisely distinguish dispatch, fix, verification, QA, signoff, and user decision.

Reference skill for quality comparison:

- `/Users/lijieli/.claude/skills/brainstorming/SKILL.md`

Use `brainstorming` as a behavior-control reference, not a template to copy.

## Calibration Reviewers

Run three reviewers.

### 1. Flow Slice Reviewer

Task:

- Review the flow slice for input/output closure, authority consistency, state transition correctness, trace continuity, failure recovery, and operational recovery.
- Produce only FLOW issues.

### 2. Instruction Control Reviewer

Task:

- Review `delivery-owner/SKILL.md` sentence by sentence.
- Compare sentence control quality to the `brainstorming` reference.
- Produce only INSTRUCTION_CONTROL issues.

### 3. Cross-Reviewer

Task:

- Review the issues from the first two reviewers.
- Reject generic, style-only, duplicate, or weak-causal findings.
- Reclassify severity when needed.
- Identify whether an issue is actually flow-rooted, skill-rooted, or both.

## Calibration Output

Write one report:

- `docs/reports/standard-chain-flow-instruction-control-calibration-2026-05-28.md`

The report must include:

1. calibration scope
2. accepted FLOW issues
3. accepted INSTRUCTION_CONTROL issues
4. rejected findings and why they were rejected
5. reviewer consistency notes
6. whether the review contract is sharp enough for full review
7. required contract adjustments before full review

## Calibration Pass Criteria

Calibration passes only if:

- at least one accepted FLOW issue has exact contract/schema/skill/artifact evidence
- at least one accepted INSTRUCTION_CONTROL issue cites an exact sentence or paragraph
- every accepted issue has impact on one human plus agent team real delivery
- every accepted P0/P1 has concrete repair direction
- the cross-reviewer rejects weak findings rather than preserving all output
- no accepted issue uses homepage readiness as the center of the claim

## Stop Conditions

Stop before full review if:

- reviewers mostly produce broad opinions without exact locations
- skill issues focus on structure labels rather than sentence-level control value
- flow issues focus on dogfood readiness instead of flow capability
- severity labels are inconsistent or unsupported by impact
- repair directions are vague

If any stop condition occurs, revise the review contract before launching full review.
