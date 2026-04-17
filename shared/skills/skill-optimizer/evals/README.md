# Skill Optimizer Evals

These evals are seed Harness evidence for deterministic contracts. They validate dataset shape, routing assertions, manifest-approved command execution, and selected `audit_skill.py` fixture behavior.

They are not a live model benchmark. They do not prove LLM trigger quality, cross-model behavior, or user-facing optimization quality by themselves. Those claims require with-skill/baseline runs or human review tied to the v2 quality dimensions.

## Case Types

| `check_type` | Meaning |
| --- | --- |
| `fixture` | Validate stable prompt metadata and derived routing decision |
| `manifest_command` | Run a script through `scripts/manifest.json` with approved arguments |
| `audit_fixture` | Run `audit_skill.py` against a repository fixture and inspect `skill-audit.json` |

## Required Audit Fixtures

| Case | Required signal |
| --- | --- |
| `audit-reference-broken-finding` | `finding-reference-contract` appears as a FAIL finding |
| `audit-minimal-good-no-fail` | No FAIL findings are emitted |
