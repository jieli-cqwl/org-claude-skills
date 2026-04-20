# Hook Adapter Contract

Trigger: A Skill audit mentions hooks, lifecycle control, state transition, gate enforcement, or runtime blocking.

Read: `skill-audit.json`, `optimization-plan.json`, `scripts/manifest.json`, target hook files, and local permission profiles.

Expect: Hook logic is modeled as an adapter contract before implementation. The contract declares state, inputs, actions, outputs, failure handling, owner, and rollback.

Consume: plan validator, hook implementation reviewer, final verification builder, and runtime lifecycle checks.

Evidence: Adapter table row, changed hook file ref, command output, and rollback command evidence.

Sync: Update this file when hook lifecycle fields or consumers change.

## Adapter Fields

| field | contract |
| --- | --- |
| phase | Lifecycle phase such as audit, plan, implementation, verification, or archive. |
| trigger | Event or command that invokes the adapter. |
| input_artifact | JSON artifact consumed by the adapter. |
| allowed_action | Narrow action set the adapter can perform. |
| output_artifact | JSON artifact emitted or updated by the adapter. |
| failure_state | Explicit state recorded when the adapter rejects or blocks flow. |
| owner | Skill, hook, or script responsible for the action. |
| rollback | Reversal path and proving command for adapter changes. |

## Lifecycle Rules

- Hook adapters consume JSON artifacts as fact source.
- Rendered Markdown and HTML remain derived views.
- Global hook registration is out of scope until an accepted plan lists exact file scope, owner, rollback, and verification command.
- Any block or reject path emits a failure state with evidence refs.

## Minimal Adapter Row

| phase | trigger | input_artifact | allowed_action | output_artifact | failure_state | owner | rollback |
| --- | --- | --- | --- | --- | --- | --- | --- |
| verification | fresh proving command exits nonzero | `verification-result.json` | block archive | `verification-result.json` | `verification_failed` | `skill-auditor` | restore previous artifact and rerun verification command |
