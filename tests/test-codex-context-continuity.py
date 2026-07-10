#!/usr/bin/env python3
"""Schema-2 context snapshot contract tests."""

from __future__ import annotations

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

        self.assertEqual(evaluate_snapshot(snapshot, valid_runtime())[0], RecoveryStatus.READY)
        self.assertEqual(
            evaluate_snapshot(snapshot, valid_runtime(turn_id="turn-2"))[0],
            RecoveryStatus.STALE,
        )
        self.assertEqual(evaluate_snapshot({}, valid_runtime())[0], RecoveryStatus.CORRUPT)

    def test_token_estimation_and_bounded_text_honor_both_limits(self):
        self.assertEqual(estimate_tokens("abcdef"), 2)
        self.assertEqual(estimate_tokens("\u4f60a\u597d"), 3)

        bounded, truncated = bounded_text("abc\u4f60def", byte_limit=6, token_limit=3)

        self.assertTrue(truncated)
        self.assertLessEqual(len(bounded.encode("utf-8")), 6)
        self.assertLessEqual(estimate_tokens(bounded), 3)


if __name__ == "__main__":
    unittest.main()
