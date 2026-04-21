# Subagent Handoff Contract

Trigger: Use when skill-harness audits SubAgent delegation, fork isolation, pipeline handoff, or downstream acceptance evidence.
Read: Read active skill-harness audit output rules plus archived source `docs/archive/skill-auditor/runtime-source-2026-04-19/references/subagent-handoff-contract.md`.
Expect: Delegated work names scope, input refs, excluded context, consumer, evidence, blockers, and next-step contract.
Consume: `shared/skills/skill-harness/SKILL.md`, validator checks, and human review consume the subagent-handoff-contract asset.
Evidence: A retained handoff contract must appear in `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json` with `asset_id` `subagent-handoff-contract`.
Sync: Update this reference and related audit output fields together.
