# Content Order Contract

Trigger: Use this when checking whether a Skill teaches the runtime in the right order.
Read: `SKILL.md`, referenced runtime files, examples, migration notes, and any generated candidate text.
Expect: Mandatory runtime limits and goal/completion boundaries come before role detail, flow detail, examples, and optional background.
Consume: Skill Harness reviewers and deterministic content-order gates consume this order check.
Evidence: Cite the first misplaced section or line and the earlier section where the blocking limit should appear.
Sync: Update this file when required section names or order rules change.

## Order

1. Frontmatter that identifies the active Skill and read-first tool boundary.
2. Title and HARD-GATE.
3. Goal contract, exclusions, input boundary, and completion boundary.
4. Role and default flow.
5. Upgrade gates and specialized candidate gates.
6. Output and completion contracts.
7. References.
8. Examples or background only when they have a current runtime consumer.

## Failure Pattern

Mark content order as FAIL when a hard gate, goal boundary, or completion boundary appears after examples, history, migration detail, scoring notes, or optional explanation. The runtime should encounter non-negotiable limits and success criteria before flexible guidance.
