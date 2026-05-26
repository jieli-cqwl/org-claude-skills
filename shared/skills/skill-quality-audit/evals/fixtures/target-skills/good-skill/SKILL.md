---
name: good-skill
description: "Use when validating skill-quality-audit positive fixtures."
allowed-tools: Read, Grep, Bash
---

# Good Skill

Goal: produce a checked report from a known input file.

## HARD-GATE

Stop if the input file is missing.

## Workflow

1. Read the input file path from the user request.
2. Verify the file exists with `test -f`.
3. Output a summary with source path, finding count, and verification command.

## Verification

Run `bash tests/example.sh` and include the command result as evidence.
