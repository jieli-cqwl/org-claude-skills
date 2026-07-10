#!/usr/bin/env python3
"""Schema-2 context snapshot contract tests."""

from __future__ import annotations

import hashlib
import json
import sys
import unittest
from pathlib import Path


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


if __name__ == "__main__":
    unittest.main()
