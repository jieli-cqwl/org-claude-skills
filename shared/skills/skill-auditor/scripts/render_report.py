#!/usr/bin/env python3
"""Render Markdown and HTML reports from a skill-audit JSON artifact."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
from pathlib import Path
from typing import Any


RENDERER = "skill-auditor-renderer"
RENDERER_VERSION = "1.0.0"


def canonical_hash(artifact: dict[str, Any]) -> str:
    clone = dict(artifact)
    clone["rendered_views"] = []
    payload = json.dumps(clone, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


def finding_lines(artifact: dict[str, Any]) -> str:
    lines = []
    for finding in artifact.get("findings", []):
        lines.append(
            f"- {finding.get('severity')} {finding.get('id')}: "
            f"{finding.get('file_ref', 'n/a')} -> {finding.get('recommendation', '')}"
        )
    return "\n".join(lines)


def render_markdown(artifact: dict[str, Any]) -> str:
    return (
        "# Skill Audit Report\n\n"
        f"Artifact: `{artifact.get('artifact_id')}`\n\n"
        f"Status: `{artifact.get('status')}`\n\n"
        "## Findings\n\n"
        f"{finding_lines(artifact)}\n"
    )


def render_html(artifact: dict[str, Any]) -> str:
    items = "".join(
        "<li>"
        + html.escape(f"{f.get('severity')} {f.get('id')}: {f.get('file_ref', 'n/a')} -> {f.get('recommendation', '')}")
        + "</li>"
        for f in artifact.get("findings", [])
    )
    return (
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>Skill Audit Report</title></head>"
        "<body>"
        f"<h1>Skill Audit Report</h1><p>Artifact: {html.escape(str(artifact.get('artifact_id')))}</p>"
        f"<p>Status: {html.escape(str(artifact.get('status')))}</p><ul>{items}</ul>"
        "</body></html>\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    artifact_path = Path(args.artifact)
    artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    markdown_path = out_dir / "audit-report.md"
    html_path = out_dir / "audit-report.html"
    markdown_path.write_text(render_markdown(artifact), encoding="utf-8")
    html_path.write_text(render_html(artifact), encoding="utf-8")

    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    source_hash = canonical_hash(artifact)
    artifact["rendered_views"] = [
        {
            "view_path": str(markdown_path),
            "source_artifact_id": artifact.get("artifact_id"),
            "source_artifact_hash": source_hash,
            "renderer": RENDERER,
            "renderer_version": RENDERER_VERSION,
            "generated_at": generated_at,
            "stale": False,
        },
        {
            "view_path": str(html_path),
            "source_artifact_id": artifact.get("artifact_id"),
            "source_artifact_hash": source_hash,
            "renderer": RENDERER,
            "renderer_version": RENDERER_VERSION,
            "generated_at": generated_at,
            "stale": False,
        },
    ]
    artifact_path.write_text(json.dumps(artifact, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
