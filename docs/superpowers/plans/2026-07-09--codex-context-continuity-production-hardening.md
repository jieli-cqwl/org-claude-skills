# Codex Context Continuity Production Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the advisory schema-1 compaction recovery hook with a strict, bounded, durable schema-2 checkpoint protocol that preserves long-task output quality across real Codex compactions.

**Architecture:** Keep `codex_context_continuity.py` as the installed entrypoint and split schema/state logic, durable storage, and bounded recovery into sibling standard-library modules. Every prompt invalidates the prior snapshot; a complete compare-and-swap update restores readiness; `Stop` and `PreCompact` fail closed; `SessionStart:compact` validates or restores from checkpoints and emits a bounded packet.

**Tech Stack:** Python 3.10+ standard library, Codex lifecycle hooks, JSON state files, Bash installer/tests, existing hook registry renderer, `unittest`, `jq`, and the repository gate runner.

## Global Constraints

- Keep the feature explicit opt-in; do not enable it for users who have not opted in.
- Use no third-party Python dependencies.
- Keep compact summaries and transcripts out of the task-truth path.
- Store no full prompt, transcript, image, Base64 payload, tool output, compact summary, or hidden reasoning.
- Reject empty, partial, stale-revision, mismatched-session, mismatched-turn, over-budget, and unknown-field state updates.
- Permit legitimate empty lists for completed, pending, blocker, plan, and non-goal fields.
- Maximum snapshot size: 64 KiB.
- Maximum recovery injection: 8 KiB and 2,000 estimated tokens.
- Maximum complete recovery output: 24 KiB and 6,000 estimated tokens.
- Transcript scan limit: final 256 KiB; never inject raw transcript lines.
- Retention defaults: 30 inactive days, 200 inactive sessions, 50 MiB total, three full generations per session.
- Preserve the active session during cleanup.
- State directory mode is `0700`; files are `0600`.
- `PreToolUse` is a documented guardrail with incomplete runtime interception. Do not claim complete tool-level enforcement.
- `Stop` and `PreCompact` are the strict turn and compaction boundaries.
- Schema-1 state is untrusted recovery evidence and can never become schema-2 `READY` without a full new snapshot.
- Every production-code step follows red-green TDD and ends with a focused proving command.

---

## File Structure

- Create `shared/hooks/managed/codex_context_model.py`
  - Owns schema-2 constants, canonical serialization, full-snapshot validation, state evaluation, token estimation, and bounded text helpers.
- Create `shared/hooks/managed/codex_context_store.py`
  - Owns per-session locking, durable atomic writes, checkpoint validation/fallback, permissions, generation rotation, and retention cleanup.
- Create `shared/hooks/managed/codex_context_recovery.py`
  - Owns bounded transcript extraction, evidence packet assembly, redaction, source accounting, and output budgets.
- Modify `shared/hooks/managed/codex_context_continuity.py`
  - Becomes the thin hook/CLI router for lifecycle events, `state-update`, and `recover`.
- Create `tests/test-codex-context-continuity.py`
  - Standard-library unit and fault-injection coverage for schema, state transitions, storage, concurrency, recovery, and budgets.
- Modify `tests/test-context-contract-hook.sh`
  - Installed-entry integration coverage using documented Codex event payloads and outputs.
- Modify `shared/hooks/registry.json`
  - Adds the opt-in `PreToolUse` context guard and keeps the existing prompt, Stop, compact, and SessionStart entries.
- Modify `install.sh`
  - Verifies all sibling modules, runs strict ready/blocked probes, and checks installed source integrity.
- Modify `tests/test-install-runtime-quick-canary.sh`
  - Proves opt-in persistence and strict probe behavior.
- Modify `tests/test-install-runtime.sh`
  - Proves installed modules, documented payload contracts, migration behavior, and bounded recovery output.
- Modify `tests/test-codex-hook-trust-audit.sh`
  - Includes the new opt-in PreToolUse command in trust expectations.
- Modify `tools/dev/probe-codex-hooks.sh`
  - Verifies the complete strict hook set only when context continuity is enabled.
- Modify `tests/run-all.sh`
  - Compiles the three new modules and the Python test.
- Modify `tests/gate-plan.json`
  - Adds the schema-2 Python test to the quick Codex runtime gate.
- Modify `README.md`
  - Replaces the manual schema-1 update description with strict protocol, limits, and recovery behavior.
- Modify `docs/superpowers/specs/2026-07-02--codex-context-continuity--design.md`
  - Keeps official PreToolUse limitations aligned with current Codex documentation.

---

### Task 1: Schema-2 Model And Full-Snapshot Validation

**Files:**
- Create: `shared/hooks/managed/codex_context_model.py`
- Create: `tests/test-codex-context-continuity.py`
- Modify: `tests/run-all.sh`
- Modify: `tests/gate-plan.json`

