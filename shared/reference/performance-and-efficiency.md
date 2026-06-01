# Performance And Efficiency

Performance work starts from an observable bottleneck and closes with baseline metrics, capacity limits, failure paths, and comparison evidence. A complex mechanism is justified only when it improves a real bottleneck.

## Decision Order

1. Locate the bottleneck with profiling, logs, traces, or benchmarks; record the baseline.
2. Identify constraints: latency, throughput, memory, cost, dependency capacity, and failure cost.
3. Choose the smallest effective strategy: incremental work, streaming, pagination, indexing, batching, or bounded concurrency.
4. Define failure paths: concurrency limits, backpressure, retries, timeouts, cleanup, rollback, and visible failure states.
5. Compare the same scenario before and after: latency, throughput, memory, hit rate, correctness regression, and failure behavior.

## Resource Boundaries

- Temporary files must use unique paths and must be cleaned up; fixed shared paths and unbounded accumulation are forbidden.
- Long-running jobs, polling, retries, batch work, and async jobs need attempt limits, intervals, timeouts, or exit conditions.
- Large files, large result sets, queues, and in-memory collections need memory, response-size, or batch-size limits.
- Background work must not fail only in logs.

## Database And Batch Work

- Large-table queries must be paginated.
- New query paths on user paths, batch jobs, or high-frequency queries must evaluate indexes and query plans when data size can grow.
- Queries, network requests, or file IO inside loops must be checked for N+1 or repeated IO risk.
- Batch work must define concurrency limits, failure strategy, retry boundary, and recovery path.
- CPU-intensive paths must check algorithmic complexity and data size before adding parallelism or task splitting.

## Async Jobs

- Async job state stored in Redis, a database, or another shared store must define timeout, idempotency key, visible failure state, and resume strategy.
- Workers must not wait forever, grow queues forever, retry forever, or mark failed work as success.

## Cache Strategy

- Shared, persistent, cross-request, cross-process, or freshness-affecting cache requires explicit user approval.
- Cache design must define cached object, invalidation strategy, bypass path, rollback path, capacity limit, cost limit, consistency risk, and target hit rate.
- Verify cache hit, miss, invalidation, stale data, dependency failure, and rollback scenarios.
- Single-run local deduplication or intermediate result reuse is not a shared cache.
