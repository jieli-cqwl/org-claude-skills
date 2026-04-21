# Reference Contract

Trigger: Use when skill-harness audits a Skill route to reference, example, template, schema, eval, or rule content.
Read: Read the active routed file and the archived source `docs/archive/skill-auditor/runtime-source-2026-04-19/references/reference-contract.md`.
Expect: Routed content declares when it is loaded, what fact it provides, who consumes it, and when it can be dropped.
Consume: `tests/test-skill-harness-directory-capability.sh`, `shared/skills/skill-harness/scripts/check_skill_harness_contract.py`, and human review consume the reference-contract asset.
Evidence: A retained reference must appear in `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json` with `asset_id` `reference-contract`.
Sync: Update this reference, its asset ownership row, and its validation command in the same change.
