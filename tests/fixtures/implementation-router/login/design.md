# Login Fixture Design

## Why

Validate that a small login requirement can be routed through the new implementation router and safely parallelized.

## Scope

- In scope: auth service task and login form task.
- Out of scope: production authentication storage.

## Goals & Success Criteria

| Goal | Success Criteria | Verification |
|------|------------------|--------------|
| G1: Parallel route | Auth and UI tasks are routed as independent parallel groups. | `execution-route.json` has `decision=parallel`. |
| G2: Stale protection | Route input mutation after route generation blocks reuse. | Rerunning router after mutation returns `decision=blocked`. |
