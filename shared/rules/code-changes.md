# Code Changes

Code must solve the requested problem without adding hidden risk, unnecessary complexity, or false success paths.

- Make the smallest change that satisfies the current scope.
- Match existing style, ownership boundaries, naming, dependency direction, and runtime patterns.
- Do not refactor, reformat, rename, or clean adjacent code unless required for the current outcome.
- Before adding behavior, search for an existing semantic equivalent through definitions, references, call sites, utilities, types, scripts, or code intelligence when available.
- Reuse or extract only when it makes the code clearer, reduces real duplication, or stabilizes a shared contract.
- Do not create an abstraction for a single use, speculative future, or cosmetic consistency.
- Keep control flow shallow and explicit; prefer early failure over nested happy paths.
- If complexity makes ownership, failure handling, or verification boundaries unclear, split by responsibility unless the shape is forced by a framework or public contract.
- Comments must explain intent, invariants, boundaries, tradeoffs, failure modes, or non-obvious business rules; do not narrate obvious code.
- Do not swallow errors, log-and-continue after failure, return fake defaults, or convert failure into success.
- External API, network, database, process execution, remote filesystem, and long-running operations need timeouts, failure handling, cleanup, and observable failure states.
- User-visible errors must be understandable and must not expose secrets, stack traces, SQL, internal paths, or service internals.
- Never hardcode secrets, tokens, passwords, credentials, environment-specific addresses, or deployment differences.
- Cross-module constants are allowed only for stable public contracts; do not import another module's private constants across ownership boundaries.
- Remove unused imports, variables, functions, fields, unreachable branches, and commented-out old implementations introduced or touched by the current change, or blocking current correctness/build/verification.
- Temporary files, retries, loops, polling, async jobs, and batch work must have bounded paths, limits, timeouts, and cleanup.
- Do not add shared, persistent, cross-request, or freshness-affecting cache without explicit user approval and a verified invalidation/failure strategy.
- For structure, complexity, reuse, compatibility, or shared contracts, read `{{RUNTIME_HOME}}/reference/code-structure-reuse.md`.
- For comments, SQL, schema, concurrency, protocol, parsing, regex, or business invariants, read `{{RUNTIME_HOME}}/reference/code-comments.md`.
- For errors, external calls, fallback, retries, cleanup, or partial success, read `{{RUNTIME_HOME}}/reference/error-handling.md`.
- For constants, configuration, secrets, environment differences, or shared values, read `{{RUNTIME_HOME}}/reference/constants-and-configuration.md`.
- For performance, batching, polling, async jobs, temp files, caching, large data, or database query cost, read `{{RUNTIME_HOME}}/reference/performance-and-efficiency.md`.
- Test: Would a senior engineer accept this as the simplest maintainable change that fails loudly and preserves existing contracts? If not, simplify or surface the risk.
