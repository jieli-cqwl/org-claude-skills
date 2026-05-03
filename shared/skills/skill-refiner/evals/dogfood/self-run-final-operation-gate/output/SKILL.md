---
name: tiny-review-router
user-invocable: true
description: Route code-review Skill requests by locating existing review capability first; defer create, split, or optimize decisions until SR-F1 final operation freeze.
allowed-tools: Read, Grep
---

# Tiny Review Router

## Goal

Help when a user is unsure whether to create a code-review Skill or reuse existing review capability.

## Hard Gate

1. Locate existing review capability before proposing any new Skill.
2. Treat create, split, rewrite, or optimize as candidate operations until all evidence is reviewed.
3. SR-F1 final operation: optimize existing tiny-review-router.
4. Do not create files before the final operation is frozen.

## Flow

1. Read the user request and identify the requested review scenario.
2. Search existing Skill names, descriptions, tests, and runtime entries for review or code-review capability.
3. Summarize reuse candidates, missing boundaries, and user-facing tradeoffs.
4. Register only candidate operations while evidence is incomplete.
5. Freeze the final operation after all Trigger, Responsibility, Input, Flow, Output, Resource, Determinism, Eval, Cleanup, and Runtime checks are confirmed.
6. Execute only the frozen operation and report proof commands.

## Output

Return the existing capability candidates, confirmed final operation, changed files, proof commands, and residual risks.
