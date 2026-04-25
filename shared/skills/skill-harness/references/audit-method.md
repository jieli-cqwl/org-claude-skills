# Audit Method

Trigger: Use this when auditing an existing Skill, runtime migration, Darwin candidate, or first-party lifecycle readiness.
Read: Target `SKILL.md`, adapter, references, manifests, scripts, tests, install exposure, archive boundary, and D9 lifecycle evidence when present.
Expect: Findings inspect trigger, loading, permission, evidence, content order, runtime noise, migration boundaries, and D9 存在合理性 readiness evidence from `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`.
Consume: Human reviewers consume Markdown findings by default; deterministic gates consume JSON only after the JSON upgrade gate passes.
Evidence: Every FAIL finding records `file:line`, evidence, impact, recommendation, and proof command.
Sync: Update this file when finding fields, audit dimensions, or default output policy changes.

This audit method consumes the Phase 1 MVP standard at `{{RUNTIME_HOME}}/reference/Skill质量标准.md`; it must not define the standard, must not self-certify, and must not make final lifecycle decisions. Every finding must map to an MVP quality concern before a `skill-harness` dimension is used as an output label.

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

Do not emit alternate verdict labels such as `REQUEST_CHANGES`, `APPROVE`, `SPEC_OK`, or `BLOCKED` in `overall_verdict`.

`file:line` must be exactly one repo-local file plus one line number, for example `shared/skills/example/SKILL.md:42`; put ranges or multiple lines in `evidence`, not `file:line`.

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

## D9 Readiness Boundary

When the target is a first-party Skill, check D9 存在合理性 readiness evidence using `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`. The audit reads `eval-type`, matching `evals/evals.json`, required `preference_anchors` or `grader_dimensions`, and latest `evals/lifecycle-review.json`.

D9 readiness evidence must not produce retain, retire, or proven-effectiveness conclusions. A D9 finding must map to an MVP quality concern, such as evidence boundary or lifecycle-overclaim risk, before `Verification` or `Evolution` is used as an output dimension. Do not require JSON output solely because a D9 review exists; JSON remains gated by the named consumer rule.

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
