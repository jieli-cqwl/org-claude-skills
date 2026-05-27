#!/usr/bin/env python3
"""Validate active context handoff contracts."""

from __future__ import annotations

import argparse
from pathlib import Path

from context_contract_common import (
    ACTIVE_STATUSES,
    PHASES,
    STANDARD_STAGES,
    WORKLOG_REQUIRED,
    ContractFailure,
    block,
    emit_failure,
)
from context_contract_registry import (
    entry_status,
    load_registry,
    validate_registry_entries,
)
from context_contract_repo import (
    validate_legacy_entry,
    validate_ownership,
    validate_repo,
    validate_supporting_docs,
)
from context_contract_worklog import (
    parse_latest_worklog,
    resolve_standard_ref,
    validate_worklog,
    validate_worklog_at,
    validate_worklog_fields,
    validate_worklog_refs,
)

__all__ = [
    "ACTIVE_STATUSES",
    "PHASES",
    "STANDARD_STAGES",
    "WORKLOG_REQUIRED",
    "ContractFailure",
    "block",
    "emit_failure",
    "entry_status",
    "load_registry",
    "parse_latest_worklog",
    "resolve_standard_ref",
    "validate_legacy_entry",
    "validate_ownership",
    "validate_registry_entries",
    "validate_repo",
    "validate_supporting_docs",
    "validate_worklog",
    "validate_worklog_at",
    "validate_worklog_fields",
    "validate_worklog_refs",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate_repo(args.repo_root.resolve())
    except ContractFailure as error:
        emit_failure(error)
        return 1
    except Exception as exc:
        emit_failure(
            ContractFailure(
                "validator_unavailable",
                str(args.repo_root),
                "context validator completes blocking checks",
                str(exc),
                "fix validator error before continuing",
            )
        )
        return 1
    print("[PASS] context contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
