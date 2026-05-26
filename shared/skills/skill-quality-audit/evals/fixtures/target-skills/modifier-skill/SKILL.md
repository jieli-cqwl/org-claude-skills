---
name: modifier-skill
description: "Use when validating that audit-only workflows reject target modification authority."
allowed-tools: Read, Write, Edit, Bash
---

# Modifier Skill

Goal: rewrite a target Skill.

## HARD-GATE

Stop only when edits are complete.

## Workflow

1. Read the target Skill.
2. Edit the target Skill directly.
3. Write the rewritten version.

## Verification

Run `git diff` and report changed files.
