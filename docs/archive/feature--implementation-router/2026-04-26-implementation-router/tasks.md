# Tasks — Implementation Router
Created: 2026-04-26
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Router core and route contract
  - AC: `bash tests/test-implementation-router.sh` proves `serial`, `parallel`, `blocked`, stale hash, stale route second-run block, unreadable existing route block, high-risk common surface, contract-grade parallel block, route/task/plan unknown task IDs, and missing input outcomes.
  - Traces: G1, G5
  - Depends: -
  - Complexity: complex
- [x] T2 Plan-stage Stop hook
  - AC: `bash tests/test-implementation-router-hook.sh` proves latest `worklog.md` `stage: plan` triggers routing, missing route input still runs router and blocks, non-plan stages allow, cwd selects the current active workset when multiple entries exist, and blocked route emits a Stop failure payload.
  - Traces: G2, G5
  - Depends: T1
  - Complexity: complex
- [x] T3 small-chain contract and writing-plans propagation
  - AC: `bash tests/test-small-chain-boundary.sh` proves the chain includes `implementation-router`, route artifacts, plan-stage worklog handoff, and serial/parallel branches.
  - Traces: G1, G3, G6
  - Depends: T1
  - Complexity: moderate
- [x] T4 Parallel execution wrapper and install visibility
  - AC: `bash tests/test-single-source-layout.sh` and `bash tests/test-small-chain-boundary.sh` prove `community/superpowers/skills/parallel-subagent-development/SKILL.md` is installed, auto-invocable, and declared as local-only or overlay-safe.
  - Traces: G4, G6
  - Depends: T1, T3
  - Complexity: moderate
- [x] T5 verify-change route evidence and documentation
  - AC: `bash tests/test-closeout-routing.sh` and `bash tests/test-small-chain-boundary.sh` prove README, verify-change, and superpowers boundary require route evidence before parallel execution can close.
  - Traces: G3, G4, G6
  - Depends: T3, T4
  - Complexity: moderate
- [x] T6 Login fixture end-to-end route validation
  - AC: `bash tests/test-implementation-router-login-flow.sh` proves a simple login workset reaches `decision=parallel`, produces per-task worktree policy, and blocks after a route-input mutation.
  - Traces: G1, G2, G4, G5
  - Depends: T1, T2, T4
  - Complexity: moderate
- [x] T7 Final verification and small-chain closeout readiness
  - AC: `bash tools/validate-contracts.sh`, `bash tests/test-small-chain-boundary.sh`, `bash tests/test-implementation-router.sh`, `bash tests/test-implementation-router-hook.sh`, `bash tests/test-implementation-router-login-flow.sh`, `bash tests/test-closeout-routing.sh`, and `bash tests/test-single-source-layout.sh` all pass; `verify-change-report.md` records PASS.
  - Traces: G1, G2, G3, G4, G5, G6
  - Depends: T1, T2, T3, T4, T5, T6
  - Complexity: moderate
- [x] T8 Small-chain quality gate hardening
  - AC: `bash tests/test-small-chain-boundary.sh`, `bash tests/test-closeout-routing.sh`, `bash tools/validate-contracts.sh`, and `python3 tools/community/validate_context_contract.py --repo-root .` prove contract-grade failure matrix and code-review-result gates are now part of the small-chain flow.
  - Traces: G5, G6, G7
  - Depends: T7
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change.
