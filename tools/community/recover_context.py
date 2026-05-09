#!/usr/bin/env python3
"""Recover active context handoff state from scope registry and worklog."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

from validate_context_contract import (
    ACTIVE_STATUSES,
    ContractFailure,
    block,
    emit_failure,
    entry_status,
    load_registry,
    parse_latest_worklog,
    resolve_standard_ref,
)


@dataclass
class Candidate:
    feature_path: str
    mode: str
    layout: str
    context_owner: str
    latest_worklog_at: str
    handoff_status: str
    state_ref: str
    next_ref: str
    worklog_path: Path
    entry: dict
    feature_dir: Path
    archived: bool = False
    archive_ref: str | None = None
    archived_at: str | None = None


def latest_worklog_time(path: Path) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            return line.removeprefix("## ").strip()
    return ""


def candidate_from_entry(root: Path, entry: dict, archived: bool = False) -> Candidate:
    feature_base = root / str(entry["feature_path"])
    archive_ref = entry.get("archive_ref") if archived else None
    feature_dir = root / str(archive_ref) if archive_ref else feature_base
    worklog_path = feature_dir / str(entry.get("entry_ref", "worklog.md"))
    if not worklog_path.is_file():
        block(
            "entry_ref_unreachable",
            worklog_path,
            "reachable worklog",
            "missing",
            "restore worklog or update registry entry",
        )
    fields = parse_latest_worklog(worklog_path)
    return Candidate(
        feature_path=str(entry["feature_path"]),
        mode=str(entry.get("mode", "")),
        layout=str(entry.get("layout", "")),
        context_owner=str(entry.get("context_owner") or entry.get("owner") or ""),
        latest_worklog_at=latest_worklog_time(worklog_path),
        handoff_status=str(fields.get("handoff_status", "")),
        state_ref=str(fields.get("state_ref", "")),
        next_ref=str(fields.get("next_ref", "")),
        worklog_path=worklog_path,
        entry=entry,
        feature_dir=feature_dir,
        archived=archived,
        archive_ref=str(archive_ref) if archive_ref else None,
        archived_at=str(entry.get("archived_at"))
        if archived and entry.get("archived_at")
        else None,
    )


def split_candidates(root: Path) -> tuple[list[Candidate], list[Candidate]]:
    registry = load_registry(root)
    phase = str(registry["context_contract_phase"])
    active: list[Candidate] = []
    legacy: list[Candidate] = []
    for entry in registry["scope_entries"]:
        status = entry_status(entry, phase)
        if status in ACTIVE_STATUSES:
            active.append(candidate_from_entry(root, entry))
        elif status == "legacy":
            legacy.append(candidate_from_entry(root, entry, archived=True))
    active.sort(
        key=lambda item: (parse_time_key(item.latest_worklog_at), item.feature_path),
        reverse=True,
    )
    return active, legacy


def parse_time_key(value: str) -> str:
    if re.match(r"^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}", value):
        return value
    return ""


def basename(path: str) -> str:
    return path.rstrip("/").split("/")[-1]


def exact_matches(candidates: list[Candidate], query: str) -> list[Candidate]:
    return [
        item
        for item in candidates
        if item.feature_path == query or basename(item.feature_path) == query
    ]


def fuzzy_matches(candidates: list[Candidate], query: str) -> list[Candidate]:
    return [item for item in candidates if query in item.feature_path]


def emit_candidate(item: Candidate, indent: str = "- ") -> None:
    print(f"{indent}feature_path: {item.feature_path}")
    print(f"  mode: {item.mode}")
    print(f"  layout: {item.layout}")
    print(f"  context_owner: {item.context_owner}")
    print(f"  latest_worklog_at: {item.latest_worklog_at}")
    print(f"  handoff_status: {item.handoff_status}")
    print(f"  state_ref: {item.state_ref}")
    print(f"  next_ref: {item.next_ref}")
    if item.archived:
        print(f"  archive_ref: {item.archive_ref}")
        print(f"  archived_at: {item.archived_at}")


def emit_candidate_list(candidates: list[Candidate]) -> None:
    print("candidates:")
    for item in candidates:
        emit_candidate(item)


def verify_candidate_refs(item: Candidate) -> None:
    if item.mode != "standard-chain":
        block(
            "scope_registry_schema_invalid",
            item.worklog_path,
            "standard-chain mode",
            item.mode,
            "update active scope registry",
        )
    fields = parse_latest_worklog(item.worklog_path)
    stage = fields.get("stage", "")
    resolve_standard_ref(item.feature_dir, item.state_ref, "state_ref", stage)
    resolve_standard_ref(item.feature_dir, item.next_ref, "next_ref", stage)


def emit_recovery(item: Candidate, root: Path) -> None:
    verify_candidate_refs(item)
    print(f"feature_path: {item.feature_path}")
    print(f"mode: {item.mode}")
    print(f"layout: {item.layout}")
    print(f"context_owner: {item.context_owner}")
    print(f"handoff_status: {item.handoff_status}")
    print(f"state_ref: {item.state_ref}")
    print(f"next_ref: {item.next_ref}")
    if item.archived:
        print(f"archive_ref: {item.archive_ref}")
        print(f"archived_at: {item.archived_at}")
        print(
            f"archived_entry_ref: {item.archive_ref}/{item.entry.get('entry_ref', 'worklog.md')}"
        )
    print("blocker_summary: null")
    print("source:")
    print("  registry: contracts/active-doc-scope.yaml")
    try:
        rel_worklog = item.worklog_path.relative_to(root)
    except ValueError:
        rel_worklog = item.worklog_path
    print(f"  worklog: {rel_worklog.as_posix()}")


def recover_feature(
    active: list[Candidate], legacy: list[Candidate], query: str, archived_only: bool
) -> int:
    if archived_only:
        legacy_exact = exact_matches(legacy, query)
        if len(legacy_exact) == 1:
            emit_recovery(legacy_exact[0], find_root(legacy_exact[0]))
            return 0
        print("decision: choose")
        emit_candidate_list(legacy_exact or fuzzy_matches(legacy, query))
        return 0

    active_exact = exact_matches(active, query)
    legacy_exact = exact_matches(legacy, query)
    if active_exact and legacy_exact:
        print("decision: choose")
        emit_candidate_list(active_exact + legacy_exact)
        return 0
    if len(active_exact) == 1:
        emit_recovery(active_exact[0], find_root(active_exact[0]))
        return 0
    if len(active_exact) > 1:
        print("decision: choose")
        emit_candidate_list(active_exact)
        return 0
    if len(legacy_exact) == 1:
        emit_recovery(legacy_exact[0], find_root(legacy_exact[0]))
        return 0
    if len(legacy_exact) > 1:
        print("decision: choose")
        emit_candidate_list(legacy_exact)
        return 0

    active_fuzzy = fuzzy_matches(active, query)
    if active_fuzzy:
        print("decision: choose")
        emit_candidate_list(active_fuzzy)
        return 0

    legacy_fuzzy = fuzzy_matches(legacy, query)
    if legacy_fuzzy:
        print("decision: choose")
        emit_candidate_list(legacy_fuzzy)
        return 0

    print("decision: block")
    print("reason: feature_not_found")
    print("path: contracts/active-doc-scope.yaml")
    print("expected: exact active or legacy feature match")
    print(f"actual: {query}")
    print("next_action: register feature or pass an exact managed feature_path")
    return 1


def find_root(item: Candidate) -> Path:
    parts = item.feature_path.split("/")
    if item.archived and item.archive_ref:
        archive_parts = item.archive_ref.split("/")
        return item.feature_dir.parents[len(archive_parts) - 1]
    return item.feature_dir.parents[len(parts) - 1]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--feature")
    parser.add_argument("--archived", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.repo_root.resolve()
    try:
        active, legacy = split_candidates(root)
        if args.list:
            emit_candidate_list(active)
            return 0
        if args.feature:
            return recover_feature(active, legacy, args.feature, args.archived)
        emit_candidate_list(active)
        return 0
    except ContractFailure as error:
        emit_failure(error)
        return 1
    except Exception as exc:
        emit_failure(
            ContractFailure(
                "recovery_unavailable",
                str(root),
                "recovery command completes",
                str(exc),
                "fix recovery command before continuing",
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