**Interfaces:**
- Produces `RecoveryStatus(str, Enum)` with `READY`, `STALE`, `INCOMPLETE`, `CORRUPT`, and `UNRECOVERABLE`, preserving Python 3.10 compatibility.
- Produces `SnapshotValidationError(ValueError)` with `field_errors: dict[str, str]`.
- Produces `canonical_json_bytes(value: object) -> bytes`.
- Produces `validate_task_payload(payload: object) -> dict[str, object]`.
- Produces `build_snapshot(task, runtime, revision, created_at, updated_at) -> dict[str, object]`.
- Produces `verify_snapshot(snapshot: object) -> dict[str, object]`.
- Produces `evaluate_snapshot(snapshot, runtime_identity) -> tuple[RecoveryStatus, str]`.
- Produces `estimate_tokens(text: str) -> int` and `bounded_text(text, byte_limit, token_limit) -> tuple[str, bool]`.

- [ ] **Step 1: Write failing schema tests**

Add `SchemaTests` covering the accepted and forbidden states:

```python
class SchemaTests(unittest.TestCase):
    def test_empty_and_partial_updates_are_rejected(self):
        for payload in ({}, {"active_goal": "goal"}):
            with self.subTest(payload=payload):
                with self.assertRaises(SnapshotValidationError):
                    validate_task_payload(payload)

    def test_legitimate_empty_lists_are_preserved(self):
        task = valid_task_payload(
            task_status="complete",
            current_plan=[],
            completed_items=[],
            pending_items=[],
            blockers=[],
            non_goals=[],
        )
        normalized = validate_task_payload(task)
        self.assertEqual(normalized["pending_items"], [])
        self.assertEqual(normalized["completed_items"], [])

    def test_snapshot_hash_detects_mutation(self):
        snapshot = build_valid_snapshot()
        snapshot["active_goal"] = "tampered"
        with self.assertRaises(SnapshotValidationError):
            verify_snapshot(snapshot)

    def test_serialized_snapshot_over_64_kib_is_rejected(self):
        task = valid_task_payload(active_goal="x" * 70000)
        with self.assertRaises(SnapshotValidationError):
            validate_task_payload(task)
```

- [ ] **Step 2: Run the schema tests and prove red**

Run:

```bash
python3 tests/test-codex-context-continuity.py SchemaTests -v
```

Expected: import failure because `codex_context_model.py` does not exist.

- [ ] **Step 3: Implement the schema model**

Use these exact public constants and fields:

```python
SCHEMA_VERSION = "2.0"
MAX_SNAPSHOT_BYTES = 64 * 1024
TASK_STATUSES = {"active", "blocked", "complete"}
TASK_FIELDS = {
    "task_status",
    "active_goal",
    "scope_boundary",
    "non_goals",
    "latest_user_correction",
    "current_phase",
    "current_plan",
    "completed_items",
    "pending_items",
    "blockers",
    "next_action",
}
RUNTIME_FIELDS = {
    "schema_version",
    "session_id",
    "turn_id",
    "revision",
    "base_revision",
    "cwd",
    "git_head",
    "last_user_prompt_hash",
    "created_at",
    "updated_at",
    "snapshot_sha256",
}
```

Implement validation as a single accumulating pass so callers receive all invalid fields in one error. Canonical JSON uses sorted keys, UTF-8, no insignificant whitespace, and excludes `snapshot_sha256` while computing the hash. `estimate_tokens` counts each CJK/non-ASCII code point as one token and ASCII runs conservatively at one token per three non-whitespace characters.

- [ ] **Step 4: Run schema tests and syntax checks**

Run:

```bash
python3 tests/test-codex-context-continuity.py SchemaTests -v
python3 -m py_compile shared/hooks/managed/codex_context_model.py tests/test-codex-context-continuity.py
```

Expected: all `SchemaTests` pass and both files compile.

- [ ] **Step 5: Register the focused test in quick gates**

Add the new Python file to `run_bash_syntax_checks`, then add this `tests/gate-plan.json` step:

```json
{
  "id": "codex-context-continuity-model",
  "command": ["python3", "tests/test-codex-context-continuity.py"],
  "area": "codex-runtime",
  "tier": "quick",
  "tags": ["canary", "codex-context-continuity", "python"],
  "parallel_safe": true,
  "timeout_sec": 90
}
```

Run:

```bash
python3 tools/community/gate_plan.py --repo-root . --mode quick --list --format json
```

Expected: the quick gate list includes `codex-context-continuity-model`.

- [ ] **Step 6: Commit Task 1**

```bash
git add shared/hooks/managed/codex_context_model.py tests/test-codex-context-continuity.py tests/run-all.sh tests/gate-plan.json
git commit -m "feat: define strict context snapshot schema"
```

---

### Task 2: Durable Store, Checkpoints, Locking, And Retention

**Files:**
- Create: `shared/hooks/managed/codex_context_store.py`
- Modify: `tests/test-codex-context-continuity.py`
- Modify: `tests/run-all.sh`

