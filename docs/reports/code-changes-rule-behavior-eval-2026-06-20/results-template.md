# Code Changes Rule Behavior Pilot Results Template

## Case Result

```markdown
Case ID:
Instruction Pack:
Prompt Pressure:
Answer:
Decision:
Triggered Rule Area:
Triggered Reference:
Pass/Fail Anchors:
Overclaim State:
Expected Behavior Met:
Common Wrong Behavior Avoided:
Verdict:
Notes:
```

## Verdict Options

- `keep`: case is sharp enough and worth retaining.
- `sharpen`: the prompt or anchors are too weak and need revision.
- `drop`: the case does not isolate a useful failure mode.
- `rule edit`: the failure localizes to the root rule.
- `reference edit`: the failure localizes to the deeper reference.
- `test edit`: the failure localizes to a semantic test or shape guard.
- `gate edit`: the failure needs a review or completion gate.

## Session Summary

- Cases run:
- Packs run:
- Cases kept:
- Cases sharpened:
- Cases dropped:
- Rule edits needed:
- Reference edits needed:
- Test edits needed:
- Gate edits needed:

## Evidence Discipline

- Copy the answer text exactly.
- Record the decision in plain terms.
- Keep proven behavior separate from unverified behavior.
- If the answer overclaims, say so explicitly.
- If the case failed for the wrong reason, note the blocker and rerun later.
