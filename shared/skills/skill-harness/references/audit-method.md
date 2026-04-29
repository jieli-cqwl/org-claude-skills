# Audit Method

Trigger: Use this when auditing an existing Skill, runtime migration, Darwin candidate, or evidence-chain review.
Read: Target `SKILL.md`, adapter, references, manifests, scripts, tests, install exposure, and archive boundary.
Expect: Findings inspect trigger, loading, permission, evidence, content order, runtime noise, data flow, multi-runtime adapter, and migration boundaries.
Consume: Human reviewers consume Markdown findings by default; deterministic gates consume JSON only after the JSON upgrade gate passes.
Evidence: Every FAIL finding records priority, skill_id, runtime_target, scope, owner, `file:line`, evidence, impact, recommendation, and proof command.
Sync: Update this file when finding fields, audit dimensions, or default output policy changes.

This audit method consumes the Skill quality standard at `{{RUNTIME_HOME}}/reference/Skill质量标准.md`; it must not define a parallel quality standard. Every finding must map to a 质量裁决项（G0-G2 gate, S1-S8 operating-quality item, or E1-E5 evidence item）before a `skill-harness` dimension is used as an output label.

## Base Fields

Use structured Markdown by default with these base fields:

- `overall_verdict`
- `dimension`
- `dimension_result`
- `finding_severity`
- `priority`
- `skill_id`
- `runtime_target`
- `scope`
- `owner`
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

When JSON output is required, `file:line` maps to JSON `file_ref` and field-consumers `file_line`; all three carry the same single repo-local `path:line` value.

`dimension_result`: `PASS / FAIL / WARN / NOT_APPLICABLE`

`finding_severity`: `S1 / S2 / S3 / INFO`

`audit_proof_type`: `file_evidence / fixture_proof / fresh_proving`

`priority`: `P0 / P1 / P2 / P3`

`runtime_target`: `claude-code / codex / copilot / api / multi / repo-static`

`scope`: frontmatter、body、resource、script、adapter、catalog、artifact、eval、effectiveness 或等价 repo-local scope。

`owner`: skill-author、runtime-owner、security-owner、consumer-owner 或当前可追责的 repo-local owner。

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

Before emitting an active audit verdict, inspect the target Skill as an executable runtime object. Do not score prose style in isolation; map each issue to the Skill quality standard gates and dimensions first, then use the final dimension labels above.

Review these checks:

- Gate readiness: `SKILL.md`, runtime reachability, and referenced evidence are available before deeper judgment.
- Discovery and trigger: the target activates for the right task, avoids adjacent-skill collisions, and respects manual-only or disabled exposure.
- Multi-skill arbitration: overlapping skills name priority, mutual exclusion, fallback, or explicit invocation rules before the same task can trigger multiple paths.
- Goal contract: the target task, exclusions, completion boundary, and proof method are clear enough to judge success. Use SMART only as a review mnemonic, not as a required heading.
- Professional workflow: the main flow follows the real work order for the Skill's responsibility, with explicit prerequisites, branch conditions, stop states, outputs, next consumers, and proof.
- Instruction precision: active instructions use observable verbs and criteria. Vague phrases such as "handle reasonably" or "improve quality" need evidence fields, thresholds, output contracts, or stop conditions.
- Progressive loading: `SKILL.md` keeps high-frequency gates, core flow, and output contracts; long methodology, examples, schemas, templates, and low-frequency detail are routed to `references/`, `resources/`, scripts, assets, or plugin-level resources with clear load timing, purpose, consumer, and verification value.
- Structured flow expression: multi-stage, branching, handoff, stateful, or rollback-heavy workflows use a flow diagram, flow table, or state table. Simple linear flows do not fail for lacking a diagram.
- Runtime fit and safety: tools, scripts, hooks, external writes, network calls, source locks, data flow, ZDR/data-retention scope, and install exposure match the Skill's responsibility. Treat `allowed-tools` as pre-approval, not a complete security boundary.
- Artifact contract: task artifacts, audit artifacts, and state artifacts have consumers and appropriate schema/validator boundaries.
- Verification loop: PASS/FAIL/COMMENT findings can be replayed from file locations, target outputs, commands, evals, or runtime artifacts, and failures stop or loop back correctly.
- WARN accumulation: three same-dimension WARN findings that affect the same success standard or six unowned cross-dimension WARN findings lower the final grade unless owner, handling record, and recheck command exist.
- Behavioral evidence: best-practice or retain claims require with-skill/baseline or old/new evidence; lack of behavioral data blocks L3/L4 claims, not basic L1/L2 operation.

## Verdict Calibration

Legacy labels such as `Correctness PASS / Practice FAIL` remain migration and baseline-smoke evidence only. They never define active audit output.
