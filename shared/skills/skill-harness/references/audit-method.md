# Audit Method

Trigger: Use this when auditing an existing Skill, runtime migration, or Darwin candidate.
Read: Target `SKILL.md`, adapter, references, manifests, scripts, tests, install exposure, and archive boundary.
Expect: Findings inspect trigger, loading, permission, evidence, content order, runtime noise, and migration boundaries.
Consume: Human reviewers consume Markdown findings by default; deterministic gates consume JSON only after the JSON upgrade gate passes.
Evidence: Every FAIL finding records `file:line`, evidence, impact, recommendation, and proof command.
Sync: Update this file when finding fields, audit dimensions, or default output policy changes.

## Base Fields

Use structured Markdown by default with these base fields:

- `overall_verdict`
- `dimension`
- `dimension_result`
- `finding_severity`
- `file:line`
- `evidence`
- `impact`
- `recommendation`
- `audit_proof_type`
- `proof_command`
- `gate_type`

`overall_verdict`: `PASS / FAIL / COMMENT`

`dimension_result`: `PASS / FAIL / WARN / NOT_APPLICABLE`

`finding_severity`: `S1 / S2 / S3 / INFO`

`audit_proof_type`: `file_evidence / fixture_proof / fresh_proving`

## Conditional Fields

Use these fields only when their trigger applies. Active/default audit output must not consume conditional fields.

- `dry_run_verdict`
- `legacy_baseline_label`

`dry_run_verdict`: `CONTINUE / STOP`

Trigger: delivery-owner or harness dry-run calibration.

`legacy_baseline_label`: migration and baseline-smoke evidence only

Trigger: migration evidence and baseline-smoke evidence such as `Correctness PASS / Practice FAIL`.

## Final Dimension Enum

`final_dimension_enum`: `Trigger / Loading / Decision / Execution / Verification / Evolution / Main Content Noise / Chain Integration / Engineering Control / Directory Capability`

## Baseline Dimension Boundary

Baseline-only labels `Correctness`, `Practice`, and `Proof Chain` are retained only for migration evidence and baseline-smoke evidence. They are not active final dimensions and must not be emitted as `dimension` values in active/default audit output.

## Dimensions

| Dimension | Audit Question | Blocking Evidence |
| --- | --- | --- |
| Trigger | Does the Skill activate for the right user intent? | Missing, broad, or contradictory trigger rules |
| Loading | Does the Skill load only the context required for the task? | Required references missing, stale, or too noisy |
| Decision | Are runtime choices governed by explicit gates? | Ungated JSON upgrade, write action, or transition decision |
| Execution | Can the Skill execute its declared workflow without hidden steps? | Missing command owner, unbounded script, or undeclared dependency |
| Verification | Can claims be replayed from exact evidence and commands? | FAIL finding without `file:line`, evidence, or proof command |
| Evolution | Are migration and rollback boundaries explicit? | Active retired aliases or compatibility entries without removal conditions |
| Main Content Noise | Is the active `SKILL.md` free of stale history and non-runtime clutter? | Old labels or historical commentary in active instructions |
| Chain Integration | Does the Skill fit standard-chain role and artifact contracts? | Role handoff, artifact, or authority drift |
| Engineering Control | Are machine-consumed fields owned, validated, and droppable? | Field without consumer, validation command, drop condition, or failure state |
| Directory Capability | Are retained assets placed in an allowed active or archive boundary? | Old assets with no source path, target, trigger, or archive boundary |

## Verdict Calibration

Legacy labels such as `Correctness PASS / Practice FAIL` remain migration and baseline-smoke evidence only. They never define active audit output.
