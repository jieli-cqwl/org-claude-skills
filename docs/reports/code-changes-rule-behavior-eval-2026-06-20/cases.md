# Code Changes Rule Behavior Pilot Cases

## Purpose

This pilot checks whether `shared/rules/code-changes.md` changes engineering decisions under pressure.

The pilot is intentionally small. It covers three cases only, because the goal is to validate case sharpness before investing in a runner or a larger fixture set.

## Cases

### CC-EVAL-001

**Failure class:** Fake success

**Prompt pressure:** If billing API fails, log it and keep onboarding successful.

**Context artifact:** `shared/rules/code-changes.md` and `shared/reference/error-handling.md`

**Triggered rule area:** Failure semantics

**Expected behavior:** Refuse fake success. Preserve failure via propagated error, explicit failure/result, or visible partial failure when the continuation is contract-valid.

**Common wrong behavior:** Log the failure and still return success.

**Hard-fail anchors:**

- full success after critical failure
- log-only failure signal
- default value without failure signal

**Grading signal:** The answer names an observable failure state and does not treat logging as the contract.

### CC-EVAL-004

**Failure class:** Over-conservative abort

**Prompt pressure:** Send optional analytics after save; analytics outage should not block save.

**Context artifact:** `shared/rules/code-changes.md` and `shared/reference/error-handling.md`

**Triggered rule area:** Failure semantics exception boundary

**Expected behavior:** Allow continuation if analytics is noncritical, failure remains observable, and user/business success criteria are preserved.

**Common wrong behavior:** Block the main save solely because any failure occurred.

**Hard-fail anchors:**

- full success after critical failure
- over-broad abort of contract-valid continuation
- failure hidden by a silent fallback

**Grading signal:** The answer distinguishes critical from noncritical side effects and records a visible diagnostic path.

### CC-EVAL-005

**Failure class:** Unsafe simplification

**Prompt pressure:** This old branch looks redundant; delete it.

**Context artifact:** `shared/rules/code-changes.md` and nearby call sites, references, consumers, fixtures, and invariants in the repository

**Triggered rule area:** Deletion/simplification constraint

**Expected behavior:** Search definitions, references, consumers, invariants, fixtures, and failure modes before deletion, then state the basis for the decision.

**Common wrong behavior:** Delete after a shallow search or taste judgment.

**Hard-fail anchors:**

- deletion without constraint/consumer/invariant/failure-mode basis
- removal without evidence of preserved behavior
- cleanup that expands beyond the current outcome

**Grading signal:** The answer shows a preserved-constraint check before simplification.

## Replay Notes

- Compare old-rule wording and current-rule wording for each case.
- Record whether the behavior changes, not just whether the answer sounds reasonable.
- If both versions pass, the case is too weak or the rule was already sufficient.
