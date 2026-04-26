---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

> Source: `obra/superpowers/skills/verification-before-completion/SKILL.md` (pinned in `community/SOURCES.yaml`)


# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

From 24 failure memories:
- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

Treat "可以交付了" / "ready to ship" as a closeout trigger, not delivery approval.

## Closeout Routing

If verification is green, route the next step by context:

1. Small-chain artifacts exist (`design.md`, `tasks.md`, `plan.md`)
   - Invoke `verify-change` before any merge, PR, archive, or "delivered" claim.
2. No small-chain artifacts
   - Branch integration or worktree cleanup is still pending.
   - Invoke `finishing-a-development-branch`.
3. Already on the target branch and no branch action is pending
   - Report verified state only. Do not imply integration, installation, or archive happened.

For small-chain, `verify-change` is the gate and `finishing-a-development-branch` is the integration step.

For routed small-chain work, collect route evidence before invoking `verify-change`:

- `execution-route.json`
- `parallel-execution-report.json` when `decision=parallel`
- fresh proving command output for the serial or parallel execution path

For contract-grade or runtime-gate small-chain work, run an adversarial code review before `verify-change` and record the result in the active workset:

- `code-review-result.json`
- `review_conclusion` must be `APPROVE`
- `gate_result` must be `PASS`
- review must cover the failure matrix and evidence integrity when hooks, validators, installers, skills, artifacts, or scripts that output PASS/decision/status are touched

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.

## 流程导航

- 当前完成条件：fresh proving command 已执行，输出已读取；若触发 contract-grade/runtime-gate，`code-review-result.json` 已 PASS。
- 下一步：small-chain 变更进入 `verify-change`；非 small-chain 场景按 closeout context 路由。
- 完整链路：`brainstorming → writing-plans → small-chain-execution-router → subagent-driven-development（serial） / parallel-subagent-development（parallel） → verification-before-completion → requesting-code-review（contract-grade/runtime-gate） → verify-change → finishing-a-development-branch → archive`

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；验证前确认当前 feature 仍由 `management_status` 纳管。
- `worklog.md` 的 `handoff_status / state_ref / next_ref` 只说明从哪里接手；完成证明必须回到真实 `tasks.md / plan.md / design.md / execution-route.json` 和 fresh proving command。
- 若验证阻断，追加新的 blocked `worklog.md` 记录，而不是编辑旧记录。
