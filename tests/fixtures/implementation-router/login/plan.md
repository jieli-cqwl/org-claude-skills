# Login Fixture Implementation Plan

> **For agentic workers:** REQUIRED NEXT STEP: run `implementation-router`. Implement only after `execution-route.json` chooses `serial` or `parallel`.

**Goal:** Build a small login flow with independent auth and UI work.

**Architecture:** Auth logic and login UI are deliberately split into separate files with independent proving commands so the router can safely choose parallel execution.

**Tech Stack:** Python fixture files and pytest-style proving commands.

---

### Task 1: Auth Service [T1]

Context: This task owns only backend auth behavior for login credentials and session token creation.

Files:
- Create: `app/auth/session_service.py`
- Test: `tests/auth/test_session_service.py`

1. [T1] Run auth proving command

Run: `pytest tests/auth/test_session_service.py`

### Task 2: Login Form [T2]

Context: This task owns only login form submission and visible success/error state.

Files:
- Create: `app/ui/login_form.py`
- Test: `tests/ui/test_login_form.py`

1. [T2] Run UI proving command

Run: `pytest tests/ui/test_login_form.py`
