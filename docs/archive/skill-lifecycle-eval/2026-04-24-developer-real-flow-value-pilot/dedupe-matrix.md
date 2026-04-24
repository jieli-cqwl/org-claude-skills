# Developer Role Dedupe Matrix

| Role | Owned boundary | Overlap with developer | Decision |
|------|----------------|------------------------|----------|
| developer | developer unique responsibility: execute one Task through TDD, preserve file-scope discipline, emit `developer-report.json` with RED/GREEN evidence and Commit SHA traceability | N/A | Keep contracts during merge planning |
| delivery-owner | Dispatch, control decisions, readiness, delivery-state, signoff routing | Requires `developer-report.json`, but does not own RED/GREEN implementation evidence | Keep upstream; do not copy developer SOP into delivery-owner |
| verify | Independent Task verification, AC closure, implementation authenticity, TDD evidence inspection | Consumes `developer-report.json` and validates evidence; does not produce Task implementation | Keep downstream; developer output remains verify input |
| test-driven-development | Generic RED/GREEN/REFACTOR method | Provides general TDD rules, but lacks standard-chain file scope and canonical report output | Merge generic method references only |
| subagent-driven-development | Controller pattern for dispatching implementation and review agents | Describes subagent orchestration, not standard-chain canonical task evidence | Keep orchestration separate |

## Decision Rule

- Retain standalone `developer` only if live execution shows it prevents process drift that delivery-owner + verify + generic TDD guidance do not catch.
- Merge contracts if the durable value is only `developer-report.json` evidence shape, TDD evidence indexing, and file-scope discipline.
- Start retirement only after merge impact is mapped and the human confirms the standalone role is no longer needed.
