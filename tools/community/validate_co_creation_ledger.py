#!/usr/bin/env python3
"""Validate standard-chain co-creation ledger recovery artifacts."""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any

PRODUCERS = {"product-director"}
REQUIRED_STEPS = {
    "product-director": (
        "问题澄清",
        "目标、成功标准与投入边界",
        "业务语义收口",
        "范围、本期不做、可行性约束与决策理由",
        "风险与未知项",
        "Phase 规划",
        "Director Finalization",
    ),
}
LEGACY_REQUIRED_STEPS = {
    "product-director": ("D-S2", "D-S3", "D-S4", "D-S5", "D-S5.5", "D-S6", "D-G1"),
}
RESOLVED_SUPERSEDES = {
    "accepted",
    "closed",
    "rejected",
    "resolved",
    "resolved_by_user_confirmation",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--producer")
    parser.add_argument("--require-finalized", action="store_true")
    return parser.parse_args()


def validate_producer_argument(producer: str | None) -> None:
    if producer is not None and producer not in PRODUCERS:
        raise ValueError(f"unsupported co-creation ledger producer: {producer}")


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"ledger not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"invalid ledger JSON at line {exc.lineno}: {exc.msg}"
        ) from exc
    if not isinstance(data, dict):
        raise ValueError("ledger must be a JSON object")
    return data


def nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def string_list(value: Any) -> bool:
    return isinstance(value, list) and all(nonempty_string(item) for item in value)


def parse_timestamp(value: Any, path: str) -> None:
    if not nonempty_string(value):
        raise ValueError(f"{path} must be a non-empty date-time string")
    try:
        datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"{path} must be an ISO date-time string") from exc


def require_fields(data: dict[str, Any], fields: tuple[str, ...], path: str) -> None:
    missing = [field for field in fields if field not in data]
    if missing:
        raise ValueError(f"{path} missing required fields: {', '.join(missing)}")


def validate_current_state(data: dict[str, Any]) -> None:
    state = data.get("current_state")
    if not isinstance(state, dict):
        raise ValueError("current_state must be an object")
    require_fields(state, ("summary", "source_refs", "next_step"), "current_state")
    if not nonempty_string(state.get("summary")):
        raise ValueError("current_state.summary must be substantive")
    if not string_list(state.get("source_refs")):
        raise ValueError("current_state.source_refs must be a non-empty string array")
    if not nonempty_string(state.get("next_step")):
        raise ValueError("current_state.next_step must be substantive")


def validate_confirmations(
    data: dict[str, Any], producer: str, require_finalized: bool
) -> set[str]:
    confirmations = data.get("confirmations")
    if not isinstance(confirmations, list) or not confirmations:
        raise ValueError("confirmations must be a non-empty array")
    checkpoint_ids: list[str] = []
    steps: set[str] = set()
    for index, item in enumerate(confirmations):
        path = f"confirmations[{index}]"
        if not isinstance(item, dict):
            raise ValueError(f"{path} must be an object")
        require_fields(
            item,
            (
                "checkpoint_id",
                "step",
                "subject_ref",
                "confirmed_at",
                "decision_summary",
                "source_refs",
                "output_refs",
            ),
            path,
        )
        for field in ("checkpoint_id", "step", "subject_ref", "decision_summary"):
            if not nonempty_string(item.get(field)):
                raise ValueError(f"{path}.{field} must be substantive")
        steps.add(str(item["step"]))
        parse_timestamp(item.get("confirmed_at"), f"{path}.confirmed_at")
        for field in ("source_refs", "output_refs"):
            if not string_list(item.get(field)):
                raise ValueError(f"{path}.{field} must be a non-empty string array")
        checkpoint_ids.append(str(item["checkpoint_id"]))
    if len(set(checkpoint_ids)) != len(checkpoint_ids):
        raise ValueError("confirmations checkpoint_id values must be unique")
    latest = data.get("latest_checkpoint_id")
    if latest != checkpoint_ids[-1]:
        raise ValueError(
            "latest_checkpoint_id must match the last confirmation checkpoint_id"
        )
    if require_finalized:
        required_steps = set(REQUIRED_STEPS[producer])
        missing_steps = sorted(required_steps - steps)
        if missing_steps:
            legacy_steps = set(LEGACY_REQUIRED_STEPS.get(producer, ()))
            if not legacy_steps or legacy_steps - steps:
                raise ValueError(
                    f"{producer} ledger confirmations missing required steps: {', '.join(missing_steps)}"
                )
    return set(checkpoint_ids)


