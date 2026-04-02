# Login Home Flow Smoke Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Run one complete small-chain workflow test using a login-to-home requirement sample.
**Architecture:** Use repository-local simulation artifacts to validate success and failure branches by executable commands. Keep all implementation scoped to the change directory and produce verification-ready evidence for archive.
**Tech Stack:** Markdown, JSON, Python 3 CLI validation script

---

### Task 1: Success Branch Simulation [T1]

Files:
- Create: `docs/user-auth/2026-04-02-login-home-flow-smoke/simulation/login-home-cases.json`
- Create: `docs/user-auth/2026-04-02-login-home-flow-smoke/scripts/validate_login_home.py`

1. [T1] Create a failing validation command for the success branch expectation (`/home`).
2. [T1] Implement success-case data and validation logic in `login-home-cases.json` + `validate_login_home.py`.
3. [T1] Run `python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case success --expect-status success --expect-route /home`.
4. [T1] Confirm command output is `[PASS]` and keep the command/result for evidence.

### Task 2: Failure Branch Preservation [T2]

Files:
- Modify: `docs/user-auth/2026-04-02-login-home-flow-smoke/simulation/login-home-cases.json`
- Modify: `docs/user-auth/2026-04-02-login-home-flow-smoke/scripts/validate_login_home.py`

1. [T2] Add a failing validation command for the failure branch expectation (`/login` + error message).
2. [T2] Implement failure-case data and validation checks.
3. [T2] Run `python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case failure --expect-status failure --expect-route /login --expect-error "invalid credentials"`.
4. [T2] Confirm command output is `[PASS]` and keep the command/result for evidence.

### Task 3: Evidence Packaging And Verify Readiness [T3]

Files:
- Create: `docs/user-auth/2026-04-02-login-home-flow-smoke/implementation.md`
- Create: `docs/user-auth/2026-04-02-login-home-flow-smoke/verify-report.md`

1. [T3] Record executed commands and observed outputs in `implementation.md`.
2. [T3] Run `python3 ../../../community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py tasks.md plan.md`.
3. [T3] Generate `verify-report.md` with PASS/CRITICAL/WARNING/SUGGESTION sections and evidence entries.
4. [T3] Ensure `tasks.md` is the only completion source and all tasks are marked `[x]` before archive.
