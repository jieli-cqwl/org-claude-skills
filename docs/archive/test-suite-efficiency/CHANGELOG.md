# Test Suite Efficiency Changelog

## 2026-04-22 - install test refactor

- Split the slow monolithic install regression into domain-focused core, runtime-smoke, safety, runtime, and migration tests.
- Kept default `tests/run-all.sh` as the full quality gate while adding an explicit quick path that excludes only full-only install safety/runtime/migration/cleanup scenarios.
- Added scenario mapping for all 20 old systematic install cases plus the runtime-audit responsibility, with final quick and full profile proofs recorded in the archived verify report.
- Absorbed the old active smoke script into the expanded runtime-smoke test, then removed `tests/test-install-smoke.sh` without keeping a compatibility wrapper.
- Improved install helper diagnostics for unexpected install failures, added explicit allow-failure wrappers for negative tests, and made helper content assertions binary-safe.
- Fixed Codex managed hook cleanup for normalized temp paths, preserved managed-looking user hook paths such as `managed-old`, and updated active docs that still referenced retired install test entrypoints.
