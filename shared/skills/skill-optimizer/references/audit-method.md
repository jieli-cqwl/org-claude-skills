# Audit Method

Trigger: Use this when auditing an existing Skill or Skill draft.
Read: Target `SKILL.md`, adapter, resources, scripts, rules, examples, evals, and install surface.
Expect: Findings follow 触发 → 加载 → 决策 → 执行 → 验证 → 演化.
Consume: `audit_skill.py`, `skill-audit.json`, rendered reports, and human review consume this method.
Evidence: Every FAIL finding records `file_ref`, `evidence_refs`, `source_marker`, `design_anchors`, impact, and verification.
Sync: Update this file when finding fields, audit chain names, or SO-* anchors change.

## Finding Levels

| Level | Meaning | Output Rule |
| --- | --- | --- |
| FAIL | Blocks stable Skill execution or verification | Requires file, evidence, impact, and fresh command |
| WARN | Risk with contained scope | Requires evidence and mitigation |
| INFO | Useful observation | Requires source and consumer |

## Script Boundary

`audit_skill.py` is a deterministic smoke producer. It checks reference routing and read-only audit gates, then emits `scope.mode = deterministic-smoke`. It does not replace the full D1-D8 audit judgment. Full review reads the target Skill, this method, and the v2 quality standard, then records human or LLM findings into the same JSON contract.

## Chain

| Link | Audit Focus | Typical Evidence |
| --- | --- | --- |
| 触发 | description, trigger examples, neighbor conflicts | frontmatter, adapter, eval cases |
| 加载 | progressive disclosure, Quick Reference, resource routing | `SKILL.md`, references, context budget |
| 决策 | rules priority, reference contract, branch criteria | rule path, source marker, examples |
| 执行 | tools, scripts, permissions, handoff | allowed-tools, manifest, agent contract |
| 验证 | schema, semantic, eval, fresh command | command output, JSON artifact, coverage |
| 演化 | migration, benchmark, rollback | before/after report, install tests |
