---
name: lifecycle-inconsistent
description: Use when checking lifecycle state consistency for Skill package audits.
allowed-tools: Read
---

# lifecycle-inconsistent

## HARD-GATE

- Stop when lifecycle evidence is unreadable.

## Goal

Goal: inspect lifecycle review consistency.
Completion boundary: output lifecycle findings with evidence.

## Workflow

| step_id | input | action | output | consumer | acceptance | failure_state | proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lifecycle | lifecycle review | Read and compare decision/state | Finding list | user | State matches decision | Stop on mismatch | JSON output |

## Verification

- [ ] Run command: `python3 shared/skills/skill-harness/scripts/check_skill_package_quality.py tests/fixtures/skill-quality-detection/lifecycle-inconsistent`.
- [ ] Evidence: output includes lifecycle mismatch.
