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
