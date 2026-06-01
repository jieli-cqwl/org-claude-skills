# Code Structure And Reuse

Code structure should reduce current complexity, not create the appearance of architecture.

## Complexity Thresholds

- Default limits: function CC <= 10, parameters <= 5, nesting <= 3, code file <= 400 lines.
- When a limit is exceeded, first check whether responsibilities are mixed; split by responsibility, boundary, or data flow.
- When parameters grow, prefer a parameter object with domain meaning over loose argument lists.
- Exceptions are limited to framework signatures, public API compatibility, generated files, pure configuration maps, or stable data tables.
- Every exception must record the reason, risk, and verification method.

## Reuse Search

Before adding implementation, check:

- Definitions, references, callers, types, interfaces, and public exports.
- Same directory, same module, shared utilities, script entrypoints, and test fixtures.
- LSP when available; use text search to cover dynamic references, configuration references, and generated paths.

## Abstraction Judgment

- Evaluate reuse from a senior engineer perspective: optimize clarity, maintainability, evolvability, and contract stability.
- Reuse or abstraction must make call relationships clearer, remove real duplication, or stabilize a shared contract.
- Single use, future speculation, naming symmetry, or surface similarity is not enough.
- Keep concrete code when abstraction increases dependency direction complexity, hidden state, parameter complexity, or test difficulty.
- An abstraction created only to satisfy a metric is a complexity regression.

## Compatibility Code

- Compatibility layers must name the retained callers, reason, removal condition, and deletion path.
- Compatibility logic must not swallow new errors, change business semantics, or hide migration failure.
