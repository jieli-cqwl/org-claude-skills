#!/usr/bin/env python3
"""Rollback fixture checks for standard-chain readiness validation."""

from __future__ import annotations

from manage_artifact_registry import get_active_revision


def assert_fixture_rollback_contract(payload: dict, expect_freeze_quarantine: bool) -> None:
    delivery_state = payload.get("delivery_state", {})
    artifact_registry = payload.get("artifact_registry", {})
    rollback_mode = payload.get("rollback_mode", "NONE")
    legacy_runtime_files = payload.get("legacy_runtime_files", [])
    if legacy_runtime_files:
        raise ValueError("mixed mode detected")
    if rollback_mode == "IN_PLACE_LEGACY":
        raise ValueError("illegal rollback mode")
    if payload.get("validator_green") is not True:
        raise ValueError("readiness gate missing validator green")
    if payload.get("replay_green") is not True:
        raise ValueError("readiness gate missing replay green")
    if not expect_freeze_quarantine:
        return
    if delivery_state.get("control_action") != "FREEZE":
        raise ValueError("failed cutover must freeze the phase")
    if delivery_state.get("status") not in {"BLOCKED", "FROZEN"}:
        raise ValueError("failed cutover must keep phase blocked or frozen")
    quarantined = [
        entry
        for entry in get_active_revision(artifact_registry).get("entries", [])
        if entry.get("lifecycle_state") == "QUARANTINED"
    ]
    if not quarantined:
        raise ValueError("failed cutover must quarantine unfinished artifacts")
    if any(entry.get("active_for_consumption") for entry in quarantined):
        raise ValueError("quarantined artifacts must not stay active")
    if rollback_mode != "FREEZE_QUARANTINE":
        raise ValueError("failed cutover must use freeze + quarantine rollback")
