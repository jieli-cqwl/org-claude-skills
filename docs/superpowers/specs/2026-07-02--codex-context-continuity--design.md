# Codex Context Continuity Production Design

**Status:** Approved for implementation on 2026-07-09
**Capability owner:** Codex runtime context-continuity hooks
**Current implementation:** Schema 1.0 is opt-in and not production-ready
**Target implementation:** Strict checkpoint protocol with bounded recovery

## Objective

Context compaction must not reduce the quality of a long-running Codex task. After manual or automatic compaction, Codex must preserve the current goal, scope, latest user correction, plan, completed evidence, pending work, blockers, and next action without guessing or flooding the new context window.

The system optimizes for increasing usefulness over long sessions. Recovery correctness takes priority over uninterrupted execution: when state is not trustworthy, Codex must pause before mutation or compaction rather than continue with a plausible but wrong interpretation.

## Acceptance Outcome

The feature is acceptable only when all of the following are proven:

- A task can cross repeated manual and automatic compactions without goal, scope, correction, progress, or evidence drift.
- A new user correction invalidates the previous snapshot before any ordinary tool call or final response.
- Empty, partial, stale, conflicting, legacy, or corrupted snapshots never become `READY`.
- Compaction is stopped when no complete current snapshot can be sealed.
- A valid precompact checkpoint can recover from a corrupted primary state.
- Recovery never reads a raw transcript into model context and stays inside explicit byte and token budgets.
- State storage is private, bounded, automatically pruned, and never deletes the active session.
- The installed runtime, not only a direct script invocation, proves the lifecycle behavior.

## First-Principles Constraints

1. `PreCompact` cannot invent semantic task state. A complete snapshot must exist before compaction begins.
2. Compact summaries and transcripts are evidence, not task truth.
3. Prompt hashes alone do not establish freshness. State must bind to the exact session, turn, workspace, Git state, and revision.
4. Presence and emptiness are different. A present empty `completed_items` or `pending_items` list can be valid for the task phase.
5. A checkpoint reference is not evidence that the checkpoint exists, is intact, or matches the current state.
6. Atomic replacement prevents torn filenames but does not prevent lost concurrent updates or guarantee durable writes.
7. Developer-context instructions are advisory. High-risk transitions also require mechanical hook gates.
8. Recovery work consumes context. Every automatic and on-demand recovery output must be bounded before it reaches the model.

## Architecture Decision

Use one strict checkpoint protocol on the existing managed hook path. Do not create a memory service, use compact summaries as truth, or reconstruct task semantics from the full transcript.

The capability has five responsibilities:

1. **Prompt tracker:** records the current turn identity and marks the previous snapshot stale.
2. **Snapshot writer:** accepts only a complete schema-2 snapshot and commits it with compare-and-swap revision checks.
3. **Execution guard:** prevents ordinary tool calls and turn completion until the current turn has a trusted snapshot.
4. **Compaction coordinator:** seals and validates checkpoints before compaction, then injects a bounded recovery packet after compaction.
5. **Retention manager:** enforces file permissions, generation limits, age limits, session limits, and total storage limits.

The existing `codex_context_continuity.py` remains the installed entrypoint. Implementation may split internal modules only where this makes state validation, storage, recovery extraction, or hook routing independently testable. No second runtime path or second state truth is allowed.

## Rejected Alternatives

### Patch schema 1.0 in place without a writer

Rejected because validation cannot make an unwritten state complete. The current runtime has no stable rich-state caller, so stronger `READY` checks alone would only produce permanent `INCOMPLETE` recovery.

### Reconstruct state from the transcript after compaction

Rejected as the primary path because transcript format is not stable, transcripts contain large tool payloads and image data, and semantic reconstruction can silently select the wrong goal or correction. A bounded extractor may produce read-only evidence, but it cannot promote state to `READY`.

### Add a new memory or MCP service

Rejected for this iteration because it introduces a second lifecycle, installation path, and truth store. The existing hook capability can carry the required protocol with lower maintenance cost.

## Schema 2.0 Snapshot

Every accepted update is a full snapshot. Partial merge semantics are forbidden.

Required envelope fields:

