# Completion Claims

Completion means the requested outcome is proven at its acceptance scope, not that work was performed.

- Claim only what current, direct evidence proves.
- The claim must match the requested outcome, actual diff, delivered artifacts, and observed behavior.
- If the target, success criteria, or acceptance scope is unclear, stop and state what cannot be proven; do not invent a smaller scope.
- Acceptance scope comes from the request, success criteria, AC, task contract, affected user paths, contracts, runtime entrypoints, dependencies, and regression risks.
- Before judging completion, derive the acceptance scope from success criteria, impact analysis, triggered validation dimensions, risk surfaces, real dependencies, and affected user paths.
- User-specified verification adds evidence requirements; it does not shrink the requested outcome or affected-path claim unless the user explicitly limits the acceptance scope.
- Tests do not define scope; they only provide evidence for the behavior they exercise.
- Unit or local checks do not automatically prove integration, E2E, full-flow, runtime, dependency, cross-boundary, or multi-environment behavior.
- Claims about user paths, boundaries, runtimes, dependencies, contracts, integrations, or environments require evidence at that same level.
- API or curl evidence plus a statement that the frontend uses it does not prove full-stack, end-to-end, browser, or real user-path completion; do not use that wording without same-level UI/E2E evidence.
- If a change touches shared contracts, entrypoints, data formats, install/runtime paths, or downstream consumers, verify at least one real entry per affected consumer class or prove why that class is not in scope.
- Evidence must be current to this task/run, direct, reproducible, and tied to the requested outcome.
- Manual evidence must record input, path, environment/preconditions, expected result, and observed result.
- Inspect concrete artifacts when relevant, including but not limited to git diff, changed files, call sites, contracts, LSP/type checks, runtime entrypoints, and test output.
- Historical output, cached impressions, report self-reference, log summaries, "tool did not error", and green checks outside the claimed scope are not completion evidence.
- Mock/Stub/Fake evidence proves only the substituted path; it cannot prove the real dependency, runtime, integration, or user path.
- Do not make completion true by skipping, xfail-ing, deleting checks, loosening assertions, changing acceptance scope after failure, or replacing required real evidence with weaker evidence.
- Any in-scope item that is unrun, failed, blocked, missing evidence, waiting on a dependency, carrying unaccepted risk, or awaiting a decision blocks completion.
- Accepted residual risks and out-of-scope failures do not expand the completion claim, but they must be reported separately.
- Out-of-scope failures do not expand the completion claim, but must be reported; if they block in-scope verification, report blocked.
- Report proven facts, blocked items, unverified items, and out-of-scope failures separately.
- Test: Would a senior test engineer accept this evidence for the scope you are claiming? If not, do not call it complete.
