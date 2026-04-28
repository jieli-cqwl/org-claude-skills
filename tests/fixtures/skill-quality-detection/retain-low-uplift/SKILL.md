---
name: retain-low-uplift
description: Use when checking retain decisions against empirical uplift gates.
allowed-tools: Read
---

# retain-low-uplift

## HARD-GATE

- Stop when retain evidence is missing.

## Goal

Goal: inspect retain evidence.
Completion boundary: output retain gate findings with evidence.

## Workflow

| step_id | input | action | output | consumer | acceptance | failure_state | proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| retain | lifecycle review | Read retain metrics and check thresholds | Finding list | user | Retain metrics meet threshold | Stop on threshold miss | JSON output |

## Verification

- [ ] Run command: `python3 shared/skills/skill-harness/scripts/check_skill_package_quality.py tests/fixtures/skill-quality-detection/retain-low-uplift`.
- [ ] Evidence: output includes retain uplift finding.
