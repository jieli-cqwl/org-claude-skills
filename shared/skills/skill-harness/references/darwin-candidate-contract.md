# Darwin Candidate Contract

Trigger: Use this when auditing a Darwin-generated Skill candidate, mutation, or improvement proposal.
Read: Candidate `SKILL.md`, changed references, claimed behavior benefit, proof command, rollback notes, and any scoring output.
Expect: The candidate is accepted only after independent boundary, order, evidence, permission, runtime noise, behavior benefit, and rollback checks.
Consume: Human reviewers and deterministic Darwin gates consume this checklist before accepting a candidate into active runtime.
Evidence: Record exact `file:line` evidence plus the proof command that demonstrates the claimed behavior benefit or rejection reason.
Sync: Update this file when Darwin scoring dimensions, rollback policy, or candidate acceptance rules change.

## Required Checks

- content order: HARD-GATE and core runtime limits appear before optional explanation, examples, or history.
- permission boundary: The candidate keeps audit mode read-first and names any write scope before proposing changes.
- evidence chain: Every FAIL or acceptance claim has `file:line`, impact, recommendation, and proof command.
- runtime noise: Legacy, migration, and historical text is removed from active runtime unless it has a current consumer.
- behavior benefit: The candidate states the user-visible or reviewer-visible behavior improvement, not just score movement.
- rollback boundary checks: The candidate names the files to revert and the command that proves rollback restored the prior contract.

## Acceptance Rule

Do not accept self-certification. Treat generated scores, summaries, and candidate notes as inputs to inspect. Acceptance requires independent evidence and a fresh proof command.