- `schema_version`: exactly `2.0`
- `session_id`: exact runtime session identifier
- `turn_id`: exact runtime turn identifier
- `revision`: monotonically increasing integer assigned by the writer
- `base_revision`: revision the caller read before updating
- `task_status`: `active`, `blocked`, or `complete`
- `cwd`: canonical working directory captured by the writer
- `git_head`: current Git HEAD captured by the writer, or explicit `not-a-git-repository`
- `last_user_prompt_hash`: SHA-256 of the current prompt
- `created_at` and `updated_at`: UTC timestamps
- `snapshot_sha256`: hash of canonical snapshot content excluding this field

Required task fields:

- `active_goal`: non-empty string
- `scope_boundary`: non-empty string
- `non_goals`: present list, allowed to be empty
- `latest_user_correction`: present string, allowed to be empty
- `current_phase`: non-empty string
- `current_plan`: present list, allowed to be empty
- `completed_items`: present list of objects containing `item` and `evidence_refs`
- `pending_items`: present list, allowed to be empty
- `blockers`: present list, allowed to be empty
- `next_action`: non-empty string

Snapshot invariants:

- `completed_items[*].evidence_refs` must be present. It may be empty only when the item explicitly records that no external evidence exists yet.
- `task_status=active` requires a concrete `next_action` but does not require prior completed work.
- `task_status=complete` permits an empty `pending_items` list.
- `task_status=blocked` requires at least one blocker and a user- or dependency-facing next action.
- Unknown fields, missing fields, empty required strings, invalid types, over-budget values, and partial updates are rejected before any state mutation.
- An update with `base_revision` different from the stored revision is a visible conflict and cannot overwrite newer state.

## State Machine

The legal states are:

- `READY`: a complete schema-2 snapshot matches the current session, turn, prompt, workspace, Git state, and revision.
- `STALE`: a new user prompt or environment change invalidated the prior snapshot.
- `INCOMPLETE`: bounded recovery evidence exists, but a complete trusted snapshot has not been rebuilt.
- `CORRUPT`: primary or checkpoint integrity validation failed.
- `UNRECOVERABLE`: trusted evidence is insufficient; user input is required.

Legal transitions:

- `READY -> STALE` on every `UserPromptSubmit` and on detected workspace or Git drift.
- `STALE -> READY` only through a complete compare-and-swap state update bound to the current turn.
- `INCOMPLETE -> READY` only after bounded recovery evidence is reviewed and a new complete snapshot is explicitly written.
- `CORRUPT -> READY` only through a validated matching checkpoint followed by a new primary write.
- `INCOMPLETE|CORRUPT -> UNRECOVERABLE` when recovery evidence is absent, invalid, contradictory, or over budget.

No hook may silently convert an invalid state to `READY`. No checkpoint path string may count as recovery evidence until the file is opened, validated, and matched.

## Runtime Flow

### UserPromptSubmit

1. Record `session_id`, `turn_id`, prompt hash, redacted preview, transcript reference, and canonical `cwd`.
2. Mark the previous snapshot `STALE` even when the new prompt text is identical to the prior prompt.
3. Emit bounded developer context containing the required snapshot action, current revision, session id, turn id, and state-update command contract.
4. Do not include the full previous snapshot, full prompt, or transcript content.

### State Update Command

The model writes state through one dedicated command on the existing managed script:

```text
codex_context_continuity.py state-update --payload <one canonical JSON argument>
```

The payload is a complete schema-2 task object. Runtime-owned envelope values, including `cwd`, `git_head`, revision, timestamps, and hashes, are computed or verified by the command rather than trusted from model text.

The update command rejects shell chaining, extra commands, missing or unknown arguments, malformed JSON, partial snapshots, stale base revisions, mismatched session/turn identifiers, and values beyond field or snapshot limits.

### PreToolUse Execution Guard

When state is not `READY`, ordinary tools are denied. Only the exact single-command forms for bounded `recover` and `state-update` are allowed. Any shell control operator, pipeline, redirection, command substitution, extra executable, or mismatched session/turn value makes the exception invalid.

This gate prevents the model from mutating code, files, external systems, or tools under stale context. Initial task intake remains possible because the first snapshot can record inspection and analysis as pending work before ordinary tools are used.

### Stop

`Stop` records current transcript metadata without overwriting an existing non-empty reference with an empty value.

If the current turn has no `READY` snapshot, `Stop` returns a continuation decision that requires a complete state update before the turn can finish. Repeated Stop invocation is loop-safe: once the matching revision is ready it exits successfully; malformed or unrecoverable state produces a visible blocked reason.

### PreCompact