**Interfaces:**
- Consumes schema validation and hashing from `codex_context_model.py`.
- Produces `StoreError`, `LockTimeout`, `RevisionConflict`, and `IntegrityError`.
- Produces `SessionStore(root: Path, session_id: str)`.
- `SessionStore.load_primary() -> dict[str, object] | None`.
- `SessionStore.commit_snapshot(task, runtime, base_revision) -> dict[str, object]`.
- `SessionStore.seal_checkpoint(trigger, runtime) -> dict[str, object]`.
- `SessionStore.load_recovery_pair() -> RecoveryPair`.
- `SessionStore.restore_primary(checkpoint) -> dict[str, object]`.
- `prune_state_root(root, active_session_id, policy, now) -> CleanupResult`.
- `RecoveryPair` contains `primary`, `latest_checkpoint`, `previous_checkpoint`, `status`, and `reason`.
- `CleanupResult` contains `deleted_sessions`, `deleted_files`, `deleted_bytes`, `remaining_sessions`, `remaining_bytes`, and `skipped_active_session`.

- [ ] **Step 1: Write failing storage and fault-injection tests**

Add `StoreTests` for:

```python
class StoreTests(unittest.TestCase):
    def test_commit_uses_compare_and_swap_revision(self):
        store = self.new_store("cas")
        first = store.commit_snapshot(valid_task_payload(), runtime("turn-1"), 0)
        self.assertEqual(first["revision"], 1)
        with self.assertRaises(RevisionConflict):
            store.commit_snapshot(valid_task_payload(), runtime("turn-1"), 0)

    def test_corrupt_primary_restores_from_valid_checkpoint(self):
        store = self.ready_store("fallback")
        checkpoint = store.seal_checkpoint("auto", runtime("turn-1"))
        store.primary_path.write_text("{broken", encoding="utf-8")
        pair = store.load_recovery_pair()
        restored = store.restore_primary(pair.latest_checkpoint)
        self.assertEqual(restored["snapshot_sha256"], checkpoint["snapshot_sha256"])

    def test_conflicting_valid_primary_and_checkpoint_is_not_auto_selected(self):
        store = self.conflicting_store("conflict")
        with self.assertRaises(IntegrityError):
            store.load_recovery_pair()

    def test_retention_never_deletes_active_session(self):
        result = build_over_limit_state_root(self.tempdir, active="active")
        prune_state_root(self.tempdir, "active", default_policy(), fixed_now())
        self.assertTrue(result.active_primary.exists())
        self.assertLessEqual(managed_size(self.tempdir), 50 * 1024 * 1024)
```

Also test mode `0700`/`0600`, three-generation rotation, 30-day pruning, 200 inactive-session pruning, 50-MiB pruning, once-per-day cleanup, lock timeout, stale lock recovery policy, interrupted temporary write cleanup, and empty filesystem errors.

- [ ] **Step 2: Run StoreTests and prove red**

```bash
python3 tests/test-codex-context-continuity.py StoreTests -v
```

Expected: import failure for `codex_context_store`.

- [ ] **Step 3: Implement durable storage**

Implement this storage policy object:

```python
@dataclass(frozen=True)
class RetentionPolicy:
    inactive_days: int = 30
    max_inactive_sessions: int = 200
    max_total_bytes: int = 50 * 1024 * 1024
    max_full_generations: int = 3
    cleanup_interval_seconds: int = 24 * 60 * 60
    lock_timeout_seconds: float = 2.0

@dataclass(frozen=True)
class RecoveryPair:
    primary: dict[str, object] | None
    latest_checkpoint: dict[str, object] | None
    previous_checkpoint: dict[str, object] | None
    status: RecoveryStatus
    reason: str

@dataclass(frozen=True)
class CleanupResult:
    deleted_sessions: int
    deleted_files: int
    deleted_bytes: int
    remaining_sessions: int
    remaining_bytes: int
    skipped_active_session: bool
```

Use a per-session lock file with a bounded platform backend: `fcntl.flock` on POSIX and `msvcrt.locking` on Windows. Every write creates a unique `0600` temporary file, writes canonical bytes, flushes, calls `os.fsync`, atomically replaces, and fsyncs the parent directory where supported. Rotation order is previous checkpoint removal, latest checkpoint to previous, then new latest checkpoint. Do not delete the last known good checkpoint before the new checkpoint is re-read and validated.

Cleanup operates only on owned schema-2 filename patterns, sorts inactive sessions by validated update time, never selects `active_session_id`, and stops after all three limits are satisfied. Invalid retention environment values raise `StoreError`; they do not disable limits.

- [ ] **Step 4: Run StoreTests and compile**

```bash
python3 tests/test-codex-context-continuity.py StoreTests -v
python3 -m py_compile shared/hooks/managed/codex_context_store.py
```

Expected: all storage and fault-injection tests pass.

- [ ] **Step 5: Commit Task 2**