def validate_supersedes(
    data: dict[str, Any], checkpoint_ids: set[str], require_finalized: bool
) -> None:
    supersedes = data.get("supersedes")
    if not isinstance(supersedes, list):
        raise ValueError("supersedes must be an array")
    for index, item in enumerate(supersedes):
        path = f"supersedes[{index}]"
        if not isinstance(item, dict):
            raise ValueError(f"{path} must be an object")
        require_fields(
            item,
            (
                "supersedes_id",
                "detected_at",
                "drifted_from_checkpoint_id",
                "proposed_change",
                "resolution",
                "status",
            ),
            path,
        )
        if require_finalized and item.get("status") not in RESOLVED_SUPERSEDES:
            raise ValueError(f"{path}.status must be resolved before finalization")
        if item.get("drifted_from_checkpoint_id") not in checkpoint_ids:
            raise ValueError(
                f"{path}.drifted_from_checkpoint_id must reference a confirmation"
            )


def validate_finalization(
    data: dict[str, Any], checkpoint_ids: set[str], require_finalized: bool
) -> None:
    finalization = data.get("finalization_basis")
    if not isinstance(finalization, dict):
        raise ValueError("finalization_basis must be an object")
    if not require_finalized:
        return
    require_fields(
        finalization,
        ("status", "confirmed_at", "summary", "accepted_checkpoint_ids"),
        "finalization_basis",
    )
    if finalization.get("status") != "confirmed":
        raise ValueError("finalization_basis.status must be confirmed")
    parse_timestamp(finalization.get("confirmed_at"), "finalization_basis.confirmed_at")
    if not nonempty_string(finalization.get("summary")):
        raise ValueError("finalization_basis.summary must be substantive")
    accepted = finalization.get("accepted_checkpoint_ids")
    if not isinstance(accepted, list) or not all(
        nonempty_string(item) for item in accepted
    ):
        raise ValueError(
            "finalization_basis.accepted_checkpoint_ids must be a non-empty string array"
        )
    accepted_ids = [str(item) for item in accepted]
    unknown = sorted(set(accepted_ids) - checkpoint_ids)
    if unknown:
        raise ValueError(
            f"finalization_basis.accepted_checkpoint_ids unknown: {', '.join(unknown)}"
        )


def validate(
    data: dict[str, Any], expected_producer: str | None, require_finalized: bool
) -> None:
    require_fields(
        data,
        (
            "artifact_type",
            "schema_version",
            "producer",
            "scope_ref",
            "current_state",
            "latest_checkpoint_id",
            "confirmations",
            "open_questions",
            "supersedes",
            "handoff_refs",
            "finalization_basis",
        ),
        "ledger",
    )
    if data.get("artifact_type") != "co-creation-ledger":
        raise ValueError("artifact_type must be co-creation-ledger")
    if data.get("producer") not in PRODUCERS:
        raise ValueError("producer is unsupported")
    if expected_producer and data.get("producer") != expected_producer:
        raise ValueError(f"producer must be {expected_producer}")
    for field in ("schema_version", "scope_ref", "latest_checkpoint_id"):
        if not nonempty_string(data.get(field)):
            raise ValueError(f"{field} must be substantive")
    if not isinstance(data.get("open_questions"), list):
        raise ValueError("open_questions must be an array")
    if not string_list(data.get("handoff_refs")):
        raise ValueError("handoff_refs must be a non-empty string array")
    validate_current_state(data)
    checkpoint_ids = validate_confirmations(data, data["producer"], require_finalized)
    validate_supersedes(data, checkpoint_ids, require_finalized)
    validate_finalization(data, checkpoint_ids, require_finalized)


def main() -> None:
    args = parse_args()
    validate_producer_argument(args.producer)
    data = load_json(args.artifact)
    validate(data, args.producer, args.require_finalized)
    print(
        json.dumps(
            {"status": "PASS", "artifact": str(args.artifact)}, ensure_ascii=False
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        raise SystemExit(f"co-creation ledger validation failed: {exc}") from exc
