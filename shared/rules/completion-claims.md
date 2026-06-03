# Completion Claims

Completion means the requested outcome is proven at its acceptance scope, not that work was performed.

- Claim only what current, direct evidence proves.
- The claim must match the requested outcome, changed artifacts, delivered artifacts, and observed behavior.
- If the target, success criteria, or acceptance scope is unclear, stop and state what cannot be proven; do not invent a smaller scope.
- Before judging completion, derive the acceptance scope from the request, success criteria, explicit acceptance requirements, affected paths, contracts, dependencies, risks, and required verification.
- User-specified verification adds evidence requirements; it does not shrink the requested outcome or affected-path claim unless the user explicitly limits the acceptance scope.
- Checks prove only what they exercise; they cannot define, shrink, or redefine the requested outcome or acceptance scope.
- Completion evidence must distinguish the claimed outcome from in-scope failure modes; a check that would pass for the wrong behavior is not evidence.
- The strength of a completion claim must match the strength of its evidence; partial, sampled, local, or indirect evidence supports only the scope it proves.
- Unit or local checks do not automatically prove integration, E2E, full-flow, runtime, dependency, cross-boundary, or multi-environment behavior.
- Claims about user paths, boundaries, runtimes, dependencies, contracts, integrations, or environments require evidence at that same level.
- Evidence from one layer, interface, or substituted path does not prove another layer, dependency, end-to-end flow, or real user path without evidence at that same level.
- If a change touches shared contracts, entrypoints, data formats, install/runtime paths, or consumers, verify representative real consumers or prove why they are outside scope.
- Evidence must be current to this task/run, direct, reproducible, and tied to the requested outcome.
- Manual evidence must record input, path, environment/preconditions, expected result, and observed result.
- Inspect concrete artifacts when relevant, including changed artifacts, call sites, contracts or interfaces, static or type checks, runtime entrypoints, and test output.
- Historical output, cached impressions, report self-reference, log summaries, "tool did not error", and green checks outside the claimed scope are not completion evidence.
- Mock/Stub/Fake evidence proves only the substituted path; it cannot prove the real dependency, runtime, integration, or user path.
- Do not make completion true by skipping, xfail-ing, deleting checks, loosening assertions, changing acceptance scope after failure, or replacing required real evidence with weaker evidence.
- Any in-scope item that is unrun, failed, blocked, missing evidence, waiting on a dependency, carrying unaccepted risk, or awaiting a decision blocks completion.
- Accepted residual risks and out-of-scope failures do not expand the completion claim, but must be reported separately; if they block in-scope verification, report blocked.
- Report proven facts, blocked items, unverified items, and out-of-scope failures separately.
- Test: Would a senior test engineer accept this evidence for the scope you are claiming? If not, do not call it complete.
