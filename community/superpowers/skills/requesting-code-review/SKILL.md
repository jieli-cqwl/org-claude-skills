---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

> Source: `obra/superpowers/skills/requesting-code-review/SKILL.md` (pinned in `community/SOURCES.yaml`)


# Requesting Code Review

Dispatch superpowers:code-reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code-reviewer subagent:**

Use Task tool with superpowers:code-reviewer type, fill template at `code-reviewer.md`

**Placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch superpowers:generic-code-reviewer subagent]
  WHAT_WAS_IMPLEMENTED: Verification and repair functions for conversation index
  PLAN_OR_REQUIREMENTS: Task 2 from docs/user-auth/2026-04-02-login-home/plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

Subagent-Driven Development:
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

Ad-Hoc Development:
- Review before merge
- Review when stuck

Small-chain contract-grade/runtime-gate changes:
- Review after `verification-before-completion` and before `verify-change`.
- Write or preserve active workset `code-review-result.json`.
- The review gate passes only when `review_conclusion=APPROVE` and `gate_result=PASS`.
- If the diff touches skills, hooks, validators, installers, artifacts, or scripts that output `PASS`, `decision`, `verified`, `APPROVE`, or `status`, include evidence-integrity review coverage.
- Any Critical/Important issue must loop back to fix and re-review before `verify-change`.

## 流程导航

- 当前完成条件：code review 已覆盖当前 diff，且无未修复 Critical/Important issue；contract-grade/runtime-gate 场景下 active workset `code-review-result.json` 为 PASS。
- 下一步：`verify-change`
- 完整链路：`brainstorming → writing-plans → implementation-router → subagent-driven-development（serial） / parallel-subagent-development（parallel） → verification-before-completion → requesting-code-review（contract-grade/runtime-gate） → verify-change → finishing-a-development-branch → archive`

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；只对 `management_status in [managed, migrated]` 的 feature 建立默认接手上下文。
- `worklog.md` 最新记录的 `handoff_status / state_ref / next_ref` 决定接手入口。
- contract-grade/runtime-gate 审查结果写入 active workset 的 `code-review-result.json`，不复制到 `worklog.md` 正文。

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md
