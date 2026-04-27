# Fixture Skill

## HARD-GATE

- Stop when the declared task scope is missing.
- Reject migration audit entries that cannot be traced to a verification reference.

## Protocol

1. Read the scoped task contract.
2. Validate the skill content layers.
3. Report each finding with a file path and line number.

## Why

These checks keep role guidance unambiguous and make migration accountability reviewable.

## How

Use the layer definitions to classify prose before deciding whether the wording mixes responsibility, rationale, or runtime behavior.

## Script Contract

Run the content-quality validator and treat a non-zero exit as a blocked gate.

## Failure Routing

If a content-quality finding appears, owner `delivery-owner` takes next action `repair_skill_or_audit_record` and continuation waits for a fresh validator pass.

## Reference Link

When migration judgment is needed, read the active phase design section named Noise Migration Rules.

## Output Contract

The output contract source of truth is the validator result emitted for the current run.
