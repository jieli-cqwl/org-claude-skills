# Audit Method

Trigger: Use this when auditing an existing Skill, runtime migration, Darwin candidate, or evidence-chain review.
Read: Target `SKILL.md`, adapter, references, manifests, scripts, tests, install exposure, and archive boundary.
Expect: Findings inspect trigger, loading, permission, evidence, content order, runtime noise, and migration boundaries.
Consume: Human reviewers consume Markdown findings by default; deterministic gates consume JSON only after the JSON upgrade gate passes.
Evidence: Every FAIL finding records `file:line`, evidence, impact, recommendation, and proof command.
Sync: Update this file when finding fields, audit dimensions, or default output policy changes.

This audit method consumes the Skill quality standard at `{{RUNTIME_HOME}}/reference/Skill质量标准.md`; it must not define a parallel quality standard. Every finding must map to a 质量裁决项 before a `skill-harness` dimension is used as an output label.

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

## Skill Body Quality Review

Before emitting an active audit verdict, inspect the target `SKILL.md` as executable runtime instruction. Do not score prose style in isolation; map each issue to the Skill quality standard D1-D8 first, then use the final dimension labels above.

Review these checks:

- Goal contract: the target task, exclusions, completion boundary, and proof method are clear enough to judge success. Use SMART only as a review mnemonic, not as a required heading.
- SOP executability: the main flow has ordered actions, explicit prerequisites, branch conditions, stop states, outputs, and next consumers. A reviewer can answer "what does the agent do next?" at each step.
- Instruction precision: active instructions use observable verbs and criteria. Vague phrases such as "handle reasonably" or "improve quality" need evidence fields, thresholds, output contracts, or stop conditions.
- Progressive loading: `SKILL.md` keeps high-frequency gates, core flow, and output contracts; long methodology, examples, schemas, templates, and low-frequency detail are routed to resources with Trigger/Read/Expect/Consume/Evidence/Sync.
- Structured flow expression: multi-stage, branching, handoff, stateful, or rollback-heavy workflows use a flow diagram, flow table, or state table. Simple linear flows do not fail for lacking a diagram.
- Evidence closure: PASS/FAIL/COMMENT findings can be replayed from file locations, target outputs, commands, evals, or runtime artifacts.

## Verdict Calibration

Legacy labels such as `Correctness PASS / Practice FAIL` remain migration and baseline-smoke evidence only. They never define active audit output.
