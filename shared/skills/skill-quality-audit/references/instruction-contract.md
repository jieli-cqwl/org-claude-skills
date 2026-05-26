# Instruction Contract Audit

An instruction is acceptable only when the next agent can execute it without guessing who acts, when it applies, what object changes, what output proves completion, and what happens on failure.

## Sentence-Level Categories

Classify each meaningful sentence as one of:

- Trigger: when the Skill should start.
- Action: the concrete operation to perform.
- Condition: branch or prerequisite.
- Gate: stop, block, rollback, or no-go rule.
- Output: artifact, field, report, or handoff.
- Evidence: proof, command, file, source, or observation.
- Reference Route: when to load a supporting file and what to extract.
- Failure Handling: what to do when evidence, input, validation, or permission is missing.
- Necessary Why: short reason that changes compliance with a hard rule.

Sentences outside these categories are likely noise unless they are examples or fixtures consumed by a test.

## Keyword-Level Audit Targets

Flag these when they lack nearby observable criteria:

- vague quality words: `clear`, `high quality`, `complete`, `reasonable`, `sufficient`, `optimize`, `polish`
- weak verbs: `consider`, `focus on`, `pay attention`, `try to`, `may`, `can`
- broad objects: `related files`, `necessary materials`, `downstream`, `context`
- hidden conditions: `when needed`, `as appropriate`, `if necessary`

## Seven Repair Questions

Use these to turn prose into an executable contract:

1. Who executes this?
2. When does it execute?
3. What exact action is required?
4. What is the object?
5. What is the observable completion state?
6. What happens on failure?
7. Who consumes the result?

## 10-Point Scoring

- 2 points: action is explicit.
- 2 points: condition or branch is explicit.
- 2 points: object and output are explicit.
- 1 point: force level is explicit and not mixed.
- 1 point: failure handling is explicit.
- 1 point: evidence or verification is explicit.
- 1 point: no unconsumed noise, duplicated instruction, or contradiction.

Score the weakest critical path, not the best paragraph. A single vague sentence can justify a finding when it controls a gate, output, or handoff.
