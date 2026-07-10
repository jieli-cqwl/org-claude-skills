#!/usr/bin/env python3
"""Schema-2 context snapshot contract tests."""

from __future__ import annotations

import hashlib
import json
import os
import select
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock


MANAGED_HOOKS = Path(__file__).resolve().parents[1] / "shared" / "hooks" / "managed"
sys.path.insert(0, str(MANAGED_HOOKS))

from codex_context_model import (  # noqa: E402
    MAX_SNAPSHOT_BYTES,
    RecoveryStatus,
    SnapshotValidationError,
    bounded_text,
    build_snapshot,
    canonical_json_bytes,
    estimate_tokens,
    evaluate_snapshot,
    validate_task_payload,
    verify_snapshot,
)
import codex_context_store  # noqa: E402
import codex_context_continuity  # noqa: E402
from codex_context_store import (  # noqa: E402
    IntegrityError,
    LockTimeout,
    RetentionPolicy,
    RevisionConflict,
    SessionStore,
    StoreError,
    prune_state_root,
)


def valid_task_payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "task_status": "active",
        "active_goal": "Implement schema validation",
        "scope_boundary": "Task 1 only",
        "non_goals": [],
        "latest_user_correction": "",
        "current_phase": "implementation",
        "current_plan": [],
        "completed_items": [],
        "pending_items": ["write model"],
        "blockers": [],
        "next_action": "write the model",
    }
    payload.update(overrides)
    return payload


def valid_runtime(**overrides: object) -> dict[str, object]:
    runtime: dict[str, object] = {
        "session_id": "session-1",
        "turn_id": "turn-1",
        "base_revision": 0,
        "cwd": "/repo",
        "git_head": "a" * 40,
        "last_user_prompt_hash": "b" * 64,
    }
    runtime.update(overrides)
    return runtime


def build_valid_snapshot(**overrides: object) -> dict[str, object]:
    return build_snapshot(
        valid_task_payload(**overrides),
        valid_runtime(),
        revision=1,
        created_at="2026-07-09T00:00:00Z",
        updated_at="2026-07-09T00:00:00Z",
    )


def valid_runtime_identity(**overrides: object) -> dict[str, object]:
    identity = {**valid_runtime(), "revision": 1}
    identity.update(overrides)
    return identity


WRONG_JSON_SCALAR_TYPES = (
    ("null", None),
    ("boolean", True),
    ("number", 1),
    ("list", []),
    ("object", {}),
)
WRONG_JSON_LIST_CONTAINERS = WRONG_JSON_SCALAR_TYPES[:-2] + (
    ("string", "value"),
    ("object", {}),
)
WRONG_NONNEGATIVE_INTEGERS = (
    ("null", None),
    ("boolean", True),
    ("negative", -1),
    ("fractional", 1.5),
    ("string", "1"),
    ("list", []),
    ("object", {}),
)


def rehash_snapshot(snapshot: dict[str, object]) -> None:
    unhashed = {
        key: value for key, value in snapshot.items() if key != "snapshot_sha256"
    }
    snapshot["snapshot_sha256"] = hashlib.sha256(
        canonical_json_bytes(unhashed)
    ).hexdigest()


