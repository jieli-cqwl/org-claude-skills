#!/usr/bin/env python3
"""Schema-2 context snapshot contract tests."""

from __future__ import annotations

import hashlib
import json
import os
import stat
import sys
import tempfile
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
        for session_id in ("../escape", "a/b", ".", "..", ".cleanup", "cleanup.meta.json"):
            with self.subTest(session_id=session_id):
                with self.assertRaises(StoreError):
                    SessionStore(self.root, session_id)

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
        one_size = new.primary_path.stat().st_size

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

    def test_retention_does_not_unlink_a_held_session_lock(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        store = self.ready_store("held-retention-lock")
        self.age_session(store, now - timedelta(days=31))
        lock_inode = store.lock_path.stat().st_ino

        with store._locked():
            with self.assertRaises(LockTimeout):
                prune_state_root(
                    self.root,
                    "active",
                    self.policy(lock_timeout_seconds=0.05),
                    now,
                )

        self.assertTrue(store.primary_path.exists())
        self.assertEqual(store.lock_path.stat().st_ino, lock_inode)

    def test_retention_leaves_only_fixed_lock_overhead_for_pruned_session(self):
        now = datetime(2026, 7, 9, tzinfo=timezone.utc)
        store = self.ready_store("pruned-lock-overhead")
        self.age_session(store, now - timedelta(days=31))
        lock_inode = store.lock_path.stat().st_ino

        result = prune_state_root(self.root, "active", self.policy(), now)

        self.assertEqual([path.name for path in store.session_dir.iterdir()], [".session.lock"])
        self.assertEqual(store.lock_path.stat().st_ino, lock_inode)
        self.assertLessEqual(store.lock_path.stat().st_size, 1)
        self.assertEqual(result.remaining_sessions, 0)
        self.assertEqual(result.remaining_bytes, 0)

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

        prune_state_root(self.root, "active", self.policy(), now)

        self.assertFalse(store.primary_path.exists())
        self.assertTrue(unrelated.exists())
        self.assertTrue(root_unrelated.exists())

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


if __name__ == "__main__":
    unittest.main()