```bash
git add shared/hooks/managed/codex_context_store.py shared/hooks/managed/codex_context_model.py tests/test-codex-context-continuity.py tests/run-all.sh
git commit -m "feat: add durable context checkpoint store"
```

---

### Task 3: Lifecycle State Machine And Full State-Update CLI

**Files:**
- Modify: `shared/hooks/managed/codex_context_continuity.py`
- Modify: `tests/test-codex-context-continuity.py`
- Modify: `tests/test-context-contract-hook.sh`

**Interfaces:**
- Consumes `SessionStore` and schema-2 model contracts.
- Produces CLI verbs `state-update --payload JSON` and `recover --session-id ID --turn-id ID`.
- Preserves hook flags `--event EVENT` and `--source SOURCE`.
- Produces `UserPromptSubmit` additional context containing status, base revision, session, turn, and exact update command shape.
- Produces Stop continuation JSON when the current turn is not ready.

- [ ] **Step 1: Replace schema-1 happy-path tests with failing schema-2 lifecycle tests**

Add `LifecycleTests` and shell assertions for this sequence:

```python
class LifecycleTests(unittest.TestCase):
    def test_new_prompt_invalidates_ready_state_by_turn_id(self):
        self.submit_prompt("same prompt", "turn-1")
        self.write_full_state("turn-1")
        self.assert_status("READY")
        self.submit_prompt("same prompt", "turn-2")
        self.assert_status("STALE")

    def test_empty_state_update_cannot_rebind_old_fields(self):
        self.submit_prompt("goal A", "turn-1")
        self.write_full_state("turn-1", goal="goal A")
        self.submit_prompt("goal B", "turn-2")
        result = self.invoke_state_update("turn-2", {})
        self.assertNotEqual(result.returncode, 0)
        self.assert_status("STALE")

    def test_stop_continues_turn_until_current_snapshot_is_ready(self):
        self.submit_prompt("goal", "turn-1")
        output = self.invoke_hook("Stop", turn_id="turn-1")
        self.assertEqual(output["decision"], "block")
        self.write_full_state("turn-1")
        self.assertEqual(self.invoke_hook("Stop", turn_id="turn-1"), {})
```

Update shell payloads to include official `turn_id`, `permission_mode`, and `last_assistant_message` fields where documented. Remove schema-1 tests that manufacture a partial `StateUpdate` event as a production-ready path; keep explicit legacy evidence tests.

- [ ] **Step 2: Run lifecycle tests and prove red**

```bash
python3 tests/test-codex-context-continuity.py LifecycleTests -v
bash tests/test-context-contract-hook.sh
```

Expected: schema-2 lifecycle tests fail and the existing shell test fails at old schema-1 READY assumptions.

- [ ] **Step 3: Refactor the entrypoint into a thin router**

Use subcommands without breaking hook invocation:

```python
def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")
    update = subparsers.add_parser("state-update")
    update.add_argument("--payload", required=True)
    recover = subparsers.add_parser("recover")
    recover.add_argument("--session-id", required=True)
    recover.add_argument("--turn-id", required=True)
    parser.add_argument("--event")
    parser.add_argument("--source")
    return parser
```

Hook mode reads one JSON object from stdin. `UserPromptSubmit` persists a pending-turn record containing exact `session_id`, `turn_id`, prompt hash, redacted preview, non-empty transcript path preservation, and canonical cwd, then emits bounded additional context. `state-update` parses one JSON argument, verifies it against the pending turn, computes Git HEAD with a five-second subprocess timeout, and calls `commit_snapshot` with the caller's `base_revision`.

Stop returns `{}` only when the exact current turn is ready. Otherwise return:

```json
{
  "decision": "block",
  "reason": "Context snapshot is not READY for this turn. Run the exact state-update command from the latest continuity context before finishing."
}
```

- [ ] **Step 4: Prove lifecycle green**

```bash
python3 tests/test-codex-context-continuity.py LifecycleTests -v
bash tests/test-context-contract-hook.sh
```

Expected: lifecycle and hook integration tests pass with no schema-1 false READY path.

- [ ] **Step 5: Commit Task 3**

```bash
git add shared/hooks/managed/codex_context_continuity.py tests/test-codex-context-continuity.py tests/test-context-contract-hook.sh
git commit -m "feat: enforce turn-bound context snapshots"
```

---

### Task 4: Intercepted Tool Guard And Fail-Closed Compaction

**Files:**
- Modify: `shared/hooks/managed/codex_context_continuity.py`
- Modify: `shared/hooks/registry.json`
- Modify: `tests/test-codex-context-continuity.py`
- Modify: `tests/test-context-contract-hook.sh`

**Interfaces:**
- `PreToolUse` returns official `hookSpecificOutput.permissionDecision=deny` for intercepted tools while stale.
- Exact single-command `state-update` and `recover` forms are exempted after token-level validation.
- `PreCompact` returns `continue:false` unless it writes and re-validates a matching checkpoint.
- `PostCompact` records only documented trigger/turn/runtime metadata.

