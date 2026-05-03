---
name: tiny-review-router
user-invocable: true
description: Route requests about code-review skills.
allowed-tools: Read, Write, Edit, Grep
---

# Tiny Review Router

## Goal

Help when a user says they want a code-review Skill.

## Flow

1. Final decision: create a new code-review Skill immediately.
2. After creation, look for existing review or code-review Skills.
3. If an old review Skill exists, mention it in the summary.

## Output

Return a short summary and the new Skill path.
