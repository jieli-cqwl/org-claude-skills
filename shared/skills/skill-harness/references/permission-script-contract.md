# Permission Script Contract

Trigger: Use when skill-harness audits allowed tools, shell entry points, `$ARGUMENTS`, script manifests, or action authorization.
Read: Read the active manifest plus archived source `docs/archive/skill-auditor/runtime-source-2026-04-19/references/permission-script-contract.md`.
Expect: Every executable path declares owner, allowed args, input roots, output root, timeout, and failure state before use.
Consume: `shared/skills/skill-harness/scripts/manifest.json`, engineering-control tests, and human review consume the permission-script-contract asset.
Evidence: A retained permission contract must appear in `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json` with `asset_id` `permission-script-contract`.
Sync: Update this reference, manifest rows, and engineering-control tests together.

Ownership evidence: `permission-profiles` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/rules/permission-profiles.md`; `old-audit-runner-scripts` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/scripts/audit_skill.py`; `old-artifact-builders` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/scripts/build_verification_result.py`.
