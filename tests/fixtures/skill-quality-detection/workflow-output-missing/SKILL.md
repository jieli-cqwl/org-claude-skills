---
name: workflow-output-missing
description: Use when checking a Skill workflow that has actions but no step-level product contract.
allowed-tools: Read
---

# workflow-output-missing

## HARD-GATE

- Stop when the target is missing.

## Goal

Goal: inspect a Skill workflow.
Completion boundary: produce an audit result with evidence.

## Workflow

1. Read the target Skill.
2. Check the target instructions.
3. Verify the result.
4. Stop on missing inputs.

## Verification

- [ ] Run command: `python3 tools/skill_quality/check_skill_package_quality.py tests/fixtures/skill-quality-detection/workflow-output-missing`.
- [ ] Evidence: output includes the workflow output contract finding.
