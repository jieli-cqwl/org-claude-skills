# Code Structure And Reuse

Code structure should preserve existing behavior first, and improve code reuse only when a separate abstraction decision earns its cost.

## Existing Path Reuse

- Existing path reuse is the default for iterative work in existing projects; start from the existing implementation path instead of creating a parallel path.
- Trace callers, state branches, side effects, source of truth, data sources, UI entries, runtime entrypoints, tests, fixtures, and historical compatibility cases.
- Before adding behavior, identify the existing capability owner, callers, contracts, extension points, and compatibility constraints.
- Prefer to compatibly extend the existing path when it owns the same capability; a different scenario does not justify a new path if old callers keep identical behavior and verification remains clear.
- Add a new path only as an exception when the existing path cannot carry the required behavior or would break an existing contract.
- When adding a path, name the boundary, retained legacy behavior, affected callers, migration or removal condition, and regression evidence.
- Completion needs regression evidence for affected legacy behavior, not just proof that the new behavior works.

## Complexity Signals

- Treat high cyclomatic complexity, long parameter lists, deep nesting, and oversized files as signals to inspect responsibility boundaries, not as automatic refactor triggers.
- When a complexity signal appears, first check whether responsibilities are mixed; split by responsibility, boundary, or data flow only when it clarifies ownership, failure handling, or verification.
- When parameters grow, prefer a domain parameter object over loose argument lists if it makes required inputs, defaults, and invariants clearer.
- Keep framework signatures, public API compatibility, generated files, pure configuration maps, and stable data tables intact when splitting would add risk or obscure intent.
- Record the reason, risk, and verification method when a high-complexity shape is intentionally retained.

## Abstraction For Code Reuse

- Abstraction is a structural change for code reuse, not the default form of existing-path reuse.
- Create shared functions, components, services, interfaces, templates, or configuration structures only when they remove real duplication, expose a stable contract, and the call sites have aligned change direction.
- Abstraction must make call relationships clearer, reduce maintenance cost, or stabilize a shared contract.
- Single use, future speculation, naming symmetry, or surface similarity is not enough.
- Keep concrete code when abstraction increases dependency direction complexity, hidden state, parameter complexity, or test difficulty.
- An abstraction created only to satisfy a metric is a complexity regression.

## Compatibility Code

- Compatibility layers must name the retained callers, reason, removal condition, and deletion path.
- Compatibility logic must not swallow new errors, change business semantics, or hide migration failure.
