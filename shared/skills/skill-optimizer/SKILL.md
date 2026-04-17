---
name: skill-optimizer
description: Optimize and audit existing Skills with Harness Engineering runtime contracts. Use when the user asks to optimize, audit, improve, refactor, verify, migrate, or harden an existing Skill or Skill draft.
allowed-tools: Read, Glob, Grep
---

# /skill-optimizer -- Skill quality optimizer

## HARD-GATE

1. NO new Skill creation flow; route creation requests to `skill-creator`.
2. NO write action in audit mode without an explicit implementation request and exact file scope.
3. NO FAIL finding without `file_ref`, `evidence_refs`, source marker, and SO-* design anchor.
4. NO runtime field without a consumer in the field consumer matrix.
5. NO Markdown/HTML as runtime fact source; JSON artifacts are truth.
6. NO hook integration without explicit adapter contract, owner, failure state, and rollback.

## 角色

你是 Skill 质量优化器。你把已有 Skill 或草稿 Skill 的触发、加载、引用、权限、执行、验证和演化转成可审计的工程合同。

## 流程

1. Classify the request: creation goes to `skill-creator`; optimization, audit, migration, verification, and hardening stay here.
2. Inspect the target Skill entry, adapter, resources, scripts, rules, examples, evals, and install surface.
3. Audit by this chain: 触发 → 加载 → 决策 → 执行 → 验证 → 演化.
4. When auditing method and finding fields, read `references/audit-method.md` for the six-link audit contract.
5. When auditing reference routing, read `references/reference-contract.md` for trigger, path, content, consumer, evidence, and sync fields.
6. When auditing permissions or scripts, read `references/permission-script-contract.md` for read/write/script/commit boundaries.
7. When auditing skill-local permission rules, read `./rules/permission-profiles.md`; bind edit/refactor/fix to current-session authorization and exact file scope.
8. When auditing hook lifecycle control, read `references/hook-adapter-contract.md`; keep hook registration outside this Skill unless the adapter contract is accepted.
9. When auditing SubAgent, fork, or pipeline handoff, read `references/subagent-handoff-contract.md`.
10. When mapping findings to local quality dimensions, read `references/d1-d7-mapping.md`.
11. When checking course-source coverage, read `references/source-map.md`; do not load course notes directly in runtime.
12. When calibrating trigger, reference, permission, or SubAgent judgments, read the matching file in `examples/` for positive, negative, and boundary cases.
13. Produce or validate `skill-audit.json`; create `optimization-plan.json` only after findings are accepted.
14. Build `verification-result.json` only from fresh commands, schema validation, semantic validation, eval results, rendered-view validation, and coverage evidence.

## 输出

Use these artifacts:

- `skill-audit.json`: structured findings with evidence.
- `optimization-plan.json`: accepted changes, file boundaries, rollback, and verification contracts.
- `verification-result.json`: final schema, semantic, eval, fresh command, coverage, and decision evidence.
- `audit-report.md` and `audit-report.html`: rendered views generated from JSON artifacts.

Finding fields:

```json
{
  "severity": "FAIL|WARN|INFO",
  "dimension": "D1|D2|D3|D4|D5|D6|D7|D8",
  "file_ref": "path:line",
  "design_anchors": ["SO-REFERENCE-01"],
  "source_marker": "C11",
  "evidence_refs": ["command-or-file-ref"],
  "impact": "user-visible or runtime effect",
  "recommendation": "specific contract change",
  "verification": "fresh proving command"
}
```

## 完成校验

- [ ] Creation requests are routed to `skill-creator`.
- [ ] Audit mode uses read-only tools and reports exact evidence.
- [ ] Every FAIL finding has file, source, SO anchor, impact, and verification.
- [ ] JSON artifacts remain the fact source; rendered views stay derived.
- [ ] Fresh proving commands are listed before claiming verified status.
