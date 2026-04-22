#!/usr/bin/env python3
"""Render conversation-only summaries for community skill update runs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _lines_for_sources(sources: list[dict[str, Any]]) -> list[str]:
    """Render source ref changes in a compact, reviewable form."""
    if not sources:
        return ["- No source ref changes."]
    lines: list[str] = []
    for source in sources:
        lines.append(
            f"- {source.get('name', 'unknown')}: "
            f"{source.get('current_ref', '')} -> {source.get('candidate_ref', '')}"
        )
    return lines


def _lines_for_checked_sources(sources: list[dict[str, Any]]) -> list[str]:
    """Render source refs checked during a no-update run."""
    if not sources:
        return ["- No checked source details were recorded."]
    return [
        f"- {source.get('name', 'unknown')}: {source.get('current_ref', '')}"
        for source in sources
    ]


def _lines_for_validations(validations: list[dict[str, Any]]) -> list[str]:
    """Render validation command outcomes."""
    if not validations:
        return ["- No validation results were recorded."]
    return [
        f"- {item.get('status', 'unknown')}: {item.get('command', '')}"
        for item in validations
    ]


def render_summary(result_json: Path) -> str:
    """Render a Markdown summary from an updater result JSON file."""
    data = json.loads(result_json.read_text(encoding="utf-8"))
    result = data.get("result", {})
    if result.get("status") == "blocked":
        return "\n".join(
            [
                "## Blocked",
                "",
                f"- Failed phase: {result.get('failed_phase', '')}",
                f"- Failed command: {result.get('failed_command', '')}",
                f"- Preserved worktree: {result.get('worktree_path', '')}",
                f"- Evidence: {result.get('stderr', '')}",
                "- Next action: inspect the preserved worktree and fix the failing phase before rerunning.",
                "",
            ]
        )

    sources = data.get("sources", [])
    checked_sources = data.get("checked_sources", sources)
    if result.get("status") == "current":
        return "\n".join(
            [
                "## Checked sources",
                *_lines_for_checked_sources(checked_sources),
                "",
                "## Result",
                "- No managed source updates were found.",
                "",
            ]
        )

    validations = data.get("validations", [])
    install = data.get("install", {})
    upstream = [
        f"- {source.get('name', 'unknown')}: {source.get('summary', 'No upstream summary recorded.')}"
        for source in sources
    ] or ["- No upstream changes."]
    return "\n".join(
        [
            "## Source updates",
            *_lines_for_sources(sources),
            "",
            "## Upstream changes",
            *upstream,
            "",
            "## Local adapter changes",
            "- Codex adapters were refreshed by the source-specific sync scripts when their source changed.",
            "",
            "## Validation results",
            *_lines_for_validations(validations),
            "",
            "## Install result",
            f"- {install.get('status', result.get('status', 'unknown'))}: {install.get('command', '')}",
            "",
            "## Branch and commit",
            f"- Branch: {result.get('branch', '')}",
            f"- Commit: {result.get('commit', '')}",
            "",
        ]
    )


def main() -> None:
    """Print a conversation summary from a result JSON file."""
    parser = argparse.ArgumentParser(description="Render community skill update summary.")
    parser.add_argument("--result-json", required=True, help="Updater result JSON path.")
    args = parser.parse_args()
    print(render_summary(Path(args.result_json)))


if __name__ == "__main__":
    main()