- [ ] **Step 1: Write failing guard and compact tests**

```python
class GuardTests(unittest.TestCase):
    def test_stale_apply_patch_is_denied(self):
        self.submit_prompt("change code", "turn-1")
        output = self.pre_tool("apply_patch", {"command": "*** Begin Patch"}, "turn-1")
        specific = output["hookSpecificOutput"]
        self.assertEqual(specific["permissionDecision"], "deny")

    def test_chained_state_update_command_is_denied(self):
        command = self.valid_update_command("turn-1") + " && rm -rf /tmp/example"
        output = self.pre_tool("Bash", {"command": command}, "turn-1")
        self.assertEqual(output["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_exact_state_update_command_is_allowed_while_stale(self):
        command = self.valid_update_command("turn-1")
        self.assertEqual(self.pre_tool("Bash", {"command": command}, "turn-1"), {})

    def test_precompact_blocks_without_ready_snapshot(self):
        output = self.invoke_hook("PreCompact", turn_id="turn-1", trigger="auto")
        self.assertFalse(output["continue"])

    def test_precompact_seals_ready_snapshot_before_allowing(self):
        self.make_ready("turn-1")
        self.assertEqual(self.invoke_hook("PreCompact", turn_id="turn-1", trigger="auto"), {})
        self.assert_checkpoint_valid("turn-1")
```

Shell integration must also prove a `SessionStart:compact` without a sealed checkpoint cannot emit `READY`.

- [ ] **Step 2: Run guard tests and prove red**

```bash
python3 tests/test-codex-context-continuity.py GuardTests -v
bash tests/test-context-contract-hook.sh
```

Expected: PreToolUse route is missing and PreCompact still allows incomplete state.

- [ ] **Step 3: Implement documented guard outputs and compact sealing**

Register an opt-in `PreToolUse` entry with matcher `*` and command `codex_context_continuity.py --event PreToolUse`.

For denial return exactly:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Context snapshot is not READY for the current turn. Refresh or recover state before using this intercepted tool."
  }
}
```

Parse Bash command strings with `shlex.split`. Exempt only one executable invocation with the installed Python launcher, exact managed script path, one of the two allowed verbs, and no control operator or extra token beyond that verb's declared arguments. For all exposed MCP and apply_patch calls, deny while stale. Record that Codex does not expose every unified execution or non-shell path to PreToolUse; do not emit a complete-enforcement claim.

PreCompact acquires the session lock, reloads state, validates current-turn `READY`, seals and fsyncs the checkpoint, re-reads it, then returns `{}`. Any validation, lock, write, fsync, or re-read failure returns `{"continue": false, "stopReason": "Context snapshot could not be sealed safely; refresh the current turn snapshot before compacting."}`.

PostCompact accepts documented `turn_id` and `trigger`; remove compact-summary extraction and all related hash/length fields.

- [ ] **Step 4: Prove guard and compact green**

```bash
python3 tests/test-codex-context-continuity.py GuardTests -v
bash tests/test-context-contract-hook.sh
python3 tools/community/render_hook_registry.py codex-hooks --registry shared/hooks/registry.json --runtime-home /tmp/codex --python-launcher "$(command -v python3)" --enable-feature context-continuity | jq -e '.hooks.PreToolUse | length > 0'
```

Expected: all guard tests pass and rendered hooks contain the opt-in PreToolUse entry.

- [ ] **Step 5: Commit Task 4**

```bash
git add shared/hooks/managed/codex_context_continuity.py shared/hooks/registry.json tests/test-codex-context-continuity.py tests/test-context-contract-hook.sh
git commit -m "feat: fail closed around context compaction"
```

---

### Task 5: Bounded Recovery And Transcript Extraction

**Files:**
- Create: `shared/hooks/managed/codex_context_recovery.py`
- Modify: `shared/hooks/managed/codex_context_continuity.py`
- Modify: `tests/test-codex-context-continuity.py`
- Modify: `tests/run-all.sh`

**Interfaces:**
- Produces `RecoveryBudget(max_scan_bytes, max_output_bytes, max_tokens)`.
- Produces `extract_transcript_tail(path, budget) -> ExtractedEvidence`.
- Produces `build_recovery_packet(pair, runtime, transcript_path, evidence_refs, budget) -> RecoveryPacket`.
- Produces packet accounting fields `bytes_scanned`, `bytes_emitted`, `estimated_tokens`, `truncated`, `sources_consulted`, and `sources_skipped`.
- Produces `default_recovery_budget() -> RecoveryBudget` returning `FULL_RECOVERY_BUDGET`.
- `ExtractedEvidence` contains `text`, `bytes_scanned`, `bytes_emitted`, `estimated_tokens`, `truncated`, and `skipped_event_count`.
- `RecoveryPacket` contains `status`, `next_action`, `text`, `bytes_scanned`, `bytes_emitted`, `estimated_tokens`, `truncated`, `sources_consulted`, and `sources_skipped`.
- `SessionStart:compact` emits a maximum 8-KiB/2,000-token developer packet.
- CLI `recover` emits a maximum 24-KiB/6,000-token complete packet.

- [ ] **Step 1: Write failing budget and hostile transcript tests**

```python
class RecoveryBudgetTests(unittest.TestCase):
    def test_large_transcript_cannot_escape_output_budget(self):
        transcript = self.write_transcript(
            user_text="真实纠偏",
            image_data="data:image/png;base64," + "A" * 2_000_000,
            tool_output="tool-noise" * 200_000,
        )
        packet = extract_transcript_tail(transcript, default_recovery_budget())
        self.assertLessEqual(packet.bytes_scanned, 256 * 1024)
        self.assertLessEqual(packet.bytes_emitted, 24 * 1024)
        self.assertLessEqual(packet.estimated_tokens, 6000)
        self.assertNotIn("base64", packet.text.lower())
        self.assertIn("真实纠偏", packet.text)

    def test_ready_sessionstart_never_reads_transcript(self):
        store = self.ready_checkpoint_store("ready")
        transcript = self.unreadable_transcript_path()
        packet = build_recovery_packet_for_store(store, transcript)
        self.assertEqual(packet.status, "READY")
        self.assertNotIn("transcript", packet.sources_consulted)

    def test_budget_exhaustion_is_unrecoverable_not_recursive(self):
        packet = self.recover_from_only_oversized_noise()
        self.assertEqual(packet.status, "UNRECOVERABLE")
        self.assertTrue(packet.truncated)
        self.assertEqual(packet.next_action, "ASK_USER_FOR_SCOPE")
