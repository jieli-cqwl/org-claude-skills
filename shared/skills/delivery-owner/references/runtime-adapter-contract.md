# Runtime Adapter Contract

Trigger: Use when installing, reviewing, or troubleshooting the delivery-owner completion gate.
Read: `shared/hooks/registry.json`, `scripts/manifest.json`, `scripts/completion_check.sh`, Codex managed hook dispatcher, and install-time runtime notes.
Expect: The completion gate has explicit trigger, input, allowed action, output, failure state, owner, rollback, and canonical artifact boundary.
Consume: Install tests, Codex adapter tests, skill quality tools, and delivery-owner maintainers consume this contract.
Evidence: `tests/test-codex-skill-adapter.sh`, `tests/test-delivery-owner-gate-contract.sh`, and `tests/test-skill-output-and-gate-contract.sh` cover the adapter behavior.
Sync: Update this file with any change to delivery-owner hook registration, script manifest, or completion gate input contract.

## Hook Lifecycle

| phase | trigger | input_artifact | allowed_action | output_artifact | failure_state | owner | rollback |
|-------|---------|----------------|----------------|-----------------|---------------|-------|----------|
| completion-gate | PostToolUse(Edit|Write) / Codex Stop dispatcher | hook payload JSON on stdin, active skill state, transcript path, edited file path | run completion_check.sh through registry timeout and manifest boundary | sanitized allow/stop JSON and stderr diagnostics | fail closed with sanitized stop message | delivery-owner maintainers | remove registry entry or disable managed hook and rerun adapter tests |

## Runtime Boundaries

- `completion_check.sh` is a hook adapter, not a fresh proving command.
- Fresh proving remains the nearest task or phase command declared in `plan.json`, plus `python3 tools/community/validate_standard_chain_readiness.py --phase-dir "$PHASE_DIR"` before delivery sign-off.
- Codex runtime may execute the gate through the managed Stop dispatcher after `/delivery-owner` is active; Claude runtime may execute it as PostToolUse(Edit|Write).
- The gate only reads current artifacts and emits a decision; it must not mutate user files.

## Canonical Artifact Boundary

- `completion_check.sh` only recognizes canonical closeout artifacts under `docs/{feature}/phase-{N}/`.
- Recognized trigger artifacts: `delivery-state.json / artifact-registry.json / signoff-package.json / user-decision.json`.
- The gate validates with `python3 tools/community/validate_standard_chain_readiness.py --phase-dir "$PHASE_DIR"`.
- Markdown projection files are not runtime fact sources for this adapter.
- If no canonical closeout artifact is present during a delivery-owner closeout dispatch, the gate fails closed with a missing-artifact diagnostic.
