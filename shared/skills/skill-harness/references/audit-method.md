# Audit Method

Trigger: Use this when auditing an existing Skill, runtime migration, or Darwin candidate.
Read: Target `SKILL.md`, adapter, references, manifests, scripts, tests, install exposure, and archive boundary.
Expect: Findings inspect trigger, loading, permission, evidence, content order, runtime noise, and migration boundaries.
Consume: Human reviewers consume Markdown findings by default; deterministic gates consume JSON only after the JSON upgrade gate passes.
Evidence: Every FAIL finding records `file:line`, evidence, impact, recommendation, and proof command.
Sync: Update this file when finding fields, audit dimensions, or default output policy changes.

## Finding Shape

Use structured Markdown by default with these fields:

- `overall_verdict`
- `finding_severity`
- `dimension`
- `file:line`
- `evidence`
- `impact`
- `recommendation`
- `proof_command`

## Dimensions

| Dimension | Audit Question | Blocking Evidence |
| --- | --- | --- |
| Correctness | Does the Skill route, load, and execute the intended contract? | Missing or contradictory runtime instructions |
| Practice | Does the implementation follow the Skill Harness operating model? | Unconsumed JSON, noisy runtime history, or weak evidence chains |
| Boundary | Does the Skill respect read/write, script, alias, and migration limits? | Active retired names, missing owner, or unbounded commands |
| Proof Chain | Can a reviewer replay the claim from exact files and commands? | FAIL finding without `file:line` or proof command |

## Verdict Calibration

Use `Correctness PASS / Practice FAIL` when behavior can still work but the runtime contract would teach future agents the wrong default. This keeps delivery-owner calibration separate from functional correctness.
