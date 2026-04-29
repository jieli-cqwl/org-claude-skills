---
name: weak-trigger
description: Quality helper.
allowed-tools: Read
---

# weak-trigger

## HARD-GATE

- Stop when the target is missing.

## Goal

Goal: audit a target Skill and report whether completion evidence exists.
Completion boundary: return a finding list that cites evidence.

## Workflow

| step_id | input | action | output | consumer | acceptance | failure_state | proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| audit | Target Skill | Read the target and check evidence | Finding list | user | Findings cite evidence | Stop on unreadable target | JSON output |

## Verification

- [ ] Run command: `python3 tools/skill_quality/check_skill_package_quality.py tests/fixtures/skill-quality-detection/weak-trigger`.
- [ ] Evidence: output includes the trigger finding.