1. Acquire the session lock.
2. Reload and validate the primary state from disk.
3. Require `READY` for the latest completed turn.
4. Write a canonical checkpoint with snapshot hash, checkpoint hash, session, turn, revision, trigger, and seal timestamp.
5. Durably flush the checkpoint and parent directory.
6. Re-read and validate the checkpoint before allowing compaction.

If any step fails, return `continue:false` with an actionable reason. Compaction must not proceed with missing, stale, conflicting, corrupt, or unverifiable state.

### PostCompact

Record only documented event metadata: session, turn, trigger, cwd, timestamp, and checkpoint reference. Do not assume Codex supplies a compact summary. Do not store or hash an undocumented summary field as proof of runtime behavior.

### SessionStart With Compact Source

1. Validate the primary state and sealed checkpoint independently.
2. Require matching session, turn, revision, cwd, Git state, and hashes.
3. If the primary is corrupt but the checkpoint is valid, rebuild the primary from the checkpoint and mark the recovery source.
4. If both are valid but conflict, use neither and enter `CORRUPT`.
5. Inject a bounded recovery packet. Never tell the model to read raw state or transcript files directly.
6. The next `UserPromptSubmit` marks this recovered snapshot stale and requires a new turn-bound update before tools or Stop.

## Bounded Recovery

Recovery is progressive and stops as soon as enough trusted evidence exists.

### Level 0: Recovery Envelope

Always inject status, allowed next action, revision identity, integrity result, and compact field summaries. Maximum output: 4 KiB and 1,200 conservatively estimated tokens, whichever limit is reached first.

### Level 1: Trusted Snapshot Digest

For `READY`, inject goal, scope, latest correction, current phase, at most three completed items with evidence, at most three pending items, blockers, and next action. Maximum cumulative output: 8 KiB and 2,000 estimated tokens.

### Level 2: Bounded Evidence Packet

For `INCOMPLETE` or `CORRUPT`, the dedicated `recover` command may inspect:

1. validated primary state;
2. validated latest and previous checkpoints;
3. a bounded transcript tail only when structured evidence is insufficient;
4. at most three explicit evidence references.

The transcript reader may scan at most the final 256 KiB of the referenced file. It emits only selected user and assistant text, strips data URLs, Base64, image payloads, encrypted reasoning, tool schemas, tool output, duplicated instructions, and oversized fields, and reports all truncation.

### Overall Budget

One recovery attempt may emit at most 24 KiB and 6,000 conservatively estimated tokens across all levels. Every packet records bytes scanned, bytes emitted, estimated tokens, truncation flags, sources consulted, and sources skipped.

Reaching the budget without enough trusted evidence transitions to `UNRECOVERABLE` and asks the user for the missing goal or scope. It never triggers broader reads or another automatic compaction loop.

## Storage And Privacy Budget

The state directory must be mode `0700`; files must be mode `0600`.

The feature stores no full prompt, transcript, compact summary, image, Base64 payload, tool output, or hidden reasoning. Prompt previews remain redacted and bounded.

Hard limits:

- Maximum serialized full snapshot: 64 KiB.
- Maximum full generations per session: three, consisting of primary, latest checkpoint, and previous fallback checkpoint.
- Default inactivity retention: 30 days.
- Maximum retained inactive sessions: 200.
- Maximum total managed state size: 50 MiB.
- Cleanup frequency: at most once per 24 hours during normal events.

The current active session is never deleted. Cleanup only removes files matching owned naming patterns, prunes the oldest inactive sessions first, and leaves an observable cleanup record without storing deleted content.

Limits may be configurable only through validated environment settings with explicit minimum and maximum values. Invalid configuration fails visibly and does not disable safety limits.

## Concurrency And Durability

- All read-modify-write operations use a per-session advisory file lock with a bounded timeout.
- State updates use compare-and-swap revisions to prevent lost updates.
- Temporary files are unique, mode `0600`, flushed with `fsync`, atomically replaced, and followed by parent-directory `fsync` where supported.
- Failed writes clean up temporary files and preserve the last known good primary and checkpoints.
- Lock timeout, revision conflict, disk-full, permission failure, malformed state, and partial checkpoint failure are distinct visible errors.
- Cleanup uses a separate bounded lock and never blocks the active session state path for an unbounded period.

## Legacy Compatibility

Schema-1 files remain readable as untrusted evidence but cannot become `READY` and are never rewritten in place as schema 2.0.

On first schema-2 event:

1. Preserve the schema-1 file as a bounded legacy generation.
2. Mark the session `INCOMPLETE` or `UNRECOVERABLE` based on available trusted evidence.
3. Require a new full schema-2 snapshot before tools, Stop, or compaction can proceed.
4. Remove legacy generations through the normal retention policy after a valid schema-2 checkpoint exists.

Default opt-in behavior remains compatible: the feature is not registered unless explicitly enabled or previously persisted as enabled. Existing enabled installations upgrade to strict enforcement only after installation probes and hook trust checks pass.

## Failure Handling

Failures are explicit and fail closed at the boundary they protect:

- Invalid update: reject update; preserve current state; report exact invalid fields.
- Revision conflict: reject update; report expected and observed revisions.
- Primary corrupt, checkpoint valid: restore from checkpoint; mark recovery source.
- Primary and checkpoint conflict: block; do not choose by timestamp.
- Missing checkpoint at compact start: block compaction.
- Storage or permission failure: block the affected transition and preserve prior state.
- Recovery budget exhausted: stop reading and ask for the missing user decision.
- Hook untrusted, disabled, timed out, or skipped: runtime acceptance fails; do not claim continuity protection.

User-visible messages state what was protected, why execution stopped, and the exact safe next action. They do not expose sensitive prompt content or unnecessary internal file paths.

## Observability

Each state transition records bounded metadata:

- event and transition name;
- session and turn hashes rather than raw prompt content;
- prior and next status;
- revision and checkpoint identity;
- integrity result;
- recovery source;
- bytes and estimated tokens emitted;
- truncation and cleanup counts;
- failure category and safe next action.

Observability records follow the same permissions and retention limits as state. A green install probe cannot substitute for a real runtime transition record.

## Verification Matrix

### Functional Correctness

- Complete current snapshot reaches `READY`.
- Empty and partial updates fail before write.
- Empty legitimate lists remain valid.
- New prompt, including repeated identical text, makes state stale by turn id.
- Postcompact user correction cannot use the injected prior-turn `READY` status.
- `task_status` invariants distinguish active, blocked, and complete work.

### Integration Correctness

- Installed hook registry covers `UserPromptSubmit`, `PreToolUse`, `Stop`, `PreCompact`, `PostCompact`, and `SessionStart:compact` using documented payload fields.
- State-update and recover exceptions pass the execution guard only in exact single-command form.
- Unknown or mutating tools are denied while state is not ready.
- Hook trust inspection proves installed commands are enabled and trusted.

### Failure Injection

- Corrupt primary with valid checkpoint.
- Corrupt checkpoint with valid primary.
- Conflicting valid primary and checkpoint.
- Missing checkpoint.
- Disk full, unwritable directory, failed replace, and interrupted write.
- Concurrent updates, lock timeout, and stale base revision.
- Same prompt twice within one timestamp resolution window.
- Stop with empty transcript path after a prior valid path.
- Legacy schema-1 state.

### Context And Privacy

- Multi-megabyte transcript containing image Base64, tool schemas, tool output, secrets, and malformed JSONL.
- Automatic injection stays under 8 KiB and 2,000 estimated tokens.
- Whole recovery stays under 24 KiB and 6,000 estimated tokens.
- No raw transcript, full prompt, compact summary, Base64, or secret reaches state or model output.
- Budget exhaustion produces `UNRECOVERABLE` without recursive reading.

### Storage And Performance

- Three-generation session cap.
- 30-day, 200-session, and 50-MiB retention limits.
- Active session protection during cleanup.
- Cleanup runs at most once per 24 hours.
- Normal prompt, update, Stop, and compact hook latency remains bounded under representative state counts.

### Runtime E2E

- Real Codex manual compaction preserves the accepted task state and resumes correctly.
- Real Codex automatic compaction preserves the accepted task state and resumes correctly.
- Repeated compactions do not accumulate recovery text or lower output quality.
- A correction submitted after compaction invalidates the recovered snapshot before tools run.
- A missing or corrupt state stops safely with an actionable path.

## Rollout Gate

The feature remains opt-in until all automated checks pass and real manual plus automatic compaction E2E evidence exists.

Production readiness requires:

1. schema-2 unit and fault-injection tests passing;
2. install and trust probes passing against documented event payloads;
3. no unresolved critical or important code-review findings;
4. repeated real compact recovery with no goal, scope, correction, evidence, or output-quality drift;
5. measured context, storage, latency, and privacy budgets within limits;
6. installed runtime source matching the reviewed repository source.

No passing test, simulated event, or install probe may independently justify a production-ready claim.