```

Also cover malformed JSONL, a partial first tail line, secrets, repeated system instructions, encrypted reasoning, input images, nested tool schemas, missing evidence refs, more than three evidence refs, and CJK token estimation.

- [ ] **Step 2: Run recovery budget tests and prove red**

```bash
python3 tests/test-codex-context-continuity.py RecoveryBudgetTests -v
```

Expected: import failure for `codex_context_recovery`.

- [ ] **Step 3: Implement progressive bounded recovery**

Use these immutable defaults:

```python
@dataclass(frozen=True)
class RecoveryBudget:
    max_scan_bytes: int
    max_output_bytes: int
    max_tokens: int

@dataclass(frozen=True)
class ExtractedEvidence:
    text: str
    bytes_scanned: int
    bytes_emitted: int
    estimated_tokens: int
    truncated: bool
    skipped_event_count: int

@dataclass(frozen=True)
class RecoveryPacket:
    status: str
    next_action: str
    text: str
    bytes_scanned: int
    bytes_emitted: int
    estimated_tokens: int
    truncated: bool
    sources_consulted: tuple[str, ...]
    sources_skipped: tuple[str, ...]

SESSIONSTART_BUDGET = RecoveryBudget(
    max_scan_bytes=0,
    max_output_bytes=8 * 1024,
    max_tokens=2000,
)
FULL_RECOVERY_BUDGET = RecoveryBudget(
    max_scan_bytes=256 * 1024,
    max_output_bytes=24 * 1024,
    max_tokens=6000,
)
MAX_EVIDENCE_REFS = 3
```

For READY, build the packet entirely from validated snapshot/checkpoint fields. For non-ready recovery, inspect validated primary, latest checkpoint, previous checkpoint, then bounded transcript, then at most three exact evidence files. Use structured JSON parsing for the current known transcript message shapes, skip unknown event shapes with accounting, and never treat transcript extraction as sufficient to auto-promote `READY`.

The output packer appends one field at a time and stops before either byte or token limit. It records truncation and omitted counts. It must never truncate inside a JSON string and then emit invalid JSON.

- [ ] **Step 4: Wire bounded packets into SessionStart and recover**

`SessionStart:compact` validates the recovery pair, restores a corrupt primary only from a matching valid checkpoint, writes injection accounting, and emits official `hookSpecificOutput.additionalContext`. It never emits raw file paths unless the next action requires a user-visible local repair.

`recover` requires exact session and turn identifiers and emits JSON containing the packet plus accounting. When evidence is insufficient or the budget is exhausted, return status `UNRECOVERABLE` and next action `ASK_USER_FOR_SCOPE` with exit code 0; this is a controlled recovery result, not a script failure.

- [ ] **Step 5: Prove recovery budgets green**

```bash
python3 tests/test-codex-context-continuity.py RecoveryBudgetTests -v
python3 -m py_compile shared/hooks/managed/codex_context_recovery.py
bash tests/test-context-contract-hook.sh
```

Expected: hostile transcript tests, packet limits, and hook integration pass.

- [ ] **Step 6: Commit Task 5**

```bash
git add shared/hooks/managed/codex_context_recovery.py shared/hooks/managed/codex_context_continuity.py tests/test-codex-context-continuity.py tests/test-context-contract-hook.sh tests/run-all.sh
git commit -m "feat: bound context recovery evidence"
```

---

### Task 6: Installer, Trust, Legacy Migration, And Runtime Documentation

**Files:**
- Modify: `install.sh`
- Modify: `tests/test-install-runtime-quick-canary.sh`
- Modify: `tests/test-install-runtime.sh`
- Modify: `tests/test-codex-hook-trust-audit.sh`
- Modify: `tools/dev/probe-codex-hooks.sh`
- Modify: `README.md`

**Interfaces:**
- Installs all four context-continuity Python files together.
- Requires the opt-in PreToolUse, UserPromptSubmit, Stop, PreCompact, PostCompact, and SessionStart commands.
- Quick probe proves both fail-closed incomplete compaction and valid schema-2 checkpoint recovery.
- Runtime test proves schema-1 state cannot become READY.
- Trust probe checks all enabled context-continuity commands.

- [ ] **Step 1: Write failing installed-runtime assertions**

Extend quick and runtime tests to require:

```bash
install_test_assert_file_exists "$home_dir/.codex/hooks/managed/codex_context_model.py" "schema model should install"
install_test_assert_file_exists "$home_dir/.codex/hooks/managed/codex_context_store.py" "durable store should install"
install_test_assert_file_exists "$home_dir/.codex/hooks/managed/codex_context_recovery.py" "recovery module should install"
```

Require the PreToolUse command in rendered hooks, assert that an incomplete PreCompact output contains `continue:false`, write a complete schema-2 state through the installed `state-update` CLI, seal it, and assert SessionStart output is READY and below both injection budgets. Remove all fabricated `compact_summary` fields and summary-length/hash assertions.

Add a schema-1 fixture under the temporary HOME and prove installed SessionStart reports `INCOMPLETE` or `UNRECOVERABLE`, never READY.

- [ ] **Step 2: Run installer tests and prove red**

```bash
bash tests/test-install-runtime-quick-canary.sh --group codex-context-continuity
bash tests/test-install-runtime.sh
bash tests/test-codex-hook-trust-audit.sh
```

Expected: missing sibling modules, missing PreToolUse command, and old probe semantics fail.

- [ ] **Step 3: Update install completeness and quick probes**

Add all sibling modules to `runtime_target_complete`, quick file checks, `python3 -m py_compile`, and installed-source hash checks. Add the PreToolUse command to `required_codex_hook_commands` and trust expectations only when opt-in is enabled.

The ready probe must execute this real sequence with documented payload fields:

```text
UserPromptSubmit(turn-1) -> state-update(schema 2, base revision 0) -> Stop -> PreCompact(auto) -> PostCompact(auto) -> SessionStart(compact)
```

The blocked probe must execute:

```text
UserPromptSubmit(turn-1) -> PreCompact(auto) => continue:false
```

The quick check passes only when both sequences match their expected outputs and installed files match repository source.

- [ ] **Step 4: Update runtime documentation**

Document in README:

- strict opt-in behavior;
- full state-update requirement;
- PreToolUse interception limitation;
- Stop and PreCompact failure closure;
- recovery and storage budgets;
- schema-1 migration behavior;
- manual disable/reinstall command;
- real compact verification requirement before production claims.

- [ ] **Step 5: Prove installer and trust green**

```bash
bash tests/test-install-runtime-quick-canary.sh --group codex-context-continuity
bash tests/test-install-runtime.sh
bash tests/test-codex-hook-trust-audit.sh
bash tools/dev/probe-codex-hooks.sh "$PWD"
```

Expected: all focused installer and trust checks pass. If the local Codex trust store still requires user review, the final command must report that exact runtime blocker rather than passing.

- [ ] **Step 6: Commit Task 6**

```bash
git add install.sh shared/hooks/registry.json tests/test-install-runtime-quick-canary.sh tests/test-install-runtime.sh tests/test-codex-hook-trust-audit.sh tools/dev/probe-codex-hooks.sh README.md
git commit -m "feat: install strict context continuity runtime"
```

---

### Task 7: Review, Full Regression, Local Install, And Real Compact Acceptance

**Files:**
- Modify only files required to fix verified review or test findings from Tasks 1-6.
- Record runtime evidence in existing state/checkpoint artifacts; do not create a second project truth document.

**Interfaces:**
- Produces a clean repository revision with focused, quick, full, install, trust, manual compact, and automatic compact evidence.
- Leaves context continuity opt-in and installed locally only after gates pass.

- [ ] **Step 1: Run focused behavior and fault-injection gates**

```bash
python3 tests/test-codex-context-continuity.py -v
bash tests/test-context-contract-hook.sh
bash tests/test-install-runtime-quick-canary.sh --group codex-context-continuity
bash tests/test-codex-hook-trust-audit.sh
git diff --check
```

Expected: zero failures; hostile transcript, corruption, locking, retention, stale state, and fail-closed compact cases all run rather than skip.

- [ ] **Step 2: Request independent code review**

Dispatch one read-only reviewer for state/concurrency/integrity and one for runtime contracts/tests. Give each the design path, this plan, the branch-start commit recorded in the SDD progress ledger, current HEAD, and require Critical/Important/Minor findings with file:line evidence. Fix all valid Critical and Important findings through new red-green tests before continuing.

- [ ] **Step 3: Run quick and full repository gates**

```bash
bash tests/run-all.sh --quick
bash tests/run-all.sh
```

Expected: both gates pass with no skipped in-scope context-continuity step. Any unrelated pre-existing failure is reported separately and cannot be used to weaken the context-continuity evidence.

- [ ] **Step 4: Install the reviewed runtime locally**

```bash
ORG_CODEX_CONTEXT_CONTINUITY_ENABLED=1 bash install.sh --target codex --check quick
cmp shared/hooks/managed/codex_context_continuity.py "$HOME/.codex/hooks/managed/codex_context_continuity.py"
cmp shared/hooks/managed/codex_context_model.py "$HOME/.codex/hooks/managed/codex_context_model.py"
cmp shared/hooks/managed/codex_context_store.py "$HOME/.codex/hooks/managed/codex_context_store.py"
cmp shared/hooks/managed/codex_context_recovery.py "$HOME/.codex/hooks/managed/codex_context_recovery.py"
```

Expected: quick install passes and all four installed sources byte-match the reviewed repository.

- [ ] **Step 5: Prove real manual compaction**

In a real Codex CLI session rooted at this repository:

```text
1. Submit a task with a unique goal, scope boundary, correction, completed evidence, pending item, and next action.
2. Confirm the schema-2 snapshot is READY for that exact turn.
3. Run /compact.
4. Confirm PreCompact sealed a validated checkpoint and SessionStart:compact injected no more than 8 KiB/2,000 estimated tokens.
5. Ask Codex to restate the six task facts and compare every fact with the precompact snapshot.
6. Submit a changed scope and confirm the old snapshot becomes STALE before intercepted tools or Stop are allowed.
```

Record input, state path, turn id, expected facts, observed facts, packet bytes/tokens, and hook timestamps in the final verification report. Any mismatch fails runtime acceptance.

Set `STATE_FILE` to the exact `task_state_ref` emitted by this manual session and keep that variable for Step 6. Do not discover the state file by modification time because another Codex task may write the same state root concurrently.

- [ ] **Step 6: Prove real automatic compaction**

Continue the implementation task until Codex emits a real `PreCompact` event with `trigger=auto`; do not substitute a direct script payload. After the event, run:

```bash
test -n "${STATE_FILE:-}" && test -f "$STATE_FILE"
jq -e '
  .precompact.trigger == "auto"
  and .last_recovery_injection.source == "compact"
  and .last_recovery_injection.recovery_status == "READY"
  and .last_recovery_injection.bytes_emitted <= 8192
  and .last_recovery_injection.estimated_tokens <= 2000
