# Hook Adapter Contract

Trigger: Use when skill-harness audits hook behavior, lifecycle blocking, adapter state, or runtime gate handoff.
Read: Read active runtime field consumers and archived source `docs/archive/skill-auditor/runtime-source-2026-04-19/references/hook-adapter-contract.md`.
Expect: Hook-like behavior is modeled as input, action, output, owner, rollback, and failure state before implementation.
Consume: `shared/skills/skill-harness/schemas/field-consumers.json`, release gates, and human review consume the hook-adapter-contract asset.
Evidence: A retained hook adapter contract must appear in `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json` with `asset_id` `hook-adapter-contract`.
Sync: Update this reference whenever field consumers or release-gate failure states change.

Ownership evidence: `optimization-plan` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/schemas/optimization-plan.schema.json`; `verification-result` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/schemas/verification-result.schema.json`.
