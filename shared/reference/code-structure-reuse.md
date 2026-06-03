# Code Structure And Reuse

Code structure should reduce current complexity, not create the appearance of architecture.

## Complexity Signals

- Treat high cyclomatic complexity, long parameter lists, deep nesting, and oversized files as signals to inspect responsibility boundaries, not as automatic refactor triggers.
- When a complexity signal appears, first check whether responsibilities are mixed; split by responsibility, boundary, or data flow only when it clarifies ownership, failure handling, or verification.
- When parameters grow, prefer a domain parameter object over loose argument lists if it makes required inputs, defaults, and invariants clearer.
- Keep framework signatures, public API compatibility, generated files, pure configuration maps, and stable data tables intact when splitting would add risk or obscure intent.
- Record the reason, risk, and verification method when a high-complexity shape is intentionally retained.

## Reuse Search

Before adding implementation, check:

- Definitions, references, callers, types, interfaces, and public exports.
- Same directory, same module, shared utilities, script entrypoints, and test fixtures.
- Code intelligence, including LSP-backed reference search, IDE navigation, code indexes, and type-aware search when available; use text search to cover dynamic, configuration, and generated paths.

## Abstraction Judgment

- Evaluate reuse from a senior engineer perspective: optimize clarity, maintainability, evolvability, and contract stability.
- Reuse or abstraction must make call relationships clearer, remove real duplication, or stabilize a shared contract.
- Single use, future speculation, naming symmetry, or surface similarity is not enough.
- Keep concrete code when abstraction increases dependency direction complexity, hidden state, parameter complexity, or test difficulty.
- An abstraction created only to satisfy a metric is a complexity regression.

## Compatibility Code

- Compatibility layers must name the retained callers, reason, removal condition, and deletion path.
- Compatibility logic must not swallow new errors, change business semantics, or hide migration failure.
