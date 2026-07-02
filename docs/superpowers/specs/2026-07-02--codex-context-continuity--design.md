# Codex Context Continuity Design

## Objective

Prevent Codex output quality from degrading after context compaction.

The target is not a general memory system. The target is a recovery protocol that lets Codex resume a long-running task after `/compact` or auto-compaction without losing the current goal, scope, plan, evidence state, latest user correction, or next action.

Success means that immediately after a compacted session resumes, Codex can accurately restate:

- current objective
- scope boundary and non-goals
- latest user correction
- current phase or step
- completed work and evidence references
- pending work, blockers, and next action

If any required item cannot be recovered from current evidence, Codex must stop and report the recovery gap instead of continuing from guesses.

## Current Evidence Boundary

Current Codex documentation and local checks establish these facts:

- Codex supports `PreCompact` and `PostCompact` hooks with `manual|auto` matchers.
- Codex supports `SessionStart` with `startup|resume|clear|compact` start-source matching.
- Codex memories are a separate background memory layer and are not a reliable current-task state source.
- The current WIP hook registers a `context-continuity` feature, but its behavior still depends on assumed hook payload fields such as `hook_event_name`, `source`, and `session_id`.
- The current WIP state card stores useful recovery references, but it does not yet populate the core task state fields needed to preserve output quality.

This design must therefore treat hook event availability as established, but treat the exact runtime payload shape as unproven until probed.

## Non-goals

- Do not build a broad personal memory or knowledge-base system.
- Do not make compact summaries the source of truth.
- Do not persist full raw prompts by default.
- Do not rewrite existing skill completion gates or standard-chain artifact governance.
- Do not claim that memories, `/goal`, or compact prompt tuning alone solve the problem.
- Do not default-enable the feature until real payload probing, trust checks, and privacy behavior are proven.

## Design Summary

Use a small external recovery contract outside the model context window.

The contract has three parts:

1. A task state card that records the minimum current-task truth needed for recovery.
2. Compact lifecycle hooks that seal and point to the state card before and after compaction.
3. A recovery injection on `SessionStart: compact` that forces Codex to read the state card before continuing.

The design favors explicit recovery over silent continuation. A missing, stale, or contradictory state card is a blocking condition.

## State Card

The state card is the durable recovery source for a single Codex session.

Minimum fields:

- `schema_version`
- `session_id`
- `cwd`
- `created_at`
- `updated_at`
- `last_user_prompt_hash`
- `last_user_prompt_preview`
- `git_head`
- `active_goal`
- `scope_boundary`
- `non_goals`
- `latest_user_correction`
- `current_phase`
- `current_plan`
- `completed_items`
- `evidence_refs`
- `pending_items`
- `blockers`
- `next_action`
- `truth_policy`

`completed_items` must only contain items with evidence references. If no evidence exists, the item belongs in `pending_items` or `blockers`.

`last_user_prompt_preview` must be short and redacted. Full prompt text is not stored by default.

## State Update Model

`PreCompact` is too late to invent task state. It can only seal the best available state.

State updates must happen before compaction through at least one of these paths:

- `UserPromptSubmit`: record latest prompt hash, short preview, and possible correction signal.
- `Stop`: checkpoint transcript path, working directory, git head, and current status summary when available.
- Explicit state update command or hook output in later iterations: allow a controlled writer to update objective, phase, plan, evidence, blockers, and next action.

The first implementation may start with `UserPromptSubmit` and `Stop`, but it must not pretend that an empty task card can fully restore quality. Until richer updates exist, recovery must say which fields are missing.

## Hook Event Flow

### UserPromptSubmit

Record the latest user prompt hash and short redacted preview. Detect obvious correction language as a signal, but do not infer a new objective without evidence.

### Stop

Checkpoint current runtime metadata:

- session id
- cwd
- transcript path when available
- git head when available
- timestamp

If a state card already has task fields, preserve and refresh them. Do not overwrite meaningful fields with empty values.

### PreCompact

Seal the current task state into a precompact checkpoint.

If required recovery fields are missing, write that fact into the checkpoint. Do not fabricate status.

### PostCompact

Record compact metadata only:

- trigger: `manual` or `auto`
- timestamp
- compact summary length and hash if supplied

Do not store the full compact summary by default. Do not use the compact summary as the recovery truth source.

### SessionStart With Compact Source

Inject additional context that instructs Codex to:

