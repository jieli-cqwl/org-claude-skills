---
name: artifact-contract-missing
description: Use when checking whether a Skill states concrete output artifacts and consumers.
allowed-tools: Read
---

# artifact-contract-missing

## HARD-GATE

- Stop when inputs are missing.

## Goal

Goal: inspect artifact wording.
Completion boundary: produce an audit result with evidence.

## Workflow

| step_id | input | action | output | consumer | acceptance | failure_state | proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| check | Target | Read and check the target | Finding list | user | Finding list cites evidence | Stop on missing input | JSON output |

## Output

Generate a report.

## Verification

- [ ] Run command: `python3 shared/skills/skill-harness/scripts/check_skill_package_quality.py tests/fixtures/skill-quality-detection/artifact-contract-missing`.
- [ ] Evidence: output includes the artifact contract finding.
