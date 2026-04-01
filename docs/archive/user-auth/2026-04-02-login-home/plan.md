# Login Home Implementation Plan

**Goal:** Redirect users to home after successful login while keeping failure behavior unchanged.
**Tech Stack:** TypeScript, frontend router, unit/integration tests

---

### Task 1: Login Success Redirect [T1]

Files:
- Modify: `src/pages/login.tsx`
- Test: `tests/login-success-redirect.test.ts`

1. [T1] Add failing test for successful login redirect to `/home`.
2. [T1] Implement success-branch redirect in login submit handler.
3. [T1] Run tests and confirm redirect case passes.
4. [T1] Commit task changes.

### Task 2: Preserve Failure Behavior [T2]

Files:
- Modify: `src/pages/login.tsx`
- Test: `tests/login-failure-stays.test.ts`

1. [T2] Add failing test for failed login route stability and error message.
2. [T2] Keep failure branch on current page and preserve message rendering.
3. [T2] Run tests and confirm failure case passes.
4. [T2] Commit task changes.
