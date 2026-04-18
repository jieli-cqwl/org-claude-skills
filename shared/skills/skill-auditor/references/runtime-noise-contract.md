# Runtime Noise Contract

Trigger: Use this when `skill-auditor` audits legacy, migration, temporary, retired, or historical text in Skill runtime files.
Read: `SKILL.md`, `references/`, `rules/`, `examples/`, `evals/`, `schemas/`, `scripts/`, install surfaces, and existing verification gates.
Expect: Runtime files contain only current executable contracts, tested fixtures, or explicitly owned compatibility behavior.
Consume: `audit_skill.py`, audit findings, optimization plans, `tests/test-skill-runtime-noise.sh`, and human review consume this contract.
Evidence: Finding records `noise_class`, current consumer, behavior impact, verification command, owner or exit condition, and archive/delete recommendation.
Sync: Update when runtime document classes, retired-contract cleanup, or Skill quality standard D7 rules change.

## Classify

- `CURRENT_CONTRACT`: current runtime behavior still depends on the text. Keep it only with consumer, behavior, verification, and owner/exit condition.
- `TEST_FIXTURE`: negative or compatibility fixture proving old behavior is rejected or migrated. Keep it under tests or fixture paths, not runtime references.
- `ARCHIVE_ONLY`: history notes, migration notes, retired dimensions, old paths, or removable guidance with no current consumer. Delete from runtime or move to `docs/archive/`.

## Default ARCHIVE_ONLY

- Legacy mapping sections, retired dimension tables, migration comparison tables, and removable notes.
- Retired quality-standard labels, invalid retired dimension wording, or old model names in runtime prose.
- Deprecated, superseded, temporary, or historical explanations that do not change current execution.
- Old file paths, old command names, or retired Skill names without an active route and verification gate.

## Allowed Only With Evidence

- Current compatibility behavior, such as rejecting or re-signing old user inputs.
- Installer or hook cleanup behavior for retired runtime files.
- Negative fixtures that prove old artifacts fail validation.
- ADR or template status enums where the enum is part of current authoring behavior.

## Four Questions

1. Who consumes it now?
2. What runtime behavior changes?
3. Which command proves it?
4. Where is owner/exit condition?

## Output

Emit `noise_class`, `consumer`, `verification`, and an archive/delete recommendation. If any question lacks evidence, classify as `ARCHIVE_ONLY`.
