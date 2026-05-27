"""Worklog and canonical ref validation for context contracts."""

from __future__ import annotations

import json
import re
from pathlib import Path

from canonical_ref_resolver import resolve_artifact_ref
from context_contract_common import STANDARD_STAGES, WORKLOG_REQUIRED, block


def parse_latest_worklog(path: Path) -> dict:
    lines = path.read_text(encoding="utf-8").splitlines()
    starts = [i for i, line in enumerate(lines) if line.startswith("## ")]
    if not starts:
        block(
            "worklog_block_missing",
            path,
            "latest ## timestamp block",
            "missing",
            "append a valid worklog block",
        )
    fields: dict[str, str] = {}
    for line in lines[starts[-1] + 1 :]:
        if line.startswith("## "):
            break
        match = re.match(r"^-\s+([A-Za-z_]+):\s*(.*)$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return fields


def validate_worklog(root: Path, entry: dict) -> None:
    feature_dir = root / str(entry["feature_path"])
    validate_worklog_at(root, feature_dir, entry)


def validate_worklog_at(root: Path, feature_dir: Path, entry: dict) -> None:
    worklog_path = feature_dir / str(entry.get("entry_ref", "worklog.md"))
    if not worklog_path.is_file():
        block(
            "entry_ref_unreachable",
            worklog_path,
            "reachable worklog entry",
            "missing",
            "restore worklog or update entry_ref",
        )
    fields = parse_latest_worklog(worklog_path)
    validate_worklog_fields(worklog_path, entry, fields)
    validate_worklog_refs(feature_dir, fields)


def validate_worklog_fields(worklog_path: Path, entry: dict, fields: dict) -> None:
    for field in WORKLOG_REQUIRED:
        if not fields.get(field):
            block(
                "worklog_required_field_missing",
                worklog_path,
                f"required field {field}",
                "missing",
                "append correction worklog record",
            )
    if fields["mode"] != entry["mode"]:
        block(
            "worklog_mode_mismatch",
            worklog_path,
            "worklog mode matches registry",
            fields["mode"],
            "append correction worklog record",
        )
    if fields["handoff_status"] not in {"doing", "blocked", "done"}:
        block(
            "worklog_enum_invalid",
            worklog_path,
            "handoff_status doing/blocked/done",
            fields["handoff_status"],
            "append correction worklog record",
        )
    if fields["stage"] not in STANDARD_STAGES:
        block(
            "worklog_enum_invalid",
            worklog_path,
            "valid standard-chain stage",
            fields["stage"],
            "append correction worklog record",
        )
    validate_status_specific_fields(worklog_path, fields)


def validate_status_specific_fields(worklog_path: Path, fields: dict) -> None:
    if fields["handoff_status"] == "blocked":
        for field in ["blocker", "waiting_on", "unblock_condition"]:
            if not fields.get(field):
                block(
                    "blocked_field_missing",
                    worklog_path,
                    f"blocked record has {field}",
                    "missing",
                    "append complete blocked record",
                )
    if fields["handoff_status"] == "done" and not fields.get("next_ref"):
        block(
            "done_next_ref_missing",
            worklog_path,
            "done record keeps next_ref",
            "missing",
            "append correction record with next_ref",
        )


def validate_worklog_refs(feature_dir: Path, fields: dict) -> None:
    resolve_standard_ref(feature_dir, fields["state_ref"], "state_ref", fields["stage"])
    resolve_standard_ref(feature_dir, fields["next_ref"], "next_ref", fields["stage"])


def resolve_standard_ref(feature_dir: Path, ref: str, field: str, stage: str) -> None:
    if not ref.startswith("canonical:") or "::" not in ref:
        block(
            "standard_ref_grammar_invalid",
            feature_dir / "worklog.md",
            "canonical:<registry>::artifact://...",
            ref,
            "use canonical active artifact ref",
        )
    registry_rel, artifact_ref = ref.removeprefix("canonical:").split("::", 1)
    registry_path = feature_dir / registry_rel
    if registry_path.name != "artifact-registry.json" or not registry_path.is_file():
        block(
            "canonical_ref_unreachable",
            feature_dir / "worklog.md",
            "reachable artifact-registry",
            ref,
            "restore artifact-registry or append corrected worklog",
        )
    try:
        artifact_rel = resolve_artifact_ref(artifact_ref, registry_path)
    except Exception as exc:
        block(
            "canonical_ref_unreachable",
            feature_dir / "worklog.md",
            "active finalized artifact ref",
            exc,
            "restore active revision or update canonical ref",
        )
    artifact_path = registry_path.parent / artifact_rel
    if not artifact_path.is_file():
        block(
            "canonical_ref_unreachable",
            feature_dir / "worklog.md",
            "reachable active artifact path",
            artifact_path,
            "restore active artifact",
        )
    validate_stage_truth(
        registry_path.parent / "delivery-state.json", feature_dir, stage
    )


def validate_stage_truth(delivery_state: Path, feature_dir: Path, stage: str) -> None:
    if not delivery_state.is_file():
        return
    state = json.loads(delivery_state.read_text(encoding="utf-8"))
    if state.get("current_stage") != stage:
        block(
            "standard_stage_drift",
            feature_dir / "worklog.md",
            "worklog.stage matches delivery-state.current_stage",
            state.get("current_stage"),
            "append correction worklog record",
        )