1. Read the task state card.
2. Read the precompact checkpoint.
3. Validate freshness against session id, cwd, git head, and last prompt hash when available.
4. Restate recovered objective, scope, latest correction, completed evidence, blockers, and next action.
5. Stop and report a recovery gap if the required fields are missing or inconsistent.

The recovery injection must not include full prompt text or full compact summary.

## Payload Contract

The implementation must not depend on undocumented runtime payload fields without proof.

Required work before enabling the feature:

- Add a temporary payload probe for `UserPromptSubmit`, `Stop`, `PreCompact`, `PostCompact`, and `SessionStart`.
- Capture real payload field names in a local redacted log.
- Update the hook command renderer to pass explicit event context when Codex does not supply enough fields, for example `--event PreCompact` or `--event SessionStart --source compact`.
- Add regression tests for missing event fields and source fields so hooks fail visibly or use explicit command arguments.

If real payload probing cannot be performed, the implementation must stay opt-in and report the uncertainty.

## Installation And Trust

The feature starts as explicit opt-in.

Opt-in requirements:

- The installer registers the context-continuity hooks only when the feature is explicitly enabled.
- The hook trust audit verifies the new commands are registered, enabled, trusted, and executable.
- A probe command validates that a simulated compact recovery emits `additionalContext` pointing to the state card and checkpoints.
- Re-running the installer without the opt-in flag must have documented behavior: either preserve the prior explicit enablement or intentionally remove it. Silent behavior changes are not acceptable.

Default enablement is allowed only after real payload shape, privacy behavior, and trust checks are stable.

## Privacy

The state card must not become a local prompt dump.

Default behavior:

- Store prompt hash.
- Store a short redacted preview.
- Store transcript reference only when supplied by Codex.
- Store evidence references and file paths needed for task recovery.
- Store compact summary hash and length, not the full summary.

Debug behavior that stores richer payloads must be explicitly enabled and must write to a clearly marked local-only diagnostic path.

## Failure Handling

Recovery failure is a quality-preserving stop, not an error to hide.

Block recovery when:

- state card is missing
- session id is missing or maps to a shared `unknown-session`
- cwd does not match the current workspace or cannot be verified
- precompact checkpoint is missing after a compact recovery
- required task fields are empty and no transcript/evidence ref is available
- git head changed and affected evidence freshness cannot be judged
- hook was skipped, untrusted, timed out, or failed

The user-facing message should state what could not be recovered and what evidence is needed next.

## Validation

Minimum tests:

- Registry renders no context-continuity hooks by default.
- Registry renders all opt-in hooks for `UserPromptSubmit`, `Stop`, `PreCompact`, `PostCompact`, and `SessionStart` with compact matching.
- Hook command rendering can pass explicit event/source arguments.
- Missing `hook_event_name` does not silently drop a user prompt update.
- `SessionStart` with compact matcher but no `source` still exercises the intended compact recovery path or fails visibly.
- State card writes are atomic and preserve existing non-empty task fields.
- State card does not store full compact summary or full prompt by default.
- Recovery injection includes state refs and required recovery instructions.
- Missing or stale state produces a visible blocked recovery result.
- Installer quick check verifies registration, trust state, and probe recovery when opt-in is enabled.

Manual validation:

- Trigger a real or near-real Codex compact.
- Confirm the first recovery turn can restate objective, boundary, latest correction, completed evidence, blockers, and next action.
- Confirm a missing state card blocks instead of continuing.

## Rollout Plan

1. Implement payload probe and document real payload fields.
2. Harden event/source handling in hook command rendering.
3. Upgrade the state card from metadata-only to recovery-ready fields.
4. Add stale-state and missing-state failure behavior.
5. Keep feature opt-in and run probe validation after install.
6. Dogfood on one long-running thread.
7. Consider default enablement only after repeated compact recovery succeeds without privacy issues.

## Open Decisions

- Whether opt-in state is persisted in config or remains an installer environment flag.
- Which component is allowed to update rich task fields beyond prompt and stop metadata.
- How much of the transcript path can be relied on across Codex app, CLI, and future runtimes.
- Whether `/goal` should be mirrored into the state card when available.

## Completion Criteria

This design is complete when it:

- Separates compaction lifecycle events from long-term memories.
- Treats compact summary as metadata, not truth.
- Defines the minimum state needed to preserve output quality.
- Requires real payload probing before enablement claims.
- Blocks recovery when state is missing, stale, or unverifiable.
- Keeps privacy risk bounded by default.
- Provides clear validation gates for registry, install, trust, hook behavior, and real compact recovery.
