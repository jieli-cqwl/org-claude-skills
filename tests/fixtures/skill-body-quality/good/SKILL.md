---
name: good
description: Use when validating a Skill body quality checker with a clean executable Skill fixture.
allowed-tools: Read, Grep, Bash
---

# good

## HARD-GATE

- Stop when required input files are missing.
- Keep audit mode read-only.

## 目标

目标是审计一个 repo-local Skill，并输出可复验的静态质量信号。不处理非 Skill 文档。完成边界是生成包含 status 和 findings 的 JSON artifact。

## Workflow

1. Read the target `SKILL.md`.
2. Check frontmatter, goal contract, workflow actions, resource loading, and verification evidence.
3. Write findings to stdout as JSON.
4. Verify the JSON contains `status`, `finding_count`, and `findings`.
5. Stop when the target file is missing.

## 资源加载

- 主流程质量口径 — Trigger: 进入 body quality audit；Read: `references/body-quality.md`；Expect: 本体质量检查规则；Consume: 生成 findings；Evidence: finding code 映射 G/S 质量项；Sync: 规则变化时同步脚本和测试。

## Verification

- [ ] Run command: `python3 shared/skills/skill-harness/scripts/check_skill_body_quality.py tests/fixtures/skill-body-quality/good`.
- [ ] Evidence: JSON status is `static_pass`.
- [ ] Artifact: stdout JSON includes empty findings.
