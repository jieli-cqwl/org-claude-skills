#!/usr/bin/env python3
"""Validate the standard-chain product-delivery field decision matrix."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


EXPECTED_HEADER = [
    "ID",
    "Artifact",
    "JSONPath",
    "Decision",
    "Owner",
    "Consumer",
    "Write stage",
    "Read stage",
    "Purpose",
    "Source of truth",
    "Verification method",
    "Failure behavior",
    "Recovery owner",
    "Cleanup surface",
    "Decision evidence",
]
ALLOWED_DECISIONS = {
    "keep",
    "delete",
    "derive",
    "move",
    "rename",
    "needs-human-decision",
}
DETERMINISTIC_TOKENS = {
    "schema",
    "validator",
    "check",
    "test",
    "preflight",
    "pilot",
    "contract",
    "readiness",
    "signoff",
    "assert",
}
DETERMINISTIC_SOURCE_TOKENS = {
    "digest",
    "canonical",
    "active registry",
    "registry ref",
    "locked field",
    "source artifact",
    "artifact registry",
    "contract",
}
REQUIRED_MARKERS = {
    "$.pre_review_issue_ledger": ("$.pre_review_issue_ledger",),
    "$.user_confirmation": ("$.user_confirmation",),
    "$.active_tasks_version_ref": ("$.active_tasks_version_ref",),
    "$.baseline_plan_version_ref": ("$.baseline_plan_version_ref",),
    "$.active_plan_version_ref": ("$.active_plan_version_ref",),
    "$.chain_registry_digest": ("$.chain_registry_digest",),
    "$.runtime_evidence_matrix": ("$.runtime_evidence_matrix",),
    "$.actor_id": ("$.actor_id",),
    "$.change_source": ("$.change_source",),
    "delivery-state recovery fields": (
        "$.blocked_from_stage",
        "$.blocker_reason_code",
        "$.blocker_resolution_evidence_refs",
        "$.unblocked_by_ref",
    ),
    "QA browser evidence": ("$.browser_tool", "$.entry_url", "$.browser_evidence"),
    "review integrity": ("$.evidence_integrity",),
    "consistency runtime fields": (
        "$.evidence_refs",
        "$.audit_scope",
        "$.mode",
        "$.runtime_chain",
    ),
    "artifact-registry.json": ("artifact-registry.json",),
    "delivery-state.json": ("delivery-state.json",),
    "fix-result.json": ("fix-result.json",),
    "projection/replay exclusion": ("projection-manifest.json", "replay"),
}
TARGET_CHANGE_X001_REQUIRED_CONSUMERS = {
    "product-director",
    "product-manager",
    "design",
    "test-design",
    "tech-lead",
    "delivery-owner",
    "consistency-auditor",
}


@dataclass(frozen=True)
class Row:
    index: int
    values: dict[str, str]

    def field(self, name: str) -> str:
        return self.values[name]

    def joined_text(self) -> str:
        return " | ".join(self.values.values())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path, required=True)
    return parser.parse_args()


def split_table_row(line: str) -> list[str]:
    if not line.startswith("|") or not line.rstrip().endswith("|"):
        raise ValueError(f"invalid table row: {line}")
    return [cell.strip().strip("`") for cell in line.strip()[1:-1].split("|")]


def is_separator(cells: list[str]) -> bool:
    return all(cell and set(cell) <= {"-", ":"} for cell in cells)


def extract_matrix_rows(text: str) -> list[Row]:
    lines = text.splitlines()
    try:
        matrix_index = next(
            index for index, line in enumerate(lines) if line.strip() == "## Matrix"
        )
    except StopIteration as exc:
        raise ValueError("missing ## Matrix section") from exc

    table_lines: list[str] = []
    for line in lines[matrix_index + 1 :]:
        if not table_lines and not line.startswith("|"):
            continue
        if table_lines and not line.startswith("|"):
            break
        if line.startswith("|"):
            table_lines.append(line)

    if len(table_lines) < 3:
        raise ValueError("## Matrix must contain a markdown table")

    header = split_table_row(table_lines[0])
    if header != EXPECTED_HEADER:
        raise ValueError(
            "matrix header mismatch: expected "
            + repr(EXPECTED_HEADER)
            + ", got "
            + repr(header)
        )

    separator = split_table_row(table_lines[1])
    if len(separator) != len(EXPECTED_HEADER) or not is_separator(separator):
        raise ValueError("matrix table separator is invalid")

    rows: list[Row] = []
    for offset, line in enumerate(table_lines[2:], start=1):
        cells = split_table_row(line)
        if len(cells) != len(EXPECTED_HEADER):
            raise ValueError(
                f"matrix row {offset} has {len(cells)} cells; expected {len(EXPECTED_HEADER)}"
            )
        rows.append(Row(index=offset, values=dict(zip(EXPECTED_HEADER, cells))))
    return rows


def validate_row(row: Row) -> None:
    row_id = row.field("ID")
    if not row_id:
        raise ValueError(f"matrix row {row.index} has empty ID")
    empty_columns = [
        column for column, value in row.values.items() if not value.strip()
    ]
    if empty_columns:
        raise ValueError(f"{row_id} has empty cells: {', '.join(empty_columns)}")

    decision = row.field("Decision")
    if decision not in ALLOWED_DECISIONS:
        raise ValueError(f"{row_id} has unsupported decision: {decision}")
    if decision == "needs-human-decision":
        raise ValueError(f"{row_id} remains unresolved: needs-human-decision")

    verification = row.field("Verification method").casefold()
    if decision == "keep" and not any(
        token in verification for token in DETERMINISTIC_TOKENS
    ):
        raise ValueError(f"{row_id} keep row lacks deterministic verification method")

    if decision != "keep":
        for column in ("Cleanup surface", "Decision evidence"):
            if not row.field(column).strip():
                raise ValueError(f"{row_id} non-keep row lacks {column}")

    source = row.field("Source of truth").casefold()
    if decision == "derive" and not any(
        token in source for token in DETERMINISTIC_SOURCE_TOKENS
    ):
        raise ValueError(f"{row_id} derive row lacks deterministic source of truth")


def validate_required_markers(rows: list[Row]) -> None:
    matrix_text = "\n".join(row.joined_text() for row in rows).casefold()
    missing: list[str] = []
    for label, markers in REQUIRED_MARKERS.items():
        for marker in markers:
            if marker.casefold() not in matrix_text:
                missing.append(f"{label} missing marker {marker}")
    if missing:
        raise ValueError(
            "matrix missing required production-readiness markers: "
            + "; ".join(missing)
        )


def validate_target_change_consumers(rows: list[Row]) -> None:
    target_rows = [
        row
        for row in rows
        if row.field("ID") == "X-001"
        and "target-change.json" in row.field("Artifact")
        and "$.invalidates_refs" in row.field("JSONPath")
    ]
    if len(target_rows) != 1:
        raise ValueError(
            "matrix must contain exactly one target-change X-001 invalidation row"
        )
    consumers = {
        item.strip().casefold() for item in target_rows[0].field("Consumer").split(",")
    }
    missing = sorted(
        consumer
        for consumer in TARGET_CHANGE_X001_REQUIRED_CONSUMERS
        if consumer not in consumers
    )
    if missing:
        raise ValueError(
            "target-change X-001 consumers must include downstream rebaseline consumers: "
            + ", ".join(missing)
        )


def validate_rows(rows: list[Row]) -> None:
    seen: set[str] = set()
    for row in rows:
        validate_row(row)
        row_id = row.field("ID")
        if row_id in seen:
            raise ValueError(f"duplicate matrix ID: {row_id}")
        seen.add(row_id)
    validate_required_markers(rows)
    validate_target_change_consumers(rows)


def main() -> int:
    args = parse_args()
    rows = extract_matrix_rows(args.matrix.read_text(encoding="utf-8"))
    validate_rows(rows)
    print(f"[PASS] field decision matrix rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
