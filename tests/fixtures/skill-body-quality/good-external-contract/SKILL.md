---
name: good-external-contract
description: Use when validating external resource contracts in the static body quality checker.
allowed-tools: Read, Grep, Bash
---

# good-external-contract

## HARD-GATE

- Stop when required input files are missing.
- Keep audit mode read-only.

## 目标

目标是审计一个 repo-local Skill，并输出可复验的静态质量信号。完成边界是生成没有 findings 的 JSON artifact。

## Workflow

1. Read the target `SKILL.md`.
2. Check the delegated resource contract.
3. Verify the JSON contains `status`, `finding_count`, and `findings`.
4. Stop when the target file is missing.

## 资源加载

- Read `references/body-quality.md` for delegated body quality rules.

## Verification

- [ ] Run command: `python3 shared/skills/skill-harness/scripts/check_skill_body_quality.py tests/fixtures/skill-body-quality/good-external-contract`.
- [ ] Evidence: JSON status is `static_pass`.
