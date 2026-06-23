# Code Changes Rule System Optimization

## Conclusion

`shared/rules/code-changes.md` should not be optimized as a sentence-polishing task. The correct work is to define a rule-system standard for agent-facing engineering guidance, then apply it to the whole Code Changes rule and its references.

The target direction is:

1. Keep root rules short, hard, high-frequency, and runtime-safe.
2. Express each root rule as a positive decision model first, with prohibitions as guardrails.
3. Put nuance, examples, exceptions, and recovery paths in `shared/reference/*`.
4. Prove critical behavior with semantic tests, evals, hooks, validators, or review gates instead of freezing prose.

The current error-handling bullet is directionally correct but incomplete as a top-level instruction:

```text
Do not swallow errors, log-and-continue after failure, return fake defaults, or convert failure into success.
```

Its underlying invariant is stronger and clearer:

```text
Preserve failure semantics: failure must remain visible, diagnosable, and recoverable, and success must not be fabricated.
```

## Scope

This document defines the direction and reasoning for a system-level optimization. It does not modify `shared/rules/code-changes.md`, `shared/reference/error-handling.md`, tests, runtime files, or installation behavior.

## Evidence Base

### Local Structure

- `AGENTS.md` defines `shared/rules/*.md` as global runtime rules that should contain only hard team-wide constraints.
- `shared/assistant.md` gives runtime `rules/` priority over `reference/`, and routes code changes to `rules/code-changes.md`.
- `shared/rules/code-changes.md` is intentionally flat: one lead sentence plus concise bullets.
- `shared/reference/error-handling.md` already contains the deeper positive model: failures must be visible, diagnosable, recoverable, and not packaged as success.
- `tests/test-runtime-contract-catalog.sh` enforces Code Changes rule shape: flat, concise, no handbook sections, one self-test bullet, and the expected reference set.
- `AGENTS.md` and `tools/community/check_test_signal_assertions.py` reject low-signal tests that lock natural-language prose in Skill, Rule, Reference, or Agent Markdown.

### External Guidance

- OpenAI Codex guidance recommends practical, concise durable instructions, clear definitions of done, and verification-oriented workflows.
- OpenAI Codex `AGENTS.md` guidance treats repository instructions as durable agent context, not a substitute for tests or tool enforcement.
- OpenAI Model Spec uses instruction hierarchy and conflict handling as a first-class design problem, which supports explicit precedence and scoped authority.
- AWS Builders Library retry/fallback guidance supports the engineering view that retries and fallbacks must be bounded, observable, and semantically safe; they are not blanket success converters.
- The prior parallel review across prompt-design, reliability engineering, and repository-structure perspectives converged on the same direction: positive action model first, hard guardrails second, deep guidance in references, and behavior evidence for critical claims.

## Best-practice Definition

For this repository, an agent-facing rule is good only if it improves real agent behavior under current workflow constraints.

Required properties:

| Property | Meaning | Failure If Missing |
| --- | --- | --- |
| Correct invariant | States what must remain true. | Rule becomes style preference or local opinion. |
| Positive default action | Tells the agent what to do. | Agent only knows what to avoid and becomes defensive. |
| Exception boundary | States when an apparent violation is actually allowed. | Legitimate fallback, partial success, or cleanup is blocked. |
| Forbidden anti-pattern | Names the dangerous shortcuts. | The rule lacks teeth and allows fake success. |
| Evidence path | Says how correctness is proven. | Rule becomes unenforceable prose. |
| Correct layer | Root rule vs reference vs validator/hook/test is clear. | Root rule becomes a handbook or prompt becomes fake enforcement. |

Recommended rule-unit shape:

```text
Trigger / Scope -> Invariant -> Default correct action -> Allowed exceptions -> Forbidden anti-patterns -> Evidence
```

Root rules do not need all six fields inline every time. They must at least preserve the invariant, default action, and hard anti-pattern. Longer exception logic belongs in a reference file.

## Evaluation Dimensions

### 1. Prompt And Agent Behavior

Question: Will the rule help an agent choose the right next action?

Good signal:

- The rule says what correct work looks like.
- The rule reduces ambiguity at common decision points.
- The rule avoids broad `never/always` wording unless the invariant is truly absolute.
- The rule has a clear stop or escalation path when conditions are not met.

Bad signal:

