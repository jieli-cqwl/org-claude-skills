# Example Contract

Trigger: Use when skill-harness audits examples, fixtures, eval cases, or old skill-audit example knowledge.
Read: Read examples archived after retirement in `docs/archive/skill-auditor/runtime-source-2026-04-19/examples/permission-cases.md`, `docs/archive/skill-auditor/runtime-source-2026-04-19/examples/reference-contract-cases.md`, `docs/archive/skill-auditor/runtime-source-2026-04-19/examples/subagent-eval-cases.md`, and `docs/archive/skill-auditor/runtime-source-2026-04-19/examples/trigger-cases.md`.
Expect: Examples become fixtures when machine-consumed, stay referenced when human-only, or remain inside the archive boundary.
Consume: `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json`, directory-capability tests, and human review consume the examples asset.
Evidence: A retained examples contract must appear in asset ownership with `asset_id` `examples`.
Sync: Update this reference when example fixtures or deferred example targets change.

Ownership evidence archived after retirement: `evals` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/evals`; `templates-renderer` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/templates/audit-report.md.tmpl`; `old-agent-exposure` consumes `docs/archive/skill-auditor/runtime-source-2026-04-19/agents/openai.yaml`.
