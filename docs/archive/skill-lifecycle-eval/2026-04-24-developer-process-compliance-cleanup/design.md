# Developer Process Compliance Cleanup

## Problem Statement

The harder D9 review showed `developer` has `uplift = 0.0` on text evals. That does not prove standalone capability value, but the Skill can still be useful as a process-compliance executor for real standard-chain tasks.

The current Skill text also contains noise from prior eval optimization: an eval-specific section name, a nonexistent `interface_change_log` JSON field, and a duplicate micro-change log table whose display format already belongs to the developer report template.

## Decision

`developer` is not retained as a capability-uplift Skill. It remains `decision = optimize` and is now documented as a process-compliance candidate. The next human decision is whether to keep it as a dedicated executor, merge its contracts into shared standard-chain guidance, or start Gate 4 retirement.

## Scope

- Clean `shared/skills/developer/SKILL.md` wording.
- Add a deterministic process-compliance contract test.
- Tighten `shared/skills/developer/scripts/completion_check.sh` so report evidence remains traceable.
- Update `shared/skills/developer/evals/lifecycle-review.json` with process-compliance rationale.
- Update changelog.

## Verification

Fresh command evidence is in `verify-change-report.md`.
