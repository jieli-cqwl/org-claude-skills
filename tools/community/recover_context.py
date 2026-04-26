#!/usr/bin/env python3
"""Recover active context handoff state from scope registry and root worklog."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from runtime_yaml import load_yaml
from validate_context_contract import CANONICAL_REF, ACTIVE_STATUSES, parse_latest_worklog, strip_anchor


def emit(payload: dict[str, Any], code: int = 0) -> int:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return code


def registry_status(entry: dict[str, Any]) -> str:
    return str(entry.get("management_status") or entry.get("status") or "")


def load_registry(root: Path) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    path = root / "contracts" / "active-doc-scope.yaml"
    if not path.is_file():
        return None, {
            "decision": "block",
            "reason": "scope_registry_missing",
            "path": path.as_posix(),
            "expected": "contracts/active-doc-scope.yaml",
        }
    try:
        return load_yaml(path), None
    except ValueError as exc:
        return None, {
            "decision": "block",
            "reason": "scope_registry_unreadable",
            "path": path.as_posix(),
            "expected": "valid scope registry YAML",
            "actual": str(exc),
        }


def basename(path: str) -> str:
    return Path(path).name


def worklog_path(root: Path, entry: dict[str, Any]) -> Path:
    feature_path = str(entry.get("feature_path") or "")
    entry_ref = str(entry.get("entry_ref") or "worklog.md")
    if registry_status(entry) == "legacy" and entry.get("archive_ref"):
        return root / str(entry["archive_ref"]) / entry_ref
    return root / feature_path / entry_ref


def candidate(root: Path, entry: dict[str, Any], archived: bool = False) -> dict[str, Any]:
    path = worklog_path(root, entry)
    latest_at = ""
    record: dict[str, str] = {}
    if path.is_file():
        latest_at, record = parse_latest_worklog(path, [])
    payload: dict[str, Any] = {
        "feature_path": entry.get("feature_path"),
        "mode": entry.get("mode"),
        "layout": entry.get("layout"),
        "context_owner": entry.get("context_owner") or entry.get("owner"),
        "latest_worklog_at": latest_at,
        "handoff_status": record.get("handoff_status"),
        "state_ref": record.get("state_ref"),
        "next_ref": record.get("next_ref"),
    }
    if archived:
        payload["archive_ref"] = entry.get("archive_ref")
        payload["archived_at"] = str(entry.get("archived_at") or "")
        payload["archived_entry_ref"] = f"{entry.get('archive_ref')}/{entry.get('entry_ref', 'worklog.md')}"
    return payload


def sort_candidates(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(items, key=lambda row: (str(row.get("latest_worklog_at") or ""), str(row.get("feature_path") or "")), reverse=True)


def exact_matches(entries: list[dict[str, Any]], query: str) -> list[dict[str, Any]]:
    return [entry for entry in entries if str(entry.get("feature_path") or "") == query or basename(str(entry.get("feature_path") or "")) == query]


def fuzzy_matches(entries: list[dict[str, Any]], query: str) -> list[dict[str, Any]]:
    return [entry for entry in entries if query in str(entry.get("feature_path") or "")]


def ref_reachable(root: Path, entry: dict[str, Any], ref: str) -> tuple[bool, str]:
    feature_root = root / str(entry.get("feature_path") or "")
    if registry_status(entry) == "legacy" and entry.get("archive_ref"):
        feature_root = root / str(entry["archive_ref"])
    if entry.get("mode") == "standard-chain":
        match = CANONICAL_REF.match(ref)
        if not match:
            return False, "canonical_ref_invalid"
        registry_path = feature_root / match.group("registry")
        return registry_path.is_file(), "state_ref_unreachable"
    ref_path, _anchor = strip_anchor(ref)
    path = feature_root / ref_path
    return path.is_file(), "state_ref_unreachable"


def recovery_payload(root: Path, entry: dict[str, Any], archived: bool = False) -> tuple[dict[str, Any], int]:
    path = worklog_path(root, entry)
    if not path.is_file():
        return {
            "decision": "block",
            "reason": "entry_ref_unreachable",
            "path": path.as_posix(),
            "expected": "reachable worklog.md",
        }, 1
    _latest_at, record = parse_latest_worklog(path, [])
    state_ref = str(record.get("state_ref") or "")
    next_ref = str(record.get("next_ref") or "")
    state_ok, state_reason = ref_reachable(root, entry, state_ref)
    if not state_ok:
        return {
            "decision": "block",
            "reason": state_reason,
            "path": path.relative_to(root).as_posix(),
            "expected": "reachable state_ref",
            "actual": state_ref,
        }, 1
    next_ok, next_reason = ref_reachable(root, entry, next_ref)
    if not next_ok:
        return {
            "decision": "block",
            "reason": next_reason,
            "path": path.relative_to(root).as_posix(),
            "expected": "reachable next_ref",
            "actual": next_ref,
        }, 1
    payload = candidate(root, entry, archived=archived)
    payload["decision"] = "recovered"
    payload["blocker_summary"] = None
    payload["source"] = {
        "registry": "contracts/active-doc-scope.yaml",
        "worklog": path.relative_to(root).as_posix(),
    }
    return payload, 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--feature", default="")
    parser.add_argument("--archived", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    registry, error = load_registry(root)
    if error:
        return emit(error, 1)
    entries = registry.get("scope_entries") or []
    if not isinstance(entries, list):
        return emit({"decision": "block", "reason": "scope_entries_invalid", "path": "contracts/active-doc-scope.yaml", "expected": "scope_entries list"}, 1)
    active = [entry for entry in entries if isinstance(entry, dict) and registry_status(entry) in ACTIVE_STATUSES]
    legacy = [entry for entry in entries if isinstance(entry, dict) and registry_status(entry) == "legacy"]
    if not args.feature:
        candidates = sort_candidates([candidate(root, entry) for entry in active])
        if not candidates:
            return emit({"decision": "block", "reason": "no_managed_features", "path": "contracts/active-doc-scope.yaml", "expected": "managed or migrated entries"}, 1)
        return emit({"decision": "candidates", "candidates": candidates})

    active_exact = exact_matches(active, args.feature)
    legacy_exact = exact_matches(legacy, args.feature)
    if active_exact and legacy_exact:
        return emit(
            {
                "decision": "choose",
                "reason": "active_and_archived_match",
                "active_candidates": sort_candidates([candidate(root, entry) for entry in active_exact]),
                "archived_candidates": sort_candidates([candidate(root, entry, archived=True) for entry in legacy_exact]),
            },
            1,
        )
    if len(active_exact) == 1:
        payload, code = recovery_payload(root, active_exact[0])
        return emit(payload, code)
    if len(active_exact) > 1:
        return emit({"decision": "choose", "reason": "multiple_active_candidates", "candidates": sort_candidates([candidate(root, entry) for entry in active_exact])}, 1)
    if legacy_exact and (args.archived or not active_exact):
        if len(legacy_exact) == 1:
            payload, code = recovery_payload(root, legacy_exact[0], archived=True)
            return emit(payload, code)
        return emit({"decision": "choose", "reason": "multiple_archived_candidates", "archived_candidates": sort_candidates([candidate(root, entry, archived=True) for entry in legacy_exact])}, 1)

    fuzzy = fuzzy_matches(active, args.feature)
    if fuzzy:
        return emit({"decision": "choose", "reason": "fuzzy_candidates", "candidates": sort_candidates([candidate(root, entry) for entry in fuzzy])}, 1)
    return emit({"decision": "block", "reason": "feature_not_found", "path": "contracts/active-doc-scope.yaml", "expected": args.feature}, 1)


if __name__ == "__main__":
    raise SystemExit(main())
