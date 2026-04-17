# Reference Contract

Trigger: Use this when a Skill routes to external reference content.
Read: `SKILL.md` routing lines and referenced files under `references/`, `examples/`, `templates/`, `rules/`, `schemas/`, and `evals/`.
Expect: Each critical reference declares trigger condition, path, content expectation, consumer, evidence, and sync obligation.
Consume: Contract tests, `audit_skill.py`, and human review consume this contract.
Evidence: Missing route, missing file, vague content expectation, or absent sync owner becomes WARN or FAIL by impact.
Sync: Update routed references and contract tests together.

## Contract Fields

| Field | Meaning |
| --- | --- |
| Trigger | Condition that activates the reference |
| Read | Exact file or directory |
| Expect | Information expected from the file |
| Consume | Script, validator, report, or human reviewer using it |
| Evidence | Output proving the file was used |
| Sync | Update obligation when the reference changes |

## Resource Boundaries

Quick Reference, QUICKREF, and INDEX files route user intent to low-frequency content. Templates shape output, scripts perform deterministic work, examples align semantics, data stores static fixtures, and references carry method details.