class SchemaTests(unittest.TestCase):
    def assert_task_field_invalid_across_public_paths(
        self, field: str, value: object, error_field: str | None = None
    ) -> None:
        expected_error = error_field or field
        task = valid_task_payload(**{field: value})

        with self.assertRaises(SnapshotValidationError) as validation_error:
            validate_task_payload(task)
        self.assertIn(expected_error, validation_error.exception.field_errors)

        with self.assertRaises(SnapshotValidationError) as build_error:
            build_snapshot(
                task,
                valid_runtime(),
                revision=1,
                created_at="2026-07-09T00:00:00Z",
                updated_at="2026-07-09T00:00:00Z",
            )
        self.assertIn(expected_error, build_error.exception.field_errors)

        snapshot = build_valid_snapshot()
        snapshot[field] = value
        rehash_snapshot(snapshot)
        with self.assertRaises(SnapshotValidationError) as verification_error:
            verify_snapshot(snapshot)
        self.assertIn(expected_error, verification_error.exception.field_errors)
        self.assertEqual(
            evaluate_snapshot(snapshot, valid_runtime_identity())[0],
            RecoveryStatus.CORRUPT,
        )

    def assert_task_field_valid_across_public_paths(
        self, field: str, value: object
    ) -> None:
        task = valid_task_payload(**{field: value})
        self.assertEqual(validate_task_payload(task)[field], value)

        snapshot = build_snapshot(
            task,
            valid_runtime(),
            revision=1,
            created_at="2026-07-09T00:00:00Z",
            updated_at="2026-07-09T00:00:00Z",
        )
        self.assertEqual(verify_snapshot(snapshot)[field], value)
        self.assertEqual(
            evaluate_snapshot(snapshot, valid_runtime_identity())[0],
            RecoveryStatus.READY,
        )

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

    def test_non_ascii_snapshot_digest_is_corrupt_and_accumulates_field_errors(self):
        snapshot = build_valid_snapshot()
        snapshot["active_goal"] = ""
        snapshot["snapshot_sha256"] = "é" * 64

        with self.assertRaises(SnapshotValidationError) as raised:
            verify_snapshot(snapshot)

        self.assertEqual(
            raised.exception.field_errors["snapshot_sha256"],
            "must be a lowercase SHA-256 hex digest",
        )
        self.assertIn("active_goal", raised.exception.field_errors)
        self.assertEqual(
            evaluate_snapshot(snapshot, valid_runtime_identity())[0], RecoveryStatus.CORRUPT
        )

    def test_serialized_snapshot_over_64_kib_is_rejected(self):
        task = valid_task_payload(active_goal="x" * 70000)
        with self.assertRaises(SnapshotValidationError):
            validate_task_payload(task)

    def test_serialized_snapshot_exact_64_kib_boundary_is_enforced(self):
        baseline = build_valid_snapshot(active_goal="x")
        accepted_goal = "x" * (
            MAX_SNAPSHOT_BYTES - len(canonical_json_bytes(baseline)) + 1
        )
        accepted = build_valid_snapshot(active_goal=accepted_goal)
        self.assertEqual(len(canonical_json_bytes(accepted)), MAX_SNAPSHOT_BYTES)

        rejected = dict(accepted)
        rejected["active_goal"] = accepted_goal + "x"
        unhashed = {
            key: value for key, value in rejected.items() if key != "snapshot_sha256"
        }
        rejected["snapshot_sha256"] = hashlib.sha256(
            json.dumps(
                unhashed,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
                allow_nan=False,
            ).encode("utf-8")
        ).hexdigest()
        self.assertEqual(len(canonical_json_bytes(rejected)), MAX_SNAPSHOT_BYTES + 1)
        with self.assertRaises(SnapshotValidationError) as raised:
            verify_snapshot(rejected)
        self.assertIn("snapshot", raised.exception.field_errors)

    def test_validation_accumulates_unknown_missing_and_invalid_fields(self):
        with self.assertRaises(SnapshotValidationError) as raised:
            validate_task_payload({"active_goal": 1, "unexpected": True})

        errors = raised.exception.field_errors
        self.assertIn("active_goal", errors)
        self.assertIn("scope_boundary", errors)
        self.assertIn("unexpected", errors)

    def test_completed_items_require_item_and_evidence_refs(self):
        task = valid_task_payload(completed_items=[{"item": "wrote test"}])
        with self.assertRaises(SnapshotValidationError) as raised:
            validate_task_payload(task)

        self.assertIn("completed_items[0].evidence_refs", raised.exception.field_errors)

    def test_blocked_task_requires_a_blocker(self):
        task = valid_task_payload(task_status="blocked", blockers=[])
        with self.assertRaises(SnapshotValidationError) as raised:
            validate_task_payload(task)

        self.assertIn("blockers", raised.exception.field_errors)

    def test_blocked_task_rejects_whitespace_only_blockers(self):
        task = valid_task_payload(task_status="blocked", blockers=["   "])

        with self.assertRaises(SnapshotValidationError) as raised:
            validate_task_payload(task)

        self.assertIn("blockers[0]", raised.exception.field_errors)

    def test_completed_item_rejects_whitespace_only_evidence_refs(self):
        task = valid_task_payload(
            task_status="complete",
            completed_items=[{"item": "wrote model", "evidence_refs": ["   "]}],
        )

        with self.assertRaises(SnapshotValidationError) as raised:
            validate_task_payload(task)

        self.assertIn("completed_items[0].evidence_refs[0]", raised.exception.field_errors)

    def test_task_scalar_string_type_matrix_is_total_across_public_paths(self):
        fields = (
            "active_goal",
            "scope_boundary",
            "latest_user_correction",
            "current_phase",
            "next_action",
        )
        for field in fields:
            for type_name, value in WRONG_JSON_SCALAR_TYPES:
                with self.subTest(field=field, type=type_name):
                    self.assert_task_field_invalid_across_public_paths(field, value)

    def test_task_status_type_matrix_is_total_across_public_paths(self):
        invalid_statuses = WRONG_JSON_SCALAR_TYPES + (("unknown", "paused"),)
        for type_name, value in invalid_statuses:
            with self.subTest(type=type_name):
                self.assert_task_field_invalid_across_public_paths(
                    "task_status", value
                )

    def test_task_list_matrix_is_total_across_public_paths(self):
        fields = ("non_goals", "current_plan", "pending_items", "blockers")
        invalid_entries = WRONG_JSON_SCALAR_TYPES + (("blank", "   "),)

        for field in fields:
            with self.subTest(field=field, case="empty"):
                self.assert_task_field_valid_across_public_paths(field, [])
            for type_name, value in WRONG_JSON_LIST_CONTAINERS:
                with self.subTest(field=field, container=type_name):
                    self.assert_task_field_invalid_across_public_paths(field, value)
            for type_name, value in invalid_entries:
                with self.subTest(field=field, entry=type_name):
                    self.assert_task_field_invalid_across_public_paths(
                        field, [value], f"{field}[0]"
                    )

    def test_completed_item_matrix_is_total_across_public_paths(self):
        self.assert_task_field_valid_across_public_paths("completed_items", [])

        for type_name, value in WRONG_JSON_LIST_CONTAINERS:
            with self.subTest(container=type_name):
                self.assert_task_field_invalid_across_public_paths(
                    "completed_items", value
                )

        invalid_items = WRONG_JSON_LIST_CONTAINERS[:-1] + (("list", []),)
        for type_name, value in invalid_items:
            with self.subTest(item=type_name):
                self.assert_task_field_invalid_across_public_paths(
                    "completed_items", [value], "completed_items[0]"
                )

        for type_name, value in WRONG_JSON_SCALAR_TYPES + (("blank", "   "),):
            completed_items = [{"item": value, "evidence_refs": ["test:1"]}]
            with self.subTest(item_field=type_name):
                self.assert_task_field_invalid_across_public_paths(
                    "completed_items", completed_items, "completed_items[0].item"
                )

        for type_name, value in WRONG_JSON_LIST_CONTAINERS:
            completed_items = [{"item": "done", "evidence_refs": value}]
            with self.subTest(evidence_container=type_name):
                self.assert_task_field_invalid_across_public_paths(
                    "completed_items",
                    completed_items,
                    "completed_items[0].evidence_refs",
                )

        for type_name, value in WRONG_JSON_SCALAR_TYPES + (("blank", "   "),):
            completed_items = [{"item": "done", "evidence_refs": [value]}]
            with self.subTest(evidence_entry=type_name):
                self.assert_task_field_invalid_across_public_paths(
                    "completed_items",
                    completed_items,
                    "completed_items[0].evidence_refs[0]",
                )

    def test_no_external_evidence_distinguishes_absence_from_explicit_null(self):
        valid_items = (
            {"item": "done", "evidence_refs": ["test:1"]},
            {
                "item": "done",
                "evidence_refs": ["test:1"],
                "no_external_evidence": False,
            },
            {"item": "done", "evidence_refs": [], "no_external_evidence": True},
        )
        for item in valid_items:
            with self.subTest(valid=item):
                self.assert_task_field_valid_across_public_paths(
                    "completed_items", [item]
                )

        invalid_values = (
            ("null", None),
            ("string", "true"),
            ("number", 1),
            ("list", []),
            ("object", {}),
        )
        for type_name, value in invalid_values:
            item = {
                "item": "done",
                "evidence_refs": ["test:1"],
                "no_external_evidence": value,
            }
            with self.subTest(type=type_name):
                self.assert_task_field_invalid_across_public_paths(
                    "completed_items",
                    [item],
                    "completed_items[0].no_external_evidence",
                )

        for item in (
            {"item": "done", "evidence_refs": []},
            {
                "item": "done",
                "evidence_refs": [],
                "no_external_evidence": False,
            },
        ):
            with self.subTest(empty_evidence=item):
                self.assert_task_field_invalid_across_public_paths(
                    "completed_items",
                    [item],
                    "completed_items[0].evidence_refs",
                )

    def test_canonical_json_is_sorted_compact_utf8(self):
        self.assertEqual(
            canonical_json_bytes({"z": "x", "a": "\u4f60\u597d"}),
            b'{"a":"\xe4\xbd\xa0\xe5\xa5\xbd","z":"x"}',
        )

    def test_build_and_verify_snapshot(self):
        snapshot = build_valid_snapshot()

        verified = verify_snapshot(snapshot)

        self.assertEqual(verified, snapshot)
        self.assertLessEqual(len(canonical_json_bytes(snapshot)), MAX_SNAPSHOT_BYTES)

    def test_evaluate_snapshot_distinguishes_ready_stale_and_corrupt(self):
        snapshot = build_valid_snapshot()

        self.assertEqual(
            evaluate_snapshot(snapshot, valid_runtime_identity())[0], RecoveryStatus.READY
        )
        self.assertEqual(
            evaluate_snapshot(snapshot, valid_runtime_identity(turn_id="turn-2"))[0],
            RecoveryStatus.STALE,
        )
        self.assertEqual(
            evaluate_snapshot({}, valid_runtime_identity())[0], RecoveryStatus.CORRUPT
        )

    def test_evaluate_snapshot_requires_an_exact_complete_runtime_identity(self):
        snapshot = build_valid_snapshot()
        identity = valid_runtime_identity()
        required_fields = {
            "session_id",
            "turn_id",
            "revision",
            "base_revision",
            "cwd",
            "git_head",
            "last_user_prompt_hash",
        }

        for field in required_fields:
            with self.subTest(field=field):
                incomplete = dict(identity)
                incomplete.pop(field)
                self.assertEqual(
                    evaluate_snapshot(snapshot, incomplete)[0],
                    RecoveryStatus.UNRECOVERABLE,
                )

        for malformed in (
            None,
            {**identity, "revision": True},
            {**identity, "last_user_prompt_hash": "unknown"},
            {**identity, "unexpected": "value"},
        ):
            with self.subTest(malformed=malformed):
                self.assertEqual(
                    evaluate_snapshot(snapshot, malformed)[0],
                    RecoveryStatus.UNRECOVERABLE,
                )

        unknown_snapshot = build_snapshot(
            valid_task_payload(),
            valid_runtime(session_id="unknown"),
            revision=1,
            created_at="2026-07-09T00:00:00Z",
            updated_at="2026-07-09T00:00:00Z",
        )
        self.assertEqual(
            evaluate_snapshot(
                unknown_snapshot, valid_runtime_identity(session_id="unknown")
            )[0],
            RecoveryStatus.UNRECOVERABLE,
        )

    def test_verify_and_evaluate_contain_malformed_snapshot_failures(self):
        malformed_snapshots = {
            "mixed_keys": lambda snapshot: snapshot.__setitem__(1, "not allowed"),
            "non_json_value": lambda snapshot: snapshot.__setitem__("active_goal", object()),
            "unpaired_surrogate": lambda snapshot: snapshot.__setitem__(
                "active_goal", "bad\\ud800"
            ),
        }

        for name, mutate in malformed_snapshots.items():
            with self.subTest(name=name):
                snapshot = build_valid_snapshot()
                mutate(snapshot)
                with self.assertRaises(SnapshotValidationError):
                    verify_snapshot(snapshot)
                self.assertEqual(
                    evaluate_snapshot(snapshot, valid_runtime_identity())[0],
                    RecoveryStatus.CORRUPT,
                )

    def test_verify_and_evaluate_contain_hash_canonicalization_failures(self):
        snapshot = build_valid_snapshot()
        circular: list[object] = []
        circular.append(circular)
        snapshot["active_goal"] = circular
        snapshot["scope_boundary"] = object()

        with self.assertRaises(SnapshotValidationError) as raised:
            verify_snapshot(snapshot)

        self.assertIn("active_goal", raised.exception.field_errors)
        self.assertIn("scope_boundary", raised.exception.field_errors)
        self.assertIn("snapshot", raised.exception.field_errors)
        self.assertEqual(
            evaluate_snapshot(snapshot, valid_runtime_identity())[0], RecoveryStatus.CORRUPT
        )

    def test_build_snapshot_runtime_scalar_matrix_raises_validation_error(self):
        runtime_string_fields = ("session_id", "turn_id", "cwd", "git_head")
        for field in runtime_string_fields:
            for type_name, value in WRONG_JSON_SCALAR_TYPES:
                with self.subTest(field=field, type=type_name):
                    with self.assertRaises(SnapshotValidationError) as raised:
                        build_snapshot(
                            valid_task_payload(),
                            valid_runtime(**{field: value}),
                            revision=1,
                            created_at="2026-07-09T00:00:00Z",
                            updated_at="2026-07-09T00:00:00Z",
                        )
                    self.assertIn(field, raised.exception.field_errors)

        for type_name, value in WRONG_NONNEGATIVE_INTEGERS:
            with self.subTest(field="base_revision", type=type_name):
                with self.assertRaises(SnapshotValidationError) as raised:
                    build_snapshot(
                        valid_task_payload(),
                        valid_runtime(base_revision=value),
                        revision=1,
                        created_at="2026-07-09T00:00:00Z",
                        updated_at="2026-07-09T00:00:00Z",
                    )
                self.assertIn("base_revision", raised.exception.field_errors)

            with self.subTest(field="revision", type=type_name):
                with self.assertRaises(SnapshotValidationError) as raised:
                    build_snapshot(
                        valid_task_payload(),
                        valid_runtime(),
                        revision=value,
                        created_at="2026-07-09T00:00:00Z",
                        updated_at="2026-07-09T00:00:00Z",
                    )
                self.assertIn("revision", raised.exception.field_errors)

        invalid_hashes = WRONG_JSON_SCALAR_TYPES + (("format", "not-a-digest"),)
        for type_name, value in invalid_hashes:
            with self.subTest(field="last_user_prompt_hash", type=type_name):
                with self.assertRaises(SnapshotValidationError) as raised:
                    build_snapshot(
                        valid_task_payload(),
                        valid_runtime(last_user_prompt_hash=value),
                        revision=1,
                        created_at="2026-07-09T00:00:00Z",
                        updated_at="2026-07-09T00:00:00Z",
                    )
                self.assertIn("last_user_prompt_hash", raised.exception.field_errors)

        for field in ("created_at", "updated_at"):
            for type_name, value in WRONG_JSON_SCALAR_TYPES:
                kwargs = {
                    "revision": 1,
                    "created_at": "2026-07-09T00:00:00Z",
                    "updated_at": "2026-07-09T00:00:00Z",
                    field: value,
                }
                with self.subTest(field=field, type=type_name):
                    with self.assertRaises(SnapshotValidationError) as raised:
                        build_snapshot(
                            valid_task_payload(), valid_runtime(), **kwargs
                        )
                    self.assertIn(field, raised.exception.field_errors)

    def test_snapshot_identity_scalar_matrix_is_corrupt(self):
        string_fields = (
            "session_id",
            "turn_id",
            "cwd",
            "git_head",
            "created_at",
            "updated_at",
        )
        cases = [
            (field, type_name, value)
            for field in string_fields
            for type_name, value in WRONG_JSON_SCALAR_TYPES
        ]
        cases.extend(
            ("schema_version", type_name, value)
            for type_name, value in WRONG_JSON_SCALAR_TYPES + (("unknown", "1.0"),)
        )
        cases.extend(
            (field, type_name, value)
            for field in ("revision", "base_revision")
            for type_name, value in WRONG_NONNEGATIVE_INTEGERS
        )
        cases.extend(
            (field, type_name, value)
            for field in ("last_user_prompt_hash", "snapshot_sha256")
            for type_name, value in WRONG_JSON_SCALAR_TYPES
            + (("format", "not-a-digest"),)
        )

        for field, type_name, value in cases:
            with self.subTest(field=field, type=type_name):
                snapshot = build_valid_snapshot()
                snapshot[field] = value
                if field != "snapshot_sha256":
                    rehash_snapshot(snapshot)

                with self.assertRaises(SnapshotValidationError) as raised:
                    verify_snapshot(snapshot)
                self.assertIn(field, raised.exception.field_errors)
                self.assertEqual(
                    evaluate_snapshot(snapshot, valid_runtime_identity())[0],
                    RecoveryStatus.CORRUPT,
                )

    def test_runtime_identity_scalar_matrix_is_unrecoverable(self):
        snapshot = build_valid_snapshot()
        string_fields = ("session_id", "turn_id", "cwd", "git_head")
        cases = [
            (field, type_name, value)
            for field in string_fields
            for type_name, value in WRONG_JSON_SCALAR_TYPES
            + (("unknown", "unknown"),)
        ]
        cases.extend(
            (field, type_name, value)
            for field in ("revision", "base_revision")
            for type_name, value in WRONG_NONNEGATIVE_INTEGERS
        )
        cases.extend(
            ("last_user_prompt_hash", type_name, value)
            for type_name, value in WRONG_JSON_SCALAR_TYPES
            + (("format", "not-a-digest"),)
        )

        for field, type_name, value in cases:
            with self.subTest(field=field, type=type_name):
                identity = valid_runtime_identity(**{field: value})
                self.assertEqual(
                    evaluate_snapshot(snapshot, identity)[0],
                    RecoveryStatus.UNRECOVERABLE,
                )

        for type_name, value in WRONG_JSON_LIST_CONTAINERS[:-1]:
            with self.subTest(container=type_name):
                self.assertEqual(
                    evaluate_snapshot(snapshot, value)[0],
                    RecoveryStatus.UNRECOVERABLE,
                )

    def test_token_estimation_and_bounded_text_honor_both_limits(self):
        self.assertEqual(estimate_tokens("abcdef"), 2)
        self.assertEqual(estimate_tokens("\u4f60a\u597d"), 3)
        self.assertEqual(estimate_tokens("\u3000\u00a0"), 2)

        bounded, truncated = bounded_text("abc\u4f60def", byte_limit=6, token_limit=3)

        self.assertTrue(truncated)
        self.assertLessEqual(len(bounded.encode("utf-8")), 6)
        self.assertLessEqual(estimate_tokens(bounded), 3)

        for text, expected in (("a\u3000b", "a\u3000"), ("a\u00a0b", "a\u00a0")):
            with self.subTest(text=text):
                bounded, truncated = bounded_text(text, byte_limit=10, token_limit=2)
                self.assertEqual(bounded, expected)
                self.assertTrue(truncated)


class StoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary_directory.name) / "state"

    def tearDown(self) -> None:
        self._temporary_directory.cleanup()

    def new_store(self, session_id: str) -> SessionStore:
        return SessionStore(self.root, session_id)

    def runtime(self, session_id: str, turn_id: str, base_revision: int) -> dict[str, object]:
        return valid_runtime(
            session_id=session_id,
            turn_id=turn_id,
            base_revision=base_revision,
            cwd=str(self.root.parent.resolve()),
        )

    def ready_store(self, session_id: str = "ready") -> SessionStore:
        store = self.new_store(session_id)
        store.commit_snapshot(
            valid_task_payload(), self.runtime(session_id, "turn-1", 0), 0
        )
        return store

    def age_session(self, store: SessionStore, updated_at: datetime) -> None:
        snapshot = store.load_primary()
        assert snapshot is not None
        timestamp = updated_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
        snapshot["created_at"] = timestamp
        snapshot["updated_at"] = timestamp
        rehash_snapshot(snapshot)
        store.primary_path.write_bytes(canonical_json_bytes(snapshot))
        os.chmod(store.primary_path, 0o600)

    def policy(self, **overrides: object) -> RetentionPolicy:
        values: dict[str, object] = {
            "inactive_days": 30,
            "max_inactive_sessions": 200,
            "max_total_bytes": 50 * 1024 * 1024,
            "max_full_generations": 3,
            "cleanup_interval_seconds": 24 * 60 * 60,
            "lock_timeout_seconds": 0.2,
        }
        values.update(overrides)
        return RetentionPolicy(**values)

    def test_commit_uses_compare_and_swap_revision(self):
        store = self.new_store("cas")
        first = store.commit_snapshot(
            valid_task_payload(), self.runtime("cas", "turn-1", 0), 0
        )

        self.assertEqual(first["revision"], 1)
        with self.assertRaises(RevisionConflict):
            store.commit_snapshot(
                valid_task_payload(), self.runtime("cas", "turn-1", 0), 0
            )
        self.assertEqual(store.load_primary(), first)

    def test_commit_rejects_runtime_and_argument_base_revision_mismatch(self):
        store = self.new_store("cas-runtime")

        with self.assertRaises(RevisionConflict):
            store.commit_snapshot(
                valid_task_payload(), self.runtime("cas-runtime", "turn-1", 9), 0
            )

        self.assertFalse(store.primary_path.exists())

    def test_commit_reopens_canonical_snapshot_with_private_permissions(self):
        store = self.ready_store("permissions")
        snapshot = store.load_primary()

        self.assertIsNotNone(snapshot)
        self.assertEqual(store.primary_path.read_bytes(), canonical_json_bytes(snapshot))
        if os.name == "posix":
            self.assertEqual(stat.S_IMODE(self.root.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE(store.session_dir.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE(store.primary_path.stat().st_mode), 0o600)

    def test_pending_turn_is_store_owned_private_and_overwrites_one_generation(self):
        store = self.new_store("pending-owner")

        first = store.record_pending_turn(
            turn_id="turn-1",
            prompt_sha256="a" * 64,
            prompt_preview="first",
            transcript_path="/tmp/transcript.jsonl",
            cwd=str(self.root.parent.resolve()),
        )
        second = store.record_pending_turn(
            turn_id="turn-2",
            prompt_sha256="b" * 64,
            prompt_preview="second",
            transcript_path="/tmp/transcript.jsonl",
            cwd=str(self.root.parent.resolve()),
        )

        self.assertEqual(first["base_revision"], 0)
        self.assertEqual(second["turn_id"], "turn-2")
        self.assertEqual(store.load_pending_turn(), second)
        self.assertEqual(
            sorted(path.name for path in store.session_dir.glob("pending*.json")),
            ["pending-turn.json"],
        )
        self.assertIn(
            store.pending_turn_path,
            codex_context_store._owned_session_files(store.session_dir),
        )
        if os.name == "posix":
            self.assertEqual(stat.S_IMODE(store.pending_turn_path.stat().st_mode), 0o600)

    def test_corrupt_pending_turn_fails_closed(self):
        store = self.new_store("pending-corrupt")
        store.record_pending_turn(
            turn_id="turn-1",
            prompt_sha256="a" * 64,
            prompt_preview="preview",
            transcript_path="/tmp/transcript.jsonl",
            cwd=str(self.root.parent.resolve()),
        )
        store.pending_turn_path.write_bytes(b"{broken")

        with self.assertRaises(IntegrityError):
            store.load_pending_turn()

    def test_retention_owns_and_prunes_pending_only_session(self):
        old = datetime(2026, 6, 1, tzinfo=timezone.utc)
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        store = self.new_store("pending-retention")
        with mock.patch.object(
            codex_context_store,
            "_utc_now_text",
            return_value=old.isoformat().replace("+00:00", "Z"),
        ):
            store.record_pending_turn(
                turn_id="turn-1",
                prompt_sha256="a" * 64,
                prompt_preview="preview",
                transcript_path="/tmp/transcript.jsonl",
                cwd=str(self.root.parent.resolve()),
            )

        result = prune_state_root(self.root, "active", self.policy(), now)

        self.assertEqual(result.deleted_sessions, 1)
        self.assertFalse(store.session_dir.exists())

    def test_managed_snapshot_read_rejects_semantically_valid_noncanonical_bytes(self):
        store = self.ready_store("noncanonical-primary")
        snapshot = store.load_primary()
        store.primary_path.write_text(
            json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True),
            encoding="utf-8",
        )

        with self.assertRaises(IntegrityError):
            store.load_primary()

    def test_managed_checkpoint_read_marks_noncanonical_bytes_corrupt(self):
        store = self.ready_store("noncanonical-checkpoint")
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("noncanonical-checkpoint", "turn-1", 0)
        )
        store.latest_checkpoint_path.write_text(
            json.dumps(checkpoint, ensure_ascii=False, indent=2, sort_keys=True),
            encoding="utf-8",
        )

        pair = store.load_recovery_pair()

        self.assertEqual(pair.status, RecoveryStatus.CORRUPT)
        self.assertIsNone(pair.latest_checkpoint)

    def test_store_rejects_managed_file_with_non_private_permissions(self):
        if os.name != "posix":
            self.skipTest("POSIX mode bits are required for this assertion")
        store = self.ready_store("broad-permissions")
        os.chmod(store.primary_path, 0o644)

        with self.assertRaises(IntegrityError):
            store.load_primary()

    def test_session_identifier_cannot_escape_or_collide_with_metadata(self):
        for session_id in (
            "../escape",
            "a/b",
            ".",
            "..",
            ".cleanup",
            "cleanup",
            "metadata",
            "cleanup.meta.json",
            "Cleanup",
            "METADATA",
            "Cleanup.Meta.Json",
            "trailing.",
            "CON",
            "con.txt",
            "PRN.log",
            "aux",
            "NUL.json",
            "COM1",
            "com9.data",
            "LPT1",
            "lpt9.backup",
        ):
            with self.subTest(session_id=session_id):
                with self.assertRaises(StoreError):
                    SessionStore(self.root, session_id)

    def test_filesystem_session_key_has_explicit_platform_semantics(self):
        key = codex_context_store._filesystem_session_key
        owns = codex_context_store._is_owned_session_id

        self.assertEqual(key("Foo", platform_semantics="posix"), "Foo")
        self.assertEqual(key("foo", platform_semantics="posix"), "foo")
        self.assertEqual(key("Foo", platform_semantics="nt"), "foo")
        self.assertEqual(
            codex_context_store._validate_session_id(
                "Foo", platform_semantics="nt"
            ),
            "Foo",
        )
        self.assertTrue(owns("Foo", platform_semantics="posix"))
        self.assertTrue(owns("Foo", platform_semantics="nt"))
        for session_id in (
            "name.",
            "CON",
            "con.txt",
            "PRN.log",
            "AUX",
            "nul.json",
            "COM1",
            "com9.data",
            "LPT1",
            "lpt9.backup",
            "CLEANUP",
            "Metadata",
            "Cleanup.Meta.Json",
        ):
            for platform_semantics in ("posix", "nt"):
                with self.subTest(
                    session_id=session_id,
                    platform_semantics=platform_semantics,
                ):
                    self.assertIsNone(
                        key(session_id, platform_semantics=platform_semantics)
                    )
                    self.assertFalse(
                        owns(session_id, platform_semantics=platform_semantics)
                    )

        for session_id in ("COM0", "COM10", "LPT0", "LPT10", "console"):
            self.assertEqual(
                key(session_id, platform_semantics="posix"), session_id
            )
            self.assertEqual(
                key(session_id, platform_semantics="nt"), session_id.casefold()
            )

    def test_nt_store_preserves_logical_id_while_using_folded_directory_key(self):
        store = SessionStore(self.root, "Foo", _platform_semantics="nt")

        snapshot = store.commit_snapshot(
            valid_task_payload(), self.runtime("Foo", "turn-1", 0), 0
        )
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("Foo", "turn-1", 0)
        )
        reopened = SessionStore(self.root, "Foo", _platform_semantics="nt")

        self.assertEqual(store.session_id, "Foo")
        self.assertEqual(store.session_key, "foo")
        self.assertEqual(store.session_dir, self.root / "foo")
        self.assertEqual(snapshot["session_id"], "Foo")
        self.assertEqual(checkpoint["session_id"], "Foo")
        self.assertEqual(reopened.load_primary(), snapshot)

    def test_nt_store_rejects_logical_alias_rebind_for_existing_directory_key(self):
        store = SessionStore(self.root, "Foo", _platform_semantics="nt")
        store.commit_snapshot(
            valid_task_payload(), self.runtime("Foo", "turn-1", 0), 0
        )

        with self.assertRaises(IntegrityError):
            SessionStore(self.root, "foo", _platform_semantics="nt")

    def test_scanner_accepts_mixed_case_snapshot_in_nt_canonical_key_directory(self):
        store = SessionStore(self.root, "Foo", _platform_semantics="nt")
        store.commit_snapshot(
            valid_task_payload(), self.runtime("Foo", "turn-1", 0), 0
        )
        store.seal_checkpoint("auto", self.runtime("Foo", "turn-1", 0))
        store.primary_path.unlink()

        records = codex_context_store._scan_session_records(
            self.root, platform_semantics="nt"
        )

        self.assertEqual(
            [(record.session_id, record.session_key) for record in records],
            [("foo", "foo")],
        )
        self.assertNotEqual(records[0].updated_at, codex_context_store._EPOCH)

    def test_session_id_matches_filesystem_key_with_explicit_platform_semantics(self):
        matches = codex_context_store._session_id_matches_filesystem_key

        self.assertTrue(matches("Foo", "foo", platform_semantics="nt"))
        self.assertFalse(matches("Foo", "Foo", platform_semantics="nt"))
        self.assertTrue(matches("Foo", "Foo", platform_semantics="posix"))

    def test_scanner_rejects_windows_aliases_but_preserves_posix_case(self):
        root = mock.Mock()
        directories = []
        for name in ("Foo", "foo"):
            directory = mock.Mock()
            directory.name = name
            directory.is_symlink.return_value = False
            directory.is_dir.return_value = True
            directories.append(directory)
        root.iterdir.return_value = directories

        with mock.patch.object(
            codex_context_store, "_ensure_private_directory"
        ), mock.patch.object(
            codex_context_store, "_owned_session_files", return_value=[]
        ), mock.patch.object(
            codex_context_store, "_account_session_tree", return_value=(0, False)
        ), mock.patch.object(
            codex_context_store,
            "_record_timestamp",
            return_value=datetime(1970, 1, 1, tzinfo=timezone.utc),
        ):
            posix_records = codex_context_store._scan_session_records(
                root, platform_semantics="posix"
            )

            self.assertEqual(
                {(record.session_id, record.session_key) for record in posix_records},
                {("Foo", "Foo"), ("foo", "foo")},
            )
            with self.assertRaisesRegex(StoreError, "aliases collide"):
                codex_context_store._scan_session_records(
                    root, platform_semantics="nt"
                )

    def test_store_fails_closed_on_root_or_owned_file_symlink(self):
        target = Path(self._temporary_directory.name) / "target"
        target.mkdir()
        root_link = Path(self._temporary_directory.name) / "root-link"
        root_link.symlink_to(target, target_is_directory=True)
        with self.assertRaises(StoreError):
            SessionStore(root_link, "session")

        store = self.new_store("linked-primary")
        external = Path(self._temporary_directory.name) / "external.json"
        external.write_text("{}", encoding="utf-8")
        store.primary_path.symlink_to(external)
        with self.assertRaises(IntegrityError):
            store.load_primary()

        broken = self.new_store("broken-link")
        broken.primary_path.symlink_to(
            Path(self._temporary_directory.name) / "missing.json"
        )
        with self.assertRaises(IntegrityError):
            broken.load_recovery_pair()

    def test_lock_timeout_is_distinct_from_stale_lock_file_presence(self):
        store = self.new_store("locking")
        store.lock_path.touch(mode=0o600)
        old = time.time() - 86400
        os.utime(store.lock_path, (old, old))
        store.commit_snapshot(
            valid_task_payload(), self.runtime("locking", "turn-1", 0), 0
        )

        with store._locked(timeout_seconds=0.2):
            with self.assertRaises(LockTimeout):
                store.commit_snapshot(
                    valid_task_payload(), self.runtime("locking", "turn-2", 1), 1
                )

    def test_lock_file_payload_is_bounded(self):
        store = self.ready_store("oversized-lock")
        store.lock_path.write_bytes(b"not-control-plane-overhead")

        with self.assertRaises(IntegrityError):
            store.load_primary()

    def test_lock_creation_tolerates_unavailable_fchmod(self):
        store = self.new_store("portable-lock")
        fchmod = getattr(codex_context_store.os, "fchmod", None)
        if fchmod is not None:
            delattr(codex_context_store.os, "fchmod")

        try:
            with store._locked():
                pass
        finally:
            if fchmod is not None:
                setattr(codex_context_store.os, "fchmod", fchmod)

        self.assertTrue(store.lock_path.exists())

    def test_session_directory_creation_waits_for_lifecycle_lock(self):
        codex_context_store._ensure_private_directory(self.root)
        lifecycle_path = self.root / codex_context_store.LIFECYCLE_LOCK_NAME
        session_path = self.root / "lifecycle-created"
        construction_started = threading.Event()
        failures: list[BaseException] = []

        def construct_store() -> None:
            construction_started.set()
            try:
                SessionStore(self.root, "lifecycle-created", lock_timeout_seconds=1.0)
            except BaseException as exc:
                failures.append(exc)

        with codex_context_store._bounded_lock(lifecycle_path, 1.0):
            thread = threading.Thread(target=construct_store)
            thread.start()
            self.assertTrue(construction_started.wait(0.5))
            time.sleep(0.05)
            created_while_lifecycle_held = session_path.exists()

        thread.join(1.0)
        self.assertFalse(thread.is_alive())
        self.assertEqual(failures, [])
        self.assertFalse(created_while_lifecycle_held)
        self.assertTrue(session_path.exists())

    def test_temp_creation_tolerates_unavailable_fchmod(self):
        store = self.new_store("portable-temp")
        fchmod = getattr(codex_context_store.os, "fchmod", None)
        if fchmod is not None:
            delattr(codex_context_store.os, "fchmod")

        try:
            temp_path = codex_context_store._prepare_temp(
                store.session_dir, "portable.json", b"{}"
            )
        finally:
            if fchmod is not None:
                setattr(codex_context_store.os, "fchmod", fchmod)

        self.assertEqual(temp_path.read_bytes(), b"{}")

    def test_unlock_failure_closes_descriptor_and_does_not_poison_next_lock(self):
        store = self.new_store("unlock-close")
        closed_descriptors: list[int] = []
        real_close = os.close

        def recording_close(descriptor: int) -> None:
            closed_descriptors.append(descriptor)
            real_close(descriptor)

        with mock.patch.object(
            codex_context_store, "_unlock", side_effect=OSError("unlock boom")
        ), mock.patch.object(
            codex_context_store.os, "close", side_effect=recording_close
        ):
            with self.assertRaisesRegex(StoreError, "unlock boom"):
                with codex_context_store._bounded_lock(store.lock_path, 0.1):
                    pass

        self.assertTrue(closed_descriptors)
        with codex_context_store._bounded_lock(store.lock_path, 0.1):
            pass

    def test_body_exception_wins_when_unlock_also_fails(self):
        store = self.new_store("unlock-body-error")

        with mock.patch.object(
            codex_context_store, "_unlock", side_effect=OSError("unlock boom")
        ):
            with self.assertRaisesRegex(RuntimeError, "body boom"):
                with codex_context_store._bounded_lock(store.lock_path, 0.1):
                    raise RuntimeError("body boom")

    def test_locked_handoff_closes_session_when_lifecycle_release_fails(self):
        store = self.new_store("handoff-release")
        lifecycle_inode = store.lifecycle_lock_path.stat().st_ino
        acquired: dict[str, int] = {}
        real_acquire = codex_context_store._acquire_bounded_lock
        real_release = codex_context_store._release_lock

        def recording_acquire(path: Path, timeout_seconds: float) -> int:
            descriptor = real_acquire(path, timeout_seconds)
            if Path(path) == store.lock_path:
                acquired["session"] = descriptor
            return descriptor

        def failing_release(descriptor: int) -> None:
            inode = os.fstat(descriptor).st_ino
            real_release(descriptor)
            if inode == lifecycle_inode:
                raise StoreError("lifecycle release boom")
            raise StoreError("session release boom")

        try:
            with mock.patch.object(
                codex_context_store,
                "_acquire_bounded_lock",
                side_effect=recording_acquire,
            ), mock.patch.object(
                codex_context_store, "_release_lock", side_effect=failing_release
            ):
                with self.assertRaisesRegex(StoreError, "lifecycle release boom"):
                    with store._locked():
                        self.fail("lifecycle release must fail before the body")

            session_descriptor = acquired["session"]
            with self.assertRaises(OSError):
                os.fstat(session_descriptor)
        finally:
            descriptor = acquired.get("session")
            if descriptor is not None:
                try:
                    os.fstat(descriptor)
                except OSError:
                    pass
                else:
                    real_release(descriptor)

        with store._locked(timeout_seconds=0.1):
            pass

    def test_retention_fstat_failure_releases_acquired_session_descriptor(self):
        store = self.ready_store("retention-fstat")
        record = codex_context_store._scan_session_records(self.root)[0]
        acquired: dict[str, int] = {}
        unlocked: list[int] = []
        closed: list[int] = []
        real_acquire = codex_context_store._acquire_bounded_lock
        real_fstat = os.fstat
        real_unlock = codex_context_store._unlock
        real_close = os.close
        injected = False

        def recording_acquire(path: Path, timeout_seconds: float) -> int:
            descriptor = real_acquire(path, timeout_seconds)
            if Path(path) == store.lock_path:
                acquired["session"] = descriptor
            return descriptor

        def failing_fstat(descriptor: int) -> os.stat_result:
            nonlocal injected
            if descriptor == acquired.get("session") and not injected:
                injected = True
                raise OSError("fstat boom")
            return real_fstat(descriptor)

        def recording_unlock(descriptor: int) -> None:
            unlocked.append(descriptor)
            real_unlock(descriptor)

        def recording_close(descriptor: int) -> None:
            closed.append(descriptor)
            real_close(descriptor)

        with mock.patch.object(
            codex_context_store,
            "_acquire_bounded_lock",
            side_effect=recording_acquire,
        ), mock.patch.object(
            codex_context_store.os, "fstat", side_effect=failing_fstat
        ), mock.patch.object(
            codex_context_store, "_unlock", side_effect=recording_unlock
        ), mock.patch.object(
            codex_context_store.os, "close", side_effect=recording_close
        ):
            with self.assertRaisesRegex(StoreError, "inspect retention lock"):
                codex_context_store._delete_record(self.root, record, 0.1)

        session_descriptor = acquired["session"]
        self.assertTrue(injected)
        self.assertIn(session_descriptor, unlocked)
        self.assertIn(session_descriptor, closed)
        with codex_context_store._bounded_lock(store.lock_path, 0.1):
            pass

    @unittest.skipUnless(os.name == "posix", "POSIX flock evidence only")
    def test_posix_lock_timeout_coordinates_across_processes(self):
        store = self.new_store("process-lock")
        child_code = """
import sys
sys.path.insert(0, sys.argv[1])
from pathlib import Path
from codex_context_store import LockTimeout, SessionStore

store = SessionStore(Path(sys.argv[2]), sys.argv[3], lock_timeout_seconds=0.15)
print("ready", flush=True)
for _ in range(2):
    if sys.stdin.readline() != "attempt\\n":
        raise SystemExit(2)
    try:
        with store._locked(timeout_seconds=0.15):
            outcome = "acquired"
    except LockTimeout:
        outcome = "timeout"
    print(outcome, flush=True)
"""
        process = subprocess.Popen(
            [
                sys.executable,
                "-c",
                child_code,
                str(MANAGED_HOOKS),
                str(self.root),
                store.session_id,
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        def read_child_line() -> str:
            assert process.stdout is not None
            readable, _, _ = select.select([process.stdout], [], [], 1.0)
            self.assertTrue(readable, "child lock attempt timed out")
            return process.stdout.readline().strip()

        try:
            self.assertEqual(read_child_line(), "ready")
            assert process.stdin is not None
            with store._locked(timeout_seconds=0.5):
                process.stdin.write("attempt\n")
                process.stdin.flush()
                self.assertEqual(read_child_line(), "timeout")

            process.stdin.write("attempt\n")
            process.stdin.flush()
            self.assertEqual(read_child_line(), "acquired")
            process.stdin.close()
            self.assertEqual(process.wait(timeout=1.0), 0, process.stderr.read())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=1.0)
            for stream in (process.stdin, process.stdout, process.stderr):
                if stream is not None and not stream.closed:
                    stream.close()

    def test_failed_replace_preserves_primary_and_cleans_unique_temp(self):
        store = self.ready_store("replace-failure")
        original = store.primary_path.read_bytes()
        with mock.patch.object(codex_context_store.os, "replace", side_effect=OSError("boom")):
            with self.assertRaises(StoreError):
                store.commit_snapshot(
                    valid_task_payload(active_goal="new"),
                    self.runtime("replace-failure", "turn-2", 1),
                    1,
                )

        self.assertEqual(store.primary_path.read_bytes(), original)
        self.assertEqual(list(store.session_dir.glob("*.tmp")), [])
        self.assertEqual(list(store.session_dir.glob(".*.tmp")), [])

    def test_failed_file_fsync_cleans_temp_without_publishing(self):
        store = self.new_store("fsync-failure")
        with mock.patch.object(codex_context_store.os, "fsync", side_effect=OSError("boom")):
            with self.assertRaises(StoreError):
                store.commit_snapshot(
                    valid_task_payload(), self.runtime("fsync-failure", "turn-1", 0), 0
                )

        self.assertFalse(store.primary_path.exists())
        self.assertEqual(list(store.session_dir.glob("*.tmp")), [])
        self.assertEqual(list(store.session_dir.glob(".*.tmp")), [])

    def test_temp_unlink_failure_reports_original_write_failure(self):
        store = self.new_store("write-cleanup-failure")

        with mock.patch.object(
            codex_context_store.os, "fsync", side_effect=OSError("write boom")
        ), mock.patch.object(
            Path, "unlink", side_effect=OSError("cleanup denied")
        ):
            with self.assertRaises(StoreError) as raised:
                codex_context_store._prepare_temp(
                    store.session_dir, "primary.json", b"{}"
                )

        message = str(raised.exception)
        self.assertIn("write boom", message)
        self.assertIn("cleanup denied", message)

    def test_temp_unlink_failure_reports_original_publish_failure(self):
        store = self.new_store("publish-cleanup-failure")
        temp_path = codex_context_store._prepare_temp(
            store.session_dir, "primary.json", b"{}"
        )

        with mock.patch.object(
            codex_context_store.os, "replace", side_effect=OSError("publish boom")
        ), mock.patch.object(
            Path, "unlink", side_effect=OSError("cleanup denied")
        ):
            with self.assertRaises(StoreError) as raised:
                codex_context_store._publish_temp(temp_path, store.primary_path)

        message = str(raised.exception)
        self.assertIn("publish boom", message)
        self.assertIn("cleanup denied", message)

    def test_checkpoint_rotation_keeps_exactly_three_full_generations(self):
        store = self.ready_store("rotation")
        first = store.seal_checkpoint("auto", self.runtime("rotation", "turn-1", 0))
        store.commit_snapshot(
            valid_task_payload(active_goal="second"),
            self.runtime("rotation", "turn-2", 1),
            1,
        )
        second = store.seal_checkpoint("auto", self.runtime("rotation", "turn-2", 1))
        store.commit_snapshot(
            valid_task_payload(active_goal="third"),
            self.runtime("rotation", "turn-3", 2),
            2,
        )
        third = store.seal_checkpoint("manual", self.runtime("rotation", "turn-3", 2))

        pair = store.load_recovery_pair()
        self.assertEqual(pair.latest_checkpoint, third)
        self.assertEqual(pair.previous_checkpoint, second)
        self.assertNotEqual(pair.previous_checkpoint["checkpoint_sha256"], first["checkpoint_sha256"])
        self.assertEqual(
            sorted(path.name for path in store.session_dir.glob("*.json")),
            ["checkpoint.latest.json", "checkpoint.previous.json", "primary.json"],
        )

    def test_corrupt_latest_never_displaces_valid_previous_on_publish_failure(self):
        store = self.ready_store("corrupt-latest-rotation")
        first = store.seal_checkpoint(
            "auto", self.runtime("corrupt-latest-rotation", "turn-1", 0)
        )
        store.commit_snapshot(
            valid_task_payload(active_goal="second"),
            self.runtime("corrupt-latest-rotation", "turn-2", 1),
            1,
        )
        store.seal_checkpoint(
            "auto", self.runtime("corrupt-latest-rotation", "turn-2", 1)
        )
        store.latest_checkpoint_path.write_bytes(b"{broken")
        previous_bytes = store.previous_checkpoint_path.read_bytes()

        real_replace = codex_context_store.os.replace

        def fail_latest(source: object, destination: object) -> None:
            if Path(destination) == store.latest_checkpoint_path:
                raise OSError("forced latest publish failure")
            real_replace(source, destination)

        with mock.patch.object(codex_context_store.os, "replace", side_effect=fail_latest):
            with self.assertRaises(StoreError):
                store.seal_checkpoint(
                    "manual", self.runtime("corrupt-latest-rotation", "turn-2", 1)
                )

        self.assertEqual(store.previous_checkpoint_path.read_bytes(), previous_bytes)
        pair = store.load_recovery_pair()
        self.assertEqual(pair.previous_checkpoint, first)
        self.assertEqual(pair.status, RecoveryStatus.CORRUPT)

    def test_corrupt_previous_is_replaced_only_by_valid_latest_before_publish(self):
        store = self.ready_store("corrupt-previous-rotation")
        store.seal_checkpoint(
            "auto", self.runtime("corrupt-previous-rotation", "turn-1", 0)
        )
        store.commit_snapshot(
            valid_task_payload(active_goal="second"),
            self.runtime("corrupt-previous-rotation", "turn-2", 1),
            1,
        )
        latest = store.seal_checkpoint(
            "auto", self.runtime("corrupt-previous-rotation", "turn-2", 1)
        )
        store.previous_checkpoint_path.write_bytes(b"{broken")
        real_replace = codex_context_store.os.replace

        def fail_latest(source: object, destination: object) -> None:
            if Path(destination) == store.latest_checkpoint_path:
                raise OSError("forced latest publish failure")
            real_replace(source, destination)

        with mock.patch.object(codex_context_store.os, "replace", side_effect=fail_latest):
            with self.assertRaises(StoreError):
                store.seal_checkpoint(
                    "manual", self.runtime("corrupt-previous-rotation", "turn-2", 1)
                )

        pair = store.load_recovery_pair()
        self.assertEqual(pair.previous_checkpoint, latest)
        self.assertEqual(pair.status, RecoveryStatus.READY)

    def test_checkpoint_rotation_rejects_unsafe_previous_path_without_mutation(self):
        store = self.ready_store("unsafe-previous-rotation")
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("unsafe-previous-rotation", "turn-1", 0)
        )
        generation_paths = (store.primary_path, store.latest_checkpoint_path)
        generations = {
            path.name: path.read_bytes() for path in generation_paths
        }
        external = Path(self._temporary_directory.name) / "external-checkpoint.json"
        external.write_bytes(canonical_json_bytes(checkpoint))
        store.previous_checkpoint_path.symlink_to(external)

        with self.assertRaises(IntegrityError):
            store.seal_checkpoint(
                "manual", self.runtime("unsafe-previous-rotation", "turn-1", 0)
            )

        self.assertTrue(store.previous_checkpoint_path.is_symlink())
        self.assertEqual(external.read_bytes(), canonical_json_bytes(checkpoint))
        self.assertEqual(
            {path.name: path.read_bytes() for path in generation_paths},
            generations,
        )

    def test_interrupted_checkpoint_rotation_retains_a_verified_fallback(self):
        store = self.ready_store("rotation-failure")
        first = store.seal_checkpoint(
            "auto", self.runtime("rotation-failure", "turn-1", 0)
        )
        store.commit_snapshot(
            valid_task_payload(active_goal="second"),
            self.runtime("rotation-failure", "turn-2", 1),
            1,
        )
        real_replace = codex_context_store.os.replace

        def fail_latest(source: object, destination: object) -> None:
            if Path(destination) == store.latest_checkpoint_path:
                raise OSError("interrupted")
            real_replace(source, destination)

        with mock.patch.object(codex_context_store.os, "replace", side_effect=fail_latest):
            with self.assertRaises(StoreError):
                store.seal_checkpoint(
                    "auto", self.runtime("rotation-failure", "turn-2", 1)
                )

        pair = store.load_recovery_pair()
        self.assertEqual(pair.previous_checkpoint, first)

    def test_previous_only_checkpoint_survives_failed_latest_publish(self):
        store = self.ready_store("previous-only-failure")
        fallback = store.seal_checkpoint(
            "auto", self.runtime("previous-only-failure", "turn-1", 0)
        )
        os.replace(store.latest_checkpoint_path, store.previous_checkpoint_path)
        store.commit_snapshot(
            valid_task_payload(active_goal="second"),
            self.runtime("previous-only-failure", "turn-2", 1),
            1,
        )
        real_replace = codex_context_store.os.replace

        def fail_latest(source: object, destination: object) -> None:
            if Path(destination) == store.latest_checkpoint_path:
                raise OSError("interrupted")
            real_replace(source, destination)

        with mock.patch.object(codex_context_store.os, "replace", side_effect=fail_latest):
            with self.assertRaises(StoreError):
                store.seal_checkpoint(
                    "auto", self.runtime("previous-only-failure", "turn-2", 1)
                )

        pair = store.load_recovery_pair()
        self.assertEqual(pair.previous_checkpoint, fallback)

    def test_surrogate_checkpoint_trigger_is_store_error_without_mutation(self):
        store = self.ready_store("surrogate-trigger")
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("surrogate-trigger", "turn-1", 0)
        )
        generations = {
            path.name: path.read_bytes() for path in store.session_dir.glob("*.json")
        }

        with self.assertRaises(StoreError) as raised:
            store.seal_checkpoint(
                "bad-\ud800-trigger", self.runtime("surrogate-trigger", "turn-1", 0)
            )

        self.assertNotIsInstance(raised.exception, UnicodeEncodeError)
        self.assertEqual(
            {path.name: path.read_bytes() for path in store.session_dir.glob("*.json")},
            generations,
        )
        self.assertEqual(store.load_recovery_pair().latest_checkpoint, checkpoint)
        self.assertEqual(list(store.session_dir.glob(".*.tmp")), [])

    def test_checkpoint_serialization_failure_is_store_error_without_mutation(self):
        store = self.ready_store("checkpoint-serialization")
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("checkpoint-serialization", "turn-1", 0)
        )
        generations = {
            path.name: path.read_bytes() for path in store.session_dir.glob("*.json")
        }

        with mock.patch.object(
            codex_context_store,
            "canonical_json_bytes",
            side_effect=ValueError("not serializable"),
        ):
            with self.assertRaises(StoreError):
                store.seal_checkpoint(
                    "manual",
                    self.runtime("checkpoint-serialization", "turn-1", 0),
                )

        self.assertEqual(
            {path.name: path.read_bytes() for path in store.session_dir.glob("*.json")},
            generations,
        )
        self.assertEqual(store.load_recovery_pair().latest_checkpoint, checkpoint)
        self.assertEqual(list(store.session_dir.glob(".*.tmp")), [])

    def test_commit_converts_caller_validation_error_without_mutation(self):
        store = self.ready_store("commit-validation-error")
        primary_bytes = store.primary_path.read_bytes()

        with self.assertRaises(StoreError) as raised:
            store.commit_snapshot(
                valid_task_payload(active_goal=7),
                self.runtime("commit-validation-error", "turn-2", 1),
                1,
            )

        self.assertNotIsInstance(raised.exception, SnapshotValidationError)
        self.assertIn("active_goal", str(raised.exception))
        self.assertEqual(store.primary_path.read_bytes(), primary_bytes)
        self.assertEqual(list(store.session_dir.glob(".*.tmp")), [])

    def test_checkpoint_prepare_oserror_is_store_error_without_mutation(self):
        store = self.ready_store("checkpoint-prepare-oserror")
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("checkpoint-prepare-oserror", "turn-1", 0)
        )
        generation_bytes = {
            path.name: path.read_bytes() for path in store.session_dir.glob("*.json")
        }

        with mock.patch.object(
            codex_context_store,
            "_prepare_temp",
            side_effect=OSError("checkpoint disk failure"),
        ):
            with self.assertRaises(StoreError) as raised:
                store.seal_checkpoint(
                    "manual",
                    self.runtime("checkpoint-prepare-oserror", "turn-1", 0),
                )

        self.assertNotIsInstance(raised.exception, OSError)
        self.assertIn("checkpoint disk failure", str(raised.exception))
        self.assertEqual(
            {path.name: path.read_bytes() for path in store.session_dir.glob("*.json")},
            generation_bytes,
        )
        self.assertEqual(store.load_recovery_pair().latest_checkpoint, checkpoint)

    def test_restore_prepare_oserror_is_store_error_without_mutation(self):
        store = self.ready_store("restore-prepare-oserror")
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("restore-prepare-oserror", "turn-1", 0)
        )
        store.primary_path.write_bytes(b"{broken")
        corrupt_primary = store.primary_path.read_bytes()

        with mock.patch.object(
            codex_context_store,
            "_prepare_temp",
            side_effect=OSError("restore disk failure"),
        ):
            with self.assertRaises(StoreError) as raised:
                store.restore_primary(checkpoint)

        self.assertNotIsInstance(raised.exception, OSError)
        self.assertIn("restore disk failure", str(raised.exception))
        self.assertEqual(store.primary_path.read_bytes(), corrupt_primary)
        self.assertEqual(list(store.session_dir.glob(".*.tmp")), [])

    def test_corrupt_primary_restores_from_valid_checkpoint(self):
        store = self.ready_store("fallback")
        checkpoint = store.seal_checkpoint("auto", self.runtime("fallback", "turn-1", 0))
        store.primary_path.write_text("{broken", encoding="utf-8")

        pair = store.load_recovery_pair()
        self.assertEqual(pair.status, RecoveryStatus.CORRUPT)
        restored = store.restore_primary(pair.latest_checkpoint)

        self.assertEqual(restored["snapshot_sha256"], checkpoint["snapshot_sha256"])
        self.assertEqual(store.load_primary(), restored)

    def test_invalid_checkpoint_timestamps_fail_before_primary_mutation(self):
        store = self.ready_store("invalid-checkpoint-time")
        checkpoint = store.seal_checkpoint(
            "auto", self.runtime("invalid-checkpoint-time", "turn-1", 0)
        )
        snapshot = dict(checkpoint["snapshot"])
        snapshot["created_at"] = "not-a-time"
        rehash_snapshot(snapshot)
        checkpoint["snapshot"] = snapshot
        checkpoint["snapshot_sha256"] = snapshot["snapshot_sha256"]
        checkpoint["checkpoint_sha256"] = codex_context_store._checkpoint_hash(
            checkpoint
        )
        store.primary_path.write_text("{broken", encoding="utf-8")
        corrupt_primary = store.primary_path.read_bytes()

        with self.assertRaises(IntegrityError):
            store.restore_primary(checkpoint)

        self.assertEqual(store.primary_path.read_bytes(), corrupt_primary)

    def test_conflicting_valid_primary_and_checkpoint_is_not_auto_selected(self):
        store = self.ready_store("conflict")
        store.seal_checkpoint("auto", self.runtime("conflict", "turn-1", 0))
        conflicting = build_snapshot(
            valid_task_payload(active_goal="contradiction"),
            self.runtime("conflict", "turn-1", 0),
            revision=1,
            created_at="2026-07-09T00:00:00Z",
            updated_at="2026-07-09T00:00:00Z",
        )
        store.primary_path.write_bytes(canonical_json_bytes(conflicting))

        with self.assertRaises(IntegrityError):
            store.load_recovery_pair()

    def test_primary_newer_than_latest_checkpoint_is_stale_not_ready(self):
        store = self.ready_store("stale-checkpoint")
        store.seal_checkpoint(
            "auto", self.runtime("stale-checkpoint", "turn-1", 0)
        )
        store.commit_snapshot(
            valid_task_payload(active_goal="newer primary"),
            self.runtime("stale-checkpoint", "turn-2", 1),
            1,
        )

        pair = store.load_recovery_pair()

        self.assertEqual(pair.status, RecoveryStatus.STALE)
        self.assertIn("older", pair.reason)

    def test_empty_filesystem_has_deterministic_incomplete_status(self):
        pair = self.new_store("empty").load_recovery_pair()

        self.assertEqual(pair.status, RecoveryStatus.INCOMPLETE)
        self.assertEqual(pair.reason, "no primary or checkpoint generation exists")

    def test_malformed_content_is_reported_without_raw_json_error(self):
        store = self.new_store("malformed")
        store.primary_path.write_text("{", encoding="utf-8")

        with self.assertRaises(IntegrityError) as raised:
            store.load_primary()
        self.assertNotIsInstance(raised.exception.__cause__, json.JSONDecodeError)
        self.assertEqual(store.load_recovery_pair().status, RecoveryStatus.CORRUPT)

    def test_read_rejects_file_swapped_between_lstat_and_open(self):
        store = self.ready_store("read-swap")
        replacement = store.session_dir / "replacement.json"
        replacement.write_bytes(store.primary_path.read_bytes())
        os.chmod(replacement, 0o600)
        displaced = store.session_dir / "displaced.json"
        real_open = os.open
        swapped = False

        def swapping_open(
            path: object, flags: int, mode: int = 0o777, *, dir_fd: int | None = None
        ) -> int:
            nonlocal swapped
            if Path(path) == store.primary_path and not swapped:
                swapped = True
                os.replace(store.primary_path, displaced)
                os.replace(replacement, store.primary_path)
            if dir_fd is None:
                return real_open(path, flags, mode)
            return real_open(path, flags, mode, dir_fd=dir_fd)

        with mock.patch.object(codex_context_store.os, "open", side_effect=swapping_open):
            with self.assertRaises(IntegrityError):
                codex_context_store._read_json(store.primary_path, "swapped primary")

        self.assertTrue(swapped)

    def test_retention_prunes_sessions_older_than_thirty_days(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        old = self.ready_store("old")
        recent = self.ready_store("recent")
        self.age_session(old, now - timedelta(days=31))
        self.age_session(recent, now - timedelta(days=29))

        result = prune_state_root(self.root, "active", self.policy(), now)

        self.assertFalse(old.primary_path.exists())
        self.assertTrue(recent.primary_path.exists())
        self.assertEqual(result.deleted_sessions, 1)

    def test_retention_prunes_oldest_inactive_sessions_to_limit(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        stores = [self.ready_store(f"session-{index}") for index in range(4)]
        for index, store in enumerate(stores):
            self.age_session(store, now - timedelta(days=4 - index))

        prune_state_root(
            self.root,
            "active",
            self.policy(inactive_days=365, max_inactive_sessions=2),
            now,
        )

        self.assertFalse(stores[0].primary_path.exists())
        self.assertFalse(stores[1].primary_path.exists())
        self.assertTrue(stores[2].primary_path.exists())
        self.assertTrue(stores[3].primary_path.exists())

    def test_retention_prunes_by_small_byte_limit_without_allocating_fifty_mib(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        old = self.ready_store("byte-old")
        new = self.ready_store("byte-new")
        self.age_session(old, now - timedelta(days=2))
        self.age_session(new, now - timedelta(days=1))
        one_size = sum(
            path.stat(follow_symlinks=False).st_size
            for path in (new.session_dir, new.primary_path, new.lock_path)
        )

        result = prune_state_root(
            self.root,
            "active",
            self.policy(inactive_days=365, max_total_bytes=one_size + 8),
            now,
        )

        self.assertFalse(old.primary_path.exists())
        self.assertTrue(new.primary_path.exists())
        self.assertLessEqual(result.remaining_bytes, one_size + 8)

    def test_retention_never_deletes_active_session(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        active = self.ready_store("active")
        inactive = self.ready_store("inactive")
        self.age_session(active, now - timedelta(days=100))
        self.age_session(inactive, now - timedelta(days=99))

        result = prune_state_root(
            self.root,
            "active",
            self.policy(inactive_days=1, max_inactive_sessions=1),
            now,
        )

        self.assertTrue(active.primary_path.exists())
        self.assertFalse(inactive.primary_path.exists())
        self.assertTrue(result.skipped_active_session)

    def test_cleanup_runs_once_per_cadence_and_metadata_is_bounded(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        first = self.ready_store("first-old")
        self.age_session(first, now - timedelta(days=31))
        prune_state_root(self.root, "active", self.policy(), now)
        second = self.ready_store("second-old")
        self.age_session(second, now - timedelta(days=31))

        result = prune_state_root(self.root, "active", self.policy(), now)

        self.assertEqual(result.deleted_sessions, 0)
        self.assertTrue(second.primary_path.exists())
        metadata = self.root / "cleanup.meta.json"
        self.assertLess(metadata.stat().st_size, 4096)
        self.assertNotIn("second-old", metadata.read_text(encoding="utf-8"))

    def test_cleanup_removes_only_exact_abandoned_metadata_temps(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        prune_state_root(self.root, "active", self.policy(), now)
        abandoned = self.root / (".cleanup.meta.json." + "a" * 32 + ".tmp")
        abandoned.write_text("partial", encoding="utf-8")
        os.chmod(abandoned, 0o600)
        unrelated = self.root / ".cleanup.meta.json.not-owned.tmp"
        unrelated.write_text("keep", encoding="utf-8")

        prune_state_root(self.root, "active", self.policy(), now + timedelta(days=1))

        self.assertFalse(abandoned.exists())
        self.assertTrue(unrelated.exists())

    def test_cleanup_removes_owned_root_temp_even_when_cadence_skips(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        prune_state_root(self.root, "active", self.policy(), now)
        abandoned = self.root / (".cleanup.meta.json." + "b" * 32 + ".tmp")
        abandoned.write_bytes(b"x" * 512)
        os.chmod(abandoned, 0o600)
        unrelated = self.root / ".cleanup.meta.json.not-owned.tmp"
        unrelated.write_bytes(b"keep")

        result = prune_state_root(
            self.root,
            "active",
            self.policy(max_total_bytes=1),
            now,
        )

        self.assertFalse(abandoned.exists())
        self.assertTrue(unrelated.exists())
        self.assertEqual(result.deleted_files, 1)
        self.assertEqual(result.deleted_bytes, 512)
        self.assertEqual(result.remaining_bytes, 0)

    def test_cleanup_sweeps_active_session_temp_before_cadence_return(self):
        now = datetime.now(timezone.utc)
        active = self.ready_store("active-temp-cadence")
        prune_state_root(self.root, active.session_id, self.policy(), now)
        temp_path = active.session_dir / (".primary.json." + "c" * 32 + ".tmp")
        temp_path.write_bytes(b"active-temp")
        os.chmod(temp_path, 0o600)

        result = prune_state_root(self.root, active.session_id, self.policy(), now)

        self.assertFalse(temp_path.exists())
        self.assertTrue(active.session_dir.exists())
        self.assertIsNotNone(active.load_primary())
        self.assertEqual(result.deleted_files, 1)
        self.assertEqual(result.deleted_bytes, len(b"active-temp"))
        expected_bytes = sum(
            path.stat(follow_symlinks=False).st_size
            for path in (active.session_dir, active.primary_path, active.lock_path)
        )
        self.assertEqual(result.remaining_bytes, expected_bytes)

    def test_temp_bytes_are_swept_before_retention_byte_selection(self):
        now = datetime.now(timezone.utc)
        store = self.ready_store("temp-byte-selection")
        managed_bytes = sum(
            path.stat(follow_symlinks=False).st_size
            for path in (store.session_dir, store.primary_path, store.lock_path)
        )
        temp_path = store.session_dir / (".primary.json." + "d" * 32 + ".tmp")
        temp_path.write_bytes(b"x" * 8192)
        os.chmod(temp_path, 0o600)
        byte_limit = managed_bytes + 1024

        result = prune_state_root(
            self.root,
            "different-active-session",
            self.policy(inactive_days=365, max_total_bytes=byte_limit),
            now,
        )

        self.assertFalse(temp_path.exists())
        self.assertTrue(store.primary_path.exists())
        self.assertLessEqual(result.remaining_bytes, byte_limit)

    def test_corrupt_cleanup_metadata_forces_cleanup_and_canonical_rewrite(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        prune_state_root(self.root, "active", self.policy(), now)
        old = self.ready_store("metadata-corrupt-old")
        self.age_session(old, now - timedelta(days=31))
        metadata = self.root / "cleanup.meta.json"
        metadata.write_text("{broken", encoding="utf-8")

        prune_state_root(self.root, "active", self.policy(), now)

        self.assertFalse(old.primary_path.exists())
        parsed = json.loads(metadata.read_text(encoding="utf-8"))
        self.assertEqual(metadata.read_bytes(), canonical_json_bytes(parsed))

    def test_cleanup_waits_for_inflight_state_operation_before_removing_session(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        store = self.ready_store("held-retention-lock")
        self.age_session(store, now - timedelta(days=31))
        state_entered = threading.Event()
        release_state = threading.Event()
        cleanup_started = threading.Event()
        failures: list[BaseException] = []
        lock_inode: list[int] = []

        def state_operation() -> None:
            try:
                with store._locked(timeout_seconds=1.0):
                    lock_inode.append(store.lock_path.stat().st_ino)
                    state_entered.set()
                    if not release_state.wait(1.0):
                        raise AssertionError("state operation release timed out")
            except BaseException as exc:
                failures.append(exc)

        def cleanup() -> None:
            cleanup_started.set()
            try:
                prune_state_root(
                    self.root,
                    "active",
                    self.policy(lock_timeout_seconds=1.0),
                    now,
                )
            except BaseException as exc:
                failures.append(exc)

        state_thread = threading.Thread(target=state_operation)
        cleanup_thread = threading.Thread(target=cleanup)
        state_thread.start()
        self.assertTrue(state_entered.wait(0.5))
        cleanup_thread.start()
        self.assertTrue(cleanup_started.wait(0.5))
        time.sleep(0.05)

        self.assertTrue(cleanup_thread.is_alive())
        self.assertEqual(store.lock_path.stat().st_ino, lock_inode[0])
        release_state.set()
        state_thread.join(1.0)
        cleanup_thread.join(1.0)

        self.assertFalse(state_thread.is_alive())
        self.assertFalse(cleanup_thread.is_alive())
        self.assertEqual(failures, [])
        self.assertFalse(store.session_dir.exists())

    def test_retention_bounds_empty_and_lock_only_session_artifacts(self):
        now = datetime(1970, 1, 2, tzinfo=timezone.utc)
        active = self.ready_store("active")
        inactive = [self.new_store(f"inactive-{index:02d}") for index in range(12)]
        for store in inactive[::2]:
            with store._locked():
                pass

        result = prune_state_root(
            self.root,
            "active",
            self.policy(inactive_days=3650, max_inactive_sessions=4),
            now,
        )

        remaining_inactive = [store for store in inactive if store.session_dir.exists()]
        remaining_locks = list(self.root.glob("inactive-*/.session.lock"))
        self.assertTrue(active.primary_path.exists())
        self.assertEqual(len(remaining_inactive), 4)
        self.assertLessEqual(len(remaining_locks), 4)
        self.assertEqual(result.remaining_sessions, 5)
        self.assertTrue(
            all(
                set(path.name for path in store.session_dir.iterdir())
                <= {codex_context_store.SESSION_LOCK_NAME}
                for store in remaining_inactive
            )
        )

    def test_retention_sweeps_exact_temp_and_accounts_for_session_lock(self):
        now = datetime(1970, 1, 2, tzinfo=timezone.utc)
        store = self.new_store("artifact-accounting")
        with store._locked():
            pass
        store.lock_path.write_bytes(b"x")
        temp_path = store.session_dir / (".primary.json." + "a" * 32 + ".tmp")
        temp_path.write_bytes(b"temp")
        os.chmod(temp_path, 0o600)

        result = prune_state_root(
            self.root,
            "active",
            self.policy(inactive_days=3650),
            now,
        )

        self.assertFalse(temp_path.exists())
        self.assertEqual(result.deleted_files, 1)
        self.assertEqual(result.deleted_bytes, 4)
        self.assertEqual(result.remaining_sessions, 1)
        self.assertEqual(
            result.remaining_bytes,
            store.session_dir.stat(follow_symlinks=False).st_size + 1,
        )

    def test_retention_accounts_for_session_directory_bytes(self):
        now = datetime.now(timezone.utc)
        store = self.ready_store("directory-accounting")
        expected_bytes = sum(
            path.stat(follow_symlinks=False).st_size
            for path in (store.session_dir, store.primary_path, store.lock_path)
        )

        result = prune_state_root(self.root, store.session_id, self.policy(), now)

        self.assertEqual(result.remaining_bytes, expected_bytes)

    def test_retention_accounts_for_nested_content_without_following_symlinks(self):
        now = datetime.now(timezone.utc)
        store = self.ready_store("nested-accounting")
        nested = store.session_dir / "operator-data"
        nested.mkdir()
        leaf = nested / "notes.bin"
        leaf.write_bytes(b"nested-content")
        external = Path(self._temporary_directory.name) / "external-large.bin"
        external.write_bytes(b"x" * 8192)
        link = nested / "external-link"
        try:
            link.symlink_to(external)
        except OSError as exc:
            self.skipTest(f"symlink creation unavailable: {exc}")
        expected_bytes = sum(
            path.stat(follow_symlinks=False).st_size
            for path in (
                store.session_dir,
                store.primary_path,
                store.lock_path,
                nested,
                leaf,
                link,
            )
        )

        result = prune_state_root(self.root, store.session_id, self.policy(), now)

        self.assertEqual(result.remaining_bytes, expected_bytes)
        self.assertLess(result.remaining_bytes, expected_bytes + external.stat().st_size)

    def test_recent_unrelated_bytes_fail_without_rewriting_cleanup_metadata(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        metadata_path = self.root / codex_context_store.CLEANUP_METADATA_NAME
        prune_state_root(self.root, "active", self.policy(), now - timedelta(days=2))
        metadata_before = metadata_path.read_bytes()
        store = self.ready_store("recent-unrelated-bytes")
        self.age_session(store, now - timedelta(days=1))
        unrelated = store.session_dir / "operator-cache.bin"
        unrelated.write_bytes(b"x" * 8192)
        owned_accounting = sum(
            path.stat(follow_symlinks=False).st_size
            for path in (store.session_dir, store.primary_path, store.lock_path)
        )
        primary_before = store.primary_path.read_bytes()

        with self.assertRaisesRegex(StoreError, "unrelated"):
            prune_state_root(
                self.root,
                "active",
                self.policy(
                    inactive_days=365,
                    max_total_bytes=owned_accounting + 1,
                ),
                now,
            )

        self.assertEqual(store.primary_path.read_bytes(), primary_before)
        self.assertEqual(unrelated.read_bytes(), b"x" * 8192)
        self.assertEqual(metadata_path.read_bytes(), metadata_before)

    def test_unrelated_selected_candidate_blocks_all_payload_deletion(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        safe = self.ready_store("count-safe-oldest")
        blocked = self.ready_store("count-blocked-middle")
        keeper = self.ready_store("count-keeper-newest")
        for days, store in ((3, safe), (2, blocked), (1, keeper)):
            self.age_session(store, now - timedelta(days=days))
        unrelated = blocked.session_dir / "operator-notes.txt"
        unrelated.write_bytes(b"keep")
        payloads_before = {
            store.session_id: store.primary_path.read_bytes()
            for store in (safe, blocked, keeper)
        }

        with self.assertRaisesRegex(StoreError, "unrelated"):
            prune_state_root(
                self.root,
                "active",
                self.policy(inactive_days=365, max_inactive_sessions=1),
                now,
            )

        for store in (safe, blocked, keeper):
            self.assertEqual(
                store.primary_path.read_bytes(), payloads_before[store.session_id]
            )
        self.assertEqual(unrelated.read_bytes(), b"keep")
        self.assertFalse((self.root / codex_context_store.CLEANUP_METADATA_NAME).exists())

    def test_active_unrelated_bytes_fail_after_safe_inactive_deletion(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        active = self.ready_store("active-unrelated-bytes")
        inactive = self.ready_store("safe-inactive-bytes")
        self.age_session(active, now - timedelta(days=1))
        self.age_session(inactive, now - timedelta(days=2))
        unrelated = active.session_dir / "operator-cache.bin"
        unrelated.write_bytes(b"y" * 8192)
        active_bytes = sum(
            path.stat(follow_symlinks=False).st_size
            for path in (
                active.session_dir,
                active.primary_path,
                active.lock_path,
                unrelated,
            )
        )
        active_primary_before = active.primary_path.read_bytes()

        with self.assertRaisesRegex(StoreError, "active session"):
            prune_state_root(
                self.root,
                active.session_id,
                self.policy(inactive_days=365, max_total_bytes=active_bytes - 1),
                now,
            )

        self.assertFalse(inactive.session_dir.exists())
        self.assertEqual(active.primary_path.read_bytes(), active_primary_before)
        self.assertEqual(unrelated.read_bytes(), b"y" * 8192)
        self.assertFalse((self.root / codex_context_store.CLEANUP_METADATA_NAME).exists())

    def test_old_session_with_unrelated_file_fails_without_deleting_or_metadata(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        store = self.ready_store("old-with-unrelated")
        self.age_session(store, now - timedelta(days=31))
        primary_bytes = store.primary_path.read_bytes()
        unrelated = store.session_dir / "operator-notes.txt"
        unrelated.write_bytes(b"keep")

        with self.assertRaisesRegex(StoreError, "unrelated"):
            prune_state_root(self.root, "active", self.policy(), now)

        self.assertEqual(unrelated.read_bytes(), b"keep")
        self.assertEqual(store.primary_path.read_bytes(), primary_bytes)
        self.assertFalse((self.root / codex_context_store.CLEANUP_METADATA_NAME).exists())

    def test_final_rescan_rejects_unsatisfied_age_limit(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        store = self.ready_store("old-not-removed")
        self.age_session(store, now - timedelta(days=31))

        with mock.patch.object(
            codex_context_store, "_delete_record", return_value=(0, 0, False)
        ):
            with self.assertRaisesRegex(StoreError, "age limit"):
                prune_state_root(self.root, "active", self.policy(), now)

        self.assertTrue(store.primary_path.exists())
        self.assertFalse((self.root / codex_context_store.CLEANUP_METADATA_NAME).exists())

    def test_future_cleanup_metadata_cannot_disable_retention(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        prune_state_root(self.root, "active", self.policy(), now + timedelta(days=1))
        old = self.ready_store("clock-rollback-old")
        self.age_session(old, now - timedelta(days=31))

        prune_state_root(self.root, "active", self.policy(), now)

        self.assertFalse(old.primary_path.exists())

    def test_cleanup_only_removes_exact_owned_patterns(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        store = self.ready_store("owned")
        self.age_session(store, now - timedelta(days=31))
        unrelated = store.session_dir / "primary.json.backup"
        unrelated.write_text("keep", encoding="utf-8")
        root_unrelated = self.root / "notes.txt"
        root_unrelated.write_text("keep", encoding="utf-8")

        with self.assertRaisesRegex(StoreError, "unrelated"):
            prune_state_root(self.root, "active", self.policy(), now)

        self.assertTrue(store.primary_path.exists())
        self.assertTrue(unrelated.exists())
        self.assertTrue(root_unrelated.exists())

    def test_reserved_session_directories_are_not_owned_or_deleted(self):
        codex_context_store._ensure_private_directory(self.root)
        reserved_paths: list[Path] = []
        for index, name in enumerate(("cleanup", "metadata", "cleanup.meta.json")):
            directory = self.root / name
            directory.mkdir(mode=0o700)
            temp_path = directory / (
                ".primary.json." + f"{index:x}" * 32 + ".tmp"
            )
            temp_path.write_bytes(b"reserved")
            os.chmod(temp_path, 0o600)
            reserved_paths.append(temp_path)

        self.assertEqual(codex_context_store._scan_session_records(self.root), [])

        for path in reserved_paths:
            self.assertEqual(path.read_bytes(), b"reserved")

    def test_cleanup_preserves_reserved_session_directories(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        codex_context_store._ensure_private_directory(self.root)
        reserved_files: list[Path] = []
        for index, name in enumerate(("cleanup", "metadata")):
            directory = self.root / name
            directory.mkdir(mode=0o700)
            temp_path = directory / (
                ".primary.json." + f"{index + 8:x}" * 32 + ".tmp"
            )
            temp_path.write_bytes(b"reserved")
            os.chmod(temp_path, 0o600)
            reserved_files.append(temp_path)

        prune_state_root(self.root, "active", self.policy(), now)

        for path in reserved_files:
            self.assertEqual(path.read_bytes(), b"reserved")

    def test_invalid_policy_and_environment_values_fail_visibly(self):
        defaults = RetentionPolicy()
        self.assertEqual(defaults.inactive_days, 30)
        self.assertEqual(defaults.max_inactive_sessions, 200)
        self.assertEqual(defaults.max_total_bytes, 50 * 1024 * 1024)
        self.assertEqual(defaults.max_full_generations, 3)
        self.assertEqual(defaults.cleanup_interval_seconds, 24 * 60 * 60)
        self.assertEqual(defaults.lock_timeout_seconds, 2.0)

        for values in (
            {"inactive_days": 0},
            {"max_inactive_sessions": 0},
            {"max_total_bytes": 0},
            {"max_full_generations": 2},
            {"max_full_generations": 3.0},
            {"cleanup_interval_seconds": 0},
            {"lock_timeout_seconds": 0},
        ):
            with self.subTest(values=values):
                with self.assertRaises(StoreError):
                    self.policy(**values)

        with self.assertRaises(StoreError):
            RetentionPolicy.from_environment(
                {"CODEX_CONTEXT_STORE_MAX_TOTAL_BYTES": "unlimited"}
            )

class LifecycleTests(unittest.TestCase):
    STOP_REASON = (
        "Context snapshot is not READY for this turn. Run the exact state-update "
        "command from the latest continuity context before finishing."
    )

    def setUp(self) -> None:
        self._temporary_directory = tempfile.TemporaryDirectory()
        self.temp = Path(self._temporary_directory.name)
        self.root = self.temp / "state"
        self.project = self.temp / "project"
        self.project.mkdir()
        self.transcript = self.temp / "transcript.jsonl"
        self.transcript.write_text("{}\n", encoding="utf-8")
        self.session_id = "lifecycle-session"
        self.script = MANAGED_HOOKS / "codex_context_continuity.py"
        self.env = {
            **os.environ,
            "ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR": str(self.root),
        }
        self.run_git("init")
        self.run_git("config", "user.email", "tests@example.invalid")
        self.run_git("config", "user.name", "Context Tests")
        (self.project / "tracked.txt").write_text("initial\n", encoding="utf-8")
        self.run_git("add", "tracked.txt")
        self.run_git("commit", "-m", "initial")

    def tearDown(self) -> None:
        self._temporary_directory.cleanup()

    def run_git(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", "-C", str(self.project), *arguments],
            check=True,
            capture_output=True,
            text=True,
        )

    def store(self, session_id: str | None = None) -> SessionStore:
        return SessionStore(self.root, session_id or self.session_id)

    def hook_payload(
        self,
        event: str,
        turn_id: str,
        **overrides: object,
    ) -> dict[str, object]:
        payload: dict[str, object] = {
            "hook_event_name": event,
            "session_id": self.session_id,
            "turn_id": turn_id,
            "cwd": str(self.project),
            "transcript_path": str(self.transcript),
            "permission_mode": "default",
            "last_assistant_message": "bounded lifecycle test",
        }
        payload.update(overrides)
        return payload

    def invoke_hook_raw(
        self,
        stdin: str,
        *,
        event: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        command = [sys.executable, str(self.script)]
        if event is not None:
            command.extend(["--event", event])
        return subprocess.run(
            command,
            input=stdin,
            capture_output=True,
            text=True,
            env=self.env,
        )

    def invoke_hook_result(
        self,
        event: str,
        turn_id: str,
        **overrides: object,
    ) -> subprocess.CompletedProcess[str]:
        payload = self.hook_payload(event, turn_id, **overrides)
        return self.invoke_hook_raw(json.dumps(payload), event=event)

    def invoke_hook(
        self,
        event: str,
        turn_id: str,
        **overrides: object,
    ) -> dict[str, object]:
        result = self.invoke_hook_result(event, turn_id, **overrides)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout or "{}")

    def submit_prompt(
        self,
        prompt: str,
        turn_id: str,
        **overrides: object,
    ) -> dict[str, object]:
        return self.invoke_hook(
            "UserPromptSubmit",
            turn_id,
            user_prompt=prompt,
            **overrides,
        )

    def update_payload(
        self,
        turn_id: str,
        task: object | None = None,
        *,
        session_id: str | None = None,
        base_revision: int | None = None,
        **extra: object,
    ) -> dict[str, object]:
        pending = self.store().load_pending_turn()
        observed_revision = 0 if pending is None else pending["base_revision"]
        payload: dict[str, object] = {
            "session_id": session_id or self.session_id,
            "turn_id": turn_id,
            "base_revision": (
                observed_revision if base_revision is None else base_revision
            ),
            "task": valid_task_payload() if task is None else task,
        }
        payload.update(extra)
        return payload

    def invoke_state_update_payload(
        self, payload: object
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(self.script),
                "state-update",
                "--payload",
                json.dumps(payload),
            ],
            capture_output=True,
            text=True,
            env=self.env,
        )

    def invoke_state_update(
        self,
        turn_id: str,
        task: object | None = None,
        **kwargs: object,
    ) -> subprocess.CompletedProcess[str]:
        return self.invoke_state_update_payload(
            self.update_payload(turn_id, task, **kwargs)
        )

    def write_full_state(
        self,
        turn_id: str,
        *,
        goal: str = "Implement lifecycle",
    ) -> dict[str, object]:
        task = valid_task_payload(
            active_goal=goal,
            scope_boundary="Task 3 lifecycle only",
            current_phase="implementation",
            pending_items=["verify lifecycle"],
            next_action="run lifecycle tests",
        )
        result = self.invoke_state_update(turn_id, task)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def recover(
        self,
        turn_id: str,
        *,
        session_id: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(self.script),
                "recover",
                "--session-id",
                session_id or self.session_id,
                "--turn-id",
                turn_id,
            ],
            capture_output=True,
            text=True,
            env=self.env,
        )

    def assert_status(self, expected: str, turn_id: str) -> dict[str, object]:
        result = self.recover(turn_id)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], expected)
        return payload

    def test_new_prompt_invalidates_ready_state_by_turn_id(self):
        self.submit_prompt("same prompt", "turn-1")
        self.write_full_state("turn-1")
        self.assert_status("READY", "turn-1")

        self.submit_prompt("same prompt", "turn-2")

        self.assert_status("STALE", "turn-2")

    def test_empty_state_update_cannot_rebind_old_fields(self):
        self.submit_prompt("goal A", "turn-1")
        self.write_full_state("turn-1", goal="goal A")
        self.submit_prompt("goal B", "turn-2")

        result = self.invoke_state_update("turn-2", {})

        self.assertNotEqual(result.returncode, 0)
        self.assert_status("STALE", "turn-2")
        self.assertEqual(self.store().load_primary()["active_goal"], "goal A")

    def test_stop_continues_turn_until_current_snapshot_is_ready(self):
        self.submit_prompt("goal", "turn-1")

        before = self.invoke_hook("Stop", "turn-1")

        self.assertEqual(before, {"decision": "block", "reason": self.STOP_REASON})
        self.write_full_state("turn-1")
        self.assertEqual(self.invoke_hook("Stop", "turn-1"), {})
        self.assertEqual(self.invoke_hook("Stop", "turn-1"), {})

    def test_stop_bootstraps_missing_pending_from_current_turn_transcript(self):
        self.submit_prompt("goal", "turn-1")
        self.write_full_state("turn-1")
        self.transcript.write_text(
            json.dumps(
                {
                    "type": "response_item",
                    "payload": {
                        "role": "user",
                        "content": [
                            {"type": "input_text", "text": "turn two request"}
                        ],
                        "internal_chat_message_metadata_passthrough": {
                            "turn_id": "turn-2"
                        },
                    },
                }
            )
            + "\n",
            encoding="utf-8",
        )

        before = self.invoke_hook_result("Stop", "turn-2")

        self.assertEqual(before.returncode, 0, before.stderr)
        output = json.loads(before.stdout)
        self.assertEqual(output["decision"], "block")
        self.assertIn("state_update_command:", output["reason"])
        pending = self.store().load_pending_turn()
        self.assertEqual(pending["turn_id"], "turn-2")
        self.assertEqual(pending["base_revision"], 1)

        update = self.invoke_state_update("turn-2")
        self.assertEqual(update.returncode, 0, update.stderr)
        self.assertEqual(self.invoke_hook("Stop", "turn-2"), {})

    def test_stop_does_not_read_untrusted_transcript_path_for_bootstrap(self):
        self.submit_prompt("goal", "turn-1")
        self.write_full_state("turn-1")
        outside_transcript = self.temp / "outside-transcript.jsonl"
        outside_transcript.write_text(
            json.dumps(
                {
                    "type": "response_item",
                    "payload": {
                        "role": "user",
                        "content": [{"type": "input_text", "text": "untrusted"}],
                        "internal_chat_message_metadata_passthrough": {
                            "turn_id": "turn-2"
                        },
                    },
                }
            )
            + "\n",
            encoding="utf-8",
        )

        before = self.invoke_hook_result(
            "Stop",
            "turn-2",
            transcript_path=str(outside_transcript),
        )

        self.assertEqual(before.returncode, 0, before.stderr)
        self.assertEqual(json.loads(before.stdout), {
            "decision": "block",
            "reason": self.STOP_REASON,
        })
        self.assertEqual(self.store().load_pending_turn()["turn_id"], "turn-1")

    def test_submit_requires_exact_identity_prompt_cwd_and_transcript(self):
        cases = (
            ("missing session", {"session_id": ""}),
            ("unsafe session alias", {"session_id": "alias/session"}),
            ("missing turn", {"turn_id": ""}),
            ("missing prompt", {"user_prompt": ""}),
            ("missing cwd", {"cwd": ""}),
            ("missing transcript", {"transcript_path": ""}),
        )
        for label, overrides in cases:
            with self.subTest(label=label):
                user_prompt = overrides.get("user_prompt", "prompt")
                result = self.invoke_hook_result(
                    "UserPromptSubmit",
                    str(overrides.get("turn_id", "turn-1")),
                    user_prompt=user_prompt,
                    **{
                        key: value
                        for key, value in overrides.items()
                        if key not in {"turn_id", "user_prompt"}
                    },
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Traceback", result.stderr)

        self.assertFalse(self.root.exists())

    def test_submit_canonicalizes_cwd_without_rebinding_session_aliases(self):
        alias = self.temp / "project-alias"
        alias.symlink_to(self.project, target_is_directory=True)

        self.submit_prompt("prompt", "turn-1", cwd=str(alias))

        pending = self.store().load_pending_turn()
        self.assertEqual(pending["cwd"], str(self.project.resolve()))
        self.assertEqual(pending["session_id"], self.session_id)

    def test_pending_preview_is_bounded_and_redacts_common_secrets(self):
        secret = (
            "token=visible-token-value sk-proj-abcdefghijklmnopqrstuvwxyz123456 "
            "ghp_abcdefghijklmnopqrstuvwxyz123456 AKIAABCDEFGHIJKLMNOP "
            "-----BEGIN PRIVATE KEY-----PRIVATEKEYMATERIAL-----END PRIVATE KEY-----"
        )

        self.submit_prompt(secret + ("x" * 1000), "turn-1")

        pending = self.store().load_pending_turn()
        serialized = json.dumps(pending)
        self.assertLessEqual(len(pending["prompt_preview"]), 240)
        for leaked in (
            "visible-token-value",
            "sk-proj-abcdefghijklmnopqrstuvwxyz123456",
            "ghp_abcdefghijklmnopqrstuvwxyz123456",
            "AKIAABCDEFGHIJKLMNOP",
            "PRIVATEKEYMATERIAL",
        ):
            self.assertNotIn(leaked, serialized)
        self.assertIn("[REDACTED]", pending["prompt_preview"])

    def test_additional_context_is_bounded_and_names_exact_update_contract(self):
        output = self.submit_prompt("prompt", "turn-1")

        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertLessEqual(len(context.encode("utf-8")), 4096)
        self.assertIn("status: INCOMPLETE", context)
        self.assertIn("base_revision: 0", context)
        self.assertIn(f"session_id: {self.session_id}", context)
        self.assertIn("turn_id: turn-1", context)
        self.assertIn("state-update --payload", context)
        self.assertNotIn("status: READY", context)

    def test_state_update_rejects_stale_base_and_mismatched_identity(self):
        self.submit_prompt("prompt", "turn-1")
        original = self.store().load_primary()

        cases = (
            self.update_payload("turn-1", base_revision=1),
            self.update_payload("other-turn"),
            self.update_payload("turn-1", session_id="other-session"),
        )
        for payload in cases:
            with self.subTest(payload=payload):
                result = self.invoke_state_update_payload(payload)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual(self.store().load_primary(), original)

    def test_state_update_rejects_partial_unknown_and_oversize_json_before_mutation(self):
        self.submit_prompt("prompt", "turn-1")
        payloads = (
            self.update_payload("turn-1", {"active_goal": "partial"}),
            self.update_payload("turn-1", extra_runtime="not allowed"),
            self.update_payload(
                "turn-1",
                valid_task_payload(active_goal="x" * (MAX_SNAPSHOT_BYTES + 1)),
            ),
        )
        for payload in payloads:
            with self.subTest(keys=list(payload)):
                result = self.invoke_state_update_payload(payload)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(self.store().load_primary())

    def test_state_update_argument_is_json_only_and_never_shell_evaluated(self):
        self.submit_prompt("prompt", "turn-1")
        marker = self.temp / "must-not-exist"
        payload = self.update_payload("turn-1")
        injected = json.dumps(payload) + f"; touch {marker}"

        result = subprocess.run(
            [sys.executable, str(self.script), "state-update", "--payload", injected],
            capture_output=True,
            text=True,
            env=self.env,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(marker.exists())
        self.assertIsNone(self.store().load_primary())

    def test_hook_stdin_rejects_empty_malformed_non_object_and_extra_json(self):
        for stdin in ("", "{broken", "[]", "{} {}"):
            with self.subTest(stdin=stdin):
                result = self.invoke_hook_raw(stdin, event="UserPromptSubmit")
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Traceback", result.stderr)
        self.assertFalse(self.root.exists())

    def test_repeated_timestamps_do_not_make_new_turn_ready(self):
        fixed = "2026-07-09T00:00:00Z"
        with mock.patch.object(codex_context_store, "_utc_now_text", return_value=fixed):
            self.submit_prompt("same", "turn-1")
            self.write_full_state("turn-1")
            self.submit_prompt("same", "turn-2")

        self.assert_status("STALE", "turn-2")

    def test_git_drift_blocks_stop_without_mutating_snapshot(self):
        self.submit_prompt("prompt", "turn-1")
        snapshot = self.write_full_state("turn-1")
        (self.project / "tracked.txt").write_text("changed\n", encoding="utf-8")
        self.run_git("add", "tracked.txt")
        self.run_git("commit", "-m", "drift")

        output = self.invoke_hook("Stop", "turn-1")

        self.assertEqual(output, {"decision": "block", "reason": self.STOP_REASON})
        self.assertEqual(self.store().load_primary(), snapshot["snapshot"])
        self.assert_status("STALE", "turn-1")

    def test_non_git_workspace_uses_explicit_sentinel(self):
        nongit = self.temp / "not-git"
        nongit.mkdir()
        self.submit_prompt("prompt", "turn-1", cwd=str(nongit))

        snapshot = self.write_full_state("turn-1")

        self.assertEqual(snapshot["snapshot"]["git_head"], "not-a-git-repository")
        self.assert_status("READY", "turn-1")

    def test_git_timeout_uses_exact_five_seconds_and_is_visible(self):
        with mock.patch.object(
            codex_context_continuity.subprocess,
            "run",
            side_effect=subprocess.TimeoutExpired(["git"], 5.0),
        ) as run:
            with self.assertRaises(codex_context_continuity.GitStateError):
                codex_context_continuity.git_head_for_cwd(self.project)

        self.assertEqual(run.call_args.kwargs["timeout"], 5.0)

    def test_corrupted_pending_never_promotes_or_leaks_traceback(self):
        self.submit_prompt("prompt", "turn-1")
        store = self.store()
        store.pending_turn_path.write_bytes(b"{broken")

        update = self.invoke_state_update_payload(
            {
                "session_id": self.session_id,
                "turn_id": "turn-1",
                "base_revision": 0,
                "task": valid_task_payload(),
            }
        )
        stop = self.invoke_hook("Stop", "turn-1")

        self.assertNotEqual(update.returncode, 0)
        self.assertNotIn("Traceback", update.stderr)
        self.assertEqual(stop, {"decision": "block", "reason": self.STOP_REASON})
        self.assertIsNone(store.load_primary())

    def test_schema1_partial_stateupdate_event_cannot_manufacture_ready(self):
        self.submit_prompt("prompt", "turn-1")
        legacy = self.invoke_hook(
            "StateUpdate",
            "turn-1",
            state={"active_goal": "legacy partial goal"},
        )

        self.assertEqual(legacy, {})
        self.assertEqual(
            self.invoke_hook("Stop", "turn-1"),
            {"decision": "block", "reason": self.STOP_REASON},
        )
        self.assertIsNone(self.store().load_primary())

    def test_recover_is_bounded_evidence_only_and_cannot_promote(self):
        self.submit_prompt("prompt", "turn-1")

        result = self.recover("turn-1")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLessEqual(len(result.stdout.encode("utf-8")), 4096)
        packet = json.loads(result.stdout)
        self.assertEqual(packet["status"], "INCOMPLETE")
        self.assertFalse(packet["can_promote"])
        self.assertTrue(packet["evidence"]["transcript_ref_present"])
        self.assertIsNone(self.store().load_primary())

    def test_recover_rejects_mismatched_session_or_turn(self):
        self.submit_prompt("prompt", "turn-1")

        wrong_turn = self.recover("turn-2")
        wrong_session = self.recover("turn-1", session_id="other-session")

        self.assertNotEqual(wrong_turn.returncode, 0)
        self.assertNotEqual(wrong_session.returncode, 0)
        self.assertNotIn(str(self.transcript), wrong_turn.stderr + wrong_session.stderr)


if __name__ == "__main__":
    unittest.main()
