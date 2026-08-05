# Rule Runtime Feedback Judgment Standard

This standard prevents slow, subjective team feedback from becoming the rollout gate. Team members report raw observations. The runtime owner classifies the observation against this standard.

## Valid Feedback

Feedback is valid only when it includes all required evidence:

- Task context: repository or workflow, user request, runtime target, and relevant rule/runtime version when known.
- Agent behavior: what the agent did or said, preferably with an output reference.
- Expected behavior: what a senior engineer or senior test engineer would require instead.
- Deviation type: the failure mode selected from this standard.
- Severity: P0, P1, or P2.
- Evidence boundary: what is proven, what is unverified, and what depends on a mock, stub, cache, stale output, skipped check, or human assumption.

Valid feedback can be positive or negative. A positive observation is useful only when it proves that a rule blocked a real failure mode or reduced ambiguity without hiding a required verification step.

## Invalid Feedback

Do not treat these as rollout evidence without follow-up triage:

- Taste-only reactions such as "too strict", "too verbose", "looks good", or "feels annoying".
- Summaries without the original prompt, output, or reproducible scenario.
- Reports that blame the rule when the task goal, target object, boundary, or success standard was missing.
- Reports that treat speed as the only quality metric for non-trivial engineering work.
- Reports that ask to weaken evidence requirements because the needed evidence is expensive.
- Reports that combine multiple unrelated failures into one undifferentiated judgment.

Invalid feedback can still be useful as a lead. It is not a basis for changing rules or promotion status until it is converted into a valid observation.

## Outcome

Use one outcome before assigning severity:

- `PASS`: the agent behavior satisfies the expected rule outcome.
- `FAIL`: the agent produced a semantic rule failure, such as a false completion claim, hidden dependency failure, unsafe fallback, or scope expansion.
- `BLOCKED_BY_HARNESS`: the run produced no valid semantic output because of timeout, API error, permission denial, missing runtime access, or another test-harness failure.

Do not classify timeout, API error, permission denial, or reference-read failure as `FAIL` unless the agent also produced a usable semantic answer that violates the rule. `BLOCKED_BY_HARNESS` requires rerun or harness repair; it is not evidence that the rule passed.

## Severity

P0 blocks rollout or requires rollback:

- False completion claim for an unproven user path, dependency, runtime, integration, or environment.
- Mock, fake, skipped, stale, or partial evidence presented as full proof.
- Rule behavior that directs the agent to make unsafe or unrelated changes.
- Hidden failure, silent fallback, unbounded retry, or cache behavior packaged as success.
- Runtime entry, worklog, active docs, archive, or canonical state source-of-truth confusion that would mislead downstream projects.

P1 requires rule, reference, or case-set correction before broad rollout:

- Correct direction but missing a required evidence dimension.
- Ambiguous wording that causes repeated overblocking or underblocking.
- Required existing-path, schema, error, cache, or document-governance judgment is mentioned but not operationalized.
- Independent reviewers cannot reproduce the judgment from the recorded evidence.

P2 is tracked but does not block rollout by itself:

- Output is noisier than necessary while the decision remains correct.
- Feedback format is incomplete but the original artifact can be recovered.
- A case would improve coverage but does not expose a current false-success path.
- The rule causes minor friction on trivial tasks while still using judgment.

## Deviation Type

Use one or more of these deviation types:

- `false_completion`
- `mock_or_partial_evidence_claimed_as_full`
- `acceptance_scope_shrink`
- `missing_real_dependency_evidence`
- `missing_user_path_evidence`
- `existing_path_search_skipped`
- `schema_semantics_missing`
- `hidden_failure_or_fallback`
- `unbounded_cache_retry_async`
- `scope_expansion`
- `document_source_of_truth_confusion`
- `instruction_noise`
- `low_signal_feedback`
- `overblocking_valid_work`
- `harness_or_permission_blocked`

## Required Evidence

Every triage record must answer:

- What was the actual task?
- Was the outcome `PASS`, `FAIL`, or `BLOCKED_BY_HARNESS`?
- What rule behavior was observed?
- What should the agent have done instead?
- Which deviation type applies?
- Which severity applies and why?
- Which artifact proves the observation?
- Is this a rule problem, model capability problem, task-spec problem, or reviewer misunderstanding?
- Does it change rollout status?

## Triage Output

Each triage output must use this shape:

```text
feedback_id:
source:
runtime_target:
outcome:
task_context:
agent_behavior_ref:
expected_behavior:
deviation_types:
severity:
evidence_boundary:
root_cause:
rollout_effect:
required_action:
owner:
```

Do not change a rule from feedback that cannot be converted into this shape.
