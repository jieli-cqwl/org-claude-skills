# Team-Use Readiness Acceptance

Use this reference before issuing or accepting a team-use readiness verdict. It is a final acceptance lens over the scorecard, not an extra scoring dimension.

Readiness state:

- `contract-hardened`: deterministic report, evidence, and handoff gates exist, but semantic audit capability is not yet proven.
- `conditional-team-use`: core gates pass, but one or more acceptance capabilities still need broader eval or field evidence.
- `team-ready`: all five capabilities below are proven by current evidence and the formal report validator passes.

The `brainstorming` benchmark matters because its structure is a target-directed state machine: each loaded sentence moves the agent toward a clearer goal, blocks a common wrong turn, or defines the next handoff state.

## Scenario Capability

Success standard: The audit names the real user scenario, target Skill consumer, expected decision, and why a team should use the audit instead of direct prompting or generic code review.

Failure mode: The report scores a Skill without first proving what problem the Skill is supposed to solve, who consumes the result, or what “ready” means for that team.

Required evidence: Target Skill trigger, expected output, consumer path, and completion standard cited from active files or current user-supplied scope.

## Structure-Content Coherence

Success standard: The audit checks whether each major structure gives the agent a target, next action, evidence requirement, stop condition, or handoff state that later work consumes.

Failure mode: The audit treats a checklist, flowchart, table, section count, or borrowed `brainstorming` shape as proof of quality. A checklist is not evidence by itself.

Required evidence: For each praised or criticized structure, name the target state it creates, the next action that consumes it, and the failure that appears when that structure is missing, duplicated, or decorative.

## Evidence Integrity

Success standard: Findings distinguish observed facts, inferred claims, and verification results. P0/P1 findings survive direct refutation checks and severity calibration.

Failure mode: The audit accepts stale paths, fake checked surfaces, unrelated command output, title-only summaries, or severity labels unsupported by current file evidence.

Required evidence: Current `path:line` citations, structured evidence checks for P0/P1, validator output, and matching `executed_verification.supports` for E4 claims.

## Repairable Handoff

Success standard: The output gives a separate repair window enough information to act without replaying the whole audit.

Failure mode: The report provides a verdict or scorecard but leaves the repair owner guessing which file, behavior, downstream consumer, or verification proves the fix.

Required evidence: Each finding includes impact, repair target, verification hint, and a handoff target grouped by file or owned artifact.

## Attention Economy

Success standard: Every loaded instruction, reference, gate, and output field has a consumer or a blocking purpose.

Failure mode: Hard gates contain non-blocking detail, references are loaded without a retrieval target, roles sound professional but do not constrain decisions, or prose repeats what deterministic validators already enforce.

Required evidence: For each large block, identify its consumer. If the consumer is a schema, script, test, or hook, keep the prose as route/context only and let the deterministic artifact enforce the rule.