' "$STATE_FILE"
```

Then compare the recovered goal, scope, latest correction, completed evidence, pending work, and next action with the sealed checkpoint. If no real automatic compaction occurs during the available execution window, keep production readiness blocked and leave the feature explicitly opt-in; do not replace this gate with simulation.

- [ ] **Step 7: Final repository and installed-runtime audit**

```bash
git status --short
git diff --check
git log --oneline "$(git merge-base main HEAD)"..HEAD
bash tools/dev/probe-codex-hooks.sh "$PWD"
```

Expected: clean worktree, no diff errors, expected task commits only, and trusted/enabled installed hooks. Report separately: proven automated scope, proven real manual scope, proven real automatic scope, PreToolUse coverage gaps, and any accepted residual risk.

- [ ] **Step 8: Commit final review fixes when present**

When Step 2 or later verification required code changes:

```bash
git add shared/hooks/managed/codex_context_continuity.py shared/hooks/managed/codex_context_model.py shared/hooks/managed/codex_context_store.py shared/hooks/managed/codex_context_recovery.py shared/hooks/registry.json tests/test-codex-context-continuity.py tests/test-context-contract-hook.sh tests/test-install-runtime-quick-canary.sh tests/test-install-runtime.sh tests/test-codex-hook-trust-audit.sh tests/run-all.sh tests/gate-plan.json install.sh tools/dev/probe-codex-hooks.sh README.md
git commit -m "fix: close context continuity review findings"
```

When no review fix changed files, do not create an empty commit.

---

## Completion Gate

Do not call the feature production-ready until every Task 1-7 checkbox is complete and fresh evidence proves:

- schema-2 full-snapshot correctness;
- no false READY path;
- durable checkpoint fallback;
- fail-closed Stop and PreCompact behavior;
- bounded recovery context and transcript extraction;
- bounded private retention;
- installed source integrity and hook trust;
- real manual compaction success;
- real automatic compaction success;
- explicit PreToolUse interception coverage gaps.

If real automatic compaction evidence is unavailable, the implementation may be installed for continued dogfood but must remain explicitly classified as not production-ready.
