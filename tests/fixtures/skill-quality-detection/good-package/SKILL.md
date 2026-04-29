---
name: good-package
description: Use when auditing a Skill package for trigger, workflow, artifact, verification, effectiveness, and retain evidence quality.
allowed-tools: Read
---

# good-package

## HARD-GATE

- Stop when the target Skill path is missing.
- Stop when effectiveness evidence is required but `evals/lifecycle-review.json` is unreadable.

## Goal

Goal: audit a Skill package and decide whether known quality gates are satisfied.
Completion boundary: output deterministic findings with exact evidence and a replay command.

## Workflow

| step_id | input | action | output | consumer | acceptance | failure_state | proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| read-target | Skill path | Read `SKILL.md` and optional `evals/lifecycle-review.json` | Target evidence summary | audit step | Required files are readable | Stop with G0/G2 finding | File evidence |
| check-contract | Evidence summary | Check trigger, workflow, artifact, verification, effectiveness, and retain gates | Finding list | user and tests | Findings map to standard dimensions | Stop on FAIL or return WARN/PASS | Checker JSON |

## Artifact Contract

Output path: stdout JSON.
Format: `skill-quality-package-audit`.
Consumer: test gates and human reviewers.
Validation: `python3 tools/skill_quality/check_skill_package_quality.py tests/fixtures/skill-quality-detection/good-package`.

## Verification

- [ ] Run command: `python3 tools/skill_quality/check_skill_package_quality.py tests/fixtures/skill-quality-detection/good-package`.
- [ ] Evidence: output status is `static_pass` with zero findings.
