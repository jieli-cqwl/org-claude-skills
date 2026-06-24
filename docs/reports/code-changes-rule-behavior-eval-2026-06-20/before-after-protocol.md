# Code Changes Rule Behavior Before/After Protocol

## Purpose

Compare the old prohibition-heavy error bullet with the current positive failure-semantics bullet, using the same pilot cases.

## Instruction Packs

| Pack | Content |
| --- | --- |
| `baseline-old-error-bullet` | Use the pre-change Code Changes bullet that only says not to swallow errors, log-and-continue, return fake defaults, or convert failure into success. |
| `current-positive-failure-semantics` | Use the current Code Changes bullet that preserves failure semantics and allows visible partial failure when continuation is valid. |

## Replay Order

For each pilot case:

1. Run the old pack first.
2. Run the current pack second.
3. Keep the user prompt, context artifact, and grading rubric identical.
4. Record only the behavior difference.

## Comparison Rules

- If old and current both pass, the case is too weak or the rule was already sufficient.
- If old fails and current passes, the rule is probably helping.
- If old passes and current fails, the current wording may be over-constraining.
- If both fail, the case probably exposes a deeper missing rule, reference, or gate.

## What Counts As Evidence

Evidence must be direct and current:

- the actual answer text;
- the actual next action;
- the triggered reference, if any;
- the specific hard-fail anchors avoided or hit;
- the overclaim state.

Do not infer behavior from a vague sense that the answer "sounds better".

## What Not To Do

- Do not rewrite the rule during the replay.
- Do not widen the case set mid-pilot.
- Do not accept a case that only tests prose familiarity.
- Do not claim behavior improvement without a before/after contrast.
