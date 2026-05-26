# Runtime Integration Audit

Runtime integration decides whether a Skill can be discovered, invoked, installed, and validated without drift.

## Surfaces To Check

- `SKILL.md`: name, description, allowed tools, workflow, output, verification.
- `agents/openai.yaml`: implicit invocation policy.
- references, scripts, templates, contracts, test prompts, evals, fixtures.
- `contracts/skill-runtime-surface.json`: mode, owner, reason, retired names.
- `install.sh`: shared skill checks and retired-skill guards.
- `tests/run-all.sh`, `tests/run-focused.sh`, `tests/gate-plan.json`.
- active README and active `shared/skills/*/evals/**` consumers.

## Rules

- Manual QA Skills should disable implicit invocation unless the runtime has a specific auto-routing contract.
- Read-only audit Skills must not declare `Write`, `Edit`, or target modification authority.
- Retired names must not remain in active gate ids, profile names, command names, schema refs, validator refs, or current lifecycle evidence.
- Historical docs and eval snapshots can remain only when active tests do not consume them as current truth.
- Deterministic checks belong in schema, validator, script, gate, or test, not in prose alone.