- It only lists prohibitions.
- It uses strong words to compensate for unclear behavior.
- It makes the agent avoid legitimate work because exceptions are not named.

### 2. Software Engineering Semantics

Question: Is the rule technically true in real code?

Good signal:

- It distinguishes error propagation, typed failure/result, visible partial failure, fallback, retry, cleanup, rollback, compensation, and manual intervention.
- It treats logs and telemetry as diagnostic evidence, not as the return contract.
- It allows partial success only when the contract says partial success is a valid result.

Bad signal:

- It implies every failure must abort all work.
- It forbids `log-and-continue` without distinguishing best-effort side effects, cleanup, batch partial success, or delayed error exposure.
- It permits defaults without preserving business semantics.

### 3. Safety And Trust

Question: Is a prompt rule enough, or is deterministic enforcement required?

Prompt rules are appropriate for judgment, style, decomposition, and review posture.

Tests, hooks, validators, schemas, or scripts are required when failure would create:

- Secret exposure.
- Destructive or irreversible operations.
- Fake completion or fake readiness claims.
- Runtime installation drift.
- Machine-consumed contract drift.
- Security, permission, or data-integrity risk.

### 4. Repository Layering

Question: Is the guidance in the right file?

Use root rule when:

- It is high-frequency across coding tasks.
- It should be hard to bypass.
- It can be stated compactly.
- It points to a deeper reference for nuance.

Use reference when:

- The rule needs examples, valid exceptions, recovery paths, or domain-specific explanation.
- A reader needs guidance for fallback, retry, compensation, logging, partial success, or cleanup.

Use tests/evals/hooks/validators when:

- The requirement must be mechanically checked.
- A prose instruction cannot reliably prevent the failure mode.

### 5. Verification Quality

Question: Would the test fail for the important wrong behavior?

Acceptable evidence:

- Parser or semantic checks over rule structure and required concepts.
- Behavior fixtures or eval prompts that distinguish correct handling from fake success.
- Runtime install checks that compare rendered shared rules/reference to actual runtime files.
- Review gates that require scope-matching evidence.

Weak evidence:

- Grepping exact prose in Markdown.
- Counting that a word appears somewhere.
- Treating green tests outside the changed behavior as proof.

## Error-handling Case Study

The current bullet is correct as a guardrail but weak as a rule unit.

Problem:

- It names anti-patterns but omits the default correct action.
- It can be misread as forbidding all continuation after any failure.
- It does not state the allowed boundary for fallback/default/partial success.

Correct engineering model:

| Concept | Correct Semantics |
| --- | --- |
| Failure propagation | Unexpected or in-scope failures must remain observable to the caller or workflow owner. |
| Typed failure/result | Expected recoverable failures should be machine-readable when the caller can act on them. |
| Log/telemetry | Diagnostic path only; not a substitute for return status. |
| Partial success | Valid only when explicitly part of the contract and represented in the result. |
| Fallback/default | Valid only when named conditions hold and business semantics do not change. |
| Retry | Valid only for suitable transient failures, with bounds and final failure exit. |
| Compensation | Recovery path after side effects; not a way to report clean success. |

Recommended root-rule direction:

```text
Preserve failure semantics: propagate errors, return explicit failure/result states, or expose visible partial-failure states when the contract allows them. Use fallback, defaults, or continue-after-failure only when business semantics are preserved and the failure remains observable. Do not swallow errors or report fake success.
```

The exact wording should be finalized only after deciding the whole Code Changes rule pass, because changing one bullet may require aligning the root lead sentence, self-test bullet, and `error-handling.md`.

## Recommended Optimization Approach

### Option A: Local Sentence Rewrite

Change only the error-handling bullet.

Decision: not recommended as the main path.

Reason:

- It fixes one symptom but leaves no standard for the rest of the rule file.
- It may improve wording without improving agent behavior.
- It risks drifting from `shared/reference/error-handling.md` if the deeper reference is not reviewed at the same time.

### Option B: Code Changes Rule System Pass

Review all bullets in `shared/rules/code-changes.md` against the rule-unit standard, then update only the bullets that fail the standard.

Decision: recommended.

Reason:

- It preserves the current root-rule architecture.
- It avoids handbook creep.
- It aligns each root bullet with its reference owner and verification path.
- It can be done surgically while still being systematic.

### Option C: Runtime Rule Architecture Redesign

Redesign `rules/`, `reference/`, assistant entry, tests, and install behavior.

