# Error Handling

Error handling must make failure visible, diagnosable, and recoverable; it must not package failure as success.

## Failure Propagation

- Empty catch blocks, bare except blocks, log-and-continue after failure, and default returns without error signal are forbidden.
- Catch only expected error types; unexpected errors must keep an observable failure path.
- Fallback, downgrade, and default values must name their valid conditions and must not change business semantics.
- Exhausted retries must return a visible failure state or enter an explicit manual intervention path.

## External Dependencies

- External API, network, database, filesystem, shell, and third-party CLI calls must set timeouts.
- Failure logs must include diagnostic context such as request ID, dependency name, operation, retry state, and affected object.
- Logs must not contain secrets, tokens, passwords, credentials, or user-sensitive data.
- Files, connections, locks, temporary resources, and subscriptions must be cleaned up on failure paths.

## User-Visible Errors

- User-facing errors must be understandable and actionable.
- Do not expose stack traces, SQL, keys, internal paths, service names, or implementation details.
- Permission, input, dependency outage, rate limit, timeout, and conflict failures should have distinct error semantics.

## State Changes And Partial Success

- State changes, batch work, async jobs, and partial success must expose the resulting failure state.
- Define rollback, retry, compensation, or manual intervention paths.
- Do not return overall success after side-effect failure unless the success criteria explicitly allow partial success and the result is visible.
