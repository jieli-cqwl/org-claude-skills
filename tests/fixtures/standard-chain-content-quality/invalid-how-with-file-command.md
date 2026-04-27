# Fixture Skill

## HARD-GATE

- Stop when the declared task scope is missing.

## Protocol

1. Read the scoped task contract.

## Why

These checks keep role guidance unambiguous.

## How

Run `python3 tools/community/validate_context_contract.py --field gate_result` and edit `docs/example/plan.json` when the check fails.

## Script Contract

Run the content-quality validator.

## Failure Routing

If a finding appears, owner `delivery-owner` takes next action `repair_skill_or_audit_record` and continuation waits for a fresh validator pass.

## Reference Link

When migration judgment is needed, read the active phase design section named Noise Migration Rules.

## Output Contract

The output contract source of truth is the validator result emitted for the current run.
