# Code Comments

Comments explain reasons, boundaries, and constraints that code cannot reveal by itself.

## Required Comments

- Public boundaries, cross-module contracts, complex business rules, non-obvious constraints, and high-risk failure conditions.
- Decisions that affect data consistency, permission, audit, idempotency, rollback, or user-visible behavior.
- Compatibility logic, temporary bypasses, migration code, and retained old paths with their expiration conditions.

## Database And Queries

- When adding or changing database schema, tables, columns, enum/status values, constraints, or non-obvious indexes must explain business meaning, units, allowed values, and constraint semantics.
- Multi-table joins, aggregation/window logic, complex filters, sorting, pagination, data repair, or performance assumptions must explain business intent and key constraints.
- SQL comments must not translate syntax; they must explain why the query filters, joins, sorts, paginates, or repairs data that way.

## Concurrency And State

- Concurrency, transactions, locks, retries, cache consistency, and idempotency logic must comment the invariant being protected and the failure conditions.
- State machines or state transitions must explain legal transitions, illegal transition protection, and failure recovery.

## Parsing And Protocols

- Complex regex, parsing rules, protocol mappings, and format conversions must explain input/output semantics, boundaries, and unsupported cases.
- External protocol compatibility must name the version, caller, and removal condition.

## Forbidden Comments

- Do not write comments that only repeat obvious assignment, branching, or function calls.
- Do not keep stale TODOs, resolved FIXMEs, or comments that disagree with implementation.
