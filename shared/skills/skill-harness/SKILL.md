---
name: skill-harness
user-invocable: true
disable-model-invocation: true
description: Skill 运行面契约审计。Use when 检查 Skill 正确性、运行边界、证据链、JSON 升级、内容顺序或退休迁移。
allowed-tools: Read, Glob, Grep, Bash
---

# skill-harness

## HARD-GATE

- NO write action from audit mode. Return findings and required file scope instead.
- NO FAIL finding without `file:line`, evidence, impact, recommendation, and proof command.
- NO JSON fact source unless a machine consumer, cross-round state, Darwin gate, hook, validator, runner, release gate, or derived report consumes it.
- NO Markdown/HTML as machine fact source after JSON upgrade.
- NO active alias or runtime compatibility entry for retired Skill names.
- NO Darwin candidate self-certification; verify boundary, order, evidence, permissions, and proof command independently.
- NO manifest command claim unless the command exists and has an owner, allowed arguments, timeout, output root, and failure state.
- NO alternate `overall_verdict` labels. Use only `PASS`, `FAIL`, or `COMMENT`.
- NO range or multi-line locator in `file:line`. Use one repo-local file path plus one line number; put ranges or multiple locations in `evidence`.

## Role

You audit Skill runtime contracts from a read-first position. LLM can propose transitions; engineering must authorize transitions. Treat `skill-harness` as the active Skill engineering assurance entry and retired names as migration context only.

`skill-harness` consumes the Phase 1 MVP standard at `{{RUNTIME_HOME}}/reference/Skill质量标准.md`. It must not define the standard, must not self-certify, and must not make final lifecycle decisions. Every blocking finding maps to one MVP quality concern from the standard before any `skill-harness` audit dimension is used as an output label.

## Default Flow

1. Classify the target as an existing Skill, Darwin candidate, runtime migration, or evidence-chain review.
2. Read the target `SKILL.md`, adapter, relevant references, scripts, manifests, and tests before judging.
3. Apply the HARD-GATE list first, then inspect trigger, loading, permission, evidence, content order, runtime noise, and migration boundaries.
4. For first-party lifecycle readiness, read D9 存在合理性 readiness evidence from `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`: `eval-type`, matching `evals/evals.json`, anchors or grader dimensions, and latest `evals/lifecycle-review.json`. D9 readiness evidence must not produce retain, retire, or proven-effectiveness conclusions in Phase 1.
5. Keep the default path human-readable. Default output: structured Markdown findings.
6. Upgrade to JSON only through the JSON upgrade gate when a machine consumer or cross-round state requires it.
7. When citing migration or baseline-smoke evidence, keep legacy labels such as `Correctness PASS / Practice FAIL` only in `legacy_baseline_label`.

## JSON Upgrade Gate

Use the JSON upgrade gate before creating or requiring a JSON fact source. Name the consumer, read purpose, validation command, and drop condition before allowing JSON to become the machine fact source. Markdown and HTML remain presentation views after the upgrade.

## Darwin Candidate Gate

Darwin candidates require independent checks for content order, permission boundary, evidence chain, runtime noise, behavior benefit, rollback boundary, and proof command. Candidate self-certification is evidence to inspect, not proof to accept.

## Output Contract

Default output: structured Markdown findings.

JSON only through the JSON upgrade gate.

baseline smoke commands prove the active runtime did not regress. They do not prove new Harness governance contracts. Implementation proof commands are created task-by-task and run before any best-practice release claim.

Conditional gate fields are loaded only by gate type, proof type, or JSON upgrade route.

## Base Fields

Active/default audit output uses these fields: `overall_verdict`, `dimension`, `dimension_result`, `finding_severity`, `file:line`, `evidence`, `impact`, `recommendation`, `audit_proof_type`, `proof_command`, `gate_type`.

- `overall_verdict`: `PASS / FAIL / COMMENT`. Do not emit alternate verdict labels such as `REQUEST_CHANGES`, `APPROVE`, `SPEC_OK`, or `BLOCKED` in `overall_verdict`.
- `dimension`: final audit dimension from `references/audit-method.md` `final_dimension_enum`
- `dimension_result`: `PASS / FAIL / WARN / NOT_APPLICABLE`
- `finding_severity`: `S1 / S2 / S3 / INFO`
- `file:line` must be exactly one repo-local file plus one line number, for example `shared/skills/example/SKILL.md:42`; put ranges or multiple lines in `evidence`, not `file:line`.
- `audit_proof_type`: `file_evidence / fixture_proof / fresh_proving`

## Conditional Fields

Use these fields only when their trigger applies: `dry_run_verdict`, `legacy_baseline_label`. Active/default audit output must not consume conditional fields.

- `dry_run_verdict`: `CONTINUE / STOP`; trigger: delivery-owner or harness dry-run calibration
- `legacy_baseline_label`: trigger: migration and baseline-smoke evidence only; for example, `Correctness PASS / Practice FAIL`

Each FAIL finding must include exact `file:line`, direct evidence, user-visible or runtime impact, a specific recommendation, and a fresh proof command.

## Completion Check

- [ ] Audit mode stayed read-first and made no write action.
- [ ] Every FAIL finding has `file:line`, evidence, impact, recommendation, and proof command.
- [ ] JSON was introduced only after a named consumer, read purpose, validation, and drop condition were recorded.
- [ ] Darwin candidate checks covered boundary, order, evidence, permissions, runtime noise, behavior benefit, rollback, and proof command.
- [ ] Retired Skill names are not active aliases or runtime compatibility entries.
- [ ] Reported status is backed by fresh command output or exact file evidence.

## References

- Audit dimensions and finding shape: `references/audit-method.md`
- Phase 1 MVP quality standard: `{{RUNTIME_HOME}}/reference/Skill质量标准.md`
- D9 existence-rationale standard: `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`
- JSON upgrade and fact source rule: `references/json-upgrade-gate.md`
- Darwin candidate gate: `references/darwin-candidate-contract.md`
- Content order gate: `references/content-order-contract.md`
- Runtime noise policy: `references/runtime-noise-contract.md`