Decision: not justified by current evidence.

Reason:

- Current architecture already has a sensible root-rule/reference split.
- Tests intentionally enforce the flat rule shape.
- The observed issue is rule-unit quality, not runtime architecture failure.

## Code Changes Bullet Audit

This audit applies the rule-unit standard to every current bullet in `shared/rules/code-changes.md`. It is a design-level assessment, not an implementation patch.

| Current Area | Current Role | Assessment | Recommended Treatment |
| --- | --- | --- | --- |
| Smallest scoped change | Positive default action | Strong root rule. It gives a clear action and protects scope. | Keep. No added nuance needed in root. |
| Match existing style and boundaries | Positive default action | Strong root rule. It prevents invention and ownership drift. | Keep. If future failures appear, route details to structure/reuse reference. |
| No adjacent refactor/reformat/rename | Guardrail | Strong but negative-only. It is acceptable because the exception is already inline: unless required for current outcome. | Keep. |
| Before deleting/simplifying artifacts, identify preserved constraint/consumer/invariant/failure mode | Positive gate before destructive simplification | Strongest current example of the desired pattern: trigger, action, evidence basis. Already semantically locked by test. | Keep. Use as model for other bullets. |
| Search for existing semantic equivalent before adding behavior | Positive default action | Strong root rule. Good trigger and action. | Keep. |
| Reuse/extract only when it clarifies, removes real duplication, or stabilizes shared contract | Positive decision boundary | Strong root rule. It gives allowed conditions. | Keep. |
| No abstraction for single use/speculation/cosmetic consistency | Guardrail | Good paired guardrail after the reuse rule. | Keep. |
| Shallow explicit control flow; prefer early failure | Positive style/default | Mostly good, but "prefer early failure" can be misread if cleanup/partial-success/fallback is needed. | Keep root wording only if error-handling reference remains explicit about allowed continuation. |
| Split by responsibility when complexity obscures ownership/failure/verification | Positive decomposition trigger | Strong rule-unit shape. | Keep. |
| Comments explain intent/invariants/boundaries/tradeoffs/failure/business rules | Positive action plus anti-pattern | Strong rule-unit shape. | Keep. |
| Do not swallow errors/log-and-continue/fake defaults/fake success | Guardrail only | Directionally right but incomplete. It lacks default correct action and exception boundary; `log-and-continue` is overbroad without visible partial-failure semantics. | Rewrite as positive failure-semantics root rule; keep anti-patterns at the end. Align with `error-handling.md`. |
| External operations need timeouts/failure handling/cleanup/observable failure states | Positive requirement | Strong root rule. It names triggered operation classes and required safeguards. | Keep. Consider reference owning detailed timeout/retry policy. |
| User-visible errors understandable and no secret/internal leakage | Positive requirement plus safety guardrail | Strong root rule. Security-sensitive enough to remain in root. | Keep. |
| Never hardcode secrets/tokens/passwords/credentials/environment-specific addresses/deployment differences | Hard guardrail | Valid absolute rule because the invariant is safety/config correctness. | Keep. No softening. |
| Cross-module constants only for stable public contracts; no private constants across boundaries | Decision boundary | Strong root rule. | Keep. |
| Remove unused/imports/etc introduced or touched by current change, or blocking correctness/build/verification | Cleanup boundary | Good but dense. It is scope-bounded and prevents adjacent cleanup creep. | Keep unless future readability pass splits it. |
| Temporary files/retries/loops/polling/async/batch bounded with cleanup | Positive requirement | Strong root rule. It names triggered resource-growth paths and safeguards. | Keep. |
| No shared/persistent/freshness-affecting cache without approval and invalidation/failure strategy | Hard guardrail with explicit exception | Strong root rule. | Keep. |
| Reference route: structure/reuse | Reference loading rule | Correct layer. | Keep. |
| Reference route: comments | Reference loading rule | Correct layer. | Keep. |
| Reference route: errors/external/fallback/retries/cleanup/partial success | Reference loading rule | Correct layer, but more important if root error bullet is rewritten. | Keep. Ensure future root wording points to this route by topic, not prose duplication. |
| Reference route: constants/config/secrets | Reference loading rule | Correct layer. | Keep. |
| Reference route: performance/batching/polling/cache/large data | Reference loading rule | Correct layer. | Keep. |
| Self-test bullet | Completion judgment | Strong concise meta-test. It already encodes simplest maintainable change, fail-loud behavior, and contract preservation. | Keep initially. Revisit only after the full rule-unit rewrite. |

## Layering Decision

The current file has one high-priority rewrite candidate: the error-handling guardrail bullet. Several other bullets are negative, but most already have valid exception boundaries or are true hard guardrails.

Recommended root-rule edits in a later implementation should be limited to:

1. Rewriting the error-handling bullet into positive failure-semantics form.
2. Optionally tightening the control-flow bullet only if the new error semantics still leave ambiguity.
3. Adding one semantic shape check if the project wants to prevent regression to negative-only error wording.

Recommended reference edits should be limited to `shared/reference/error-handling.md` if the audit finds missing nuance for allowed continuation. Candidate additions:

- Allowed continuation categories: best-effort noncritical side effect, cleanup/rollback collection, bounded batch partial success, documented degraded mode.
- Required result evidence: explicit status, failed items, retry exhaustion reason, affected object, recovery or manual intervention path.
- Forbidden result states: log-only failure signal, default without error signal, full success after critical side-effect failure.

## Candidate Semantic Test Design

If the implementation changes semantics, test the concept rather than the sentence.

Potential check in `tests/test-runtime-contract-catalog.sh`:

```text
The Code Changes rule must contain error semantics that require an observable failure path and prohibit fake success.
```

Machine-checkable concept tokens can include:

- `failure semantics` or equivalent explicit failure-state phrase.
- one of `propagate`, `explicit failure`, `failure/result`, or `partial-failure`.
- one of `observable`, `visible`, or `failure remains`.
- one of `fake success`, `convert failure into success`, or `report full success`.

This should be implemented as a semantic guard with multiple allowed phrasings, not an exact prose assertion.

## Proposed Work Plan

1. Build a rule-unit audit table for every bullet in `shared/rules/code-changes.md`.
2. For each bullet, classify:
   - invariant
   - default action
   - exception boundary
   - anti-pattern
   - reference owner
   - verification owner
   - risk if misread
3. Mark each bullet as:
   - keep
   - rewrite root bullet
   - move nuance to reference
   - add/adjust semantic test
   - out of scope
4. Update `shared/reference/error-handling.md` only if the root-rule pass exposes missing nuance.
5. Add tests only for machine-checkable structure or critical semantics; do not lock exact prose.
6. Run targeted verification first, then quick regression if behavior or runtime shape changes.

## Acceptance Criteria For A Future Implementation

The future implementation is acceptable only if:

- `shared/rules/code-changes.md` remains flat, concise, and within the existing bullet-count contract.
- Root bullets say what to do, not only what to avoid.
- Guardrails remain explicit for fake success, secrets, destructive risk, hidden cache, and unbounded work.
- `shared/reference/error-handling.md` keeps the detailed failure model and does not duplicate root-rule boilerplate.
- Tests do not use low-signal natural-language prose locking.
- Verification includes:
  - `bash tests/test-runtime-contract-catalog.sh`
  - `bash tests/test-reference-decision-rules.sh`
  - `bash tests/test-reference-graph-hygiene.sh`
  - `bash tests/test-test-assertion-boundary-contract.sh`
  - `bash tests/test-install-runtime-smoke.sh`
  - `bash tests/run-all.sh --quick` when runtime rule behavior changes.

## Non-goals

- Do not rewrite every rule for cosmetic consistency.
- Do not turn `code-changes.md` into a handbook.
- Do not merge reference guidance into root rules.
- Do not treat community advice as authority without mapping it to local failure modes.
- Do not claim the optimized wording improves behavior until eval or pressure-case evidence exists.

## Open Questions

1. Should this repository add a dedicated eval case for `log-and-continue` versus visible partial failure?
2. Should the Code Changes root self-test bullet be updated after the full audit, or remain stable?
3. Should `error-handling.md` add explicit allowed-continuation cases, or is that better handled by future language/runtime-specific references?
4. Should rule-unit audit become a reusable checklist for all `shared/rules/*.md`, or stay limited to Code Changes for now?

## Recommended Next Decision

Approve Option B as the implementation direction:

```text
Run a Code Changes rule-unit audit, then make minimal root-rule/reference/test changes for bullets that fail the standard.
```

Do not approve direct sentence-level patching unless the goal is deliberately limited to copy editing.
